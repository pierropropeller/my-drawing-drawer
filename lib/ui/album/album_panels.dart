import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/sensitive_gate.dart';
import '../common/sensitive_reveal.dart';
import '../common/svg_icon.dart';
import 'album_actions.dart';
import 'album_image.dart';
import '../search/tagged_list.dart';
import 'fan_art_edit_page.dart';
import 'ipadlists_icons.dart';
import 'official_new_page.dart';
import 'wide_layout.dart';

/// 官方圖冊／好看同人圖在平板上的預覽面板內容（FanArt／Official 設計稿的右側 aside）。
///
/// 寬版（≥840）固定在右側；medium（600–839）放進底部 sheet。面板自己不含外框，
/// 外框（[SidePanelFrame]）由呼叫端決定。
class AlbumPreviewPanel extends StatelessWidget {
  const AlbumPreviewPanel({
    super.key,
    required this.image,
    required this.info,
    required this.actions,
    required this.onReference,
  });
  final AlbumImage image;

  /// 封面下方的資訊（作者／出處／tag／加入日期）。
  final List<Widget> info;
  final List<PanelAction> actions;

  /// 「參考檢視」入口：呼叫端（`AlbumView`）接到 `openReferenceViewer`。
  final VoidCallback onReference;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = image.media;
    return LayoutBuilder(
      builder: (context, c) {
        final coverH = (c.maxHeight * 0.5).clamp(200.0, 420.0);
        // 影片／GIF（MediaVideo）：影片在面板裡點播放鈕才播（控制列的全螢幕鍵＝參考檢視），
        // GIF 預覽時自動循環；圖片仍是靜態圖＋右下角「參考檢視」。
        final Widget cover;
        if (media.isVideo) {
          // D-113 ①：已標記的影片在安全模式開時只顯示模糊的 poster，不建立播放器；
          // 撳面板左上角的眼睛鈕（P-038）只顯示這一張。
          cover = SizedBox(
            height: coverH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: const Color(0xFF1E1B18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SensitiveMotionGate(
                      file: media.file,
                      badgeInset: 10,
                      circleSize: 52,
                      showBadge: false,
                      still: (_) => StaticMediaImage(
                        media,
                        cacheWidth: 900,
                        fit: BoxFit.contain,
                      ),
                      live: (_) => VideoPlayerView(
                        key: ValueKey('panel-video-${image.id}'),
                        file: media.file,
                        poster: media.poster,
                        durationMs: media.durationMs,
                        badgeInset: 10,
                        onFullscreen: (_, _) => onReference(),
                      ),
                    ),
                    const SensitiveRevealOverlayButton(),
                  ],
                ),
              ),
            ),
          );
        } else {
          cover = Semantics(
            button: true,
            label: context.l10n.ipadListsReferenceView,
            child: GestureDetector(
              onTap: onReference,
              child: SizedBox(
                height: coverH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: t.chipBg),
                      if (media.isGif)
                        // 已標記的 GIF 在安全模式開時只畫模糊的第一格（D-113 ①）。
                        SensitiveMotionGate(
                          file: media.file,
                          badgeInset: 10,
                          circleSize: 52,
                          still: (_) => StaticMediaImage(
                            media,
                            cacheWidth: 900,
                            fit: BoxFit.contain,
                          ),
                          live: (_) => MediaViewer(media, cacheWidth: 900),
                        )
                      else
                        MediaThumb(
                          media,
                          cacheWidth: 900,
                          fit: BoxFit.contain,
                          badgeInset: 10,
                          sensitiveCircle: 52,
                        ),
                      if (media.isGif)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: _PanelBadge(context.l10n.ipadauditGifLoop),
                        ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _ReferencePill(
                          context.l10n.ipadListsReferenceView,
                        ),
                      ),
                      // P-038：面板沒有標題列，眼睛鈕在圖片左上角（只顯示這一張）。
                      const SensitiveRevealOverlayButton(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final meta = media.isVideo
            ? context.l10n.ipadauditVideoMeta(
                formatMediaDuration(media.durationMs),
              )
            : media.isGif
            ? context.l10n.ipadauditGifMeta
            : null;
        return SensitiveReveal(
          current: media.file,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(height: 14),
                      ...info.take(1),
                      if (meta != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            meta,
                            style: TextStyle(fontSize: 12.5, color: t.text3),
                          ),
                        ),
                      ...info.skip(1),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              PanelActionBar(actions: actions),
            ],
          ),
        );
      },
    );
  }
}

/// 預覽面板封面上的小標（例如「GIF · 自動循環」）：深色半透明底、白字。
class _PanelBadge extends StatelessWidget {
  const _PanelBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: mediaBadgeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.44,
        height: 1.1,
      ),
    ),
  );
}

class _ReferencePill extends StatelessWidget {
  const _ReferencePill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
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
          label,
          style: const TextStyle(color: Color(0xFFF5F0E8), fontSize: 12),
        ),
      ],
    ),
  );
}

/// 一排 tag 小標（#角色1…）；用資料庫的 tag 對照名稱。
class AlbumTagPills extends ConsumerWidget {
  const AlbumTagPills({
    super.key,
    required this.pitId,
    required this.target,
    required this.id,
  });
  final String pitId;
  final TagTarget target;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final ids = ref.watch(tagIdsProvider((target, id))).value ?? const [];
    final names = {
      for (final tag in ref.watch(tagsProvider(pitId)).value ?? const <Tag>[])
        tag.id: tag.name,
    };
    final shown = [
      for (final i in ids)
        if (names[i] != null) (i, names[i]!),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (tagId, n) in shown)
            // 點 tag：進該坑的搜尋結果頁並帶上這個 tag（D-107）。
            GestureDetector(
              onTap: () => openTagSearch(context, pitId, tagId),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: t.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#$n',
                  style: TextStyle(fontSize: 12, color: t.text2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _addedDate(BuildContext context, DateTime? d) =>
    d == null ? '' : previewDateText(context, d);

/// 「2026 / 09 / 21 加入」。
String previewDateText(BuildContext context, DateTime d) =>
    context.l10n.albumPreviewDateAdded(
      d.year,
      d.month.toString().padLeft(2, '0'),
      d.day.toString().padLeft(2, '0'),
    );

/// 官方圖冊的預覽面板（Official 設計稿）：分組小標＋加入日期、tag；
/// 分享／下載／設為封面／編輯（分組、tag）／刪除。
class OfficialPreviewPanel extends ConsumerWidget {
  const OfficialPreviewPanel({
    super.key,
    required this.pitId,
    required this.image,
    required this.onReference,
    required this.onDismiss,
  });
  final String pitId;
  final AlbumImage image;
  final VoidCallback onReference;

  /// 圖被刪除後，關掉面板（寬版＝清掉選取、sheet＝收起）。
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final group = image.groupName ?? '';
    return AlbumPreviewPanel(
      image: image,
      onReference: onReference,
      info: [
        Row(
          children: [
            if (group.isNotEmpty)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.official.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.official.fg,
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Text(
              _addedDate(context, image.createdAt),
              style: TextStyle(fontSize: 12, color: t.text3),
            ),
          ],
        ),
        AlbumTagPills(pitId: pitId, target: TagTarget.official, id: image.id),
      ],
      actions: [
        PanelAction(
          AppIcons.share,
          l.commonShare,
          () => shareImage(ref, image),
        ),
        PanelAction(AppIcons.download, l.commonDownload, () async {
          final n = await downloadImages(ref, [image]);
          if (!context.mounted) return;
          showSnack(context, n > 0 ? l.albumSavedToGallery : l.albumSaveFailed);
        }),
        PanelAction(AppIcons.setCover, l.albumSetCover, () async {
          await ref.read(databaseProvider).setOfficialCover(pitId, image.id);
          if (context.mounted) showSnack(context, l.albumCoverSetOfficial);
        }),
        PanelAction(AppIcons.edit, l.commonEdit, () async {
          final deleted = await openOfficialEdit(
            context,
            pitId: pitId,
            imageId: image.id,
          );
          if (deleted == true) onDismiss();
        }),
        PanelAction(AppIcons.trash, l.commonDelete, () async {
          final ok = await confirmDelete(
            context,
            title: l.albumDeleteImageTitle,
            toTrash: true,
          );
          if (!ok || !context.mounted) return;
          await ref.read(databaseProvider).deleteOfficial([image.id]);
          onDismiss();
        }, color: t.danger),
      ],
    );
  }
}

/// 好看同人圖的預覽面板（FanArt 設計稿）：作者＋出處小標、tag、加入日期；
/// 設為封面／下載／編輯／刪除。
class FanArtPreviewPanel extends ConsumerWidget {
  const FanArtPreviewPanel({
    super.key,
    required this.pitId,
    required this.image,
    required this.onReference,
    required this.onDismiss,
  });
  final String pitId;
  final AlbumImage image;
  final VoidCallback onReference;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final author = image.author ?? '';
    final group = image.groupName ?? '';
    return AlbumPreviewPanel(
      image: image,
      onReference: onReference,
      info: [
        if (author.isNotEmpty || group.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (group.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: t.chipBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.text2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        AlbumTagPills(pitId: pitId, target: TagTarget.fanArt, id: image.id),
        if (image.createdAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _addedDate(context, image.createdAt),
              style: TextStyle(fontSize: 12, color: t.text4),
            ),
          ),
      ],
      actions: [
        PanelAction(AppIcons.setCover, l.albumSetCover, () async {
          await ref.read(databaseProvider).setFanArtCover(pitId, image.id);
          if (context.mounted) showSnack(context, l.albumFanCoverSet);
        }),
        PanelAction(AppIcons.download, l.commonDownload, () async {
          final n = await downloadImages(ref, [image]);
          if (!context.mounted) return;
          showSnack(context, n > 0 ? l.albumSavedToGallery : l.albumSaveFailed);
        }),
        PanelAction(AppIcons.edit, l.commonEdit, () async {
          final deleted = await openFanArtEdit(
            context,
            pitId: pitId,
            imageId: image.id,
          );
          if (deleted == true) onDismiss();
        }),
        PanelAction(AppIcons.trash, l.commonDelete, () async {
          final ok = await confirmDelete(
            context,
            title: l.albumDeleteImageTitle,
            toTrash: true,
          );
          if (!ok || !context.mounted) return;
          await ref.read(databaseProvider).deleteFanArts([image.id]);
          onDismiss();
        }, color: t.danger),
      ],
    );
  }
}
