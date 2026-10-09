import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/image_location.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/svg_icon.dart';
import 'sync_colors.dart';
import 'sync_icons.dart';

/// 打開「同步進度」bottom sheet（SyncSheet，D-052）。傳完會自動關閉。
///
/// 設計稿的 sheet 蓋住底部導覽列，所以用最上層 Navigator（全域 sheet）。
Future<void> showSyncSheet(BuildContext context) {
  final t = context.tokens;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const SyncSheet(),
  );
}

/// 最多列出幾張（其餘寫「還有 N 張等待中」）。
const syncSheetMaxRows = 4;

class SyncSheet extends ConsumerStatefulWidget {
  const SyncSheet({super.key});

  @override
  ConsumerState<SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<SyncSheet> {
  bool _closing = false;

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    // 打開的瞬間剛好傳完：直接關。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(syncControllerProvider).isTransferring) {
        _close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    ref.listen(syncControllerProvider.select((s) => s.isTransferring), (
      _,
      transferring,
    ) {
      if (!transferring) _close();
    });
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: l.syncuiSheetLabel,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const _Header(),
              const _Rows(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 標題、已完成 / 總數、總進度條、上傳與下載張數。
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    // 只取數字，傳輸清單裡逐位元組的變動不會讓標頭重建。
    final (done, total, up, down) = ref.watch(
      syncControllerProvider.select(
        (s) =>
            (s.transferDone, s.transferTotal, s.uploadCount, s.downloadCount),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.pitsSyncing,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              l.syncuiProgress(done, total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.strong,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: _Bar(
            height: 6,
            fraction: total == 0 ? 0 : done / total,
            track: colors.track,
            color: colors.progress,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                l.syncuiUploadCount(up),
                style: TextStyle(fontSize: 13, color: t.text2),
              ),
              const SizedBox(width: 16),
              Text(
                l.syncuiDownloadCount(down),
                style: TextStyle(fontSize: 13, color: t.text2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 逐張列出尚未完成的圖片（先處理的在前，最多 [syncSheetMaxRows] 張）＋「還有 N 張等待中」。
class _Rows extends ConsumerWidget {
  const _Rows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final transfers = ref.watch(
      syncControllerProvider.select((s) => s.transfers),
    );
    final pending = [
      for (final x in transfers)
        if (!x.isDone) x,
    ];
    final shown = pending.take(syncSheetMaxRows).toList();
    final more = pending.length - shown.length;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final x in shown)
            _TransferRow(key: ValueKey('${x.direction.name}:${x.file}'), x: x),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                context.l10n.syncuiMoreWaiting(more),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.text3),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow({super.key, required this.x});
  final SyncTransfer x;

  static String cellName(BuildContext context, ImageCell cell) {
    final l = context.l10n;
    return switch (cell) {
      ImageCell.official => l.pitsOfficial,
      ImageCell.fan => l.pitsFanArt,
      ImageCell.junk => l.junkTitle,
      ImageCell.draft => l.goalsKindDraft,
      ImageCell.idea => l.goalsKindIdea,
      ImageCell.piece => l.goalsKindPiece,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final loc = ref.watch(imageLocationProvider(x.file)).value;
    final waiting = !x.isActive;
    final percent = x.isActive && x.progress != null
        ? (x.progress! * 100).round().clamp(0, 100)
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: StoredImage(
                x.file,
                cacheWidth: 150,
                showDownloadBadge: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _DirectionTag(upload: x.isUpload),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc == null
                            ? ''
                            : l.syncuiLocation(
                                loc.pitName,
                                cellName(context, loc.cell),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (waiting)
                      Text(
                        l.syncuiWaiting,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.waitText,
                        ),
                      )
                    else if (percent != null)
                      Text(
                        l.syncuiPercent(percent),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.strong,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: waiting
                      ? _Bar(
                          height: 5,
                          fraction: 0,
                          track: colors.waitTrack,
                          color: colors.progress,
                        )
                      : _Bar(
                          height: 5,
                          // 進行中但不知道大小：不確定進度條。
                          fraction: x.progress,
                          track: colors.track,
                          color: colors.progress,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionTag extends StatelessWidget {
  const _DirectionTag({required this.upload});
  final bool upload;

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: colors.tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(
            upload ? SyncIcons.upload : SyncIcons.download,
            size: 14,
            strokeWidth: 2.2,
            color: colors.progress,
          ),
          const SizedBox(width: 3),
          Text(
            upload ? l.syncuiUpload : l.syncuiDownload,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.progress,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圓角進度條；[fraction] 為 null＝不確定進度。
class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.fraction,
    required this.track,
    required this.color,
  });
  final double height;
  final double? fraction;
  final Color track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: height,
        child: fraction == null
            ? LinearProgressIndicator(
                minHeight: height,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(color),
              )
            : TweenAnimationBuilder<double>(
                tween: Tween(end: fraction!.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 200),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: height,
                  backgroundColor: track,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
      ),
    );
  }
}
