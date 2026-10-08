import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database.dart';
import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../data/payment.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import 'draft_detail_page.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'image_gallery_page.dart';
import 'piece_form_page.dart';
import 'piece_platform.dart';
import 'piece_widgets.dart';

/// 成圖詳情：圖片、標題內文、tag（可點）、公開發佈與商稿資訊、社交媒體連結、
/// 互動量（可更新實際值）、完成時間、關聯的腦洞與草稿。沒有導覽列。
class PieceDetailPage extends ConsumerWidget {
  const PieceDetailPage({
    super.key,
    required this.pieceId,
    required this.pitId,
    this.onTagTap,
  });
  final String pieceId;
  final String pitId;

  /// 點 tag 時呼叫（D-043，由搜尋接上；預設不做事）。
  final ValueChanged<String>? onTagTap;

  Future<void> _editLikes(
    BuildContext context,
    WidgetRef ref,
    PieceView v,
  ) async {
    final c = TextEditingController(text: '${v.piece.actualLikes}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.pieceDetailUpdateLikes),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: Text(context.l10n.albumConfirm),
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
    if (v == null) {
      return const HideNavBar(child: Scaffold(body: SizedBox.shrink()));
    }
    final ideas = ref.watch(ideaViewsProvider((pitId, null))).value ?? const [];
    final drafts = ref.watch(draftViewsProvider(pitId)).value ?? const [];
    final myIdeas = ideas.where((i) => v.ideaIds.contains(i.idea.id)).toList();
    final myDrafts = drafts
        .where((d) => v.draftIds.contains(d.draft.id))
        .toList();
    final p = v.piece;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SubPageHeader(
                title: '',
                trailing: [
                  HeaderIconButton(
                    label: context.l10n.commonEdit,
                    icon: AppIcons.edit,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PieceFormPage(pitId: pitId, pieceId: pieceId),
                      ),
                    ),
                  ),
                  HeaderIconButton(
                    label: context.l10n.commonDelete,
                    icon: AppIcons.trash,
                    color: t.danger,
                    onTap: () async {
                      final ok = await confirmDelete(
                        context,
                        title: context.l10n.pieceDetailDeleteTitle,
                      );
                      if (!ok || !context.mounted) return;
                      await ref.read(databaseProvider).deletePieces([pieceId]);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    if (v.images.isEmpty)
                      AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.piece.bg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: SvgIcon(
                              AppIcons.image,
                              size: 46,
                              strokeWidth: 1.4,
                              color: t.ink.withValues(alpha: .22),
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < v.images.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ImageGalleryPage(
                                images: v.images,
                                initialIndex: i,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
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
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            p.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${p.finishedAt.year} / ${p.finishedAt.month.toString().padLeft(2, '0')} / ${p.finishedAt.day.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: t.text3),
                        ),
                      ],
                    ),
                    if (p.isPublished) ...[
                      const SizedBox(height: 14),
                      _LikesCard(
                        piece: p,
                        dark: dark,
                        onTap: () => _editLikes(context, ref, v),
                      ),
                    ],
                    if (p.body.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        p.body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: t.ink.withValues(alpha: .85),
                        ),
                      ),
                    ],
                    if (v.tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in v.tags)
                            GestureDetector(
                              onTap: onTagTap == null
                                  ? null
                                  : () => onTagTap!(tag.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: t.chipBg,
                                  borderRadius: BorderRadius.circular(
                                    Radii.chip,
                                  ),
                                ),
                                child: Text(
                                  '#${tag.name}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.text2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (p.isPublished || p.isCommission) ...[
                      const SizedBox(height: 16),
                      _InfoCard(piece: p, payment: v.payment),
                    ],
                    if (p.isPublished && v.links.isNotEmpty) ...[
                      _Section(context.l10n.pieceFormSocialLinks),
                      for (final l in v.links)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _LinkRow(link: l),
                        ),
                    ],
                    if (myIdeas.isNotEmpty) ...[
                      _Section(context.l10n.ideaLinkedHeading),
                      for (final i in myIdeas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => IdeaDetailPage(
                                  ideaId: i.idea.id,
                                  pitId: pitId,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: t.idea.bg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      // 設計稿 #EDE2B5（比腦洞底色深一階）。
                                      color: dark
                                          ? t.idea.fg.withValues(alpha: .2)
                                          : const Color(0xFFEDE2B5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: SvgIcon(
                                        AppIcons.bulb,
                                        size: 20,
                                        strokeWidth: 1.7,
                                        color: t.idea.fg,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      i.idea.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SvgIcon(
                                    AppIcons.chevronRight,
                                    size: 18,
                                    strokeWidth: 2,
                                    color: t.idea.fg,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (myDrafts.isNotEmpty) ...[
                      _Section(context.l10n.draftLinkedHeading),
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
                                  builder: (_) => DraftDetailPage(
                                    draftId: d.draft.id,
                                    pitId: pitId,
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
    );
  }
}

/// 區塊標題：13/700，上距 20、下距 10。
class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

/// 互動量卡：愛心＋實際／目標、達標徽章、進度條、兩端說明。
class _LikesCard extends StatelessWidget {
  const _LikesCard({
    required this.piece,
    required this.dark,
    required this.onTap,
  });
  final Piece piece;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final act = piece.actualLikes;
    final tar = piece.targetLikes;
    final reached = tar > 0 && act >= tar;
    final accentHex =
        '#${(t.accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderCard),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SvgIcon(
                  AppIcons.heart,
                  size: 26,
                  strokeWidth: 0,
                  color: t.accent,
                  fill: accentHex,
                ),
                const SizedBox(width: 8),
                Text(
                  '$act',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (tar > 0)
                  Text(
                    ' / $tar',
                    style: TextStyle(fontSize: 14, color: t.text3, height: 1.8),
                  ),
                const Spacer(),
                if (reached)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF5C8A5C).withValues(alpha: .25)
                          : const Color(0xFFE5EFE3),
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Text(
                      context.l10n.pieceDetailReached,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: dark
                            ? const Color(0xFF9CC79C)
                            : const Color(0xFF5C8A5C),
                      ),
                    ),
                  ),
              ],
            ),
            if (tar > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (act / tar).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: t.accent,
                  backgroundColor: dark ? t.chipBg : const Color(0xFFF0DDD4),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.pieceDetailActualLikes(act),
                  style: TextStyle(fontSize: 11, color: t.text3),
                ),
                if (tar > 0)
                  Text(
                    context.l10n.pieceDetailTarget(tar),
                    style: TextStyle(fontSize: 11, color: t.text3),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 公開發佈與商稿資訊卡（設計稿沒畫，沿用卡片樣式）：左標籤、右內容，細線分隔。
/// 發佈日期（已公開發佈）；委託人、金額、收款、交稿日期（商稿，空的欄位不列）。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.piece, required this.payment});
  final Piece piece;
  final PaymentState payment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final divider = Theme.of(context).brightness == Brightness.dark
        ? t.border
        : const Color(0xFFF1EADF);
    final p = piece;
    final rows = <(String, Widget)>[
      if (p.isPublished)
        (
          context.l10n.pieceFormPublishDate,
          _value(fmtSlash(p.publishedAt ?? p.finishedAt)),
        ),
      if (p.isCommission) ...[
        if (p.client.isNotEmpty)
          (context.l10n.pieceFormClient, _value(p.client)),
        if (p.amount != null && p.amount! > 0)
          (
            context.l10n.pieceFormAmount,
            _value(formatPieceMoney(p.currency, p.amount!), bold: true),
          ),
        (
          context.l10n.pieceDetailPayment,
          PaymentChip(state: payment, currency: p.currency),
        ),
        if (p.dueAt != null)
          (context.l10n.pieceFormDueDate, _value(fmtSlash(p.dueAt!))),
      ],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: divider)),
              ),
              child: Row(
                children: [
                  Text(
                    rows[i].$1,
                    style: TextStyle(fontSize: 13, color: t.text3),
                  ),
                  const Spacer(),
                  rows[i].$2,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _value(String text, {bool bold = false}) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    ),
  );
}

/// 社交媒體連結列：平台徽章、平台名稱、外開圖示；點擊開啟網址。
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});
  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var platform = PieceSocialPlatform.fromLabel(link.platform);
    if (platform == PieceSocialPlatform.other) {
      platform = detectSocialPlatform(link.url);
    }
    final host = socialHostOf(link.url);
    final name = platform == PieceSocialPlatform.other && host.isNotEmpty
        ? host
        : platform.displayName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final uri = Uri.tryParse(
          link.url.contains('://') ? link.url : 'https://${link.url}',
        );
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderCard),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SocialPlatformBadge(platform, size: 30, radius: 8, fontSize: 13),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            SvgIcon(
              AppIcons.externalLink,
              size: 16,
              strokeWidth: 1.9,
              color: t.text4,
            ),
          ],
        ),
      ),
    );
  }
}
