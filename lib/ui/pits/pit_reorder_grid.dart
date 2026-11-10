import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../common/dashed_box.dart';

/// 主頁坑卡片／坑列表的拖曳排序（D-132，MainSortEdit／MainSortDrag／MainShallowSortEdit）。
///
/// 手感同表單圖片格（D-082 `ReorderableImageGrid`）：長按 0.3 秒浮起（放大一點＋陰影、輕震），
/// 原位變虛線空位，其他格約 200ms 讓位（含換行），放手後落進空位。差別是格子不是正方形
/// （坑卡片＝封面＋兩行字；列表＝整列），欄距、列距可以不同，而且可以有一格不能拖的尾巴
/// （「開新坑」）。靠近捲動區上下邊緣時自動捲動。
///
/// [onDragStart]：長按浮起的那一刻（主頁用來進入編輯排序）。
/// [itemBuilder] 的 `dragging`＝正在拖別格（要藏起封面上的小圖示）；`lifted`＝這格是浮起的那格。
class PitReorderGrid extends StatefulWidget {
  const PitReorderGrid({
    super.key,
    required this.count,
    required this.columns,
    required this.cellWidth,
    required this.cellHeight,
    required this.itemBuilder,
    required this.onReorder,
    this.gapX = 0,
    this.gapY = 0,
    this.trailing,
    this.trailingHeight,
    this.onDragStart,
    this.placeholderRadius = Radii.card,
    this.placeholderHeight,
    this.liftScale = 1.06,
  });

  final int count;
  final int columns;
  final double cellWidth;
  final double cellHeight;
  final double gapX;
  final double gapY;
  final Widget Function(
    BuildContext context,
    int index,
    bool dragging,
    bool lifted,
  )
  itemBuilder;
  final void Function(int from, int to) onReorder;

  /// 固定在最後、不能拖的一格（開新坑）；高度預設同 [cellHeight]。
  final Widget? trailing;
  final double? trailingHeight;
  final VoidCallback? onDragStart;
  final double placeholderRadius;

  /// 虛線空位的高度（坑卡片只畫封面那塊正方形）；null＝整格。
  final double? placeholderHeight;
  final double liftScale;

  @override
  State<PitReorderGrid> createState() => _PitReorderGridState();
}

class _PitReorderGridState extends State<PitReorderGrid> {
  static const _slide = Duration(milliseconds: 200);
  static const _edge = 64.0;

  int? _from;
  int _slot = 0;
  Offset _finger = Offset.zero;
  Offset _grab = Offset.zero;
  Offset _global = Offset.zero;
  bool _dropping = false;
  double _speed = 0;
  Timer? _scrollTimer;
  Timer? _dropTimer;
  final _stackKey = GlobalKey();

  bool get _dragging => _from != null;
  int get _cols => widget.columns < 1 ? 1 : widget.columns;
  double get _pitchX => widget.cellWidth + widget.gapX;
  double get _pitchY => widget.cellHeight + widget.gapY;

  @override
  void didUpdateWidget(PitReorderGrid old) {
    super.didUpdateWidget(old);
    if (_dragging && !_dropping && old.count != widget.count) _reset();
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
    _dropping = false;
    _speed = 0;
  }

  Offset _slotOffset(int slot) =>
      Offset((slot % _cols) * _pitchX, (slot ~/ _cols) * _pitchY);

  double get _height {
    final total = widget.count + (widget.trailing != null ? 1 : 0);
    if (total == 0) return 0;
    final rows = (total + _cols - 1) ~/ _cols;
    final lastRowTrailing =
        widget.trailing != null && (widget.count % _cols == 0);
    final lastH = lastRowTrailing
        ? (widget.trailingHeight ?? widget.cellHeight)
        : widget.cellHeight;
    return (rows - 1) * _pitchY + lastH;
  }

  int? _hitIndex(Offset p) {
    if (p.dx < 0 || p.dy < 0) return null;
    final col = p.dx ~/ _pitchX;
    if (col >= _cols) return null;
    if (p.dx - col * _pitchX > widget.cellWidth) return null;
    final row = p.dy ~/ _pitchY;
    if (p.dy - row * _pitchY > widget.cellHeight) return null;
    final i = row * _cols + col;
    return i < widget.count ? i : null;
  }

  /// 手指（以被拖格中心為準）所在格 → 目標格位；範圍外夾到頭尾。
  int _slotAt(Offset p) {
    final last = widget.count - 1;
    final col = (p.dx / _pitchX).floor().clamp(0, _cols - 1);
    final row = (p.dy / _pitchY).floor();
    if (row < 0) return 0;
    return (row * _cols + col).clamp(0, last);
  }

  Offset _toLocal(Offset global) =>
      ((_stackKey.currentContext ?? context).findRenderObject() as RenderBox)
          .globalToLocal(global);

  Offset get _center =>
      _finger - _grab + Offset(widget.cellWidth / 2, widget.cellHeight / 2);

  void _start(LongPressStartDetails d) {
    final local = _toLocal(d.globalPosition);
    final i = _hitIndex(local);
    if (i == null) return;
    HapticFeedback.lightImpact();
    widget.onDragStart?.call();
    setState(() {
      _from = i;
      _slot = i;
      _finger = local;
      _grab = local - _slotOffset(i);
      _global = d.globalPosition;
    });
  }

  void _move(Offset global) {
    if (!_dragging || _dropping) return;
    setState(() {
      _global = global;
      _finger = _toLocal(global);
      _slot = _slotAt(_center);
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
        _slot = _slotAt(_center);
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
  Widget build(BuildContext context) {
    final t = context.tokens;
    final from = _from;
    final order = [for (var i = 0; i < widget.count; i++) i];
    if (from != null) {
      order.remove(from);
      order.insert(_slot, from);
    }
    final slotOf = {for (var s = 0; s < order.length; s++) order[s]: s};
    final duration = _dragging ? _slide : Duration.zero;

    Widget positioned(Key key, int slot, Widget child) {
      final o = _slotOffset(slot);
      return AnimatedPositioned(
        key: key,
        duration: duration,
        curve: Curves.easeOut,
        left: o.dx,
        top: o.dy,
        width: widget.cellWidth,
        height: widget.cellHeight,
        child: child,
      );
    }

    final trailingOffset = _slotOffset(widget.count);
    final stack = SizedBox(
      key: _stackKey,
      width: double.infinity,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < widget.count; i++)
            if (i == from)
              positioned(
                ValueKey('slot$i'),
                slotOf[i]!,
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: widget.placeholderHeight ?? widget.cellHeight,
                    width: double.infinity,
                    child: DashedBox(
                      color: t.dashed,
                      radius: widget.placeholderRadius,
                      fill: t.dashed.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              )
            else
              positioned(
                ValueKey('tile$i'),
                slotOf[i]!,
                widget.itemBuilder(context, i, _dragging, false),
              ),
          if (widget.trailing != null)
            Positioned(
              left: trailingOffset.dx,
              top: trailingOffset.dy,
              width: widget.cellWidth,
              height: widget.trailingHeight ?? widget.cellHeight,
              child: widget.trailing!,
            ),
          if (from != null) _lifted(from),
        ],
      ),
    );
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
      child: stack,
    );
  }

  Widget _lifted(int from) {
    final o = _dropping ? _slotOffset(_slot) : _finger - _grab;
    return AnimatedPositioned(
      key: const ValueKey('lifted'),
      duration: _dropping ? _slide : Duration.zero,
      curve: Curves.easeOut,
      left: o.dx,
      top: o.dy,
      width: widget.cellWidth,
      height: widget.cellHeight,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: _dropping ? 1.0 : widget.liftScale,
          duration: _dropping ? _slide : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.itemBuilder(context, from, true, !_dropping),
        ),
      ),
    );
  }
}

/// 拖動時浮起的那格的陰影（稿：0 14 28 rgba(43,38,34,.28)）。
const pitLiftShadow = [
  BoxShadow(color: Color(0x472B2622), offset: Offset(0, 14), blurRadius: 28),
];
