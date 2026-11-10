import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../common/dashed_box.dart';

/// 圖冊編輯排序（D-134，AlbumSortEdit／AlbumSortDrag）：跟列表、多選一樣的瀑布流，
/// 長按 0.3 秒浮起（放大一點、輕震），原位變虛線空位；拖到別張圖上＝插到它的位置，
/// 其他圖約 200ms 讓位（瀑布流會重排，可能換欄）。放手落進空位後才呼叫 [onReorder]。
/// 靠近捲動區上下邊緣時自動捲動。
///
/// 要放在可捲動的容器裡（本身不捲動）。每格高度先用 [estimateHeight] 估，
/// 畫出來量到真正高度後再修正（圖下的說明行數不一定）。
class ReorderMasonry extends StatefulWidget {
  const ReorderMasonry({
    super.key,
    required this.count,
    required this.columns,
    required this.idOf,
    required this.estimateHeight,
    required this.itemBuilder,
    required this.onReorder,
    this.crossGap = 12,
    this.mainGap = 12,
    this.placeholderRadius = Radii.image,
    this.liftScale = 1.04,
  });

  final int count;
  final int columns;
  final String Function(int index) idOf;

  /// 還沒量到高度前的估計（給欄寬）。
  final double Function(int index, double width) estimateHeight;

  /// [lifted]＝這格是正被拖著的那張（畫陰影）。
  final Widget Function(BuildContext context, int index, bool lifted)
  itemBuilder;
  final void Function(int from, int to) onReorder;
  final double crossGap;
  final double mainGap;
  final double placeholderRadius;
  final double liftScale;

  @override
  State<ReorderMasonry> createState() => _ReorderMasonryState();
}

class _ReorderMasonryState extends State<ReorderMasonry> {
  static const _slide = Duration(milliseconds: 200);
  static const _edge = 64.0;

  final _heights = <String, double>{};
  final _stackKey = GlobalKey();

  double _colW = 0;
  int? _from;
  int _slot = 0;
  int? _ignore;
  Offset _finger = Offset.zero;
  Offset _grab = Offset.zero;
  Offset _global = Offset.zero;
  bool _dropping = false;
  double _speed = 0;
  Timer? _scrollTimer;
  Timer? _dropTimer;

  bool get _dragging => _from != null;
  int get _cols => widget.columns < 1 ? 1 : widget.columns;

  @override
  void didUpdateWidget(ReorderMasonry old) {
    super.didUpdateWidget(old);
    if (_dragging && !_dropping && old.count != widget.count) {
      setState(_reset);
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _dropTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _dropTimer?.cancel();
    _from = null;
    _ignore = null;
    _dropping = false;
    _speed = 0;
  }

  double _h(int i) =>
      _heights[widget.idOf(i)] ?? widget.estimateHeight(i, _colW);

  /// 目前的顯示次序（拖動中：被拖的那張插在 [_slot]）。
  List<int> get _order {
    final order = [for (var i = 0; i < widget.count; i++) i];
    final from = _from;
    if (from != null) {
      order.remove(from);
      order.insert(_slot.clamp(0, order.length), from);
    }
    return order;
  }

  /// 瀑布流擺法（同 MasonryGridView：每張放進目前最矮的那欄，一樣矮放左邊）。
  (Map<int, Rect>, double) _layout(List<int> order) {
    final cols = List<double>.filled(_cols, 0);
    final rects = <int, Rect>{};
    for (final i in order) {
      var c = 0;
      for (var k = 1; k < _cols; k++) {
        if (cols[k] < cols[c]) c = k;
      }
      final h = _h(i);
      rects[i] = Rect.fromLTWH(
        c * (_colW + widget.crossGap),
        cols[c],
        _colW,
        h,
      );
      cols[c] += h + widget.mainGap;
    }
    var height = 0.0;
    for (final v in cols) {
      if (v > height) height = v;
    }
    return (rects, order.isEmpty ? 0 : height - widget.mainGap);
  }

  void _measured(String id, double h) {
    if (!mounted) return;
    final old = _heights[id];
    if (old != null && (old - h).abs() < 0.5) return;
    setState(() => _heights[id] = h);
  }

  Offset _toLocal(Offset global) =>
      ((_stackKey.currentContext ?? context).findRenderObject() as RenderBox)
          .globalToLocal(global);

  void _start(LongPressStartDetails d) {
    final local = _toLocal(d.globalPosition);
    final (rects, _) = _layout(_order);
    int? hit;
    for (final e in rects.entries) {
      if (e.value.contains(local)) hit = e.key;
    }
    if (hit == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _from = hit;
      _slot = hit!;
      _ignore = null;
      _finger = local;
      _grab = local - rects[hit]!.topLeft;
      _global = d.globalPosition;
    });
  }

  /// 被拖那張的中心碰到哪張圖，就插到那張的位置。剛換過的那張要等中心離開它才再算，
  /// 免得高矮不同的圖來回跳。
  void _retarget() {
    final from = _from;
    if (from == null) return;
    final order = _order;
    final (rects, _) = _layout(order);
    final center = _finger - _grab + Offset(_colW / 2, _h(from) / 2);
    final ignore = _ignore;
    if (ignore != null && !(rects[ignore]?.contains(center) ?? false)) {
      _ignore = null;
    }
    for (final e in rects.entries) {
      if (e.key == from || e.key == _ignore) continue;
      if (e.value.contains(center)) {
        _slot = order.indexOf(e.key);
        _ignore = e.key;
        return;
      }
    }
  }

  void _move(Offset global) {
    if (!_dragging || _dropping) return;
    setState(() {
      _global = global;
      _finger = _toLocal(global);
      _retarget();
    });
    _updateAutoScroll();
  }

  void _updateAutoScroll() {
    final scrollable = Scrollable.maybeOf(context);
    final viewport = scrollable?.context.findRenderObject();
    if (scrollable == null || viewport is! RenderBox) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    if (_global.dy < top + _edge) {
      _speed = -(top + _edge - _global.dy).clamp(0, _edge) / _edge;
    } else if (_global.dy > bottom - _edge) {
      _speed = (_global.dy - (bottom - _edge)).clamp(0, _edge) / _edge;
    } else {
      _speed = 0;
    }
    if (_speed == 0) {
      _scrollTimer?.cancel();
      _scrollTimer = null;
      return;
    }
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_dragging || _dropping) return;
      final pos = scrollable.position;
      final target = (pos.pixels + _speed * 12).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (target == pos.pixels) return;
      pos.jumpTo(target);
      setState(() {
        _finger = _toLocal(_global);
        _retarget();
      });
    });
  }

  void _end() {
    final from = _from;
    if (from == null || _dropping) return;
    _scrollTimer?.cancel();
    _scrollTimer = null;
    setState(() => _dropping = true);
    final to = _slot;
    _dropTimer = Timer(_slide, () {
      if (!mounted) return;
      if (from != to) widget.onReorder(from, to);
      setState(_reset);
    });
  }

  void _cancel() {
    if (!_dragging || _dropping) return;
    setState(_reset);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      _colW = (box.maxWidth - widget.crossGap * (_cols - 1)) / _cols;
      final t = context.tokens;
      final from = _from;
      final (rects, height) = _layout(_order);
      final duration = _dragging ? _slide : Duration.zero;
      final children = <Widget>[];
      for (var i = 0; i < widget.count; i++) {
        final r = rects[i]!;
        final id = widget.idOf(i);
        children.add(
          AnimatedPositioned(
            key: ValueKey('reorder-$id'),
            duration: duration,
            curve: Curves.easeOut,
            left: r.left,
            top: r.top,
            width: _colW,
            child: i == from
                ? SizedBox(
                    height: r.height,
                    child: DashedBox(
                      color: t.dashed,
                      radius: widget.placeholderRadius,
                      fill: t.dashed.withValues(alpha: 0.12),
                    ),
                  )
                : _Measure(
                    onHeight: (h) => _measured(id, h),
                    child: widget.itemBuilder(context, i, false),
                  ),
          ),
        );
      }
      if (from != null) {
        final o = _dropping ? rects[from]!.topLeft : _finger - _grab;
        children.add(
          AnimatedPositioned(
            key: const ValueKey('reorder-lifted'),
            duration: _dropping ? _slide : Duration.zero,
            curve: Curves.easeOut,
            left: o.dx,
            top: o.dy,
            width: _colW,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: _dropping ? 1.0 : widget.liftScale,
                duration: _dropping
                    ? _slide
                    : const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: widget.itemBuilder(context, from, !_dropping),
              ),
            ),
          ),
        );
      }
      return RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 300),
                ),
                (r) => r
                  ..onLongPressStart = _start
                  ..onLongPressMoveUpdate = ((d) => _move(d.globalPosition))
                  ..onLongPressEnd = ((_) => _end())
                  ..onLongPressCancel = _cancel,
              ),
        },
        child: SizedBox(
          key: _stackKey,
          width: double.infinity,
          height: height,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      );
    },
  );
}

/// 量子元件畫出來的高度（排版後回報；同一高度不重複回報）。
class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasure(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasure renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasure extends RenderProxyBox {
  _RenderMeasure(this.onHeight);
  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (_last != null && (_last! - h).abs() < 0.5) return;
    _last = h;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}
