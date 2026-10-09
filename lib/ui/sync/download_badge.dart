import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import 'ring_painter.dart';
import 'sync_colors.dart';
import 'sync_icons.dart';

/// 還沒下載完的圖片上的蓋層：淡色（35%）＋右下角白色圓形角標（下載箭頭＋進度環，MainSyncing）。
///
/// 整個蓋層不接收點擊，不影響圖片格的點擊與尺寸。[progress] 非 null＝確定進度環；
/// null＝排隊中，環轉圈。格子太小時角標等比縮小，小到放不下就只留淡色。
class DownloadOverlay extends StatelessWidget {
  const DownloadOverlay({super.key, required this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide;
          // 設計稿：32px、距右下 8px；小格子縮小，過小不畫角標。
          final size = side >= 96 ? 32.0 : (side * 0.34).clamp(0.0, 32.0);
          final inset = side >= 96 ? 8.0 : (size * 0.25).clamp(2.0, 8.0);
          final label = progress == null
              ? l.pitsNotDownloaded
              : l.syncuiBadgeDownloading((progress! * 100).round());
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: t.ground.withValues(alpha: .35)),
              if (size >= 14)
                Positioned(
                  right: inset,
                  bottom: inset,
                  child: Semantics(
                    label: label,
                    child: DownloadBadge(size: size, progress: progress),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 白色圓底＋下載箭頭＋進度環。[size] 32 為設計稿尺寸。
class DownloadBadge extends StatefulWidget {
  const DownloadBadge({super.key, this.size = 32, this.progress});
  final double size;
  final double? progress;

  @override
  State<DownloadBadge> createState() => _DownloadBadgeState();
}

class _DownloadBadgeState extends State<DownloadBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _spin;

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(DownloadBadge old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  // 只有排隊中（沒有進度）才需要轉圈；有進度時停掉動畫。
  void _syncSpin() {
    if (widget.progress == null) {
      _spin ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat();
    } else if (_spin != null) {
      _spin!.dispose();
      _spin = null;
    }
  }

  @override
  void dispose() {
    _spin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final k = widget.size / 32;
    CustomPainter painter(double f) => RingPainter(
      radius: 12.5 * k,
      strokeWidth: 2.5 * k,
      track: colors.track,
      color: colors.progress,
      fraction: f,
    );
    final ring = widget.progress != null
        ? CustomPaint(
            size: Size.square(widget.size),
            painter: painter(widget.progress!),
          )
        : RotationTransition(
            turns: _spin!,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: painter(0.25),
            ),
          );
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.badgeBg,
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: ring),
          SvgIcon(
            SyncIcons.badgeDownload,
            size: 14 * k,
            strokeWidth: 2.4,
            color: colors.progress,
          ),
        ],
      ),
    );
  }
}
