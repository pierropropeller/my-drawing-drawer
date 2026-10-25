import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/user_avatar.dart';
import '../me/backup_page.dart';
import 'ring_painter.dart';
import 'sync_colors.dart';
import 'sync_popover.dart';

/// 外圈狀態（D-052）。
enum SyncRingMode { none, checking, transferring }

/// 外圈淡出後留在頭像右下角的小圓點：琥珀＝有圖片同步失敗（D-109），紅＝Drive 已滿（D-103）。
/// 同步進行中不畫（外圈在轉）。
enum SyncRingDot { none, failed, full }

/// 主頁左上角頭像：同步狀態收在外圈（MainSyncing）。
///
/// 檢查中＝一段短弧轉圈（不可點）；傳輸中＝進度環（按完成張數／總張數），可點開「同步進度」；
/// 其他＝外圈淡出，若有琥珀點（失敗）／紅點（Drive 已滿）也可點，開啟對應狀態的 sheet（D-113 ③）。外圈 48px 但佔位只有頭像本身（外圈畫在頭像外 4px），頁面不會因此位移。
///
/// 點開的方式依視窗闊度：＜600 底部 sheet（手機）、≥600 頭像 popover（iPad／平板，見
/// [showSyncProgress]）。rail／sidebar 的頭像用 [serif]／[background]／[foreground] 套上稿的配色，
/// [onOpenSettings] 是 popover「同步設定」連結的動作。
class SyncAvatar extends ConsumerWidget {
  const SyncAvatar({
    super.key,
    this.size = 40,
    this.serif = false,
    this.background,
    this.foreground,
    this.onOpenSettings,
  });
  final double size;
  final bool serif;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      syncControllerProvider.select(
        (s) => s.isRingTransferring
            ? SyncRingMode.transferring
            : s.isChecking
            ? SyncRingMode.checking
            : SyncRingMode.none,
      ),
    );
    final dot = ref.watch(
      syncControllerProvider.select(
        (s) => s.isSyncing
            ? SyncRingDot.none
            : s.quotaFull
            ? SyncRingDot.full
            : s.hasFailures
            ? SyncRingDot.failed
            : SyncRingDot.none,
      ),
    );
    final fraction =
        ref.watch(syncControllerProvider.select((s) => s.transferFraction)) ??
        0.0;
    return SyncRing(
      mode: mode,
      dot: dot,
      // rail／sidebar 的頭像（SyncPopoverPartial／Full）：小點 13px，貼頭像右下角。
      navStyleDot: serif,
      fraction: fraction,
      size: size,
      // 傳輸中點外圈、或外圈收掉後點琥珀／紅點（D-113 ③）都打開同步 sheet／popover；
      // 小點在可點範圍裡（整個 48px 外圈）。檢查中不可點。
      onTap:
          mode == SyncRingMode.transferring ||
              (mode == SyncRingMode.none && dot != SyncRingDot.none)
          ? () => showSyncProgress(
              context,
              onOpenSettings: onOpenSettings,
              // 手機沒有「我的」側欄：Drive 已滿的「管理儲存空間」直接推備份頁（BackupFull）。
              onManageStorage:
                  onOpenSettings ??
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BackupPage()),
                  ),
            )
          : null,
      child: UserAvatar(
        size: size,
        serif: serif,
        background: background,
        foreground: foreground,
      ),
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
    this.dot = SyncRingDot.none,
    this.navStyleDot = false,
  });

  final SyncRingMode mode;

  /// 外圈收掉之後的狀態小點（見 [SyncRingDot]）。
  final SyncRingDot dot;

  /// iPad rail／sidebar 的小點：13px、描邊 2.5（用導覽列底色）、對齊頭像右下（right 0、bottom 1）。
  final bool navStyleDot;

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
          if (widget.dot != SyncRingDot.none && !visible)
            Positioned(
              // 外圈比頭像大 4px：navStyleDot 把小點貼回頭像本身的右下角。
              right: widget.navStyleDot ? 4 : 1,
              bottom: widget.navStyleDot ? 5 : 1,
              child: Container(
                key: ValueKey('syncRingDot:${widget.dot.name}'),
                width: widget.navStyleDot ? 13 : 12,
                height: widget.navStyleDot ? 13 : 12,
                decoration: BoxDecoration(
                  color: widget.dot == SyncRingDot.full
                      ? colors.fullDot
                      : colors.failedDot,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.navStyleDot
                        ? context.tokens.nav
                        : Theme.of(context).scaffoldBackgroundColor,
                    width: widget.navStyleDot ? 2.5 : 2,
                  ),
                ),
              ),
            ),
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
          excludeSemantics:
              widget.mode != SyncRingMode.none ||
              widget.dot != SyncRingDot.none,
          label: switch (widget.mode) {
            SyncRingMode.checking => l.syncuiRingChecking,
            SyncRingMode.transferring => l.syncuiRingTransferring,
            SyncRingMode.none => switch (widget.dot) {
              SyncRingDot.failed => l.syncuiRingFailed,
              SyncRingDot.full => l.backupFullTitle,
              SyncRingDot.none => null,
            },
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
