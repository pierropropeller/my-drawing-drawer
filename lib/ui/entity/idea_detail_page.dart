import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import 'connect_field.dart';
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
    final body = t.ink.withValues(alpha: 0.82);
    Future<void> connect(
      String label,
      List<ConnectOption> options,
      List<String> current,
      Future<void> Function(List<String>) save,
    ) async {
      final r = await showConnectSheet(
        context,
        label: label,
        options: options,
        selected: current,
      );
      if (r != null) await save(r);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: '腦洞詳情',
              titleSize: 20,
              gap: 6,
              trailing: [
                HeaderIconButton(
                  icon: AppIcons.edit,
                  label: '編輯',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          IdeaFormPage(pitId: pitId, ideaId: ideaId),
                    ),
                  ),
                ),
                HeaderIconButton(
                  icon: AppIcons.trash,
                  label: '刪除',
                  color: t.danger,
                  onTap: () async {
                    final ok = await confirmDelete(context, title: '刪除這個腦洞？');
                    if (!ok || !context.mounted) return;
                    await ref.read(databaseProvider).deleteIdeas([ideaId]);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.idea.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IdeaStatusChip(v, short: true, fontSize: 11),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '建立於 ${fmtSlash(v.idea.createdAt)}',
                    style: TextStyle(color: t.text4, fontSize: 12),
                  ),
                  if (v.idea.body.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      v.idea.body,
                      style: TextStyle(
                        color: body,
                        fontSize: 14.5,
                        height: 1.75,
                      ),
                    ),
                  ],
                  if (v.images.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 96,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < v.images.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
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
                                  width: 96,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      Radii.image,
                                    ),
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
                    const SizedBox(height: 14),
                    TagPills(v.tags, large: true),
                  ],
                  _Section(
                    title: '連接的草稿',
                    addLabel: '連接草稿',
                    onAdd: () => connect(
                      '連接草稿',
                      [
                        for (final d in drafts)
                          ConnectOption(
                            id: d.draft.id,
                            title: d.draft.title ?? '',
                          ),
                      ],
                      v.draftIds,
                      (r) =>
                          ref.read(databaseProvider).setIdeaDrafts(ideaId, r),
                    ),
                    children: [
                      for (final d in myDrafts)
                        ThumbSquare(
                          images: d.images,
                          size: 80,
                          placeholder: t.draft.bg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => DraftDetailPage(
                                draftId: d.draft.id,
                                pitId: pitId,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _Section(
                    title: '連接的成圖',
                    addLabel: '連接成圖',
                    onAdd: () => connect(
                      '連接成圖',
                      [
                        for (final p in pieces)
                          ConnectOption(id: p.piece.id, title: p.piece.title),
                      ],
                      v.pieceIds,
                      (r) =>
                          ref.read(databaseProvider).setIdeaPieces(ideaId, r),
                    ),
                    children: [
                      for (final p in myPieces)
                        ThumbSquare(
                          images: p.images,
                          size: 80,
                          placeholder: t.piece.bg,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PieceDetailPage(
                                pieceId: p.piece.id,
                                pitId: pitId,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });
  final String title;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...children,
            DashedAddTile(size: 80, onTap: onAdd, semanticLabel: addLabel),
          ],
        ),
      ],
    );
  }
}
