import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/sensitive.dart';
import 'app_icons.dart';
import 'media_badges.dart' show mediaBadgeColor;
import 'sensitive_reveal.dart';
import 'svg_icon.dart';

export '../../state/sensitive.dart' show SensitiveDisplay;

/// 敏感內容（D-104）的列表類縮圖共用外框：依 [sensitiveDisplayProvider] 把 [child]
/// 模糊（安全模式開）、加左上角小標（安全模式關），或原樣顯示。
///
/// - 所有「列表類」畫面的縮圖（列表、九宮格、瀑布、搜尋結果、時間軸、各種選擇 sheet、同步 sheet…）
///   都經過它（目前集中在 `MediaThumb`）。D-110 起詳情頁也模糊（取代 D-104「一律正常顯示」），
///   圓圈固定 52px（[circleSize]；`DraftDetailSafe`），安全模式關時不加小標（[showBadge] false）。
///   圖片預覽頁（官圖／同人圖預覽、詳情頁點開的全螢幕看圖、iPad 參考檢視）和表單內預覽（D-102）一律正常顯示，不經過它。
/// - [file] 是這張圖的檔名（原檔檔名；影片的截圖檔名也可以）。
/// - 模糊的是 [child]（圖片本身）；GIF／影片小標、張數、選取框等請畫在它外面，不會被模糊。
/// - 不攔截點擊（蓋層包 [IgnorePointer]）。
class SensitiveGate extends ConsumerWidget {
  const SensitiveGate({
    super.key,
    required this.file,
    required this.child,
    this.badgeInset = 6,
    this.enabled = true,
    this.circleSize,
    this.showBadge = true,
  });

  final String file;
  final Widget child;

  /// 小標離左上角的距離（九宮格 6，artboard `DraftGridR18Off`）。
  final double badgeInset;

  /// false＝這個位置永遠不處理（例如詳情頁裡重用列表元件時）。
  final bool enabled;

  /// 模糊時中間圓圈的直徑；null＝列表預設（34px，小格子縮小）。詳情頁主圖 52、縮圖列 24。
  final double? circleSize;

  /// false＝安全模式關時不加左上角小標（詳情頁：小標只在列表類畫面出現）。
  final bool showBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    return SensitiveFrame(
      mode: resolveSensitiveMode(context, ref, file, showBadge: showBadge),
      badgeInset: badgeInset,
      circleSize: circleSize,
      child: child,
    );
  }
}

/// [file] 現在該怎麼畫（[SensitiveGate]、[SensitiveMotionGate] 共用）。
///
/// - [showBadge] false：安全模式關時不加左上角小標（詳情／預覽頁）。
SensitiveDisplay resolveSensitiveMode(
  BuildContext context,
  WidgetRef ref,
  String file, {
  bool showBadge = true,
}) {
  var mode = ref.watch(sensitiveDisplayProvider(file));
  if (!showBadge && mode == SensitiveDisplay.badge) {
    mode = SensitiveDisplay.none;
  }
  if (mode == SensitiveDisplay.badge && SensitivePanelScope.of(context)) {
    mode = SensitiveDisplay.none;
  }
  return mode;
}

/// 會動的媒體（GIF、影片，D-113 ①）的敏感閘門。
///
/// 安全模式開（[SensitiveDisplay.blur]／[SensitiveDisplay.pending]）：只畫 [still]（第一格靜態圖：
/// GIF＝第一格、影片＝poster），套模糊＋中間圓圈；**不會建立 [live]**——不解碼動畫、不建立播放器，
/// 也就不會在模糊後面偷偷播放。其他情況（沒標記、安全模式關、被撳開）畫 [live]（安全模式關時
/// 照 [showBadge] 決定要不要加左上角小標）。
class SensitiveMotionGate extends ConsumerWidget {
  const SensitiveMotionGate({
    super.key,
    required this.file,
    required this.still,
    required this.live,
    this.badgeInset = 6,
    this.circleSize,
    this.showBadge = true,
  });

  final String file;
  final WidgetBuilder still;
  final WidgetBuilder live;
  final double badgeInset;
  final double? circleSize;
  final bool showBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = resolveSensitiveMode(context, ref, file, showBadge: showBadge);
    final blurred =
        mode == SensitiveDisplay.blur || mode == SensitiveDisplay.pending;
    return SensitiveFrame(
      mode: mode,
      badgeInset: badgeInset,
      circleSize: circleSize,
      child: blurred ? still(context) : live(context),
    );
  }
}

/// [SensitiveGate] 的畫法本身（不查 provider），方便測試與直接指定模式。
class SensitiveFrame extends StatelessWidget {
  const SensitiveFrame({
    super.key,
    required this.mode,
    required this.child,
    this.badgeInset = 6,
    this.circleSize,
  });

  final SensitiveDisplay mode;
  final Widget child;
  final double badgeInset;
  final double? circleSize;

  /// 模糊強度（CSS `blur(16px)`）。
  static const double blurSigma = 16;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case SensitiveDisplay.none:
        return child;
      case SensitiveDisplay.badge:
        return Stack(
          fit: StackFit.passthrough,
          children: [
            child,
            Positioned(
              left: badgeInset,
              top: badgeInset,
              child: const IgnorePointer(child: SensitiveBadge()),
            ),
          ],
        );
      case SensitiveDisplay.pending:
      case SensitiveDisplay.blur:
        return Stack(
          fit: StackFit.passthrough,
          children: [
            ClipRect(
              child: ImageFiltered(
                key: const ValueKey('sensitiveBlur'),
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: child,
              ),
            ),
            if (mode == SensitiveDisplay.blur)
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // 34px 圓底；格子太小（小縮圖）時縮成格子短邊的 60%，免得蓋滿整張。
                      // 指定了 [circleSize]（詳情頁 52／縮圖列 24）就照它。
                      final side = circleSize != null
                          ? circleSize!
                          : c.hasBoundedWidth && c.hasBoundedHeight
                          ? (c.biggest.shortestSide * 0.6).clamp(14.0, 34.0)
                          : 34.0;
                      return Center(child: SensitiveBlurCircle(size: side));
                    },
                  ),
                ),
              ),
          ],
        );
    }
  }
}

/// 模糊時中間的圓：34px、`rgba(43,38,34,.62)`、白色眼睛斜線（icon 約為圓的 53%）。
class SensitiveBlurCircle extends StatelessWidget {
  const SensitiveBlurCircle({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.sensitiveBadgeLabel,
    child: Container(
      key: const ValueKey('sensitiveCircle'),
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: mediaBadgeColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgIcon(
        AppIcons.eyeSlash,
        size: size * 18 / 34,
        strokeWidth: 1.9,
        color: Colors.white,
      ),
    ),
  );
}

/// 縮圖上的敏感小標：22px 圓、`rgba(43,38,34,.62)`、白色眼睛斜線（13px、線寬 2.4）。
/// 安全模式關時列表左上角用；表單的小縮圖（左下角）也用同一個。
class SensitiveBadge extends StatelessWidget {
  const SensitiveBadge({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.sensitiveBadgeLabel,
    child: Container(
      key: const ValueKey('sensitiveBadge'),
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: mediaBadgeColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgIcon(
        AppIcons.eyeSlash,
        size: size * 13 / 22,
        strokeWidth: 2.4,
        color: Colors.white,
      ),
    ),
  );
}
