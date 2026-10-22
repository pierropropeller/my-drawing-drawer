import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/sensitive.dart';
import 'app_icons.dart';
import 'media_badges.dart' show mediaBadgeColor;
import 'svg_icon.dart';

export '../../state/sensitive.dart' show SensitiveDisplay;

/// 敏感內容（D-104）的列表類縮圖共用外框：依 [sensitiveDisplayProvider] 把 [child]
/// 模糊（安全模式開）、加左上角小標（安全模式關），或原樣顯示。
///
/// - 所有「列表類」畫面的縮圖（列表、九宮格、瀑布、搜尋結果、時間軸、各種選擇 sheet、同步 sheet…）
///   都經過它（目前集中在 `MediaThumb`）；詳情頁與圖片預覽頁**不要**用它，永遠正常顯示。
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
  });

  final String file;
  final Widget child;

  /// 小標離左上角的距離（九宮格 6，artboard `DraftGridR18Off`）。
  final double badgeInset;

  /// false＝這個位置永遠不處理（例如詳情頁裡重用列表元件時）。
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;
    final mode = ref.watch(sensitiveDisplayProvider(file));
    return SensitiveFrame(mode: mode, badgeInset: badgeInset, child: child);
  }
}

/// [SensitiveGate] 的畫法本身（不查 provider），方便測試與直接指定模式。
class SensitiveFrame extends StatelessWidget {
  const SensitiveFrame({
    super.key,
    required this.mode,
    required this.child,
    this.badgeInset = 6,
  });

  final SensitiveDisplay mode;
  final Widget child;
  final double badgeInset;

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
                      final side = c.hasBoundedWidth && c.hasBoundedHeight
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
