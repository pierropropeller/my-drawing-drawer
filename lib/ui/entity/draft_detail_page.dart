import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import 'draft_form_page.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'image_gallery_page.dart';

/// 草稿詳情：看圖、標題內文、tag、連接的腦洞。
class DraftDetailPage extends ConsumerWidget {
  const DraftDetailPage({
    super.key,
    required this.draftId,
    required this.pitId,
  });
  final String draftId;
  final String pitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final v = ref.watch(draftViewProvider(draftId)).value;
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final mine = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final d = v.draft;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DraftFormPage(pitId: pitId, draftId: draftId),
              ),
            ),
          ),
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDelete(context, title: '刪除這份草稿？');
              if (!ok || !context.mounted) return;
              await ref.read(databaseProvider).deleteDrafts([draftId]);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          if ((d.title ?? '').isNotEmpty)
            Text(d.title!, style: Theme.of(context).textTheme.headlineSmall),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              fmtDate(d.createdAt),
              style: TextStyle(color: t.text3, fontSize: 12),
            ),
          ),
          for (var i = 0; i < v.images.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ImageGalleryPage(images: v.images, initialIndex: i),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: AspectRatio(
                    aspectRatio: v.images[i].aspect.clamp(0.5, 2.0),
                    child: StoredImage(v.images[i].file, cacheWidth: 1000),
                  ),
                ),
              ),
            ),
          if ((d.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.body!, style: const TextStyle(height: 1.6)),
          ],
          if (v.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            TagPills(v.tags),
          ],
          if (mine.isNotEmpty) ...[
            const SizedBox(height: 24),
            const FormLabel('連接的腦洞'),
            for (final i in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EntityCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          IdeaDetailPage(ideaId: i.idea.id, pitId: pitId),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.idea.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IdeaStatusChip(i),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
