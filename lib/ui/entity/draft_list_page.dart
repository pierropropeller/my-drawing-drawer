import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import 'draft_detail_page.dart';
import 'draft_form_page.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';

/// 我的草稿：列表（D-083 統一卡片）與九宮格切換。
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

class _DraftListPageState extends ConsumerState<DraftListPage> {
  bool _grid = false;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DraftFormPage(pitId: widget.pitId, initialImages: picked),
      ),
    );
  }

  void _open(DraftView d) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DraftDetailPage(
        draftId: d.draft.id,
        pitId: widget.pitId,
        onTagTap:
            widget.onTagTap ??
            (id) => onListTagTap(
              context,
              pitId: widget.pitId,
              kind: TaggedKind.draft,
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
                _ViewToggle(
                  grid: _grid,
                  onChanged: (g) => setState(() => _grid = g),
                ),
                const SizedBox(width: 6),
              ],
            ),
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
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        itemCount: views.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final d = views[i];
                          return DraftListCard(
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
              : StoredImage(imgs.first.file, cacheWidth: 400),
          if (imgs.length > 1)
            Positioned(right: 5, bottom: 5, child: CountBadge(imgs.length)),
        ],
      ),
    );
  }
}

/// 草稿列表卡（D-083）：版面只看「內文」——有內文＝小圖版，沒有＝大圖版。
/// 兩種版本共用同一個框架（同腦洞卡）：頂部＝標題＋右上關聯成圖標記，底部＝tag＋關聯腦洞＋日期。
class DraftListCard extends StatelessWidget {
  const DraftListCard({
    super.key,
    required this.view,
    required this.ideaTitles,
    this.onTap,
  });
  final DraftView view;
  final List<String> ideaTitles;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = view.draft;
    final title = d.title ?? '';
    final small = (d.body ?? '').isNotEmpty;
    final pieces = view.pieceIds.length;
    return EntityCard(
      onTap: onTap,
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 標題與關聯成圖都沒有時，整行不顯示。
          if (title.isNotEmpty || pieces > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ),
                  if (pieces > 0) ...[
                    const SizedBox(width: 10),
                    _HatchedMark(pieces),
                  ],
                ],
              ),
            ),
          if (small) ..._small(context) else _large(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
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
              const SizedBox(width: 6),
              Text(
                fmtMd(d.date),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 小圖版：一排 64px 小圖（最多 4 張，第 4 張蓋 +N）＋內文。
  List<Widget> _small(BuildContext context) {
    final t = context.tokens;
    final shown = view.images.take(4).toList();
    final extra = view.images.length - 4;
    return [
      if (shown.isNotEmpty)
        Row(
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 6),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StoredImage(shown[i].file, cacheWidth: 300),
                        if (i == 3 && extra > 0)
                          MoreOverlay(extra, fontSize: 15),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      Padding(
        padding: EdgeInsets.only(top: shown.isEmpty ? 0 : 9),
        child: Text(
          view.draft.body!,
          style: TextStyle(color: t.text2, fontSize: 13, height: 1.5),
        ),
      ),
    ];
  }

  /// 大圖版：1 張＝整寬闊圖（高 140）；2 張以上＝一排 3 格正方形，第 3 格蓋 +N。
  Widget _large() {
    final imgs = view.images;
    if (imgs.length <= 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 140,
          width: double.infinity,
          child: imgs.isEmpty
              ? const ImagePlaceholder(iconSize: 26)
              : StoredImage(imgs.first.file, cacheWidth: 900),
        ),
      );
    }
    final shown = imgs.take(3).toList();
    final extra = imgs.length - 3;
    return LayoutBuilder(
      builder: (_, c) {
        final cell = (c.maxWidth - 8) / 3;
        return Row(
          children: [
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
                child: SizedBox(
                  width: cell,
                  height: cell,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StoredImage(shown[i].file, cacheWidth: 400),
                        if (i == 2 && extra > 0) MoreOverlay(extra),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
