import 'package:flutter/material.dart';

import '../../state/app_icon.dart';
import '../../theme/tokens.dart';

/// App 圖示圖片（D-086）：圓角＋1px 外框；[shadow] 為設計稿的柔和陰影（關於／開頭／選擇頁用）。
/// 圖片本身不跟主題色。
class AppIconImage extends StatelessWidget {
  const AppIconImage(
    this.option, {
    super.key,
    required this.size,
    required this.radius,
    this.shadow = true,
  });

  final AppIconOption option;
  final double size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ring = dark ? t.border : const Color(0xFFEAE1D5);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(color: ring, spreadRadius: 1),
          if (shadow)
            BoxShadow(
              color: const Color(0xFF2B2622).withValues(alpha: .12),
              offset: const Offset(0, 6),
              blurRadius: 16,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          option.asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // 圖是白底：不論亮暗主題都保持原色。
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
