import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../state/settings.dart' show sharedPrefsProvider;
import '../../share/share_inbox.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/image_picker_field.dart' show ImageItem, ImageItemThumb;
import '../common/adaptive_modal.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';
import '../goals/pit_pill.dart' show mockLine;
import '../common/window_class.dart';
import '../material/material_category.dart';
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
  });
  final ShareAction action;
  final String? pitId;
  final ShareSection? section;

  /// 官方圖冊＝分組；好看同人圖＝出處（可為 null）。
  final String? groupId;

  /// 好看同人圖的作者（trim 過，可為空）。
  final String author;

  /// 官方圖冊、好看同人圖選的 tag。
  final List<String> tagIds;

  /// 「素材庫」段選的分類（action＝addMaterial 時才有）。
  final MaterialCategory? material;
}

const _kDestKey = 'shareLastDest';
const _kMaterialKey = 'shareLastMaterial';

/// 分享進來的「加入到」bottom sheet（ShareImport，D-053／D-059／D-064）。
///
/// 視窗 ≥840（iPad 設計稿 ShareImport）改成置中的 720×760 對話框：取消／標題／張數 標題列、
/// 位置 7 欄一排；其餘欄位與手機版相同。較窄維持 bottom sheet。
Future<ShareChoice?> showShareSheet(
  BuildContext context, {
  required List<String> paths,
  String? pitId,
  ShareSection? section,
  String? groupId,
}) {
  final t = context.tokens;
  if (MediaQuery.sizeOf(context).width >= WindowClass.expandedMin) {
    return showDialog<ShareChoice>(
      context: context,
      useRootNavigator: true,
      barrierColor: const Color(0x591E1A17),
      builder: (_) => AdaptiveModalDialog(
        width: 720,
        height: 760,
        child: ShareSheet(
          paths: paths,
          initialPitId: pitId,
          initialSection: section,
          initialGroupId: groupId,
          asDialog: true,
        ),
      ),
    );
  }
  return showModalBottomSheet<ShareChoice>(
    context: context,
    // 全域的 sheet：蓋在所有分頁之上。
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ShareSheet(
      paths: paths,
      initialPitId: pitId,
      initialSection: section,
      initialGroupId: groupId,
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
  });

  final List<String> paths;

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

  /// 頂部「坑｜素材庫」切換（D-071）；預設停在上次用的那段。
  bool _toMaterial = false;
  late MaterialCategory _material;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _toMaterial = prefs?.getString(_kDestKey) == 'material';
    _material =
        MaterialCategory.values
            .where((c) => c.name == prefs?.getString(_kMaterialKey))
            .firstOrNull ??
        MaterialCategory.values.first;
    final memory = ref.read(shareMemoryProvider);
    _pitId = widget.initialPitId ?? memory.lastPit;
    _section =
        widget.initialSection ??
        ShareSection.fromKey(memory.lastSection) ??
        ShareSection.official;
    _groupId = widget.initialGroupId;
  }

  @override
  void dispose() {
    _author.dispose();
    super.dispose();
  }

  void _setDest(bool material) {
    if (material == _toMaterial) return;
    setState(() => _toMaterial = material);
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kDestKey, material ? 'material' : 'pit');
  }

  void _finishMaterial() {
    ref.read(sharedPrefsProvider)?.setString(_kMaterialKey, _material.name);
    Navigator.of(context)
        .pop(ShareChoice(ShareAction.addMaterial, material: _material));
  }

  void _finish(
    ShareAction action,
    String? pitId,
    ShareSection section,
    String? group, {
    List<String> tagIds = const [],
  }) {
    ref.read(shareMemoryProvider).save(pitId: pitId, section: section.name);
    Navigator.of(context).pop(
      ShareChoice(
        action,
        pitId: pitId,
        section: section,
        groupId: group,
        author: section == ShareSection.fan ? _author.text.trim() : '',
        tagIds: tagIds,
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
    final fanGroup = fanGroups.where((g) => g.id == _fanGroupId).firstOrNull;
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
        (section != ShareSection.official || group != null);
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
                        l.commonCountImages(widget.paths.length),
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
                      l.commonCountImages(widget.paths.length),
                      style: TextStyle(fontSize: 13, color: t.text3),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        _Thumbs(paths: widget.paths),
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
                _DestToggle(toMaterial: _toMaterial, onChanged: _setDest),
                if (_toMaterial) ...[
                  _Label(l.materialFieldCategory),
                  _ChipWrap(
                    children: [
                      for (final c in MaterialCategory.values)
                        KeyedSubtree(
                          key: ValueKey('shareMaterial-${c.name}'),
                          child: _GroupChip(
                            label: c.label(l),
                            selected: c == _material,
                            onTap: () => setState(() => _material = c),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  _Label(l.shareFieldPit),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final p in pits)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _PitChip(
                              pit: p,
                              selected: p.id == pit?.id,
                              onTap: () => setState(() {
                                if (_pitId != p.id) {
                                  _groupId = null;
                                  _fanGroupId = null;
                                  _tagIds.clear();
                                }
                                _pitId = p.id;
                              }),
                            ),
                          ),
                        _NewPitChip(
                          label: l.pitsNewTitle,
                          onTap: () => _finish(
                            ShareAction.newPit,
                            pit?.id,
                            section,
                            group?.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Label(l.shareFieldPosition),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (_, c) {
                        // 手機 4 欄、對話框 7 欄（一排），欄距 8。
                        final cols = asDialog ? 7 : 4;
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
                                  onTap: () => setState(() => _section = s),
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
                            onTap: () => setState(() => _groupId = g.id),
                          ),
                      ],
                    ),
                  ],
                  if (section == ShareSection.fan) ...[
                    const SizedBox(height: 14),
                    _Label(l.albumFieldAuthor),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
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
                      ),
                    ),
                    if (fanGroups.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Label(l.albumFieldSource),
                      _ChipWrap(
                        children: [
                          for (final g in fanGroups)
                            _GroupChip(
                              label: g.name,
                              selected: g.id == fanGroup?.id,
                              // 再點一次已選的出處＝取消（出處可留空）。
                              onTap: () => setState(
                                () => _fanGroupId = g.id == fanGroup?.id
                                    ? null
                                    : g.id,
                              ),
                            ),
                        ],
                      ),
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
          child: GestureDetector(
            onTap: _toMaterial
                ? _finishMaterial
                : canGo
                ? () => _finish(
                    section.needsForm ? ShareAction.next : ShareAction.add,
                    pit.id,
                    section,
                    groupForResult,
                    tagIds: tagIds,
                  )
                : null,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: (canGo || _toMaterial)
                    ? t.accent
                    : t.accent.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(Radii.button),
              ),
              child: Text(
                (!_toMaterial && section.needsForm) ? l.shareNext : l.shareAdd,
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(bool material, String label) {
      final on = material == toMaterial;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            key: ValueKey(material ? 'shareDestMaterial' : 'shareDestPit'),
            onTap: () => onChanged(material),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: on ? t.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2B2622)
                              .withValues(alpha: 0.12),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: on ? t.ink : t.text3,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Semantics(
        label: context.l10n.materialShareDestLabel,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: t.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              seg(false, context.l10n.shareFieldPit),
              const SizedBox(width: 2),
              seg(true, context.l10n.materialTitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Wrap(spacing: 6, runSpacing: 6, children: children),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 0, 20, 8),
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
