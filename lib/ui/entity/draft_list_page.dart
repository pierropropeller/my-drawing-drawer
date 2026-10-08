import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/svg_icon.dart';
import 'draft_detail_page.dart';
import 'draft_form_page.dart';
import 'entity_widgets.dart';

/// 我的草稿：列表（有字的卡片／純圖卡）與九宮格切換。
class DraftListPage extends ConsumerStatefulWidget {
  const DraftListPage({super.key, required this.pitId});
  final String pitId;

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
      builder: (_) => DraftDetailPage(draftId: d.draft.id, pitId: widget.pitId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final views = ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final ideaTitle = {for (final i in ideas) i.idea.id: i.idea.title};
    return Scaffold(
      floatingActionButton: EntityFab(label: '新增草稿', onPressed: _add),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: pitName == null ? '我的草稿' : '$pitName · 我的草稿',
              trailing: [
                HeaderCount('${views.length} 份'),
                _ViewToggle(
                  grid: _grid,
                  onChanged: (g) => setState(() => _grid = g),
                ),
                const SizedBox(width: 6),
              ],
            ),
            Expanded(
              child: views.isEmpty
                  ? EmptyState(
                      icon: Icons.draw_outlined,
                      text: '還沒有草稿',
                      color: t.draft,
                      actionLabel: '新增草稿',
                      onAction: _add,
                    )
                  : _grid
                  ? GridView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                      itemCount: views.length,
                      itemBuilder: (_, i) => _GridCell(
                        view: views[i],
                        onTap: () => _open(views[i]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      itemCount: views.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final d = views[i];
                        return d.imageOnly
                            ? _ImageOnlyCard(view: d, onTap: () => _open(d))
                            : _TextCard(
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
          seg(AppIcons.listRows, 1.8, '列表', !grid, false),
          const SizedBox(width: 3),
          seg(AppIcons.grid3x3, 1.7, '九宮格', grid, true),
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

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.view,
    required this.onTap,
    required this.ideaTitles,
  });
  final DraftView view;
  final VoidCallback onTap;
  final List<String> ideaTitles;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = view.draft;
    final shown = view.images.take(4).toList();
    final extra = view.images.length - 4;
    return EntityCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  d.title ?? '',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                fmtMd(d.createdAt),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ],
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == shown.length - 1 ? 0 : 6,
                    ),
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
          ],
          if ((d.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              d.body!,
              style: TextStyle(color: t.text2, fontSize: 13, height: 1.5),
            ),
          ],
          if (view.tags.isNotEmpty || ideaTitles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in view.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.chipBg,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      '#${tag.name}',
                      style: TextStyle(color: t.text2, fontSize: 11),
                    ),
                  ),
                for (final title in ideaTitles)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
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
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 純圖草稿：日期在卡片右上；單圖一張闊圖（高 140），多圖最多 3 格（3 欄、間距 4），超出疊「+N」。
class _ImageOnlyCard extends StatelessWidget {
  const _ImageOnlyCard({required this.view, required this.onTap});
  final DraftView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final imgs = view.images;
    final Widget body;
    if (imgs.length <= 1) {
      body = SizedBox(
        height: 140,
        width: double.infinity,
        child: imgs.isEmpty
            ? const ImagePlaceholder(iconSize: 26)
            : StoredImage(imgs.first.file, cacheWidth: 900),
      );
    } else {
      final shown = imgs.take(3).toList();
      final extra = imgs.length - 3;
      body = LayoutBuilder(
        builder: (_, c) {
          final cell = (c.maxWidth - 8) / 3;
          return Row(
            children: [
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == shown.length - 1 ? 0 : 4,
                  ),
                  child: SizedBox(
                    width: cell,
                    height: cell,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StoredImage(shown[i].file, cacheWidth: 400),
                        if (i == 2 && extra > 0) MoreOverlay(extra),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
    return EntityCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                fmtMd(view.draft.createdAt),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ),
          ),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: body),
        ],
      ),
    );
  }
}
