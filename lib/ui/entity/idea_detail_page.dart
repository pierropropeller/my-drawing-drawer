import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart' show GoalKind;
import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import 'entity_name.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/detail_carousel.dart';
import '../common/sensitive_safe_button.dart';
import '../common/nav_bar_hidden.dart';
import '../search/tagged_list.dart';
import '../common/responsive.dart';
import 'draft_detail_page.dart';
import 'entity_widgets.dart';
import 'idea_form_page.dart';
import 'piece_detail_page.dart';
import 'post_swipe.dart';

/// 腦洞詳情：關聯的草稿／成圖以正方形縮圖呈現，多圖右下角顯示張數。
/// 詳情頁不能新增關聯（D-037）：沒有關聯時整段不顯示，要改關聯請進編輯頁。
class IdeaDetailPage extends ConsumerStatefulWidget {
  const IdeaDetailPage({
    super.key,
    required this.ideaId,
    required this.pitId,
    this.order,
    this.onShown,
  });
  final String ideaId;
  final String pitId;

  /// 上／下篇的次序（進來前那個列表的次序，D-122）；null＝只有這一篇。
  final List<String>? order;
  final ValueChanged<String>? onShown;

  @override
  ConsumerState<IdeaDetailPage> createState() => _IdeaDetailPageState();
}

class _IdeaDetailPageState extends ConsumerState<IdeaDetailPage>
    with HidesNavBar<IdeaDetailPage> {
  String get pitId => widget.pitId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: PostSwipeView(
        initialId: widget.ideaId,
        order: widget.order,
        onShown: widget.onShown,
        header: _header,
        body: (context, id) => _body(context, id),
      ),
    ),
  );

  Widget _header(BuildContext context, String id, VoidCallback afterDelete) {
    final t = context.tokens;
    final v = ref.watch(ideaViewProvider(id)).value;
    return SubPageHeader(
      // D-128：標題列不顯示頁面名稱，只留返回和右邊的按鈕。
      title: '',
      trailing: [
        SensitiveSafeButton(
          files: v == null ? const [] : flaggableFiles(v.images),
        ),
        HeaderIconButton(
          icon: AppIcons.edit,
          label: context.l10n.commonEdit,
          onTap: () => openIdeaForm(context, pitId: pitId, ideaId: id),
        ),
        HeaderIconButton(
          icon: AppIcons.trash,
          label: context.l10n.commonDelete,
          color: t.danger,
          onTap: () async {
            final ok = await confirmDelete(
              context,
              title: context.l10n.ideaDetailDeleteTitle,
              toTrash: true,
            );
            if (!ok || !context.mounted) return;
            await ref.read(databaseProvider).deleteIdeas([id]);
            if (context.mounted) afterDelete();
          },
        ),
      ],
    );
  }

  Widget _body(BuildContext context, String id) => Consumer(
    builder: (context, ref, _) {
      final t = context.tokens;
      final v = ref.watch(ideaViewProvider(id)).value;
      if (v == null) return const SizedBox.shrink();
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
      final hasImages = v.images.isNotEmpty;
      return ContentWidth(
        child: ListView(
          // 有圖時圖片滿版放最上面（D-092，同摸魚詳情）；沒圖維持原樣。
          padding: EdgeInsets.only(bottom: hasImages ? 32 : 24),
          children: [
            if (hasImages) DetailImageStage(images: v.images),
            Padding(
              padding: EdgeInsets.fromLTRB(20, hasImages ? 16 : 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 沒有標題（D-129）：不顯示大標題，狀態 pill 和日期同一行。
                  if (v.idea.title.trim().isNotEmpty) ...[
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
                      context.l10n.ideaDetailCreatedAt(fmtSlash(v.idea.date)),
                      style: TextStyle(color: t.text4, fontSize: 12),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.ideaDetailCreatedAt(
                              fmtSlash(v.idea.date),
                            ),
                            style: TextStyle(color: t.text4, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IdeaStatusChip(v, short: true, fontSize: 11),
                      ],
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
                  if (v.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    TagPills(
                      v.tags,
                      large: true,
                      onTagTap: (id) => openTagSearch(context, pitId, id),
                    ),
                  ],
                  if (myDrafts.isNotEmpty)
                    _Section(
                      title: context.l10n.draftLinkedHeading,
                      children: [
                        for (final d in myDrafts)
                          Semantics(
                            button: true,
                            label: (d.draft.title ?? '').isEmpty
                                ? context.l10n.ideaDetailDraftLabel(
                                    d.images.length,
                                  )
                                : d.draft.title,
                            child: ThumbSquare(
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
                          ),
                      ],
                    ),
                  if (myPieces.isNotEmpty)
                    _Section(
                      title: context.l10n.pieceLinkedHeading,
                      children: [
                        for (final p in myPieces)
                          Semantics(
                            button: true,
                            label: entityDisplayName(
                              context.l10n,
                              title: p.piece.title,
                              body: p.piece.body,
                              date: p.piece.finishedAt,
                              kind: GoalKind.piece,
                            ),
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
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
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
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}
