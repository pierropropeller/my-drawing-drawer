import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/detail_carousel.dart';
import '../common/sensitive_safe_button.dart';
import '../common/nav_bar_hidden.dart';
import '../search/tagged_list.dart';
import '../common/responsive.dart';
import 'connect_field.dart';
import 'draft_form_page.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'piece_detail_page.dart';

/// 草稿詳情（沒有導覽列），三種情況（D-017）：
/// - 完整（DraftDetail）：大圖（多張時右上「1 / N」＋縮圖列）、標題、日期、內文、tag、關聯腦洞；
/// - 只有一張圖（DraftDetailOne）：大圖＋日期；
/// - 只有多張圖（DraftDetailMulti）：大圖＋「1 / N」＋縮圖列＋日期。
/// 右上角編輯、刪除；詳情頁不能新增關聯（D-037）。
class DraftDetailPage extends ConsumerStatefulWidget {
  const DraftDetailPage({
    super.key,
    required this.draftId,
    required this.pitId,
  });
  final String draftId;
  final String pitId;

  @override
  ConsumerState<DraftDetailPage> createState() => _DraftDetailPageState();
}

class _DraftDetailPageState extends ConsumerState<DraftDetailPage>
    with HidesNavBar<DraftDetailPage> {
  String get draftId => widget.draftId;
  String get pitId => widget.pitId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = ref.watch(draftViewProvider(draftId)).value;
    if (v == null) return const Scaffold(body: SizedBox.shrink());
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final mine = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final pieces =
        ref.watch(pieceViewsProvider((pitId, null))).value ?? const [];
    final myPieces = pieces
        .where((p) => v.pieceIds.contains(p.piece.id))
        .toList();
    final d = v.draft;
    final plain = v.imageOnly;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(
              title: context.l10n.draftDetailTitle,
              titleSize: 20,
              gap: 6,
              trailing: [
                SensitiveSafeButton(files: flaggableFiles(v.images)),
                HeaderIconButton(
                  icon: AppIcons.edit,
                  label: context.l10n.commonEdit,
                  onTap: () =>
                      openDraftForm(context, pitId: pitId, draftId: draftId),
                ),
                HeaderIconButton(
                  icon: AppIcons.trash,
                  label: context.l10n.commonDelete,
                  color: t.danger,
                  onTap: () async {
                    final ok = await confirmDelete(
                      context,
                      title: context.l10n.draftDetailDeleteTitle,
                      toTrash: true,
                    );
                    if (!ok || !context.mounted) return;
                    await ref.read(databaseProvider).deleteDrafts([draftId]);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Expanded(
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    DetailImageStage(images: v.images),
                    if (plain)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Text(
                          fmtSlash(d.date),
                          style: TextStyle(color: t.text4, fontSize: 12.5),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  fmtSlash(d.date),
                                  style: TextStyle(
                                    color: t.text4,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if ((d.body ?? '').isNotEmpty) ...[
                              const SizedBox(height: 10),
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
                              const SizedBox(height: 12),
                              TagPills(
                                v.tags,
                                large: true,
                                onTagTap: (id) =>
                                    openTagSearch(context, pitId, id),
                              ),
                            ],
                            if (mine.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                child: Text(
                                  context.l10n.ideaLinkedHeading,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final i in mine)
                                    RelationChip(
                                      kind: ConnectKind.idea,
                                      title: i.idea.title,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => IdeaDetailPage(
                                            ideaId: i.idea.id,
                                            pitId: pitId,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (myPieces.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                child: Text(
                                  context.l10n.pieceLinkedHeading,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final p in myPieces)
                                    Semantics(
                                      button: true,
                                      label: p.piece.title,
                                      child: ThumbSquare(
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
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
