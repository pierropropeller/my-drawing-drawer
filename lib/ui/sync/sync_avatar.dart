import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../sync/sync_controller.dart';
import '../common/user_avatar.dart';
import 'ring_painter.dart';
import 'sync_colors.dart';
import 'sync_sheet.dart';

/// 外圈狀態（D-052）。
enum SyncRingMode { none, checking, transferring }

/// 主頁左上角頭像：同步狀態收在外圈（MainSyncing）。
///
/// 檢查中＝一段短弧轉圈（不可點）；傳輸中＝進度環（按完成張數／總張數），可點開「同步進度」；
/// 其他＝外圈淡出。外圈 48px 但佔位只有頭像本身（外圈畫在頭像外 4px），頁面不會因此位移。
class SyncAvatar extends ConsumerWidget {
  const SyncAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      syncControllerProvider.select(
        (s) => s.isTransferring
            ? SyncRingMode.transferring
            : s.isChecking
            ? SyncRingMode.checking
            : SyncRingMode.none,
      ),
    );
    final fraction =
        ref.watch(syncControllerProvider.select((s) => s.transferFraction)) ??
        0.0;
    return SyncRing(
      mode: mode,
      fraction: fraction,
      size: size,
      onTap: mode == SyncRingMode.transferring
          ? () => showSyncSheet(context)
          : null,
      child: UserAvatar(size: size),
    );
  }
}

/// 頭像外圈本體（可單獨測試）：[child] 是頭像，[size] 是頭像直徑，外圈在其外 4px。
class SyncRing extends StatefulWidget {
  const SyncRing({
    super.key,
    required this.mode,
    required this.fraction,
    required this.child,
    this.size = 40,
    this.onTap,
  });

  final SyncRingMode mode;

  /// 傳輸中的進度 0~1。
  final double fraction;
  final double size;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<SyncRing> createState() => _SyncRingState();
}

class _SyncRingState extends State<SyncRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  // 淡出時外圈還要畫完最後一個樣子，所以記住最後一個有效狀態。
  SyncRingMode _shown = SyncRingMode.none;
  double _shownFraction = 0;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(SyncRing old) {
    super.didUpdateWidget(old);
    _apply();
  }

  void _apply() {
    if (widget.mode != SyncRingMode.none) {
      _shown = widget.mode;
      _shownFraction = widget.fraction;
    }
    // 只有檢查中才需要持續動畫。
    if (widget.mode == SyncRingMode.checking) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final outer = widget.size + 8;
    final visible = widget.mode != SyncRingMode.none;
    final Widget ring;
    if (_shown == SyncRingMode.checking) {
      // 不確定狀態：弧約占 1/4，整個環轉動。
      ring = RotationTransition(
        turns: _spin,
        child: CustomPaint(
          size: Size.square(outer),
          painter: RingPainter(
            radius: outer / 2 - 1.5,
            strokeWidth: 2.5,
            track: colors.track,
            color: colors.progress,
            fraction: 0.25,
          ),
        ),
      );
    } else {
      // 進度平滑推進，避免一張一張跳。
      ring = TweenAnimationBuilder<double>(
        tween: Tween(end: _shownFraction),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (_, v, _) => CustomPaint(
          size: Size.square(outer),
          painter: RingPainter(
            radius: outer / 2 - 1.5,
            strokeWidth: 2.5,
            track: colors.track,
            color: colors.progress,
            fraction: v,
          ),
        ),
      );
    }
    final content = SizedBox(
      width: outer,
      height: outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: ring,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
    // 佔位只算頭像本身（外圈畫在外面），觸控範圍用整個 48px 外圈。
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: OverflowBox(
        maxWidth: outer,
        maxHeight: outer,
        child: Semantics(
          button: widget.onTap != null,
          // 有狀態時只念狀態（頭像裡的字母沒有意義）。
          excludeSemantics: widget.mode != SyncRingMode.none,
          label: switch (widget.mode) {
            SyncRingMode.checking => l.syncuiRingChecking,
            SyncRingMode.transferring => l.syncuiRingTransferring,
            SyncRingMode.none => null,
          },
          child: widget.onTap == null
              ? content
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  child: content,
                ),
        ),
      ),
    );
  }
}
