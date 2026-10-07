import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import 'entity_widgets.dart';
import 'piece_detail_page.dart';
import 'piece_form_page.dart';

enum _Mode { waterfall, grid, nine }

/// 成圖列表：瀑布／田字／九宮格切換；tag chips 篩選；顯示互動量。
class FinishedListPage extends ConsumerStatefulWidget {
  const FinishedListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<FinishedListPage> createState() => _FinishedListPageState();
}

class _FinishedListPageState extends ConsumerState<FinishedListPage> {
  _Mode _mode = _Mode.waterfall;
  String? _tagId;

  void _open(PieceView v) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PieceDetailPage(pieceId: v.piece.id, pitId: widget.pitId),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tags = ref.watch(tagsProvider(widget.pitId)).value ?? const [];
    final tagId = tags.any((e) => e.id == _tagId) ? _tagId : null;
    final views =
        ref.watch(pieceViewsProvider((widget.pitId, tagId))).value ?? const [];
    final icon = switch (_mode) {
      _Mode.waterfall => Icons.grid_view,
      _Mode.grid => Icons.apps,
      _Mode.nine => Icons.view_quilt_outlined,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的成圖'),
        actions: [
          IconButton(
            tooltip: '切換版面',
            icon: Icon(icon),
            onPressed: () =>
                setState(() => _mode = _Mode.values[(_mode.index + 1) % 3]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PieceFormPage(pitId: widget.pitId),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          if (tags.isNotEmpty)
            ChipRow(
              options: [for (final e in tags) (e.id, '#${e.name}')],
              selected: tagId,
              onSelected: (v) => setState(() => _tagId = v),
            ),
          Expanded(
            child: views.isEmpty
                ? Center(
                    child: Text('還沒有成圖', style: TextStyle(color: t.text3)),
                  )
                : switch (_mode) {
                    _Mode.waterfall => MasonryGridView.count(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      itemCount: views.length,
                      itemBuilder: (_, i) => _PieceTile(
                        view: views[i],
                        onTap: () => _open(views[i]),
                        ratio: views[i].images.isEmpty
                            ? 1
                            : views[i].images.first.aspect.clamp(0.5, 2.0),
                      ),
                    ),
                    _Mode.grid => GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: views.length,
                      itemBuilder: (_, i) => _PieceTile(
                        view: views[i],
                        onTap: () => _open(views[i]),
                        ratio: 1,
                      ),
                    ),
                    _Mode.nine => GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemCount: views.length,
                      itemBuilder: (_, i) => ThumbSquare(
                        images: views[i].images,
                        onTap: () => _open(views[i]),
                      ),
                    ),
                  },
          ),
        ],
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.view,
    required this.onTap,
    required this.ratio,
  });
  final PieceView view;
  final VoidCallback onTap;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final p = view.piece;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              view.images.isEmpty
                  ? ColoredBox(color: context.tokens.chipBg)
                  : StoredImage(view.images.first.file, cacheWidth: 500),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        p.targetLikes > 0
                            ? '${p.actualLikes}/${p.targetLikes}'
                            : '${p.actualLikes}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
