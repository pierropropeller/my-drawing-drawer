import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 底圈＋一段弧（從 12 點鐘方向順時針）。頭像進度環與未下載角標共用（設計稿的 circle + dasharray）。
class RingPainter extends CustomPainter {
  const RingPainter({
    required this.radius,
    required this.strokeWidth,
    required this.track,
    required this.color,
    required this.fraction,
  });

  final double radius;
  final double strokeWidth;
  final Color track;
  final Color color;

  /// 弧占整圈的比例 0~1。
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, radius, paint..color = track);
    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      2 * math.pi * f,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.track != track ||
      old.color != color ||
      old.fraction != fraction;
}
