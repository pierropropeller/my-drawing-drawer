import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 一排 pills，選中的深色膠囊跟著 [progress]（小數頁碼，來自 [SwipePager]）滑動（D-118）。
///
/// 底下用 [CustomPaint] 畫每粒的底色／框和深色膠囊（位置與闊度在相鄰兩粒之間插值）；
/// 上面一排 pill 只畫字（透明底、透明框，大小不變），字色按膠囊蓋住多少從未選漸變到選中。
/// 每粒的字只有一份（無障礙與測試不會看到兩個）。
///
/// [pill] 回傳第 i 粒：`selectedness` 0＝未選、1＝選中（字色用）；`decorated` 為 true 時
/// 要自己畫底色和框（第一個 frame 還沒量到位置時用），false 時底色和框都要透明。
///
/// 放在橫向捲動區裡時，進度一變就把膠囊捲到可視範圍中間附近；使用者自己捲 pill 列時不會被拉回。
class SlidingPillRow extends StatefulWidget {
  const SlidingPillRow({
    super.key,
    required this.count,
    required this.progress,
    required this.pill,
    required this.fill,
    required this.border,
    required this.capsuleColor,
    this.capsuleBorder,
    this.radius = 999,
    this.spacing = 8,
  });

  final int count;
  final ValueListenable<double> progress;
  final Widget Function(
    BuildContext context,
    int index,
    double selectedness,
    bool decorated,
  )
  pill;

  /// 未選 pill 的底色、框色。
  final Color fill;
  final Color border;
  final Color capsuleColor;
  final Color? capsuleBorder;
  final double radius;
  final double spacing;

  @override
  State<SlidingPillRow> createState() => _SlidingPillRowState();
}

class _SlidingPillRowState extends State<SlidingPillRow> {
  final _stackKey = GlobalKey();
  List<GlobalKey> _keys = [];
  List<Rect>? _rects;

  @override
  void initState() {
    super.initState();
    _syncKeys();
    widget.progress.addListener(_onProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(scroll: true));
  }

  @override
  void didUpdateWidget(SlidingPillRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
    _syncKeys();
    // 文字、數量可能變了：下一個 frame 重量。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _syncKeys() {
    if (_keys.length != widget.count) {
      _keys = [for (var i = 0; i < widget.count; i++) GlobalKey()];
      _rects = null;
    }
  }

  void _measure({bool scroll = false}) {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || !stack.hasSize) return;
    final rects = <Rect>[];
    for (final k in _keys) {
      final box = k.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final o = box.localToGlobal(Offset.zero, ancestor: stack);
      rects.add(o & box.size);
    }
    if (!listEquals(rects, _rects)) setState(() => _rects = rects);
    if (scroll) _follow(animate: false);
  }

  void _onProgress() {
    if (_rects == null) return;
    _follow(animate: false);
  }

  Rect? _capsule(double p) {
    final rects = _rects;
    if (rects == null || rects.isEmpty) return null;
    final c = p.clamp(0.0, rects.length - 1.0);
    final i = c.floor();
    final j = (i + 1).clamp(0, rects.length - 1);
    return Rect.lerp(rects[i], rects[j], c - i);
  }

  /// 把膠囊捲到橫向捲動區中間附近。
  void _follow({required bool animate}) {
    final rect = _capsule(widget.progress.value);
    if (rect == null) return;
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null ||
        scrollable.axisDirection == AxisDirection.up ||
        scrollable.axisDirection == AxisDirection.down) {
      return;
    }
    final pos = scrollable.position;
    if (!pos.hasContentDimensions || !pos.hasViewportDimension) return;
    if (pos.maxScrollExtent <= pos.minScrollExtent) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final viewport = scrollable.context.findRenderObject() as RenderBox?;
    if (stack == null || viewport == null) return;
    // 膠囊中心在捲動內容座標裡的位置。
    final inViewport = stack.localToGlobal(rect.center, ancestor: viewport).dx;
    final contentX = inViewport + pos.pixels;
    final target = (contentX - pos.viewportDimension / 2).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() < 0.5) return;
    if (animate) {
      pos.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      pos.jumpTo(target);
    }
  }

  /// 第 i 粒被膠囊蓋住的比例（0～1）。
  double _cover(Rect capsule, Rect pill) {
    final w = pill.width;
    if (w <= 0) return 0;
    final overlap =
        math.min(capsule.right, pill.right) - math.max(capsule.left, pill.left);
    return (overlap / w).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.progress,
      builder: (context, p, _) {
        final rects = _rects;
        final capsule = _capsule(p);
        final sel = p.round();
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.count; i++) ...[
              if (i > 0) SizedBox(width: widget.spacing),
              KeyedSubtree(
                key: _keys[i],
                child: widget.pill(
                  context,
                  i,
                  capsule == null || rects == null
                      ? (i == sel ? 1.0 : 0.0)
                      : _cover(capsule, rects[i]),
                  capsule == null,
                ),
              ),
            ],
          ],
        );
        return CustomPaint(
          key: _stackKey,
          painter: capsule == null || rects == null
              ? null
              : _PillsPainter(
                  rects: rects,
                  capsule: capsule,
                  radius: widget.radius,
                  fill: widget.fill,
                  border: widget.border,
                  capsuleColor: widget.capsuleColor,
                  capsuleBorder: widget.capsuleBorder,
                ),
          child: row,
        );
      },
    );
  }
}

class _PillsPainter extends CustomPainter {
  _PillsPainter({
    required this.rects,
    required this.capsule,
    required this.radius,
    required this.fill,
    required this.border,
    required this.capsuleColor,
    required this.capsuleBorder,
  });
  final List<Rect> rects;
  final Rect capsule;
  final double radius;
  final Color fill;
  final Color border;
  final Color capsuleColor;
  final Color? capsuleBorder;

  RRect _rr(Rect r) => RRect.fromRectAndRadius(
    r,
    Radius.circular(math.min(radius, r.shortestSide / 2)),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fill;
    final borderPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in rects) {
      canvas.drawRRect(_rr(r), fillPaint);
      canvas.drawRRect(_rr(r.deflate(0.5)), borderPaint);
    }
    canvas.drawRRect(_rr(capsule), Paint()..color = capsuleColor);
    final cb = capsuleBorder;
    if (cb != null) {
      canvas.drawRRect(
        _rr(capsule.deflate(0.5)),
        Paint()
          ..color = cb
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PillsPainter old) =>
      old.capsule != capsule ||
      !listEquals(old.rects, rects) ||
      old.fill != fill ||
      old.border != border ||
      old.capsuleColor != capsuleColor ||
      old.capsuleBorder != capsuleBorder;
}

/// 沒有 [SwipePager] 帶動時（內容不跟著換頁的 pills），選中項目一變就把進度
/// 用 250ms ease-out 滑過去，給 [SlidingPillRow] 用。減少動態時直接跳。
class AnimatedPillProgress extends StatefulWidget {
  const AnimatedPillProgress({
    super.key,
    required this.index,
    required this.builder,
  });
  final int index;
  final Widget Function(BuildContext context, ValueListenable<double> progress)
  builder;

  @override
  State<AnimatedPillProgress> createState() => _AnimatedPillProgressState();
}

class _AnimatedPillProgressState extends State<AnimatedPillProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  @override
  void didUpdateWidget(AnimatedPillProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduce) {
        _c.value = widget.index.toDouble();
      } else {
        _c.animateTo(
          widget.index.toDouble(),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _c);
}
