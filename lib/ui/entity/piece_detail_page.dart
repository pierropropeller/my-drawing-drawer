import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import 'draft_detail_page.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'image_gallery_page.dart';
import 'piece_form_page.dart';

/// 成圖詳情：圖片、標題內文、tag、社交媒體連結、互動量（可更新實際值）、完成時間、連接的腦洞與草稿。
class PieceDetailPage extends ConsumerWidget {
  const PieceDetailPage({
    super.key,
    required this.pieceId,
    required this.pitId,
  });
  final String pieceId;
  final String pitId;

  Future<void> _editLikes(
    BuildContext context,
    WidgetRef ref,
    PieceView v,
  ) async {
    final c = TextEditingController(text: '${v.piece.actualLikes}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更新實際互動量'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (value != null && value >= 0) {
      await ref.read(databaseProvider).setActualLikes(v.piece.id, value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final v = ref.watch(pieceViewProvider(pieceId)).value;
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final drafts = ref.watch(draftViewsProvider(pitId)).value ?? const [];
    final myIdeas = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final myDrafts = drafts
        .where((d) => v.draftIds.contains(d.draft.id))
        .toList();
    final p = v.piece;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PieceFormPage(pitId: pitId, pieceId: pieceId),
              ),
            ),
          ),
          IconButton(
            tooltip: '刪除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirmDelete(context, title: '刪除這張成圖？');
              if (!ok || !context.mounted) return;
              await ref.read(databaseProvider).deletePieces([pieceId]);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
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
          const SizedBox(height: 8),
          Text(p.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _editLikes(context, ref, v),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.piece.bg,
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 14, color: t.piece.fg),
                      const SizedBox(width: 4),
                      Text(
                        p.targetLikes > 0
                            ? '${p.actualLikes} / ${p.targetLikes}'
                            : '${p.actualLikes}',
                        style: TextStyle(
                          color: t.piece.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '完成於 ${fmtDate(p.finishedAt)}',
                style: TextStyle(color: t.text3, fontSize: 12),
              ),
            ],
          ),
          if (p.body.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(p.body, style: const TextStyle(height: 1.6)),
          ],
          if (v.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            TagPills(v.tags),
          ],
          if (v.links.isNotEmpty) ...[
            const SizedBox(height: 24),
            const FormLabel('社交媒體連結'),
            for (final l in v.links)
              EntityCard(
                onTap: () async {
                  final uri = Uri.tryParse(l.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      l.platform,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.accentStrong),
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 16, color: t.text3),
                  ],
                ),
              ),
          ],
          if (myIdeas.isNotEmpty) ...[
            const SizedBox(height: 24),
            const FormLabel('連接的腦洞'),
            for (final i in myIdeas)
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
          if (myDrafts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const FormLabel('連接的草稿'),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
          ],
        ],
      ),
    );
  }
}
