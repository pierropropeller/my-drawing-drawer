import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/database.dart' show TagTarget;
import '../../data/entity_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../state/sensitive.dart';
import '../common/sensitive_actions.dart';
import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/image_masonry.dart' show SelectMark;
import '../common/app_icons.dart';
import '../common/drag_select.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../oshi/oshi_selection.dart';
import '../common/empty_state.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../album/wide_layout.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'detail_panes.dart';
import 'entity_select.dart';
import 'entity_widgets.dart';
import 'piece_detail_page.dart';
import 'piece_form_page.dart';
import '../pits/pit_section_tabs.dart';

enum _Mode { waterfall, grid, nine }

/// 成圖列表（Finished）：瀑布／田字／九宮格切換；顯示互動量；有導覽列。
/// D-043：頂部不放 tag chips，卡片不顯示 tag；[tagId] 只篩選內容（篩選列另有人接）。
class FinishedListPage extends ConsumerStatefulWidget {
  const FinishedListPage({
    super.key,
    required this.pitId,
    this.tagId,
    this.onTagTap,
  });
  final String pitId;

  /// 只列出有這個 tag 的成圖；有值時標題列下多一條「#tag ×」篩選列（D-043）。
  final String? tagId;

  /// 詳情頁點 tag 的處理；省略＝預設導覽（回到本格列表並篩選）。
  final ValueChanged<String>? onTagTap;

  @override
  ConsumerState<FinishedListPage> createState() => _FinishedListPageState();
}

class _FinishedListPageState extends ConsumerState<FinishedListPage>
    with HidesNavBar<FinishedListPage> {
  // 瀏覽時有導覽列；進入多選才隱藏（build 時依 _sel.active 同步）。
  @override
  bool get hidesNavBarOnOpen => false;

  _Mode _mode = _Mode.waterfall;

  /// 多選（D-095）：在原本的佈局上選，三種佈局都一樣。
  final _sel = OshiSelection();

  static final _tagBackend = entityTagBackend(
    TagTarget.piece,
    (l, n) => l.commonCountImages(n),
  );

  @override
  void initState() {
    super.initState();
    _sel.addListener(_onSel);
  }

  @override
  void dispose() {
    _sel.dispose();
    super.dispose();
  }

  void _onSel() {
    if (mounted) setState(() {});
  }

  List<PieceView> _picked(List<PieceView> views) => [
    for (final v in views)
      if (_sel.isSelected(v.piece.id)) v,
  ];

  Future<void> _share(List<PieceView> picked) async {
    if (picked.isEmpty) return;
    await shareEntityImages(ref, [for (final v in picked) v.images]);
  }

  Future<void> _download(List<PieceView> picked) async {
    if (picked.isEmpty) return;
    final r = await downloadEntityImages(ref, [
      for (final v in picked) v.images,
    ]);
    if (!mounted) return;
    if (r.total > 0) {
      showSnack(
        context,
        r.saved > 0
            ? context.l10n.albumSavedCountToGallery(r.saved)
            : context.l10n.albumSaveFailed,
      );
    }
    _sel.exit();
  }

  Future<void> _tag(List<PieceView> picked) async {
    if (picked.isEmpty) return;
    final applied = await showEntityTagSheet(
      context,
      pitId: widget.pitId,
      backend: _tagBackend,
      ids: [for (final v in picked) v.piece.id],
    );
    if (applied == true && mounted) _sel.exit();
  }

  Future<void> _sensitive(List<PieceView> picked) async {
    if (picked.isEmpty) return;
    final done = await applySensitiveToSelection(
      context,
      ref,
      SensitiveSource.piece,
      [for (final v in picked) v.piece.id],
    );
    if (done && mounted) _sel.exit();
  }

  Future<void> _delete(List<PieceView> picked) async {
    if (picked.isEmpty) return;
    final ok = await confirmDelete(
      context,
      title: context.l10n.pieceDeleteSelectedTitle(picked.length),
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deletePieces([
      for (final v in picked) v.piece.id,
    ]);
    if (mounted) _sel.exit();
  }

  /// 寬版右側詳情面板目前顯示的成圖（放在 State，拉窗不會丟）。
  String? _selectedId;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    await openPieceForm(context, pitId: widget.pitId, initialImages: picked);
  }

  /// 瀑布／田字／九宮格的內容。手機維持 2／2／3 欄；平板依可用闊度逐格增減（間距 16／16／8）。
  Widget _content(
    List<PieceView> views,
    EdgeInsets pad, {
    required bool wide,
    bool highlight = false,
  }) {
    final compact = WindowClass.of(context).isCompact;
    return LayoutBuilder(
      builder: (context, c) {
        final inner = c.maxWidth - pad.horizontal;
        final wfCols = compact ? 2 : gridColumnsFor(inner);
        final wfGap = compact ? 12.0 : 16.0;
        final nineCols = compact ? 3 : gridColumnsFor(inner, minCell: 120);
        final nineGap = 8.0;
        void tap(PieceView v) => _open(v);
        bool sel(PieceView v) => highlight && _selectedId == v.piece.id;
        final selecting = _sel.active;
        // 多選的狀態（長按＋拖曳連續多選用 index ＝ views 的順序）。
        Widget pick(int i, Widget tile) =>
            DragSelectItem(index: i, child: tile);
        bool picked(PieceView v) => _sel.isSelected(v.piece.id);
        final layout = switch (_mode) {
          _Mode.waterfall => MasonryGridView.count(
            padding: pad,
            crossAxisCount: wfCols,
            mainAxisSpacing: compact ? 14 : 16,
            crossAxisSpacing: wfGap,
            itemCount: views.length,
            itemBuilder: (_, i) => pick(
              i,
              _PieceTile(
                view: views[i],
                selected: sel(views[i]),
                selecting: selecting,
                picked: picked(views[i]),
                onTap: () => tap(views[i]),
                ratio: views[i].images.isEmpty
                    ? 1
                    : views[i].images.first.aspect.clamp(0.5, 2.0),
              ),
            ),
          ),
          _Mode.grid => GridView.builder(
            padding: pad,
            gridDelegate: compact
                ? const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // 方圖＋標題＋互動量
                    childAspectRatio: 0.76,
                  )
                : SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wfCols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    // 方圖＋標題＋互動量（約 52px 文字）
                    mainAxisExtent: (inner - 16 * (wfCols - 1)) / wfCols + 52,
                  ),
            itemCount: views.length,
            itemBuilder: (_, i) => pick(
              i,
              _PieceTile(
                view: views[i],
                selected: sel(views[i]),
                selecting: selecting,
                picked: picked(views[i]),
                onTap: () => tap(views[i]),
                ratio: 1,
              ),
            ),
          ),
          _Mode.nine => GridView.builder(
            padding: pad,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: nineCols,
              mainAxisSpacing: nineGap,
              crossAxisSpacing: nineGap,
            ),
            itemCount: views.length,
            itemBuilder: (_, i) => pick(
              i,
              _NineTile(
                view: views[i],
                selected: sel(views[i]),
                selecting: selecting,
                picked: picked(views[i]),
                onTap: () => tap(views[i]),
              ),
            ),
          ),
        };
        // 長按＋拖曳連續多選（D-081）。區域放在三種佈局的外面，切換佈局不會中斷。
        return DragSelectArea(
          itemCount: views.length,
          isSelected: (i) => _sel.isSelected(views[i].piece.id),
          onChanged: (idx, finished) =>
              _sel.applyIndices(idx, finished: finished),
          child: layout,
        );
      },
    );
  }

  /// 寬版：左邊成圖（瀑布／田字／九宮格）＋右邊詳情面板（Finished 設計稿，350）。
  Widget _wideBody(List<PieceView> views) {
    final spec = WideSpec.of(
      MediaQuery.sizeOf(context).width,
      expanded: (320, 350),
      large: (350, 380),
    );
    final sel = _selectedId;
    final valid = sel != null && views.any((v) => v.piece.id == sel);
    // 多選時沒有詳情面板，成圖鋪滿。
    if (_sel.active) {
      return _content(
        views,
        EdgeInsets.fromLTRB(spec.hpad, 10, spec.hpad, 96),
        wide: true,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _content(
            views,
            EdgeInsets.fromLTRB(spec.hpad, 10, 0, 96),
            wide: true,
            highlight: true,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: spec.gap, right: spec.hpad, top: 10),
          child: SizedBox(
            width: spec.panel,
            child: SidePanelFrame(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: valid
                  ? PieceDetailPanel(
                      key: ValueKey(sel),
                      pitId: widget.pitId,
                      pieceId: sel,
                    )
                  : WideEmptyHint(context.l10n.ipadListsPieceEmpty),
            ),
          ),
        ),
      ],
    );
  }

  void _open(PieceView v) {
    if (_sel.active) {
      _sel.toggle(v.piece.id);
      return;
    }
    if (WindowClass.of(context).isWide) {
      setState(() => _selectedId = v.piece.id);
      return;
    }
    _openDetail(v);
  }

  void _openDetail(PieceView v) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PieceDetailPage(
        pieceId: v.piece.id,
        pitId: widget.pitId,
        onTagTap:
            widget.onTagTap ??
            (id) => onListTagTap(
              context,
              pitId: widget.pitId,
              kind: TaggedKind.piece,
              tagId: id,
              listFiltered: widget.tagId != null,
              fromDetail: true,
            ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pit = ref.watch(pitProvider(widget.pitId)).value;
    final views =
        ref.watch(pieceViewsProvider((widget.pitId, widget.tagId))).value ??
        const [];
    const pad = EdgeInsets.fromLTRB(20, 10, 20, 96);
    final wide = WindowClass.of(context).isWide;
    _sel.updateOrder([for (final v in views) v.piece.id]);
    final selecting = _sel.active;
    setNavBarHidden(selecting);
    final picked = _picked(views);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sel.exit();
      },
      child: Scaffold(
        bottomNavigationBar: selecting
            ? EntitySelectBar(
                onShare: () => _share(picked),
                onDownload: () => _download(picked),
                onTag: () => _tag(picked),
                onDelete: () => _delete(picked),
                onSensitive: ref.watch(sensitiveMarkingProvider(widget.pitId))
                    ? () => _sensitive(picked)
                    : null,
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  if (selecting)
                    EntitySelectHeader(
                      title: context.l10n.commonSelectedCount(picked.length),
                      allSelected: _sel.allSelected,
                      onExit: _sel.exit,
                      onToggleAll: () =>
                          _sel.allSelected ? _sel.exit() : _sel.selectAll(),
                    )
                  else
                    SubPageHeader(
                      title: pit == null
                          ? context.l10n.searchCategoryPiece
                          : context.l10n.albumTitleWithPit(
                              pit.name,
                              context.l10n.searchCategoryPiece,
                            ),
                      titleSize: 19,
                      trailing: [
                        SearchIconButton(pitId: widget.pitId),
                        _ModeToggle(
                          mode: _mode,
                          onChanged: (m) => setState(() => _mode = m),
                        ),
                      ],
                    ),
                  if (!selecting)
                    PitSectionTabBar(
                      pitId: widget.pitId,
                      selected: PitSection.pieces,
                    ),
                  if (widget.tagId != null)
                    TagFilterBar(
                      pitId: widget.pitId,
                      kind: TaggedKind.piece,
                      tagId: widget.tagId!,
                      countText: context.l10n.commonCountImages(views.length),
                    ),
                  Expanded(
                    child: views.isEmpty
                        ? EmptyState(
                            svg: AppIcons.pitPieceEmpty,
                            text: context.l10n.pieceListEmpty,
                            color: t.piece,
                            actionLabel: context.l10n.commonAdd,
                            onAction: _add,
                          )
                        : wide
                        ? _wideBody(views)
                        : _content(views, pad, wide: false),
                  ),
                ],
              ),
              if (views.isNotEmpty && !selecting)
                Positioned(
                  right: 18,
                  bottom: 14,
                  child: EntityFab(
                    onPressed: _add,
                    label: context.l10n.pieceFormTitleNew,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右上的版面切換：白底 1px 邊框、圓角 11、三顆 34×32 按鈕，選中＝主色底白圖。
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(_Mode m, String label, String icon, double stroke) {
      final on = mode == m;
      return Semantics(
        button: true,
        label: label,
        selected: on,
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: on ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgIcon(
                icon,
                size: 18,
                strokeWidth: stroke,
                color: on ? Colors.white : t.text4,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          btn(
            _Mode.waterfall,
            context.l10n.pieceViewWaterfall,
            AppIcons.waterfallView,
            1.8,
          ),
          btn(_Mode.grid, context.l10n.pieceViewGrid, AppIcons.gridView, 1.8),
          btn(_Mode.nine, context.l10n.pieceViewNine, AppIcons.grid3x3, 1.7),
        ],
      ),
    );
  }
}

/// 圖片或圖片佔位（分類底色＋圖片 glyph）。
Widget _pieceImage(
  BuildContext context,
  PieceView v, {
  double glyph = 26,
  double badgeInset = 7,
}) {
  final t = context.tokens;
  if (v.images.isNotEmpty) {
    return MediaThumb(
      MediaSource.fromImageRef(v.images.first),
      cacheWidth: 500,
      badgeInset: badgeInset,
    );
  }
  return ColoredBox(
    color: t.piece.bg,
    child: Center(
      child: SvgIcon(
        AppIcons.image,
        size: glyph,
        strokeWidth: 1.5,
        color: t.ink.withValues(alpha: .24),
      ),
    ),
  );
}

/// 瀑布／田字的卡：圖（圓角 14）、標題 14/700、愛心＋實際 / 目標。
class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.view,
    required this.onTap,
    required this.ratio,
    this.selected = false,
    this.selecting = false,
    this.picked = false,
  });
  final bool selected;

  /// 多選中／被選中（D-095）：2px 主色框＋右上勾（同 MaterialSelect）。
  final bool selecting;
  final bool picked;
  final PieceView view;
  final VoidCallback onTap;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = view.piece;
    final reached = p.targetLikes > 0 && p.actualLikes >= p.targetLikes;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _pieceImage(context, view),
                ),
                if (selected && !selecting) const _SelectRing(radius: 14),
                if (selecting) _PickMark(radius: 14, picked: picked, inset: 7),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
            child: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          // 沒公開發佈的成圖沒有互動量，不顯示愛心列。
          if (p.isPublished)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
              child: Row(
                children: [
                  SvgIcon(
                    AppIcons.heart,
                    size: 15,
                    strokeWidth: reached ? 0 : 1.8,
                    color: t.accent,
                    fill: reached ? _hex(t.accent) : 'none',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${p.actualLikes}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.targetLikes > 0)
                    Text(
                      ' / ${p.targetLikes}',
                      style: TextStyle(fontSize: 11.5, color: t.text2),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 九宮格的格：方圖（圓角 11）、左下白色半透明愛心＋實際互動量。
class _NineTile extends StatelessWidget {
  const _NineTile({
    required this.view,
    required this.onTap,
    this.selected = false,
    this.selecting = false,
    this.picked = false,
  });
  final bool selected;
  final bool selecting;
  final bool picked;
  final PieceView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _pieceImage(context, view, glyph: 22, badgeInset: 5),
              if (selected && !selecting) const _SelectRing(radius: 11),
              if (selecting) _PickMark(radius: 11, picked: picked, inset: 6),
              if (view.piece.isPublished)
                Positioned(
                  left: 5,
                  // 第一張是 GIF／影片時，左下角已有媒體標記，愛心列疊在它上面。
                  bottom:
                      (view.images.isNotEmpty &&
                          !view.images.first.kind.isImage)
                      ? 29
                      : 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        SvgIcon(
                          AppIcons.heart,
                          size: 10,
                          color: t.accent,
                          fill: _hex(t.accent),
                          strokeWidth: 0,
                        ),
                        Text(
                          '${view.piece.actualLikes}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2622),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 寬版詳情面板目前顯示的那張：2.5px 主色框（稿：`outline:2.5px solid accent`）。
class _SelectRing extends StatelessWidget {
  const _SelectRing({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.tokens.accent, width: 2.5),
      ),
    ),
  );
}

/// 多選的標記：選中＝2px 主色框；右上角圓圈（選中＝實心主色白勾，未選＝白邊半透明）。
class _PickMark extends StatelessWidget {
  const _PickMark({
    required this.radius,
    required this.picked,
    required this.inset,
  });
  final double radius;
  final bool picked;
  final double inset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (picked)
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: context.tokens.accent, width: 2),
            ),
          ),
        ),
      Positioned(
        top: inset,
        right: inset,
        child: SelectMark(selected: picked),
      ),
    ],
  );
}
