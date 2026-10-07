import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/empty_state.dart';
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
    final views = ref.watch(draftViewsProvider(widget.pitId)).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的草稿'),
        actions: [
          IconButton(
            tooltip: _grid ? '切換為列表' : '切換為九宮格',
            icon: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: views.isEmpty
          ? EmptyState(
              icon: Icons.draw_outlined,
              text: '還沒有草稿',
              color: t.draft,
              actionLabel: '新增',
              onAction: _add,
            )
          : _grid
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: views.length,
              itemBuilder: (_, i) => ThumbSquare(
                images: views[i].images,
                onTap: () => _open(views[i]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: views.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final d = views[i];
                return d.imageOnly
                    ? _ImageOnlyCard(view: d, onTap: () => _open(d))
                    : _TextCard(view: d, onTap: () => _open(d));
              },
            ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.view, required this.onTap});
  final DraftView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = view.draft;
    final shown = view.images.take(4).toList();
    final extra = view.images.length - 4;
    return EntityCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (d.title ?? '').isEmpty ? '（無標題）' : d.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                fmtDate(d.createdAt),
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
            ],
          ),
          if ((d.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              d.body!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text2, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < shown.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == shown.length - 1 ? 0 : 6,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.image),
                            child: StoredImage(shown[i].file, cacheWidth: 300),
                          ),
                          if (i == 3 && extra > 0) _MoreOverlay(extra),
                        ],
                      ),
                    ),
                  ),
                ),
              for (var i = shown.length; i < 4; i++)
                const Expanded(child: SizedBox()),
            ],
          ),
          if (view.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            TagPills(view.tags),
          ],
        ],
      ),
    );
  }
}

/// 純圖草稿：單圖一張闊圖，多圖最多 3 格，超出疊「+N」；右上角顯示日期。
class _ImageOnlyCard extends StatelessWidget {
  const _ImageOnlyCard({required this.view, required this.onTap});
  final DraftView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imgs = view.images;
    final Widget body;
    if (imgs.length <= 1) {
      body = AspectRatio(
        aspectRatio: imgs.isEmpty ? 2 : imgs.first.aspect.clamp(1.2, 2.2),
        child: imgs.isEmpty
            ? ColoredBox(color: context.tokens.chipBg)
            : StoredImage(imgs.first.file, cacheWidth: 900),
      );
    } else {
      final shown = imgs.take(3).toList();
      final extra = imgs.length - 3;
      body = Row(
        children: [
          for (var i = 0; i < shown.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 4),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      StoredImage(shown[i].file, cacheWidth: 400),
                      if (i == 2 && extra > 0) _MoreOverlay(extra),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: Stack(
          children: [
            body,
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Text(
                  fmtDate(view.draft.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOverlay extends StatelessWidget {
  const _MoreOverlay(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black54,
    child: Center(
      child: Text(
        '+$n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
