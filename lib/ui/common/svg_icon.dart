import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 設計稿 icon：直接使用設計稿裡的 24×24 線條 SVG 圖形（inline `<path>` / `<circle>` / `<rect>`）。
///
/// [shapes] 只放圖形本身（不含 `<svg>` 外框）；線寬、顏色、尺寸由這裡帶入。
/// 顏色預設取目前的 [IconTheme]／文字色，需要時傳 [color]。
class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.shapes, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.8,
    this.fill = 'none',
  });

  final String shapes;
  final double size;
  final Color? color;
  final double strokeWidth;

  /// 設計稿少數 icon 用實心（例如同人圖的愛心），其餘為 `none`。
  final String fill;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
      'fill="$fill" stroke="currentColor" stroke-width="$strokeWidth" '
      'stroke-linecap="round" stroke-linejoin="round">$shapes</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: c),
    );
  }
}
