import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import 'draft_detail_page.dart';
import 'entity_widgets.dart';
import 'idea_form_page.dart';
import 'image_gallery_page.dart';
import 'piece_detail_page.dart';

/// 腦洞詳情：連接的草稿／成圖以正方形縮圖呈現，多圖右下角顯示張數。
class IdeaDetailPage extends ConsumerWidget {
  const IdeaDetailPage({super.key, required this.ideaId, required this.pitId});
  final String ideaId;
  final String pitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final v = ref.watch(ideaViewProvider(ideaId)).value;
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final drafts = ref.watch(draftViewsProvider(pitId)).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((pitId, null))).value ?? const [];
    final myDrafts = drafts
        .where((d) => v.draftIds.contains(d.draft.id))
        .toList();
    final myPieces = pieces
        .where((p) => v.pieceIds.contains(p.piece.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => IdeaFormPage(pitId: pitId, ideaId: ideaId),
              ),
            ),
          ),
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDelete(context, title: '刪除這個腦洞？');
              if (!ok || !context.mounted) return;
              await ref.read(databaseProvider).deleteIdeas([ideaId]);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(v.idea.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              IdeaStatusChip(v),
              const Spacer(),
              Text(
                fmtDate(v.idea.createdAt),
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
            ],
          ),
          if (v.idea.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(v.idea.body, style: const TextStyle(height: 1.6)),
          ],
          if (v.images.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < v.images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ImageGalleryPage(
                              images: v.images,
                              initialIndex: i,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.image),
                            child: StoredImage(
                              v.images[i].file,
                              cacheWidth: 400,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (v.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            TagPills(v.tags),
          ],
          const SizedBox(height: 24),
          _Section(
            title: '連接的草稿',
            empty: '還沒有連接草稿',
            children: [
              for (final d in myDrafts)
                ThumbSquare(
                  images: d.images,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DraftDetailPage(draftId: d.draft.id, pitId: pitId),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: '連接的成圖',
            empty: '還沒有連接成圖',
            children: [
              for (final p in myPieces)
                ThumbSquare(
                  images: p.images,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PieceDetailPage(pieceId: p.piece.id, pitId: pitId),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.children,
  });
  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormLabel(title),
        if (children.isEmpty)
          Text(empty, style: TextStyle(color: t.text3))
        else
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
      ],
    );
  }
}
