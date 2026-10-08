import 'package:flutter/material.dart';

/// 設計稿的虛線外框（1.5px dashed）。內容放在 [child]。
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.color,
    required this.radius,
    this.fill,
    this.width = 1.5,
    this.padding,
    this.child,
  });

  final Color color;
  final double radius;
  final Color? fill;
  final double width;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPainter(color, radius, fill, width),
    child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
  );
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color, this.radius, this.fill, this.width);
  final Color color;
  final double radius;
  final Color? fill;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      Radius.circular(radius),
    );
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 6 + 4;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter o) =>
      o.color != color ||
      o.radius != radius ||
      o.fill != fill ||
      o.width != width;
}
