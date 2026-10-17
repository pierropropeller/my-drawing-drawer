import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/media_mini.dart';
import '../common/empty_state.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../album/wide_layout.dart';
import 'draft_detail_page.dart';
import 'detail_panes.dart';
import 'draft_form_page.dart';
import 'image_gallery_page.dart';
import 'master_detail.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';
import '../pits/pit_section_tabs.dart';

/// 我的草稿：列表（D-087 推特式）與九宮格切換。
/// 瀏覽用頁面，有底部導覽列。
class DraftListPage extends ConsumerStatefulWidget {
  const DraftListPage({
    super.key,
    required this.pitId,
    this.tagId,
    this.onTagTap,
  });
  final String pitId;

  /// 只顯示有這個 tag 的草稿；有值時標題列下多一條「#tag ×」篩選列（D-043）。
  final String? tagId;

  /// 傳給詳情頁的 tag 點擊回呼；省略＝預設導覽（回到本格列表並篩選）。
  final void Function(String tagId)? onTagTap;

  @override
  ConsumerState<DraftListPage> createState() => _DraftListPageState();
}

class _DraftListPageState extends ConsumerState<DraftListPage>
    with MasterDetailState<DraftListPage> {
  bool _grid = false;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add() async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    await openDraftForm(context, pitId: widget.pitId, initialImages: picked);
  }

  void _onTagTap(String id) =>
      (widget.onTagTap ??
      (tid) => onListTagTap(
        context,
        pitId: widget.pitId,
        kind: TaggedKind.draft,
        tagId: tid,
        listFiltered: widget.tagId != null,
        fromDetail: true,
      ))(id);

  /// 開詳情頁（手機／600–839，或由寬變窄時停在詳情）。
  void _pushDetail(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PopWhenWide(
        child: DraftDetailPage(
          draftId: id,
          pitId: widget.pitId,
          onTagTap: _onTagTap,
        ),
      ),
    ),
  );

  /// 並排時：選中該項（右側顯示詳情）；否則開詳情頁（並記住它，之後拉寬可還原）。
  void _open(DraftView d, {bool wide = false}) {
    setState(() => selectedId = d.draft.id);
    if (!wide) _pushDetail(d.draft.id);
  }

  /// 寬版：左邊緊湊列表（固定約 400，縮圖 76）＋右邊詳情。
  Widget _splitBody(List<DraftView> views, Map<String, String> ideaTitle) {
    final t = context.tokens;
    final w = MediaQuery.sizeOf(context).width;
    final listW = (w * 0.42).clamp(340.0, 400.0);
    final sel = selectedId;
    final valid = sel != null && views.any((v) => v.draft.id == sel);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listW,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: t.border)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: views.length,
              itemBuilder: (_, i) => DraftRow(
                view: views[i],
                selected: views[i].draft.id == sel,
                ideaTitles: [
                  for (final id in views[i].ideaIds)
                    if (ideaTitle[id] != null) ideaTitle[id]!,
                ],
                onTap: () => _open(views[i], wide: true),
              ),
            ),
          ),
        ),
        Expanded(
          child: valid
              ? DraftDetailPane(
                  key: ValueKey(sel),
                  pitId: widget.pitId,
                  draftId: sel,
                  onDeleted: () => setState(() => selectedId = null),
                  onTagTap: _onTagTap,
                )
              : WideEmptyHint(context.l10n.ipadListsDraftEmpty),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final views =
        ref
            .watch(draftViewsFilteredProvider((widget.pitId, widget.tagId)))
            .value ??
        const [];
    // 標題列一律顯示全部份數；篩選時符合的份數在篩選列。
    final total = widget.tagId == null
        ? views.length
        : (ref.watch(draftViewsFilteredProvider((widget.pitId, null))).value ??
                  views)
              .length;
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final ideaTitle = {for (final i in ideas) i.idea.id: i.idea.title};
    final wide = WindowClass.of(context).isWide;
    syncMasterDetail(wide, _pushDetail);
    return Scaffold(
      floatingActionButton: views.isEmpty
          ? null
          : EntityFab(label: context.l10n.draftFormTitleNew, onPressed: _add),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: pitName == null
                  ? context.l10n.pitsDrafts
                  : context.l10n.albumTitleWithPit(
                      pitName,
                      context.l10n.pitsDrafts,
                    ),
              trailing: [
                HeaderCount(context.l10n.pitsCountDrafts(total)),
                SearchIconButton(pitId: widget.pitId),
                // 並排時右邊是詳情，不提供九宮格切換（_grid 狀態保留，拉窄後還原）。
                if (!wide)
                  _ViewToggle(
                    grid: _grid,
                    onChanged: (g) => setState(() => _grid = g),
                  ),
                const SizedBox(width: 6),
              ],
            ),
            PitSectionTabBar(pitId: widget.pitId, selected: PitSection.drafts),
            if (widget.tagId != null)
              TagFilterBar(
                pitId: widget.pitId,
                kind: TaggedKind.draft,
                tagId: widget.tagId!,
                countText: context.l10n.pitsCountDrafts(views.length),
              ),
            Expanded(
              child: views.isEmpty
                  ? EmptyState(
                      svg: AppIcons.edit,
                      text: context.l10n.draftListEmpty,
                      color: t.draft,
                      actionLabel: context.l10n.draftFormTitleNew,
                      onAction: _add,
                    )
                  : wide
                  ? _splitBody(views, ideaTitle)
                  : _grid
                  ? GridView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 96),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnsForWidth(
                          MediaQuery.sizeOf(context).width,
                          phone: 3,
                        ),
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: views.length,
                      itemBuilder: (_, i) => _GridCell(
                        view: views[i],
                        onTap: () => _open(views[i]),
                      ),
                    )
                  : ContentWidth(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: views.length,
                        itemBuilder: (_, i) {
                          final d = views[i];
                          return DraftRow(
                            view: d,
                            onTap: () => _open(d),
                            ideaTitles: [
                              for (final id in d.ideaIds)
                                if (ideaTitle[id] != null) ideaTitle[id]!,
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表／九宮格的分段切換（34×32 的兩格，選中＝深色底）。
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onChanged});
  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(
      String icon,
      double stroke,
      String label,
      bool on,
      bool toGrid,
    ) => Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(toGrid),
        child: Container(
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: on ? t.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: SvgIcon(
              icon,
              size: 18,
              strokeWidth: stroke,
              color: on ? t.ground : t.text3,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(AppIcons.listRows, 1.8, context.l10n.draftViewList, !grid, false),
          const SizedBox(width: 3),
          seg(AppIcons.grid3x3, 1.7, context.l10n.pieceViewNine, grid, true),
        ],
      ),
    );
  }
}

/// 九宮格的一格：整張鋪滿、無圓角，多圖右下角張數。
class _GridCell extends StatelessWidget {
  const _GridCell({required this.view, required this.onTap});
  final DraftView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imgs = view.images;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imgs.isEmpty
              ? const ImagePlaceholder()
              : MediaThumb(
                  MediaSource.fromImageRef(imgs.first),
                  cacheWidth: 400,
                  count: imgs.length,
                ),
        ],
      ),
    );
  }
}

/// 推特式列表的圖片版面（D-087）：寬 [w] 內的每張圖尺寸與是否橫捲。
class DraftImageLayout {
  const DraftImageLayout(this.sizes, {required this.scrolls});
  final List<Size> sizes;
  final bool scrolls;
}

/// 圖片間距、圓角（D-087）。
const double kDraftImageGap = 4;
const double kDraftImageRadius = 12;

/// 單張的比例（寬÷高）上限／下限：高度落在 [0.25W, 1.6W]（極端長／扁圖的上限〔待評估〕）。
const double kDraftMinRatio = 1 / 1.6;
const double kDraftMaxRatio = 4;

/// 依各張比例（寬÷高）算出 [w] 寬內的版面：1 張＝整寬；2 張＝同高拼滿；3 張以上＝同高橫捲，
/// 第 1 張完整、第 2 張露一半。一律不裁切（每格按比例定大小）。
DraftImageLayout draftImageLayout(List<double> ratios, double w) {
  final r = [
    for (final x in ratios)
      (x.isFinite && x > 0 ? x : 1.0).clamp(kDraftMinRatio, kDraftMaxRatio),
  ];
  if (r.isEmpty) return const DraftImageLayout([], scrolls: false);
  if (r.length == 1) {
    return DraftImageLayout([Size(w, w / r[0])], scrolls: false);
  }
  if (r.length == 2) {
    final h = (w - kDraftImageGap) / (r[0] + r[1]);
    return DraftImageLayout([
      Size(h * r[0], h),
      Size(h * r[1], h),
    ], scrolls: false);
  }
  final h = (w - kDraftImageGap) / (r[0] + 0.5 * r[1]);
  return DraftImageLayout([for (final x in r) Size(h * x, h)], scrolls: true);
}

/// 我的摸魚列表的一列（D-087，推特式）：不用卡片框，底部 1px 分隔線，左右留白 20。
/// 標題（粗）·日期（灰）＋右邊「已孵 N 成圖」→ 內文 → 圖片 → tag＋關聯腦洞。
class DraftRow extends StatelessWidget {
  const DraftRow({
    super.key,
    required this.view,
    required this.ideaTitles,
    this.onTap,
    this.selected = false,
  });
  final DraftView view;
  final List<String> ideaTitles;
  final VoidCallback? onTap;

  /// 並排版選中的那一列（淡色底）。
  final bool selected;

  static const double _pad = 20;

  void _openImage(BuildContext context, int i) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ImageGalleryPage(images: view.images, initialIndex: i),
    ),
  );

  Widget _tile(BuildContext context, int i, Size size) {
    final im = view.images[i];
    final t = context.tokens;
    return GestureDetector(
      onTap: () => _openImage(context, i),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kDraftImageRadius),
          child: ColoredBox(
            color: t.chipBg,
            child: MiniMediaThumb(
              MediaSource.fromImageRef(im),
              cacheWidth: 900,
              fit: BoxFit.contain,
              inset: 6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _images(BuildContext context, double rowWidth) {
    final w = rowWidth - _pad * 2;
    final lay = draftImageLayout([for (final i in view.images) i.aspect], w);
    Widget tile(int i) => _tile(context, i, lay.sizes[i]);
    if (lay.scrolls) {
      return SizedBox(
        height: lay.sizes.first.height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: _pad),
          itemCount: lay.sizes.length,
          separatorBuilder: (_, _) => const SizedBox(width: kDraftImageGap),
          itemBuilder: (_, i) => tile(i),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _pad),
      child: Row(
        children: [
          for (var i = 0; i < lay.sizes.length; i++) ...[
            if (i > 0) const SizedBox(width: kDraftImageGap),
            tile(i),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = view.draft;
    final title = d.title ?? '';
    final body = d.body ?? '';
    final pieces = view.pieceIds.length;
    final date = fmtMd(d.date);
    final hasMeta = view.tags.isNotEmpty || ideaTitles.isNotEmpty;
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? t.accentSoft : null,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (title.isNotEmpty) ...[
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '·',
                                style: TextStyle(fontSize: 13, color: t.text4),
                              ),
                            ),
                          ],
                          Text(
                            date,
                            style: TextStyle(fontSize: 13, color: t.text4),
                          ),
                        ],
                      ),
                    ),
                    if (pieces > 0) ...[
                      const SizedBox(width: 10),
                      _HatchedMark(pieces),
                    ],
                  ],
                ),
              ),
              if (body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pad, 4, _pad, 0),
                  child: Text(
                    body,
                    style: TextStyle(color: t.ink, fontSize: 14.5, height: 1.6),
                  ),
                ),
              if (view.images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _images(context, c.maxWidth),
                ),
              if (hasMeta)
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pad, 10, _pad, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in view.tags) _TagChip(tag.name),
                      for (final title in ideaTitles) _IdeaChip(title),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右上角「已孵 N 成圖」小標：與腦洞卡的 [IdeaStatusChip]（已孵）同字樣、同樣式。
class _HatchedMark extends StatelessWidget {
  const _HatchedMark(this.count);
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: t.piece.bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        context.l10n.ideaStatusHatched(count),
        style: TextStyle(
          color: t.piece.fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text('#$name', style: TextStyle(color: t.text2, fontSize: 11)),
    );
  }
}

/// 關聯腦洞（黃色，帶燈泡）。
class _IdeaChip extends StatelessWidget {
  const _IdeaChip(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: t.idea.bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(AppIcons.bulb, size: 12, color: t.idea.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: t.idea.fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
