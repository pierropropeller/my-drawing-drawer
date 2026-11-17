import '../common/themed_sheet.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/segment_toggle.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../data/album_queries.dart';
import '../../data/author_link.dart';
import '../../data/database.dart';
import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../state/settings.dart' show sharedPrefsProvider;
import '../../share/share_inbox.dart';
import '../../share/tweet_share.dart';
import '../../state/providers.dart';
import '../../state/sensitive.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_set_form.dart' show AlbumSetCombineRow;
import '../album/image_picker_field.dart' show ImageItem, ImageItemThumb;
import '../authors/author_pick_sheet.dart';
import '../authors/author_sync.dart' show RemoteAuthorAvatar;
import '../common/app_icons.dart';
import '../common/adaptive_modal.dart';
import '../common/app_switch.dart';
import '../common/dashed_box.dart';
import '../common/device_class.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';
import '../goals/pit_pill.dart' show mockLine;
import '../common/window_class.dart';
import 'share_icons.dart';

/// 「加入到」的七個位置。順序＝設計稿 4 欄 7 格的順序（官方圖冊、好看同人圖、推活、雜物、腦洞、摸魚、成圖，D-091）。
enum ShareSection {
  official,
  fan,
  oshi,
  junk,
  idea,
  draft,
  piece;

  /// 對應的坑內格子（淺坑只開放它開啟的格子，D-088）。
  PitSectionKey get sectionKey => PitSectionKey.values.byName(name);

  /// 草稿／腦洞／成圖／推活要先填表單，按鈕是「下一步」；其餘直接存。
  bool get needsForm =>
      this == ShareSection.draft ||
      this == ShareSection.idea ||
      this == ShareSection.piece ||
      this == ShareSection.oshi;

  /// 官方圖冊、好看同人圖有 tag。
  bool get hasTags => this == ShareSection.official || this == ShareSection.fan;

  static ShareSection? fromKey(String? key) {
    for (final s in values) {
      if (s.name == key) return s;
    }
    return null;
  }

  String label(AppLocalizations l) => switch (this) {
    official => l.pitsOfficial,
    fan => l.pitsFanArt,
    oshi => l.shareMoveOshi,
    junk => l.junkTitle,
    draft => l.goalsKindDraft,
    idea => l.goalsKindIdea,
    piece => l.goalsKindPiece,
  };

  CategoryColor color(AppTokens t, {required bool dark}) => switch (this) {
    official => t.official,
    fan => t.fanArt,
    // 設計稿 ShareImport：#ECE6F3／#6E5A92（tokens 還沒有推活色，深色版自訂）。
    oshi =>
      dark
          ? const CategoryColor(Color(0xFF302B3A), Color(0xFFB5A3D6))
          : const CategoryColor(Color(0xFFECE6F3), Color(0xFF6E5A92)),
    junk => CategoryColor(t.chipBg, t.text3),
    draft => t.draft,
    idea => t.idea,
    piece => t.piece,
  };

  (String, double) get icon => switch (this) {
    official || fan || junk => (ShareIcons.folder, 1.8),
    oshi => (ShareIcons.star, 1.8),
    draft => (ShareIcons.pen, 1.8),
    idea => (ShareIcons.bulb, 1.8),
    piece => (ShareIcons.img, 1.8),
  };
}

/// [addMaterial]＝「素材庫」段的「加入」（D-071），分類在 [ShareChoice.material]。
enum ShareAction { add, next, newPit, addMaterial }

/// sheet 的結果：按了什麼，以及當時選的坑／位置／分組。
class ShareChoice {
  const ShareChoice(
    this.action, {
    this.pitId,
    this.section,
    this.groupId,
    this.author = '',
    this.tagIds = const [],
    this.material,
    this.sensitive = false,
    this.authorId,
    this.newAuthor,
    this.sourceUrl,
    this.combine = false,
    this.paths,
  });
  final ShareAction action;

  /// 分享推文（D-158）：選的作者（已在 Drawer 的）。
  final String? authorId;

  /// 分享推文：還沒在 Drawer 的作者，加入時新增（連結 X）。
  final LinkedProfile? newAuthor;

  /// 分享推文：原文連結（推文網址）。
  final String? sourceUrl;

  /// 分享推文：2 張以上時「合成一組」。
  final bool combine;

  /// 分享推文：最後要加入的檔案（縮圖列刪過、加過圖）；一般分享是 null（用分享進來的那批）。
  final List<String>? paths;

  /// 「全部標為敏感」（D-104）：加進去的圖全部標成敏感。只有直接加入（不開表單）時才會是 true。
  final bool sensitive;
  final String? pitId;
  final ShareSection? section;

  /// 官方圖冊＝分組；好看同人圖＝出處（可為 null）。
  final String? groupId;

  /// 好看同人圖的作者（trim 過，可為空）。
  final String author;

  /// 官方圖冊、好看同人圖選的 tag。
  final List<String> tagIds;

  /// 「素材庫」段選的分類（action＝addMaterial 時才有）。
  final String? material;
}

const _kDestKey = 'shareLastDest';
const _kMaterialKey = 'shareLastMaterial';

/// 分享進來的「加入到」bottom sheet（ShareImport，D-053／D-059／D-064）。
///
/// 視窗 ≥600（iPad 設計稿 ShareImport）改成置中的 720×760 sheet：取消／標題／張數 標題列、
/// 位置 7 欄一排、坑用換行排列、作者和出處左右並排；
/// 視窗 ＜600 的 iPad（分屏約 400，ShareImport400）是全闊 page sheet：位置 4 欄一排、作者／出處上下排。
/// 手機維持 bottom sheet。
Future<ShareChoice?> showShareSheet(
  BuildContext context, {
  required List<String> paths,
  String? pitId,
  ShareSection? section,
  String? groupId,
  TweetShareController? tweet,
}) {
  if (MediaQuery.sizeOf(context).width >= WindowClass.mediumMin ||
      isTabletDevice(context)) {
    return showAdaptiveModal<ShareChoice>(
      context,
      width: 720,
      height: 760,
      barrierColor: const Color(0x591E1A17),
      sheetChrome: false,
      builder: (_, _) => ShareSheet(
        paths: paths,
        initialPitId: pitId,
        initialSection: section,
        initialGroupId: groupId,
        asDialog: true,
        tweet: tweet,
      ),
    );
  }
  return showThemedSheet<ShareChoice>(
    context: context,
    // 全域的 sheet：蓋在所有分頁之上。
    useRootNavigator: true,
    builder: (_) => ShareSheet(
      paths: paths,
      initialPitId: pitId,
      initialSection: section,
      initialGroupId: groupId,
      tweet: tweet,
    ),
  );
}

class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({
    super.key,
    required this.paths,
    this.initialPitId,
    this.initialSection,
    this.initialGroupId,
    this.asDialog = false,
    this.tweet,
  });

  final List<String> paths;

  /// 從推文分享進來（D-158）：讀取中／讀不到／可加入，縮圖可刪可加，作者自動帶。
  final TweetShareController? tweet;

  /// 畫成置中對話框的內容（iPad）：沒有拖曳條、不依鍵盤縮高，位置 7 欄。
  final bool asDialog;

  /// 沒指定就用上一次用過的坑／位置。
  final String? initialPitId;
  final ShareSection? initialSection;
  final String? initialGroupId;

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late String? _pitId;
  late ShareSection _section;
  String? _groupId; // 官方圖冊的分組
  String? _fanGroupId; // 好看同人圖的出處（可不選）
  final Set<String> _tagIds = {};
  final _author = TextEditingController();

  /// 「全部標為敏感」（D-104）；目標坑有開敏感內容（素材庫：總開關開著）才出現。
  bool _sensitive = false;

  /// 頂部「坑｜素材庫」切換（D-071）；預設停在上次用的那段。
  bool _toMaterial = false;

  /// 選的分類 id；還沒選（或記住的分類已刪）時用第一個分類。
  String? _material;

  // ---- 分享推文（D-158） ----
  /// 選的作者（已在 Drawer 的）。
  String? _authorId;

  /// 推文作者還沒在 Drawer：預設加入時新增（「新作者」）；自己換了作者就不新增。
  bool _newAuthorPending = true;

  /// 自己點過出處（不再自動選「推特」）。
  bool _sourceTouched = false;

  /// 預設合成一組。
  bool _combine = true;

  /// 推文讀到後的預設（作者、坑、位置）已經套用。
  bool _tweetApplied = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _toMaterial = prefs?.getString(_kDestKey) == 'material';
    final saved = prefs?.getString(_kMaterialKey);
    // 舊版記的是分類的英文名（clothing…），新版記分類 id。
    _material = saved == null || saved.contains('-') ? saved : 'mcat-$saved';
    final memory = ref.read(shareMemoryProvider);
    _pitId = widget.initialPitId ?? memory.lastPit;
    _section =
        widget.initialSection ??
        ShareSection.fromKey(memory.lastSection) ??
        ShareSection.official;
    _groupId = widget.initialGroupId;
    final tweet = widget.tweet;
    if (tweet != null) {
      // 推文的圖預設進好看同人圖（開新坑回來時沿用原本選的位置）。
      _toMaterial = false;
      _section = widget.initialSection ?? ShareSection.fan;
      tweet.addListener(_onTweet);
      _applyTweet();
    }
  }

  void _onTweet() {
    if (!mounted) return;
    setState(_applyTweet);
  }

  /// 推文讀到時套用預設：作者已在 Drawer → 選他、坑＝他最近加圖的坑；新作者 → 坑照一般分享的預設。
  void _applyTweet() {
    final tweet = widget.tweet!;
    if (_tweetApplied || tweet.status != TweetShareStatus.ready) return;
    _tweetApplied = true;
    _authorId = tweet.author?.id;
    _newAuthorPending = tweet.author == null;
    final pit = tweet.authorPitId;
    if (widget.initialPitId == null && pit != null) _pitId = pit;
  }

  @override
  void dispose() {
    widget.tweet?.removeListener(_onTweet);
    _author.dispose();
    super.dispose();
  }

  Future<void> _addImages() async {
    final files = await ref.read(imagePickerProvider)(context);
    if (!mounted || files.isEmpty) return;
    widget.tweet?.addAll([for (final f in files) f.path]);
  }

  Future<void> _pickAuthor() async {
    final r = await showAuthorPickSheet(context, selectedId: _authorId);
    if (r == null || !mounted) return;
    setState(() {
      _authorId = r.id;
      _newAuthorPending = false;
    });
  }

  void _setDest(bool material) {
    if (material == _toMaterial) return;
    setState(() => _toMaterial = material);
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kDestKey, material ? 'material' : 'pit');
  }

  /// 目前的分類：記住的那個還在就用它，不然用第一個。
  String? _materialIn(List<InspoCategory> cats) =>
      cats.any((c) => c.id == _material) ? _material : cats.firstOrNull?.id;

  void _finishMaterial() {
    final id = _materialIn(ref.read(inspoCategoriesProvider).value ?? const []);
    if (id == null) return;
    ref.read(sharedPrefsProvider)?.setString(_kMaterialKey, id);
    Navigator.of(context).pop(
      ShareChoice(
        ShareAction.addMaterial,
        material: id,
        paths: widget.tweet == null ? null : List.of(widget.tweet!.paths),
        sensitive: _sensitive && ref.read(sensitiveMarkingProvider(null)),
      ),
    );
  }

  void _finish(
    ShareAction action,
    String? pitId,
    ShareSection section,
    String? group, {
    List<String> tagIds = const [],
    bool sensitive = false,
  }) {
    final tweet = widget.tweet;
    final info = tweet?.info;
    // 分享推文時不記成「上次用的坑」：坑是依作者自動選的。
    if (tweet == null) {
      ref.read(shareMemoryProvider).save(pitId: pitId, section: section.name);
    }
    final fan = section == ShareSection.fan;
    final newAuthor =
        fan && info != null && _authorId == null && _newAuthorPending
        ? info.author
        : null;
    final paths = tweet?.paths;
    Navigator.of(context).pop(
      ShareChoice(
        action,
        pitId: pitId,
        section: section,
        groupId: group,
        author: tweet != null
            ? (newAuthor?.name ?? '')
            : fan
            ? _author.text.trim()
            : '',
        tagIds: tagIds,
        sensitive: sensitive,
        authorId: tweet != null && fan ? _authorId : null,
        newAuthor: newAuthor,
        sourceUrl: fan ? info?.url : null,
        combine:
            paths != null &&
            paths.length > 1 &&
            _combine &&
            (fan || section == ShareSection.official),
        paths: paths == null ? null : List.of(paths),
      ),
    );
  }

  Future<void> _newTag(String pitId) async {
    final name = await promptText(context, title: context.l10n.tagsAdd);
    if (name == null || !mounted) return;
    final id = await ref.read(databaseProvider).createTag(pitId, name);
    if (mounted) setState(() => _tagIds.add(id));
  }

  OutlineInputBorder _fieldBorder(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: mockLine(context)),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 現坑＋淺坑；封存坑不列（D-088）。
    final pits = ref.watch(selectablePitsProvider).value ?? const <Pit>[];
    final cats = ref.watch(inspoCategoriesProvider).value ?? const [];
    // 選中的坑不在列表（已封存、還沒載入）時退回第一個。
    final pit =
        pits.where((p) => p.id == _pitId).firstOrNull ?? pits.firstOrNull;
    // 沒開啟雜物的坑不列雜物（和「移動到」一致）；淺坑只列它開啟的格子。
    // 選到的位置不在清單裡就退回第一個。
    final sections = [
      for (final s in ShareSection.values)
        if (pit == null
            ? s != ShareSection.junk
            : pit.sectionOpen(s.sectionKey))
          s,
    ];
    final section = sections.contains(_section)
        ? _section
        : (sections.firstOrNull ?? ShareSection.official);
    final groups = pit == null || section != ShareSection.official
        ? const <OfficialGroup>[]
        : ref.watch(groupsProvider((pit.id, 'official'))).value ?? const [];
    final group =
        groups.where((g) => g.id == _groupId).firstOrNull ?? groups.firstOrNull;
    final fanGroups = pit == null || section != ShareSection.fan
        ? const <OfficialGroup>[]
        : ref.watch(groupsProvider((pit.id, 'fan'))).value ?? const [];
    final tweet = widget.tweet;
    final tweetStatus = tweet?.status;
    final paths = tweet?.paths ?? widget.paths;
    // 分享推文：出處沒自己點過時，自動選名字是「推特」「Twitter」「X」的那個。
    final fanGroup = tweet != null && !_sourceTouched && _fanGroupId == null
        ? fanGroups.where((g) => _isTwitterSource(g.name)).firstOrNull
        : fanGroups.where((g) => g.id == _fanGroupId).firstOrNull;
    final tags = pit == null || !section.hasTags
        ? const <Tag>[]
        : ref.watch(tagsProvider(pit.id)).value ?? const [];
    final tagIds = [
      for (final tag in tags)
        if (_tagIds.contains(tag.id)) tag.id,
    ];
    final canGo =
        pit != null &&
        sections.isNotEmpty &&
        (section != ShareSection.official || group != null) &&
        (tweet == null ||
            (tweetStatus == TweetShareStatus.ready && paths.isNotEmpty));
    // 「全部標為敏感」（D-104）：目標坑有開敏感內容；素材庫只看總開關。要開表單的位置（摸魚、腦洞、成圖、推活）
    // 在表單裡標，這裡不放。
    final showSensitive = _toMaterial
        ? ref.watch(sensitiveMarkingProvider(null))
        : pit != null &&
              !section.needsForm &&
              ref.watch(sensitiveMarkingProvider(pit.id));
    final groupForResult = switch (section) {
      ShareSection.official => group?.id,
      ShareSection.fan => fanGroup?.id,
      _ => null,
    };

    // 最高 88% 螢幕（D-064）；鍵盤出來時再讓出空間。
    final maxHeight = math.min(
      media.size.height * 0.88,
      media.size.height - media.viewInsets.bottom - media.padding.top,
    );
    final asDialog = widget.asDialog;
    // 彈出頁在窄視窗（＜600，ShareImport400）是 page sheet。
    final narrow = asDialog && AdaptiveModalScope.sheetOf(context);
    final pitChips = <Widget>[
      for (final p in pits)
        _PitChip(
          pit: p,
          selected: p.id == pit?.id,
          onTap: () => setState(() {
            if (_pitId != p.id) {
              _groupId = null;
              _fanGroupId = null;
              _sourceTouched = false;
              _tagIds.clear();
            }
            _pitId = p.id;
          }),
        ),
    ];
    final authorField = TextField(
      key: const ValueKey('shareAuthor'),
      controller: _author,
      style: TextStyle(fontSize: 15, color: t.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: _fieldBorder(context),
        enabledBorder: _fieldBorder(context),
        focusedBorder: _fieldBorder(context),
      ),
    );
    final Widget authorInput = tweet == null
        ? authorField
        : (_authorId == null && _newAuthorPending && tweet.info != null)
        ? _NewAuthorRow(profile: tweet.info!.author, onTap: _pickAuthor)
        : AuthorField(
            authorId: _authorId,
            onChanged: (id) => setState(() {
              _authorId = id;
              _newAuthorPending = false;
            }),
          );
    final sourceChips = <Widget>[
      for (final g in fanGroups)
        _GroupChip(
          label: g.name,
          selected: g.id == fanGroup?.id,
          // 再點一次已選的出處＝取消（出處可留空）。
          onTap: () => setState(() {
            _sourceTouched = true;
            _fanGroupId = g.id == fanGroup?.id ? null : g.id;
          }),
        ),
    ];
    final newPitChip = _NewPitChip(
      label: l.pitsNewTitle,
      onTap: () => _finish(ShareAction.newPit, pit?.id, section, group?.id),
    );
    final sheet = Column(
      mainAxisSize: asDialog ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asDialog)
          // 取消／襯線標題／張數（ShareImport：64 高）。
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: t.text2,
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                    child: Text(l.commonCancel),
                  ),
                  Expanded(
                    child: Text(
                      l.ipadformsShareTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 64),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        tweet != null && tweetStatus != TweetShareStatus.ready
                            ? ''
                            : l.commonCountImages(paths.length),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 13, color: t.text3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // 固定的頂部：拖曳條、標題＋張數、縮圖列。
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.shareTitle,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      tweet != null && tweetStatus != TweetShareStatus.ready
                          ? ''
                          : l.commonCountImages(paths.length),
                      style: TextStyle(fontSize: 13, color: t.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        if (tweet == null)
          _Thumbs(paths: widget.paths)
        else if (tweetStatus == TweetShareStatus.loading)
          const _SkeletonThumbs()
        else if (tweetStatus == TweetShareStatus.ready)
          _EditableThumbs(
            paths: paths,
            onRemove: tweet.remove,
            onAdd: _addImages,
          ),
        Divider(height: 1, thickness: 1, color: t.border),
        // 可捲動的中間。
        Flexible(
          fit: asDialog ? FlexFit.tight : FlexFit.loose,
          child: SingleChildScrollView(
            key: const ValueKey('shareScroll'),
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tweet != null)
                  _TweetCard(
                    url: tweet.displayUrl,
                    loading: tweetStatus == TweetShareStatus.loading,
                  ),
                if (tweetStatus == TweetShareStatus.failed)
                  _TweetFail(onRetry: tweet!.load)
                else ...[
                  _DestToggle(toMaterial: _toMaterial, onChanged: _setDest),
                  // 讀取推文中：下面整塊淡掉、不能點（設計稿 opacity .45）。
                  _Dimmed(
                    dimmed: tweetStatus == TweetShareStatus.loading,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_toMaterial) ...[
                          _Label(l.materialFieldCategory),
                          _ChipWrap(
                            children: [
                              for (final c in cats)
                                KeyedSubtree(
                                  key: ValueKey('shareMaterial-${c.id}'),
                                  child: _GroupChip(
                                    label: c.name,
                                    selected: c.id == _materialIn(cats),
                                    onTap: () =>
                                        setState(() => _material = c.id),
                                  ),
                                ),
                            ],
                          ),
                        ] else ...[
                          _Label(l.shareFieldPit),
                          if (asDialog)
                            // 對話框／page sheet：坑換行排列（ShareImport／ShareImport400）。
                            _ChipWrap(children: [...pitChips, newPitChip])
                          else
                            SizedBox(
                              height: 38,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                children: [
                                  for (final c in pitChips)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: c,
                                    ),
                                  newPitChip,
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          _Label(l.shareFieldPosition),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: LayoutBuilder(
                              builder: (_, c) {
                                // 手機和 page sheet 4 欄、對話框 7 欄（一排），欄距 8。
                                final cols = asDialog && !narrow ? 7 : 4;
                                final w = (c.maxWidth - 8 * (cols - 1)) / cols;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final s in sections)
                                      SizedBox(
                                        width: w,
                                        child: _SectionCell(
                                          section: s,
                                          dark: dark,
                                          selected: s == section,
                                          onTap: () =>
                                              setState(() => _section = s),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (section == ShareSection.official &&
                              groups.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _Label(l.albumGroupLabel),
                            _ChipWrap(
                              children: [
                                for (final g in groups)
                                  _GroupChip(
                                    label: g.name,
                                    selected: g.id == group?.id,
                                    onTap: () =>
                                        setState(() => _groupId = g.id),
                                  ),
                              ],
                            ),
                          ],
                          if (section == ShareSection.fan) ...[
                            const SizedBox(height: 14),
                            if (asDialog && !narrow)
                              // 對話框（ShareImport）：作者 220 寬在左、出處在右並排。
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 220,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _Label(l.albumFieldAuthor, left: 2),
                                          authorInput,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _Label(l.albumFieldSource, left: 2),
                                          _ChipWrap(
                                            pad: false,
                                            children: sourceChips,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              // 手機和 page sheet（ShareImport400）：作者、出處上下排。
                              _Label(l.albumFieldAuthor),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: authorInput,
                              ),
                              if (fanGroups.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _Label(l.albumFieldSource),
                                _ChipWrap(children: sourceChips),
                              ],
                            ],
                          ],
                          if (section.hasTags && pit != null) ...[
                            const SizedBox(height: 12),
                            _Label(l.shareMoveTag),
                            _ChipWrap(
                              children: [
                                for (final tag in tags)
                                  _GroupChip(
                                    label: '#${tag.name}',
                                    selected: _tagIds.contains(tag.id),
                                    onTap: () => setState(() {
                                      if (!_tagIds.remove(tag.id)) {
                                        _tagIds.add(tag.id);
                                      }
                                    }),
                                  ),
                                DashedAddChip(
                                  semanticLabel: l.tagsAdd,
                                  onTap: () => _newTag(pit.id),
                                ),
                              ],
                            ),
                          ],
                        ],
                        // 分享推文 2 張以上：合成一組（預設開，和新增頁同一列）。
                        if (tweet != null &&
                            !_toMaterial &&
                            paths.length > 1 &&
                            (section == ShareSection.fan ||
                                section == ShareSection.official))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AlbumSetCombineRow(
                              value: _combine,
                              onChanged: (v) => setState(() => _combine = v),
                            ),
                          ),
                        if (showSensitive)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: _SensitiveRow(
                              value: _sensitive,
                              onChanged: (v) => setState(() => _sensitive = v),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // 固定的底部按鈕。
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            math.max(24, media.padding.bottom),
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: tweetStatus == TweetShareStatus.failed
              ? _CloseButton(onTap: () => Navigator.of(context).pop())
              : GestureDetector(
                  onTap: tweet != null && tweetStatus != TweetShareStatus.ready
                      ? null
                      : _toMaterial
                      ? (tweet != null && paths.isEmpty
                            ? null
                            : _finishMaterial)
                      : canGo
                      ? () => _finish(
                          section.needsForm
                              ? ShareAction.next
                              : ShareAction.add,
                          pit.id,
                          section,
                          groupForResult,
                          tagIds: tagIds,
                          sensitive: showSensitive && _sensitive,
                        )
                      : null,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color:
                          (canGo ||
                              (_toMaterial &&
                                  (tweet == null ||
                                      (tweetStatus == TweetShareStatus.ready &&
                                          paths.isNotEmpty))))
                          ? t.accent
                          : t.accent.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                    child: Text(
                      (!_toMaterial && section.needsForm)
                          ? l.shareNext
                          : l.shareAdd,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
    if (asDialog) return sheet;
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: sheet,
      ),
    );
  }
}

/// 頂部「坑｜素材庫」兩段切換（ShareImport）：底色 chipBg、圓角 12，選中＝白底＋淡影。
class _DestToggle extends StatelessWidget {
  const _DestToggle({required this.toMaterial, required this.onChanged});
  final bool toMaterial;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: SegmentToggle(
      labels: [context.l10n.shareFieldPit, context.l10n.materialTitle],
      selected: toMaterial ? 1 : 0,
      onChanged: (i) => onChanged(i == 1),
      segmentKeys: const [
        ValueKey('shareDestPit'),
        ValueKey('shareDestMaterial'),
      ],
      semanticsLabel: context.l10n.materialShareDestLabel,
    ),
  );
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children, this.pad = true});
  final List<Widget> children;

  /// 左右各留 20（單獨一列時）；放進別的版面裡時傳 false。
  final bool pad;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: pad ? 20 : 0),
    child: Wrap(spacing: 6, runSpacing: 6, children: children),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.left = 22});
  final String text;
  final double left;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(left, 0, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}

/// 分享進來的縮圖列（60×60，圓角 10，一排橫向捲動，不論幾張）。
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          key: const ValueKey('shareThumbs'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: paths.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 60,
              height: 60,
              // GIF／影片（D-080）：靜態第一格＋小標；圖片維持原樣。
              child: mediaKindFromExtension(paths[i]) != MediaKind.image
                  ? ImageItemThumb(
                      ImageItem.picked(XFile(paths[i])),
                      key: ValueKey('shareThumb$i'),
                      cacheWidth: 180,
                    )
                  : Image.file(
                      File(paths[i]),
                      key: ValueKey('shareThumb$i'),
                      fit: BoxFit.cover,
                      cacheWidth: 180,
                      errorBuilder: (_, _, _) => Container(
                        color: t.chipBg,
                        alignment: Alignment.center,
                        child: SvgIcon(
                          ShareIcons.img,
                          size: 18,
                          color: t.text4,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 坑 chip：文件夾 icon ＋ 坑名；選中＝主色底白字（同目標卡上的坑標籤）。
class _PitChip extends StatelessWidget {
  const _PitChip({
    required this.pit,
    required this.selected,
    required this.onTap,
  });
  final Pit pit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? Colors.white : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.fromLTRB(11, 7, 14, 7),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.surface,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: selected ? t.accent : t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(ShareIcons.folder, size: 16, color: fg, strokeWidth: 1.8),
              const SizedBox(width: 6),
              Text(
                pit.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewPitChip extends StatelessWidget {
  const _NewPitChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: DashedBox(
          color: t.dashed,
          radius: Radii.chip,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                ShareIcons.plus,
                size: 14,
                color: t.dashedText,
                strokeWidth: 2,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: t.dashedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCell extends StatelessWidget {
  const _SectionCell({
    required this.section,
    required this.dark,
    required this.selected,
    required this.onTap,
  });
  final ShareSection section;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = section.color(t, dark: dark);
    final (icon, stroke) = section.icon;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 9),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: SvgIcon(
                  icon,
                  size: 19,
                  color: c.fg,
                  strokeWidth: stroke,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                section.label(context.l10n),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.accent : t.surface,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: selected ? t.accent : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : t.text2,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 「全部標為敏感」一行（D-104）：白底圓角卡＋開關；加進去的圖全部標成敏感。
class _SensitiveRow extends StatelessWidget {
  const _SensitiveRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      key: const ValueKey('shareSensitiveRow'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.sensitiveMarkAll,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AppSwitch(
            key: const ValueKey('shareSensitiveSwitch'),
            value: value,
            semanticLabel: context.l10n.sensitiveMarkAll,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

bool _isTwitterSource(String name) {
  final n = name.trim().toLowerCase();
  return n == '推特' || n == 'twitter' || n == 'x' || n == 'x（推特）';
}

/// 讀取推文中時整塊淡掉、不能點。
class _Dimmed extends StatelessWidget {
  const _Dimmed({required this.dimmed, required this.child});
  final bool dimmed;
  final Widget child;

  @override
  Widget build(BuildContext context) => dimmed
      ? IgnorePointer(child: Opacity(opacity: 0.45, child: child))
      : child;
}

/// 推文卡片（TweetShare*）：X 標＋網址（＋讀取中）。
class _TweetCard extends StatelessWidget {
  const _TweetCard({required this.url, required this.loading});
  final String url;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      key: const ValueKey('tweetCard'),
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.ink,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              'X',
              style: TextStyle(
                color: t.surface,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: t.text2),
            ),
          ),
          if (loading) ...[
            const SizedBox(width: 8),
            const _Spinner(),
            const SizedBox(width: 5),
            Text(
              context.l10n.tweetshareLoading,
              style: TextStyle(fontSize: 12, color: t.dashedText),
            ),
          ],
        ],
      ),
    );
  }
}

/// 讀取中的轉圈（設計稿：3/4 圓弧，#a58c6a）。
class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _c,
    child: SvgIcon(
      ShareIcons.spinner,
      size: 16,
      color: context.tokens.dashedText,
      strokeWidth: 2.2,
    ),
  );
}

/// 讀不到推文（TweetShareFail）。
class _TweetFail extends StatelessWidget {
  const _TweetFail({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      key: const ValueKey('tweetFail'),
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 36),
      child: Column(
        children: [
          SvgIcon(
            ShareIcons.warn,
            size: 28,
            color: const Color(0xFFB84B38),
            strokeWidth: 1.8,
          ),
          const SizedBox(height: 10),
          Text(
            l.tweetshareFailTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            l.tweetshareFailBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.text3, height: 1.7),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('tweetRetry'),
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: t.accent,
              backgroundColor: t.surface,
              side: BorderSide(color: t.accent),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 9),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l.commonRetry),
          ),
        ],
      ),
    );
  }
}

/// 讀不到推文時的底部「關閉」（淺底深字）。
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: t.chipBg,
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        child: Text(
          context.l10n.commonClose,
          style: TextStyle(
            color: t.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 讀取中的縮圖位置（4 格淺色方塊）。
class _SkeletonThumbs extends StatelessWidget {
  const _SkeletonThumbs();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
        ],
      ),
    );
  }
}

/// 分享推文的縮圖列：每張右上角 ✕ 可刪，最後一格虛線「＋」再加圖（同新增頁）。
class _EditableThumbs extends StatelessWidget {
  const _EditableThumbs({
    required this.paths,
    required this.onRemove,
    required this.onAdd,
  });
  final List<String> paths;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return SizedBox(
      height: 78,
      child: ListView(
        key: const ValueKey('shareThumbs'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
        children: [
          for (final (i, p) in paths.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: ImageItemThumb(
                        ImageItem.picked(XFile(p)),
                        key: ValueKey('shareThumb$i'),
                        cacheWidth: 180,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Semantics(
                      button: true,
                      label: l.albumRemoveImage,
                      child: GestureDetector(
                        key: ValueKey('shareThumbRemove$i'),
                        onTap: () => onRemove(p),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: t.ground, width: 2),
                          ),
                          child: SvgIcon(
                            ShareIcons.close,
                            size: 11,
                            color: t.surface,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Semantics(
            button: true,
            label: l.albumAddImage,
            child: GestureDetector(
              key: const ValueKey('shareThumbAdd'),
              onTap: onAdd,
              child: DashedBox(
                color: t.dashed,
                radius: 10,
                child: SizedBox(
                  width: 57,
                  height: 57,
                  child: Center(
                    child: SvgIcon(
                      ShareIcons.plus,
                      size: 22,
                      color: t.dashedText,
                      strokeWidth: 1.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 推文作者還沒在 Drawer（TweetShareNewAuthor）：平台頭像、名字、@帳號、「新作者」標、＞。
class _NewAuthorRow extends StatelessWidget {
  const _NewAuthorRow({required this.profile, required this.onTap});
  final LinkedProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.field),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('tweetNewAuthor'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              RemoteAuthorAvatar(
                url: profile.avatarUrl,
                name: profile.name,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      '@${profile.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: t.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBE7E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.tweetshareNewAuthor,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB84B38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgIcon(
                AppIcons.chevronRight,
                size: 18,
                strokeWidth: 2,
                color: const Color(0xFFB7ADA0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
