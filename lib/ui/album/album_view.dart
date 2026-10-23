import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/junk_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../state/sensitive.dart';
import '../common/sensitive_actions.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../reference/reference_viewer.dart';
import 'album_actions.dart';
import 'album_icons.dart';
import 'album_image.dart';
import 'image_masonry.dart';
import 'image_preview_page.dart';
import 'ipadlists_icons.dart';
import 'move_sheet.dart';
import 'tag_batch_sheet.dart';
import 'wide_layout.dart';

/// 寬版預覽面板的內容建構器：[image] 目前選取的圖，[openReference] 開參考檢視（`openReferenceViewer`），
/// [dismiss] 圖被刪掉後關閉面板。
typedef AlbumPanelBuilder = Widget Function(
  BuildContext context,
  AlbumImage image,
  VoidCallback openReference,
  VoidCallback dismiss,
);

/// 官方圖冊、同人圖、雜物共用：列表＋長按多選（下載／移動／tag／刪除，雜物沒有 tag、多一個分享）＋點擊預覽＋新增按鈕。
/// 瀏覽時有底部導覽列，進入多選就隱藏（OfficialSelect／JunkSelect 沒畫 `<nav>`）。
class AlbumView extends ConsumerStatefulWidget {
  const AlbumView({
    super.key,
    required this.pitId,
    required this.title,
    required this.images,
    required this.emptyLabel,
    required this.emptyColor,
    required this.onAdd,
    required this.onDelete,
    this.emptySvg,
    this.emptyIcon,
    this.emptyAction,
    this.total,
    this.filter,
    this.appBarActions = const [],
    this.searchAction,
    this.cell,
    this.squares = false,
    this.shareInSelect = false,
    this.previewBuilder,
    this.panelBuilder,
    this.sectionTabs,
  });

  /// 這個列表是哪一格；多選的「移動」要用。省略就沒有「移動」。
  final AlbumCell? cell;

  /// true＝3 欄正方形純圖格（雜物），false＝2 欄瀑布流。
  final bool squares;

  /// 多選底部多一個「分享」（雜物）。
  final bool shareInSelect;

  /// 點圖開啟的預覽頁；省略＝官方圖冊的 [ImagePreviewPage]。
  final Widget Function(List<AlbumImage> images, int index)? previewBuilder;

  /// 平板的預覽面板（官方圖冊、同人圖才有）：≥840 固定在右側，600–839 點圖彈出底部 sheet，
  /// ＜600 省略效果＝照舊進全螢幕預覽。
  final AlbumPanelBuilder? panelBuilder;

  /// 標題列下方（內容之上）的坑內分區 tab。
  /// 由 Official／FanArt 頁傳入 `PitSectionTabBar`（lib/ui/pits/pit_section_tabs.dart）；＜600 它自己不畫。
  final Widget? sectionTabs;

  final String pitId;
  final String title;
  final List<AlbumImage> images;
  final String emptyLabel;

  /// 空白頁 icon：優先用設計稿 SVG 圖形。
  final String? emptySvg;
  final IconData? emptyIcon;
  final String? emptyAction;
  final CategoryColor emptyColor;
  final VoidCallback onAdd;
  final Future<void> Function(List<AlbumImage> images) onDelete;

  /// 這個相簿的總張數（標題列右側「48 張」）；省略時用目前列出的張數。
  /// 為 0 時顯示空白頁（沒有篩選列與右下新增鈕，照 OfficialEmpty）。
  final int? total;

  /// 顯示在清單上方的篩選 chips。
  final Widget? filter;
  final List<Widget> appBarActions;

  /// 標題列最右（張數之後）的搜尋 icon（D-043）；省略＝沒有。
  final Widget? searchAction;

  @override
  ConsumerState<AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends ConsumerState<AlbumView>
    with HidesNavBar<AlbumView> {
  // 瀏覽時有導覽列；進入多選才隱藏（build 時依 _selecting 同步）。
  @override
  bool get hidesNavBarOnOpen => false;

  bool _selecting = false;
  final Set<String> _selected = {};

  /// 寬版預覽面板目前顯示的圖（狀態放在 State，拉窗不會丟）。
  String? _panelId;

  void _toggle(AlbumImage im) {
    setState(() {
      if (!_selected.remove(im.id)) _selected.add(im.id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _exit() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  bool get _allSelected =>
      widget.images.isNotEmpty && _selected.length >= widget.images.length;

  void _toggleAll() => setState(() {
    if (_allSelected) {
      _selected.clear();
      _selecting = false;
    } else {
      _selected
        ..clear()
        ..addAll(widget.images.map((i) => i.id));
    }
  });

  List<AlbumImage> get _picked =>
      widget.images.where((i) => _selected.contains(i.id)).toList();

  Future<void> _download() async {
    if (_selected.isEmpty) return;
    final n = await downloadImages(ref, _picked);
    if (!mounted) return;
    showSnack(
      context,
      n > 0
          ? context.l10n.albumSavedCountToGallery(n)
          : context.l10n.albumSaveFailed,
    );
    _exit();
  }

  Future<void> _share() async {
    if (_selected.isEmpty) return;
    await shareImages(ref, _picked);
  }

  Future<void> _move() async {
    final cell = widget.cell;
    if (cell == null || _selected.isEmpty) return;
    final picked = _picked;
    // 所選圖都在同一個分組時預選它。
    final groups = {for (final p in picked) p.groupId};
    final target = await showMoveSheet(
      context,
      pitId: widget.pitId,
      from: cell,
      count: picked.length,
      initialGroupId: groups.length == 1 ? groups.first : null,
    );
    if (target == null || !mounted) return;
    await ref
        .read(databaseProvider)
        .moveAlbumImages(
          from: cell,
          ids: [for (final p in picked) p.id],
          to: target.cell,
          groupId: target.groupId,
          targetPitId: target.pitId,
        );
    if (!mounted) return;
    final cellLabel = albumCellLabel(context.l10n, target.cell);
    showSnack(
      context,
      target.crossPit
          ? context.l10n.moveReviewMovedToPit(
              picked.length,
              target.pitName ?? '',
              cellLabel,
            )
          : context.l10n.albumMovedCount(picked.length, cellLabel),
      success: true,
    );
    _exit();
  }

  /// 官方圖冊、好看同人圖的多選有 tag（D-060）；雜物沒有。
  bool get _taggable =>
      widget.cell == AlbumCell.official || widget.cell == AlbumCell.fan;

  Future<void> _tag() async {
    final cell = widget.cell;
    if (cell == null || _selected.isEmpty) return;
    final applied = await showBatchTagSheet(
      context,
      pitId: widget.pitId,
      cell: cell,
      ids: [for (final p in _picked) p.id],
    );
    if (applied == true && mounted) _exit();
  }

  /// 「敏感」動作（D-104）：官方圖冊、好看同人圖、雜物。
  SensitiveSource? get _sensitiveSource => switch (widget.cell) {
    AlbumCell.official => SensitiveSource.official,
    AlbumCell.fan => SensitiveSource.fan,
    AlbumCell.junk => SensitiveSource.junk,
    null => null,
  };

  Future<void> _sensitive() async {
    final source = _sensitiveSource;
    if (source == null || _selected.isEmpty) return;
    final done = await applySensitiveToSelection(context, ref, source, [
      for (final p in _picked) p.id,
    ]);
    if (done && mounted) _exit();
  }

  Future<void> _delete() async {
    final picked = _picked;
    if (picked.isEmpty) return;
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImagesTitle(picked.length),
    );
    if (!ok || !mounted) return;
    await widget.onDelete(picked);
    if (mounted) _exit();
  }

  void _openFullPreview(int i) {
    // 預覽頁自己會隱藏底部導覽列（HidesNavBar），走分頁的 Navigator，
    // 這樣 Android 返回手勢只會退一頁。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.previewBuilder?.call(widget.images, i) ??
            ImagePreviewPage(
              pitId: widget.pitId,
              images: widget.images,
              initialIndex: i,
            ),
      ),
    );
  }

  /// 開參考圖檢視（RefFull／RefSplit／RespRef400／RespRef900，版型按檢視器自己的闊度）。
  /// 預覽面板的「參考檢視」入口走這裡，不再退回手機版的深色預覽頁。
  Future<void> _openReference(int i) async {
    final pitName = ref.read(pitProvider(widget.pitId)).value?.name;
    final title = pitName == null
        ? widget.title
        : context.l10n.albumTitleWithPit(pitName, widget.title);
    await openReferenceViewer(
      context,
      images: [
        for (final im in widget.images)
          RefImage.fromAlbum(im, pitId: widget.pitId, title: title),
      ],
      index: i < 0 ? 0 : i,
    );
  }

  void _open(AlbumImage im, int i) {
    if (_selecting) {
      _toggle(im);
      return;
    }
    final cls = WindowClass.of(context);
    if (widget.panelBuilder != null && !cls.isCompact) {
      if (cls.isWide) {
        // 寬版：選中這張，右側面板顯示。
        setState(() => _panelId = im.id);
      } else {
        _showPanelSheet(im);
      }
      return;
    }
    _openFullPreview(i);
  }

  /// 600–839：預覽面板放在底部 sheet。
  Future<void> _showPanelSheet(AlbumImage im) async {
    final index = widget.images.indexWhere((e) => e.id == im.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: widget.panelBuilder!(ctx, im, () {
              Navigator.pop(ctx);
              _openReference(index);
            }, () => Navigator.pop(ctx)),
          ),
        ),
      ),
    );
  }

  void _longPress(AlbumImage im) => setState(() {
    _selecting = true;
    _selected.add(im.id);
  });

  /// 長按＋拖曳連續多選（D-081）：收到完整的已選 index，放手時一個都沒有才離開多選。
  void _dragSelect(Set<int> idx, bool finished) => setState(() {
    final imgs = widget.images;
    _selected
      ..clear()
      ..addAll([
        for (final i in idx)
          if (i < imgs.length) imgs[i].id,
      ]);
    _selecting = !finished || _selected.isNotEmpty;
  });

  Widget _grid({bool wide = false, bool showPanel = false, WideSpec? spec}) =>
      widget.squares
      ? SquareGrid(
          images: widget.images,
          selecting: _selecting,
          selected: _selected,
          onLongPress: _longPress,
          onDragSelect: _dragSelect,
          onTap: _open,
        )
      : ImageMasonry(
          images: widget.images,
          selecting: _selecting,
          selected: _selected,
          highlightId: showPanel ? _panelId : null,
          // iPad 多選：預覽面板收起，列表固定 4 欄（FanArtSelect）。
          columns: wide && _selecting ? 4 : null,
          padding: wide
              ? EdgeInsets.fromLTRB(
                  spec!.hpad,
                  4,
                  showPanel ? 0 : spec.hpad,
                  96,
                )
              : const EdgeInsets.fromLTRB(20, 2, 20, 96),
          onLongPress: _longPress,
          onDragSelect: _dragSelect,
          onTap: _open,
        );

  /// 寬版右側預覽面板：選了圖顯示該圖，沒選顯示提示。
  Widget _panel(WideSpec spec) {
    final sel = widget.images.where((e) => e.id == _panelId).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(left: spec.gap, right: spec.hpad),
      child: SizedBox(
        width: spec.panel,
        child: SidePanelFrame(
          child: sel == null
              ? WideEmptyHint(context.l10n.ipadListsPreviewEmpty)
              : widget.panelBuilder!(
                  context,
                  sel,
                  () => _openReference(
                    widget.images.indexWhere((e) => e.id == sel.id),
                  ),
                  () => setState(() => _panelId = null),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    setNavBarHidden(_selecting);
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final total = widget.total ?? widget.images.length;
    final fullyEmpty = total == 0 && widget.images.isEmpty;
    final cls = WindowClass.of(context);
    // 寬版（≥840）且有預覽面板：列表＋右側面板；選取（多選）時面板收起。
    final wide = cls.isWide && widget.panelBuilder != null;
    final showPanel = wide && !_selecting;
    final spec = WideSpec.of(MediaQuery.sizeOf(context).width);
    final serif = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 58,
          titleSpacing: 4,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: _selecting
                ? IconButton(
                    tooltip: context.l10n.albumCancelSelect,
                    padding: EdgeInsets.zero,
                    icon: SvgIcon(
                      AppIcons.closeX,
                      size: 22,
                      color: t.ink,
                      strokeWidth: 2,
                    ),
                    onPressed: _exit,
                  )
                : IconButton(
                    tooltip: context.l10n.commonBack,
                    padding: EdgeInsets.zero,
                    icon: SvgIcon(
                      AppIcons.back,
                      color: t.ink,
                      strokeWidth: 1.9,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
          ),
          title: Text(
            _selecting
                ? context.l10n.commonSelectedCount(_selected.length)
                : (pitName == null
                      ? widget.title
                      : context.l10n.albumTitleWithPit(pitName, widget.title)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serif,
          ),
          actions: _selecting
              ? [
                  TextButton(
                    onPressed: _toggleAll,
                    style: TextButton.styleFrom(
                      foregroundColor: t.piece.fg,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      _allSelected
                          ? context.l10n.commonDeselectAll
                          : context.l10n.commonSelectAll,
                    ),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  ...widget.appBarActions,
                  if (cls.isWide && widget.panelBuilder != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: WideIconButton(
                        svg: IpadListsIcons.multiSelect,
                        label: context.l10n.ipadListsMultiSelect,
                        onTap: () => setState(() => _selecting = true),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(
                      right: widget.searchAction == null ? 22 : 6,
                    ),
                    child: Text(
                      context.l10n.commonCountImages(total),
                      style: TextStyle(color: t.text3, fontSize: 12),
                    ),
                  ),
                  if (widget.searchAction != null) ...[
                    widget.searchAction!,
                    const SizedBox(width: 12),
                  ],
                ],
        ),
        floatingActionButton: (_selecting || fullyEmpty)
            ? null
            : FloatingActionButton(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onPressed: widget.onAdd,
                child: const SvgIcon(
                  AppIcons.plus,
                  size: 26,
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              ),
        bottomNavigationBar: _selecting
            ? Container(
                // iPad 寬版（FanArtSelect）：動作列兩側各留 120，五個動作靠近中間。
                padding: EdgeInsets.fromLTRB(
                  wide ? 120 : (widget.shareInSelect ? 12 : 20),
                  4,
                  wide ? 120 : (widget.shareInSelect ? 12 : 20),
                  0,
                ),
                decoration: BoxDecoration(
                  color: t.nav,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      if (widget.shareInSelect)
                        Expanded(
                          child: _BarAction(
                            context.l10n.commonShare,
                            AppIcons.share,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.7,
                            onTap: _share,
                          ),
                        ),
                      Expanded(
                        child: _BarAction(
                          context.l10n.commonDownload,
                          AppIcons.download,
                          t.ink,
                          iconSize: 22,
                          strokeWidth: 1.7,
                          onTap: _download,
                        ),
                      ),
                      if (_sensitiveSource != null &&
                          ref.watch(sensitiveMarkingProvider(widget.pitId)))
                        Expanded(
                          child: _BarAction(
                            context.l10n.sensitiveAction,
                            AppIcons.eyeSlash,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.9,
                            onTap: _sensitive,
                          ),
                        ),
                      if (widget.cell != null)
                        Expanded(
                          child: _BarAction(
                            context.l10n.commonMove,
                            AlbumIcons.moveFolder,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.7,
                            onTap: _move,
                          ),
                        ),
                      if (_taggable)
                        Expanded(
                          child: _BarAction(
                            context.l10n.shareMoveTag,
                            AlbumIcons.tag,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.7,
                            onTap: _tag,
                          ),
                        ),
                      Expanded(
                        child: _BarAction(
                          context.l10n.commonDelete,
                          AppIcons.trash,
                          t.danger,
                          iconSize: 20,
                          strokeWidth: 1.8,
                          onTap: _delete,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            ?widget.sectionTabs,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        if (!fullyEmpty && widget.filter != null)
                          // 寬版時 chips 與瀑布左緣對齊（chips 預設左邊距 20）。
                          Padding(
                            padding: EdgeInsets.only(
                              left: wide ? spec.hpad - 20 : 0,
                            ),
                            child: widget.filter,
                          ),
                        Expanded(
                          child: widget.images.isEmpty
                              ? EmptyState(
                                  icon: widget.emptyIcon,
                                  svg:
                                      widget.emptySvg ??
                                      (widget.emptyIcon == null
                                          ? AppIcons.image
                                          : null),
                                  text: widget.emptyLabel,
                                  color: widget.emptyColor,
                                  actionLabel:
                                      widget.emptyAction ??
                                      context.l10n.albumAddImage,
                                  onAction: widget.onAdd,
                                )
                              : _grid(
                                  wide: wide,
                                  showPanel: showPanel,
                                  spec: spec,
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (showPanel && !fullyEmpty) _panel(spec),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction(
    this.label,
    this.svg,
    this.color, {
    required this.iconSize,
    required this.strokeWidth,
    required this.onTap,
  });
  final String label;
  final String svg;
  final Color color;
  final double iconSize;
  final double strokeWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        // 放在 bottomNavigationBar 時高度不受限，要縮到內容大小，否則整頁會被撐滿。
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgIcon(svg, size: iconSize, color: color, strokeWidth: strokeWidth),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11.5)),
        ],
      ),
    ),
  );
}

/// 篩選列最右的「管理分組」按鈕（左側細分隔線＋兩條滑桿 icon）。
class ChipRowManageButton extends StatelessWidget {
  const ChipRowManageButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      child: Tooltip(
        message: context.l10n.albumManageGroups,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.border)),
            ),
            alignment: Alignment.center,
            child: SvgIcon(AppIcons.sliders, size: 20, color: t.text2),
          ),
        ),
      ),
    );
  }
}

/// 一排可橫向捲動的選項 chips。[selected] 為 null 表示「全部」。
/// 預設為列表篩選樣式（選中＝深色 ink 底＋白字，未選＝白底細框）；
/// 表單裡的分組選擇請傳 [accentSelected]（選中＝主色底）。
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.showAll = true,
    this.trailing,
    this.accentSelected = false,
    this.wrap = false,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 0, 12),
  });

  final List<(String, String)> options; // (id, label)
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// 是否顯示最前面的「全部」chip；表單裡的分組選擇不顯示。
  final bool showAll;
  final Widget? trailing;
  final bool accentSelected;

  /// 表單用：chips 自動換行而不是橫向捲動。
  final bool wrap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (showAll)
        _Chip(
          context.l10n.commonAll,
          selected == null,
          () => onSelected(null),
          accentSelected,
        ),
      for (final o in options)
        _Chip(o.$2, selected == o.$1, () => onSelected(o.$1), accentSelected),
    ];
    if (wrap) {
      return Padding(
        padding: padding,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(spacing: 8, children: chips),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap, this.accentSelected);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accentSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onColor = accentSelected ? t.accent : t.ink;
    return Padding(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: accentSelected ? 7 : 6,
          ),
          decoration: BoxDecoration(
            color: selected ? onColor : t.surface,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: selected ? onColor : t.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (accentSelected ? Colors.white : t.surface)
                  : t.text2,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
