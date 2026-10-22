import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/ipadlists_icons.dart';
import '../album/wide_layout.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/detail_carousel.dart';
import '../common/media_mini.dart';
import '../common/media_widgets.dart';
import '../common/svg_icon.dart';
import 'connect_field.dart';
import 'draft_detail_page.dart';
import 'draft_form_page.dart';
import 'entity_widgets.dart';
import '../search/tagged_list.dart';
import 'idea_detail_page.dart';
import 'idea_form_page.dart';
import '../reference/reference_viewer.dart';
import 'piece_detail_page.dart';
import 'piece_platform.dart';

/// 平板寬版（≥840）我的腦洞／我的摸魚／我的成圖並排時，右側的詳情內容（Ideas／Drafts／Finished 設計稿）。
/// 手機與 600–839 仍走原本的詳情頁（IdeaDetailPage 等）。

/// 標題列右側的「編輯」「刪除」44×44 方形鈕。
class _PaneActions extends StatelessWidget {
  const _PaneActions({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        WideIconButton(
          svg: AppIcons.edit,
          label: context.l10n.commonEdit,
          onTap: onEdit,
        ),
        WideIconButton(
          svg: AppIcons.trash,
          label: context.l10n.commonDelete,
          color: t.danger,
          onTap: onDelete,
        ),
      ],
    );
  }
}

/// 腦洞詳情（Ideas 設計稿右側）：標題＋狀態＋編輯刪除、建立日期、內文、配圖 150、tag、
/// 腦洞→摸魚→成圖三段、「從這個腦洞開摸魚」。另保留手機詳情有的關聯摸魚／成圖縮圖。
class IdeaDetailPane extends ConsumerWidget {
  const IdeaDetailPane({
    super.key,
    required this.pitId,
    required this.ideaId,
    required this.onDeleted,
  });
  final String pitId;
  final String ideaId;

  /// 刪除後（清掉選取）。
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final v = ref.watch(ideaViewProvider(ideaId)).value;
    if (v == null) return WideEmptyHint(l.ipadListsIdeaEmpty);
    final drafts = ref.watch(draftViewsProvider(pitId)).value ?? const [];
    final pieces =
        ref.watch(pieceViewsProvider((pitId, null))).value ?? const [];
    final myDrafts = drafts
        .where((d) => v.draftIds.contains(d.draft.id))
        .toList();
    final myPieces = pieces
        .where((p) => v.pieceIds.contains(p.piece.id))
        .toList();
    final stage = switch (v.status) {
      IdeaStatus.open => 0,
      IdeaStatus.hatching => 1,
      IdeaStatus.hatched => 2,
    };
    final stages = [
      l.ipadListsStageIdea,
      l.ipadListsStageDraft,
      l.ipadListsStagePiece,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 26, 36, 32),
      children: [
        // 有圖時圖片放最上面（D-092，同摸魚詳情版型）。
        if (v.images.isNotEmpty) ...[
          DetailImageStage(
            images: v.images,
            borderRadius: 14,
            sidePadding: 0,
            maxHeightFactor: 0.5,
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                v.idea.title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            IdeaStatusChip(v, short: true, fontSize: 12),
            const SizedBox(width: 12),
            _PaneActions(
              onEdit: () => openIdeaForm(context, pitId: pitId, ideaId: ideaId),
              onDelete: () async {
                final ok = await confirmDelete(
                  context,
                  title: l.ideaDetailDeleteTitle,
                );
                if (!ok || !context.mounted) return;
                await ref.read(databaseProvider).deleteIdeas([ideaId]);
                onDeleted();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.ideaDetailCreatedAt(fmtSlash(v.idea.date)),
          style: TextStyle(color: t.text3, fontSize: 12.5),
        ),
        if (v.idea.body.isNotEmpty) ...[
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              v.idea.body,
              style: TextStyle(
                color: t.ink.withValues(alpha: 0.82),
                fontSize: 16,
                height: 1.85,
              ),
            ),
          ),
        ],
        if (v.tags.isNotEmpty) ...[
          const SizedBox(height: 18),
          TagPills(
            v.tags,
            large: true,
            onTagTap: (id) => openTagSearch(context, pitId, id),
          ),
        ],
        const SizedBox(height: 28),
        Text(
          l.ipadListsIdeaFlow,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var k = 0; k < stages.length; k++)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: k <= stage ? t.accentSoft : t.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: k <= stage ? t.accent : t.dashed,
                      ),
                    ),
                    Text(
                      stages[k],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: k <= stage ? t.accentStrong : t.text3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            label: l.ipadListsStartDraftFromIdea,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openDraftForm(
                context,
                pitId: pitId,
                initialIdeaIds: [ideaId],
              ),
              child: DashedBox(
                color: t.dashed,
                radius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    SvgIcon(
                      AppIcons.plus,
                      size: 18,
                      strokeWidth: 2,
                      color: t.text2,
                    ),
                    Text(
                      l.ipadListsStartDraftFromIdea,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (myDrafts.isNotEmpty) ...[
          _Heading(l.draftLinkedHeading),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in myDrafts)
                Semantics(
                  button: true,
                  label: (d.draft.title ?? '').isEmpty
                      ? l.ideaDetailDraftLabel(d.images.length)
                      : d.draft.title,
                  child: ThumbSquare(
                    images: d.images,
                    size: 80,
                    placeholder: t.draft.bg,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DraftDetailPage(draftId: d.draft.id, pitId: pitId),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (myPieces.isNotEmpty) ...[
          _Heading(l.pieceLinkedHeading),
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
                        builder: (_) =>
                            PieceDetailPage(pieceId: p.piece.id, pitId: pitId),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

/// 摸魚詳情（Drafts 設計稿右側）：大圖（右上頁碼、右下參考檢視）＋右側 64px 縮圖欄，
/// 下方標題／日期／編輯刪除、內文、tag、關聯腦洞。目前張數放在 State，換摸魚時重置（以 key 區分）。
class DraftDetailPane extends ConsumerStatefulWidget {
  const DraftDetailPane({
    super.key,
    required this.pitId,
    required this.draftId,
    required this.onDeleted,
  });
  final String pitId;
  final String draftId;
  final VoidCallback onDeleted;

  @override
  ConsumerState<DraftDetailPane> createState() => _DraftDetailPaneState();
}

class _DraftDetailPaneState extends ConsumerState<DraftDetailPane> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final v = ref.watch(draftViewProvider(widget.draftId)).value;
    if (v == null) return WideEmptyHint(l.ipadListsDraftEmpty);
    final ideas =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final mine = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final pieces =
        ref.watch(pieceViewsProvider((widget.pitId, null))).value ?? const [];
    final myPieces = pieces
        .where((p) => v.pieceIds.contains(p.piece.id))
        .toList();
    final d = v.draft;
    final imgs = v.images;
    final n = imgs.length;
    final index = n == 0 ? 0 : _index.clamp(0, n - 1);
    final title = d.title ?? '';
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final refTitle = pitName == null
        ? l.pitsDrafts
        : l.albumTitleWithPit(pitName, l.pitsDrafts);
    return LayoutBuilder(
      builder: (context, c) {
        final stageH = (c.maxHeight * 0.52).clamp(240.0, 420.0);
        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
          children: [
            SizedBox(
              height: stageH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: t.chipBg),
                          if (n == 0)
                            const ImagePlaceholder(iconSize: 40)
                          else
                            MediaThumb(
                              MediaSource.fromImageRef(imgs[index]),
                              cacheWidth: 1200,
                              fit: BoxFit.contain,
                              badgeInset: 12,
                              protectSensitive: false, // 詳情不模糊（D-104）
                            ),
                          if (n > 0)
                            Positioned(
                              right: 12,
                              top: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x9E2B2622),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${index + 1} / $n',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (n > 0)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: GestureDetector(
                                // 參考檢視（RefFull／RefSplit／RespRef400…）；影片會開影片參考檢視。
                                onTap: () => openReferenceViewer(
                                  context,
                                  images: [
                                    for (var i = 0; i < imgs.length; i++)
                                      RefImage(
                                        id: '${d.id}#$i',
                                        file: imgs[i].file,
                                        width: imgs[i].width,
                                        height: imgs[i].height,
                                        kind: imgs[i].kind,
                                        durationMs: imgs[i].durationMs,
                                        posterFile: imgs[i].poster,
                                        title: refTitle,
                                        addedAt: d.createdAt,
                                      ),
                                  ],
                                  index: index,
                                ),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xB81E1B18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 5,
                                    children: [
                                      const SvgIcon(
                                        IpadListsIcons.reference,
                                        size: 14,
                                        strokeWidth: 2,
                                        color: Color(0xFFF5F0E8),
                                      ),
                                      Text(
                                        l.ipadListsReferenceView,
                                        style: const TextStyle(
                                          color: Color(0xFFF5F0E8),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (n > 1) ...[
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 64,
                      child: ListView.separated(
                        itemCount: n,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => Semantics(
                          button: true,
                          label: l.ipadListsDraftImageN(i + 1),
                          child: GestureDetector(
                            onTap: () => setState(() => _index = i),
                            child: Container(
                              width: 64,
                              height: 64,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: i == index
                                    ? Border.all(color: t.accent, width: 2.5)
                                    : null,
                              ),
                              child: MiniMediaThumb(
                                MediaSource.fromImageRef(imgs[i]),
                                cacheWidth: 200,
                                protectSensitive: false, // 詳情不模糊（D-104）
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? l.ipadListsDraftUntitled : title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: title.isEmpty ? t.text3 : t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  fmtSlash(d.date),
                  style: TextStyle(color: t.text3, fontSize: 12.5),
                ),
                const SizedBox(width: 10),
                _PaneActions(
                  onEdit: () => openDraftForm(
                    context,
                    pitId: widget.pitId,
                    draftId: widget.draftId,
                  ),
                  onDelete: () async {
                    final ok = await confirmDelete(
                      context,
                      title: l.draftDetailDeleteTitle,
                    );
                    if (!ok || !context.mounted) return;
                    await ref.read(databaseProvider).deleteDrafts([
                      widget.draftId,
                    ]);
                    widget.onDeleted();
                  },
                ),
              ],
            ),
            if ((d.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                d.body!,
                style: TextStyle(
                  color: t.ink.withValues(alpha: 0.82),
                  fontSize: 15,
                  height: 1.75,
                ),
              ),
            ],
            if (v.tags.isNotEmpty || mine.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tag in v.tags)
                    GestureDetector(
                      onTap: () => openTagSearch(context, widget.pitId, tag.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: t.chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#${tag.name}',
                          style: TextStyle(color: t.text2, fontSize: 12),
                        ),
                      ),
                    ),
                  for (final i in mine)
                    RelationChip(
                      kind: ConnectKind.idea,
                      title: l.ipadListsDraftIdeaLink(i.idea.title),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => IdeaDetailPage(
                            ideaId: i.idea.id,
                            pitId: widget.pitId,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (myPieces.isNotEmpty) ...[
              _Heading(l.pieceLinkedHeading),
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
                              pitId: widget.pitId,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 成圖詳情面板（Finished 設計稿右側 350）：封面 230、標題＋日期、互動量 act/target＋進度條＋達標標籤、
/// 社交媒體連結、關聯腦洞。
///
/// 設計稿的面板沒有編輯／刪除：點封面開完整的成圖詳情頁（可編輯、刪除）——這是自行補的入口。
class PieceDetailPanel extends ConsumerWidget {
  const PieceDetailPanel({
    super.key,
    required this.pitId,
    required this.pieceId,
  });
  final String pitId;
  final String pieceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final v = ref.watch(pieceViewProvider(pieceId)).value;
    if (v == null) return WideEmptyHint(l.ipadListsPieceEmpty);
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final myIdeas = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final p = v.piece;
    final reached = p.targetLikes > 0 && p.actualLikes >= p.targetLikes;
    final pct = p.targetLikes > 0
        ? (p.actualLikes / p.targetLikes).clamp(0.0, 1.0)
        : 0.0;
    return LayoutBuilder(
      builder: (context, c) {
        final coverH = (c.maxHeight * 0.34).clamp(160.0, 230.0);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Semantics(
              button: true,
              label: p.title,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PieceDetailPage(pieceId: pieceId, pitId: pitId),
                  ),
                ),
                child: SizedBox(
                  height: coverH,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: v.images.isEmpty
                        ? ImagePlaceholder(color: t.piece.bg, iconSize: 26)
                        : MediaThumb(
                            MediaSource.fromImageRef(v.images.first),
                            cacheWidth: 900,
                            protectSensitive: false, // 詳情不模糊（D-104）
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  fmtSlash(p.finishedAt),
                  style: TextStyle(fontSize: 12, color: t.text3),
                ),
              ],
            ),
            if (p.isPublished) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: t.ground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgIcon(
                          AppIcons.heart,
                          size: 22,
                          strokeWidth: reached ? 0 : 1.8,
                          color: t.accent,
                          fill: reached ? _hex(t.accent) : 'none',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${p.actualLikes}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.targetLikes > 0)
                          Text(
                            ' / ${p.targetLikes}',
                            style: TextStyle(fontSize: 13, color: t.text3),
                          ),
                        const Spacer(),
                        if (p.targetLikes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: reached ? t.piece.bg : t.chipBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              reached
                                  ? l.ipadListsReached
                                  : l.ipadListsNotReached,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: reached ? t.piece.fg : t.text2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (p.targetLikes > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: t.accentSoft,
                          valueColor: AlwaysStoppedAnimation(t.accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (p.isPublished && v.links.isNotEmpty) ...[
              _Heading(l.pieceFormSocialLinks),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final link in v.links) _LinkButton(link)],
              ),
            ],
            if (myIdeas.isNotEmpty) ...[
              _Heading(l.ideaLinkedHeading),
              for (final i in myIdeas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            IdeaDetailPage(ideaId: i.idea.id, pitId: pitId),
                      ),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: t.idea.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        spacing: 10,
                        children: [
                          SvgIcon(
                            AppIcons.bulb,
                            size: 18,
                            strokeWidth: 1.7,
                            color: t.idea.fg,
                          ),
                          Expanded(
                            child: Text(
                              i.idea.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SvgIcon(
                            AppIcons.chevronRight,
                            size: 16,
                            strokeWidth: 2,
                            color: t.idea.fg,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 社交媒體連結：44×44 平台徽章，點了開外部瀏覽器。
class _LinkButton extends StatelessWidget {
  const _LinkButton(this.link);
  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    var platform = PieceSocialPlatform.fromLabel(link.platform);
    if (platform == PieceSocialPlatform.other) {
      platform = detectSocialPlatform(link.url);
    }
    return Semantics(
      button: true,
      label: platform.displayNameOf(context.l10n),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(
            link.url.contains('://') ? link.url : 'https://${link.url}',
          );
          if (uri != null) {
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          }
        },
        child: SocialPlatformBadge(
          platform,
          size: 44,
          radius: 12,
          fontSize: 14,
        ),
      ),
    );
  }
}
