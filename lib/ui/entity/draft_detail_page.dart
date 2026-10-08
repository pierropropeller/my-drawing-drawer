import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import 'connect_field.dart';
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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: '草稿詳情',
              titleSize: 20,
              gap: 6,
              trailing: [
                HeaderIconButton(
                  icon: AppIcons.edit,
                  label: '編輯',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DraftFormPage(pitId: pitId, draftId: draftId),
                    ),
                  ),
                ),
                HeaderIconButton(
                  icon: AppIcons.trash,
                  label: '刪除',
                  color: t.danger,
                  onTap: () async {
                    final ok = await confirmDelete(context, title: '刪除這份草稿？');
                    if (!ok || !context.mounted) return;
                    await ref.read(databaseProvider).deleteDrafts([draftId]);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                children: [
                  if ((d.title ?? '').isNotEmpty)
                    Text(
                      d.title!,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: Text(
                      '建立於 ${fmtSlash(d.createdAt)}',
                      style: TextStyle(color: t.text4, fontSize: 12),
                    ),
                  ),
                  for (var i = 0; i < v.images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ImageGalleryPage(
                                  images: v.images,
                                  initialIndex: i,
                                ),
                              ),
                            ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.image),
                          child: AspectRatio(
                            aspectRatio: v.images[i].aspect.clamp(0.5, 2.0),
                            child: StoredImage(
                              v.images[i].file,
                              cacheWidth: 1000,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if ((d.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      d.body!,
                      style: TextStyle(
                        color: t.ink.withValues(alpha: 0.82),
                        fontSize: 14.5,
                        height: 1.75,
                      ),
                    ),
                  ],
                  if (v.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    TagPills(v.tags, large: true),
                  ],
                  const Padding(
                    padding: EdgeInsets.only(top: 24, bottom: 10),
                    child: Text(
                      '連接的腦洞',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final i in mine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EntityCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IdeaStatusChip(i),
                          ],
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DashedAddTile(
                      size: 80,
                      semanticLabel: '連接腦洞',
                      onTap: () async {
                        final r = await showConnectSheet(
                          context,
                          label: '連接腦洞',
                          options: [
                            for (final i in ideas)
                              ConnectOption(id: i.idea.id, title: i.idea.title),
                          ],
                          selected: v.ideaIds,
                        );
                        if (r != null) {
                          await ref
                              .read(databaseProvider)
                              .setDraftIdeas(draftId, r);
                        }
                      },
                    ),
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
