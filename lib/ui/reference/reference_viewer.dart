// 參考圖檢視（RefFull／RefSplit／RespRef400／RespRef900）。
//
// ═══ 給其他區塊：怎麼開 ═══
//
//   final removed = await openReferenceViewer(
//     context,
//     images: [for (final i in images) RefImage.fromAlbum(i, pitId: pitId, title: '$pitName · 官方圖冊')],
//     index: selectedIndex,
//   );
//
// - [RefImage]：一張要檢視的圖。官方圖／同人圖用 `RefImage.fromAlbum`；其他來源直接建構
//   （沒有 `album` 就沒有資料面板的動作，只顯示分類／tag／加入日期）。
// - 回傳值：檢視器裡被刪除的圖的 `RefImage.id` 集合（沒刪＝空集合）。呼叫端用來更新自己的列表。
// - 傳入的 [index] 是影片時，開的是影片參考檢視（`RefVideoViewer`，只有這一支影片）；
//   否則開圖片檢視器，列表裡的影片會被濾掉（index 會對應調整）。GIF 當圖片，會動。
// - 用該分頁自己的 Navigator（不是 rootNavigator）；頁面存在期間隱藏導覽列。
//
// ═══ 版型（RespSpec，按檢視器自己的闊度，不是整個視窗）═══
//   <600      縮圖列在底部（52）＋只有 icon 的工具列；圖片資料收進「更多」
//   600–839   縮圖列在底部＋icon＋文字工具列
//   ≥840      縮圖列在左邊直排（92／104）＋可開關的右側資料面板（250／288）＋舞台下浮動工具 pill
//
// ═══ 檢視狀態（RespSpec「最重要」）═══
//   每張圖各自記住縮放、位置、鎖定縮放、翻轉、灰階、背景（`RefViewStates` 表，純本機、不同步，
//   從不改原圖檔）；離開再進來、切 App、拉窗、轉方向都原位還原。鎖定縮放時拉窗不會重新 fit，
//   只改可視範圍，視窗中央仍對到同一個圖片位置。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/ref_view_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/preview_shell.dart' show PreviewPalette;
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'ref_actions.dart';
import 'ref_filmstrip.dart';
import 'ref_icons.dart';
import 'ref_image.dart';
import 'ref_info.dart';
import 'ref_palette.dart';
import 'ref_stage.dart';
import 'ref_toolbar.dart';
import 'ref_video_viewer.dart';
import 'ref_view_store.dart';

export 'ref_image.dart';
export 'ref_video_viewer.dart' show RefVideoViewer, RefVideoViewerPage;

/// 開啟參考圖檢視（見檔頭說明）。回傳被刪除的圖的 id。
Future<Set<String>> openReferenceViewer(
  BuildContext context, {
  required List<RefImage> images,
  required int index,
}) async {
  if (images.isEmpty) return const {};
  final i = index.clamp(0, images.length - 1);
  final current = images[i];
  final navigator = Navigator.of(context);
  if (current.isVideo) {
    final removed = await navigator.push<Set<String>>(
      MaterialPageRoute<Set<String>>(
        builder: (_) => RefVideoViewerPage(image: current),
      ),
    );
    return removed ?? const {};
  }
  // 圖片檢視器只放圖片與 GIF。
  final list = [
    for (final im in images)
      if (!im.isVideo) im,
  ];
  final start = list.indexWhere(
    (e) => e.id == current.id && e.file == current.file,
  );
  final removed = await navigator.push<Set<String>>(
    MaterialPageRoute<Set<String>>(
      builder: (_) => ReferenceViewerPage(
        images: list,
        initialIndex: start < 0 ? 0 : start,
      ),
    ),
  );
  return removed ?? const {};
}

/// 預覽頁頂欄上的「參考檢視」入口 chip（Official／FanArt 預覽面板上的樣式）。
class RefEntryChip extends StatelessWidget {
  const RefEntryChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.refviewEntry;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xB81E1B18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SvgIcon(
                    RefIcons.expand,
                    size: 14,
                    color: PreviewPalette.text,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: PreviewPalette.text,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 圖片檢視器的頁面：沒有導覽列；返回時把被刪除的圖 id 交回去。
class ReferenceViewerPage extends StatefulWidget {
  const ReferenceViewerPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<RefImage> images;
  final int initialIndex;

  @override
  State<ReferenceViewerPage> createState() => _ReferenceViewerPageState();
}

class _ReferenceViewerPageState extends State<ReferenceViewerPage>
    with HidesNavBar<ReferenceViewerPage> {
  final _removed = <String>{};

  @override
  Widget build(BuildContext context) {
    return PopScope<Set<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_removed);
      },
      child: Scaffold(
        backgroundColor: RefPalette.dark.pane,
        body: ReferenceViewer(
          images: widget.images,
          initialIndex: widget.initialIndex,
          onClose: () => Navigator.of(context).pop(_removed),
          onRemoved: _removed.add,
        ),
      ),
    );
  }
}

/// 自適應的參考圖檢視器本體（按自己的闊度切版型，見檔頭）。
///
/// 需要 Material 祖先（[ReferenceViewerPage] 的 Scaffold 即可）。
class ReferenceViewer extends ConsumerStatefulWidget {
  const ReferenceViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onClose,
    this.onRemoved,
    this.useSafeArea = true,
  });

  final List<RefImage> images;
  final int initialIndex;

  /// 點返回時呼叫；預設 `Navigator.maybePop`。
  final VoidCallback? onClose;

  /// 有圖片被刪除時呼叫（參數是 `RefImage.id`）。
  final ValueChanged<String>? onRemoved;
  final bool useSafeArea;

  @override
  ConsumerState<ReferenceViewer> createState() => _ReferenceViewerState();
}

class _ReferenceViewerState extends ConsumerState<ReferenceViewer>
    with WidgetsBindingObserver {
  late final List<RefImage> _items = [...widget.images];
  late int _index = widget.initialIndex.clamp(
    0,
    widget.images.isEmpty ? 0 : widget.images.length - 1,
  );
  late final RefViewStore _store = RefViewStore(ref.read(databaseProvider));
  final _stageKeys = <String, GlobalKey<RefStageState>>{};

  /// 目前這張圖的檢視狀態；還在讀資料庫時是 null。
  RefViewSnapshot? _snap;

  /// ≥840 才有資料面板；開關狀態記在這裡，拉窗回到窄版再拉寬仍保持。
  bool _info = true;

  RefImage get _current => _items[_index];

  GlobalKey<RefStageState> _keyOf(String file) =>
      _stageKeys.putIfAbsent(file, GlobalKey<RefStageState>.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_items.isNotEmpty) _loadCurrent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    // 切到背景（或被系統收走）前先存：回來時原位還原。
    if (_items.isNotEmpty) _stageKeys[_current.file]?.currentState?.commit();
    unawaited(_store.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_store.dispose());
    super.dispose();
  }

  void _loadCurrent() {
    final file = _current.file;
    final cached = _store.peek(file);
    if (cached != null) {
      _snap = cached;
      return;
    }
    _snap = null;
    unawaited(
      _store.load(file).then((s) {
        if (!mounted || _items.isEmpty || _current.file != file) return;
        setState(() => _snap = s);
      }),
    );
  }

  void _pick(int i) {
    if (i == _index) return;
    _stageKeys[_current.file]?.currentState?.commit();
    setState(() {
      _index = i;
      _loadCurrent();
    });
  }

  /// 舞台回報新的縮放／位置：只存檔，不重建。
  void _onStage(String file, RefViewSnapshot s) {
    _store.update(file, s);
    if (_items.isNotEmpty && _current.file == file) _snap = s;
  }

  /// 改旗標（鎖定、翻轉、灰階、背景）。先讀回舞台目前的位置，免得蓋掉還沒回報的手勢結果。
  void _mutate(RefViewSnapshot Function(RefViewSnapshot) f) {
    final file = _current.file;
    final live = _stageKeys[file]?.currentState?.currentSnapshot() ?? _snap;
    if (live == null) return;
    final next = f(live);
    _store.update(file, next);
    setState(() => _snap = next);
  }

  void _removeCurrent() {
    if (_items.isEmpty) return;
    final gone = _items.removeAt(_index);
    _stageKeys.remove(gone.file);
    widget.onRemoved?.call(gone.id);
    if (_items.isEmpty) {
      _close();
      return;
    }
    setState(() {
      if (_index >= _items.length) _index = _items.length - 1;
      _loadCurrent();
    });
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 資料面板的 tag 名稱。[watch] true＝build 中監聽（tag 改了會跟著更新）；false＝回呼裡讀一次。
  List<String> _tagNames(RefImage im, {bool watch = true}) {
    if (im.tags != null) return im.tags!;
    final a = im.album;
    final pitId = im.pitId;
    if (a == null || pitId == null || a.kind == AlbumKind.junk) return const [];
    final target = a.kind == AlbumKind.fanArt
        ? TagTarget.fanArt
        : TagTarget.official;
    final idsP = tagIdsProvider((target, a.id));
    final tagsP = tagsProvider(pitId);
    final ids =
        (watch ? ref.watch(idsP) : ref.read(idsP)).value ?? const <String>[];
    final all =
        (watch ? ref.watch(tagsP) : ref.read(tagsP)).value ?? const <Tag>[];
    final names = {for (final t in all) t.id: t.name};
    return [
      for (final id in ids)
        if (names[id] != null) names[id]!,
    ];
  }

  Future<void> _showMore(RefPalette palette) async {
    final im = _current;
    final tags = _tagNames(im, watch: false);
    final actions = buildRefActions(
      context: context,
      ref: ref,
      image: im,
      onRemoved: _removeCurrent,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.pane,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
          ),
          child: SingleChildScrollView(
            child: RefInfoContent(
              image: im,
              tags: tags,
              palette: palette,
              pushActionsDown: false,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              gap: 20,
              actions: [
                for (final a in actions)
                  RefInfoAction(
                    icon: a.icon,
                    label: a.label,
                    danger: a.danger,
                    // 先收起 sheet 再執行（刪除會再跳確認框）。
                    onTap: () {
                      Navigator.pop(ctx);
                      a.onTap();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap ?? RefViewSnapshot.initial;
    final palette = RefPalette.of(lightBg: snap.lightBg);
    final accent = context.tokens.accent;
    Widget body = ColoredBox(
      color: palette.pane,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          final cls = WindowClass.forWidth(width);
          final wide = cls.isWide;
          if (_items.isEmpty) return const SizedBox.expand();
          return DefaultTextStyle.merge(
            style: TextStyle(color: palette.fg),
            child: Column(
              children: [
                _header(palette, wide: wide),
                Expanded(
                  child: wide
                      ? _wideBody(palette, accent, snap, width)
                      : _narrowBody(palette, accent, snap, cls, width),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (widget.useSafeArea) {
      body = ColoredBox(
        color: palette.pane,
        child: SafeArea(child: body),
      );
    }
    return body;
  }

  Widget _header(RefPalette palette, {required bool wide}) {
    final l10n = context.l10n;
    final counter = '${_index + 1} / ${_items.length}';
    return Padding(
      padding: wide
          ? const EdgeInsets.fromLTRB(20, 6, 20, 10)
          : const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.commonBack,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SvgIcon(
                    RefIcons.back,
                    size: wide ? 24 : 22,
                    color: palette.fg,
                    strokeWidth: 1.9,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: wide ? 6 : 4),
          Flexible(
            child: Text(
              _current.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.fg,
                fontSize: wide ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: wide ? 8 : 12),
          Expanded(
            child: Text(
              counter,
              maxLines: 1,
              style: TextStyle(color: palette.sub, fontSize: wide ? 13 : 12),
            ),
          ),
          if (wide)
            Semantics(
              button: true,
              selected: _info,
              label: l10n.refviewPanel,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _info = !_info),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _info ? palette.activeBtn : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SvgIcon(RefIcons.panel, size: 22, color: palette.fg),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stage(
    RefPalette palette,
    RefViewSnapshot snap, {
    required bool wide,
    required Color accent,
    required BorderRadius radius,
  }) {
    final im = _current;
    final s = _snap;
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: palette.stage,
        child: s == null
            ? const SizedBox.expand()
            : RefStage(
                key: _keyOf(im.file),
                image: im,
                snapshot: s,
                onChanged: (v) => _onStage(im.file, v),
                overlayBuilder: (context, transform) => wide
                    ? RefFloatingBar(
                        transform: transform,
                        snapshot: s,
                        accent: accent,
                        onLock: _toggleLock,
                        onFlip: _toggleFlip,
                        onGray: _toggleGray,
                        onBackground: _toggleBackground,
                      )
                    : RefZoomChip(
                        transform: transform,
                        locked: s.locked,
                        onToggleLock: _toggleLock,
                      ),
              ),
      ),
    );
  }

  void _toggleLock() => _mutate((s) => s.copyWith(locked: !s.locked));
  void _toggleFlip() => _mutate((s) => s.copyWith(flipped: !s.flipped));
  void _toggleGray() => _mutate((s) => s.copyWith(gray: !s.gray));
  void _toggleBackground() => _mutate((s) => s.copyWith(lightBg: !s.lightBg));

  Widget _narrowBody(
    RefPalette palette,
    Color accent,
    RefViewSnapshot snap,
    WindowClass cls,
    double width,
  ) {
    final showLabels = cls != WindowClass.compact;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _stage(
              palette,
              snap,
              wide: false,
              accent: accent,
              radius: BorderRadius.circular(12),
            ),
          ),
        ),
        SizedBox(
          height: 68,
          child: RefFilmstrip(
            images: _items,
            index: _index,
            onPick: _pick,
            palette: palette,
            accent: accent,
          ),
        ),
        RefBottomToolbar(
          snapshot: snap,
          palette: palette,
          accent: accent,
          showLabels: showLabels,
          onLock: _toggleLock,
          onFlip: _toggleFlip,
          onGray: _toggleGray,
          onBackground: _toggleBackground,
          onMore: () => _showMore(palette),
        ),
      ],
    );
  }

  Widget _wideBody(
    RefPalette palette,
    Color accent,
    RefViewSnapshot snap,
    double width,
  ) {
    final stripW = (width * 0.087).clamp(92.0, 104.0);
    final thumb = 64 + (stripW - 92) / 12 * 8;
    final panelW = (width * 0.241).clamp(250.0, 288.0);
    final im = _current;
    return Row(
      children: [
        SizedBox(
          width: stripW,
          child: RefFilmstrip(
            images: _items,
            index: _index,
            onPick: _pick,
            palette: palette,
            accent: accent,
            vertical: true,
            thumb: thumb,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 16, right: _info ? 0 : 16),
            child: _stage(
              palette,
              snap,
              wide: true,
              accent: accent,
              radius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_info)
          SizedBox(
            width: panelW,
            child: Semantics(
              container: true,
              label: context.l10n.refviewInfoTitle,
              child: LayoutBuilder(
                builder: (context, pc) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: pc.maxHeight),
                    child: IntrinsicHeight(
                      child: RefInfoContent(
                        image: im,
                        tags: _tagNames(im),
                        palette: palette,
                        gap: panelW >= 270 ? 24 : 20,
                        padding: EdgeInsets.fromLTRB(
                          panelW >= 270 ? 20 : 18,
                          8,
                          panelW >= 270 ? 20 : 18,
                          20,
                        ),
                        actions: buildRefActions(
                          context: context,
                          ref: ref,
                          image: im,
                          onRemoved: _removeCurrent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
