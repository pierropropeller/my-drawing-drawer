import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../media_source/media_menu_anchor.dart';
import 'adaptive_modal.dart';
import 'dashed_box.dart';

/// 表單圖片格的拖曳排序（D-082，`ImageReorder`）。
///
/// 長按 0.3 秒圖片浮起（約 1.08 倍＋陰影、輕震），所有 × 先隱藏，原位變虛線空位；
/// 拖動時空位跟著手指所在的格子走，其他圖以約 200ms ease-out 滑一格讓位（含換行）；
/// 放手後圖片縮回原大小滑進空位。拖到「＋」或格子範圍外＝排到最後；
/// 靠近捲動區上下邊緣約 64px 時自動捲動。
///
/// 為什麼不用 `reorderable_grid_view`／`flutter_reorderable_grid_view`：表單裡是
/// 嵌在 ListView 內、不自己捲動的小格子，而且尾端固定一格不能拖的「＋」、
/// 「拖到範圍外＝排最後」、外層頁面要自動捲動；套件的 grid 自己是 scrollable，
/// 這幾點都要繞開。固定尺寸的格子用 AnimatedPositioned 排在計算出的格位上即可。
///
/// [itemBuilder] 的 `hideActions` 為 true 時要隱藏 ×。[onReorder] 為 null＝不能排序。
class ReorderableImageGrid extends StatefulWidget {
  const ReorderableImageGrid({
    super.key,
    required this.count,
    required this.size,
    required this.itemBuilder,
    this.trailing,
    this.onReorder,
    this.spacing = 8,
    this.columns = 5,
    this.dialogColumns = 3,
    this.dialogSpacing = 12,
  });

  final int count;

  /// 沒有 [columns] 時的固定邊長。
  final double size;

  /// 一行固定幾張：邊長＝（可用闊 − 間距）÷ 欄數，不同機型寬度都剛好排滿一行（預設 5 欄＝各 20%）。
  /// 傳 null＝用固定的 [size]。
  final int? columns;
  final double spacing;

  /// 在置中 form sheet（≥600 的新增頁）裡的欄數／間距：稿是 3 欄方形、間距 12
  /// （NewOfficial／NewFanArt／NewDraft／NewPiece／NewOshi）；傳 null＝用固定的 [size]（NewIdea 的 72×72）。
  final int? dialogColumns;
  final double dialogSpacing;
  final Widget Function(BuildContext context, int index, bool hideActions)
  itemBuilder;

  /// 固定在最後一格的「＋」。
  final Widget? trailing;
  final void Function(int from, int to)? onReorder;

  @override
  State<ReorderableImageGrid> createState() => _ReorderableImageGridState();
}

class _ReorderableImageGridState extends State<ReorderableImageGrid> {
  static const _slide = Duration(milliseconds: 200);
  static const _edge = 64.0;

  int? _from; // 被拖的原 index
  int _slot = 0; // 目前空位的格位
  Offset _finger = Offset.zero; // 手指在格子區內的座標
  Offset _grab = Offset.zero; // 手指相對被拖圖左上角的偏移
  Offset _global = Offset.zero;
  bool _dropping = false;
  double _speed = 0; // 自動捲動速度（-1～1）
  double _width = 0;
  Timer? _scrollTimer;
  Timer? _dropTimer;
  int _cols = 1;

  bool get _dragging => _from != null;

  @override
  void didUpdateWidget(ReorderableImageGrid old) {
    super.didUpdateWidget(old);
    if (_dragging && old.count != widget.count) _reset();
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

  double _size = 84;
  double _gap = 8;
  double get _pitch => _size + _gap;

  Offset _slotOffset(int slot) =>
      Offset((slot % _cols) * _pitch, (slot ~/ _cols) * _pitch);

  /// 手指所在格 → 目標格位；在「＋」、空格或範圍外＝最後一張。
  int _slotAt(Offset p) {
    final total = widget.count + (widget.trailing != null ? 1 : 0);
    final rows = (total + _cols - 1) ~/ _cols;
    final height = rows * _pitch - _gap;
    final last = widget.count - 1;
    if (p.dx < 0 || p.dx > _width || p.dy < 0 || p.dy > height) return last;
    final col = (p.dx ~/ _pitch).clamp(0, _cols - 1);
    final row = p.dy ~/ _pitch;
    return (row * _cols + col).clamp(0, last);
  }

  /// 格子區（Stack）自己的座標；橫向捲動時不能用整個元件的座標。
  final _stackKey = GlobalKey();

  Offset _toLocal(Offset global) =>
      ((_stackKey.currentContext ?? context).findRenderObject() as RenderBox)
          .globalToLocal(global);

  int? _hitIndex(Offset p) {
    if (p.dx < 0 || p.dy < 0) return null;
    final col = p.dx ~/ _pitch;
    if (col >= _cols) return null;
    final i = (p.dy ~/ _pitch) * _cols + col;
    return i < widget.count ? i : null;
  }

  void _start(LongPressStartDetails d) {
    final i = _hitIndex(d.localPosition);
    if (i == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _from = i;
      _slot = i;
      _finger = d.localPosition;
      _grab = d.localPosition - _slotOffset(i);
      _global = d.globalPosition;
    });
  }

  void _move(Offset global) {
    if (!_dragging || _dropping) return;
    final local = _toLocal(global);
    setState(() {
      _global = global;
      _finger = local;
      _slot = _slotAt(local);
    });
    _updateAutoScroll();
  }

  /// 靠近可捲動區上下邊緣時，以 timer 持續捲動，越靠邊越快。
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
      // 頁面動了、手指沒動：格子區位置變了，重算目標。
      setState(() {
        _finger = _toLocal(_global);
        _slot = _slotAt(_finger);
      });
    });
  }

  void _end() {
    final from = _from;
    if (from == null || _dropping) return;
    _scrollTimer?.cancel();
    _scrollTimer = null;
    // 先讓浮起的圖縮回並滑進空位，動畫完再通知排序。
    setState(() => _dropping = true);
    final to = _slot;
    _dropTimer = Timer(_slide, () {
      if (!mounted) return;
      if (from != to) widget.onReorder?.call(from, to);
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
    final sheet = AdaptiveModalScope.sheetOf(context);
    final dialog = !sheet && AdaptiveModalScope.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final total = widget.count + (widget.trailing != null ? 1 : 0);
        // page sheet（NewXxx400）：76 的縮圖排成一列、往右捲（gap 10）。
        final horizontal = sheet;
        _gap = horizontal
            ? 10
            : dialog
            ? widget.dialogSpacing
            : widget.spacing;
        final cols = dialog ? widget.dialogColumns : widget.columns;
        _size = horizontal
            ? 76
            : cols != null && c.maxWidth.isFinite
            ? ((c.maxWidth - _gap * (cols - 1)) / cols).floorToDouble().clamp(
                40.0,
                400.0,
              )
            : widget.size;
        final size = _size;
        if (horizontal) {
          _cols = total < 1 ? 1 : total;
          _width = _cols * _pitch - _gap;
        } else {
          _width = c.maxWidth.isFinite ? c.maxWidth : 5 * _pitch;
          _cols = ((_width + _gap) ~/ _pitch).clamp(1, 1 << 20);
        }
        final rows = total == 0 ? 0 : (total + _cols - 1) ~/ _cols;
        final height = rows == 0 ? 0.0 : rows * _pitch - _gap;

        // 各圖目前的格位：被拖的那張抽掉、插到 _slot，其餘依序排。
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
            width: size,
            height: size,
            child: child,
          );
        }

        final stack = SizedBox(
          key: _stackKey,
          width: horizontal ? _width : double.infinity,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < widget.count; i++)
                if (i == from)
                  positioned(
                    ValueKey('slot$i'),
                    slotOf[i]!,
                    DashedBox(
                      color: t.dashed,
                      radius: Radii.image,
                      fill: t.dashed.withValues(alpha: 0.12),
                    ),
                  )
                else
                  positioned(
                    ValueKey('tile$i'),
                    slotOf[i]!,
                    widget.itemBuilder(context, i, _dragging),
                  ),
              if (widget.trailing != null)
                Positioned(
                  left: _slotOffset(widget.count).dx,
                  top: _slotOffset(widget.count).dy,
                  width: size,
                  height: size,
                  // 加圖格：按下時記位置，加圖來源選單（iPad）錨在它旁邊。
                  child: MediaMenuAnchorTarget(child: widget.trailing!),
                ),
              if (from != null) _lifted(from, size),
            ],
          ),
        );
        Widget wrap(Widget child) => horizontal
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                // 「×」凸出縮圖右上角 6px，上方留 6（稿：padding-top 6）。
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: child,
              )
            : child;
        if (widget.onReorder == null) return wrap(stack);
        return wrap(
          RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
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
          ),
        );
      },
    );
  }

  /// 浮起（或正在落下）的那張圖。
  Widget _lifted(int from, double size) {
    final o = _dropping ? _slotOffset(_slot) : _finger - _grab;
    return AnimatedPositioned(
      key: const ValueKey('lifted'),
      duration: _dropping ? _slide : Duration.zero,
      curve: Curves.easeOut,
      left: o.dx,
      top: o.dy,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: _dropping ? 1.0 : 1.08,
          duration: _dropping ? _slide : const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.image),
              boxShadow: _dropping
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x472B2622),
                        offset: Offset(0, 10),
                        blurRadius: 22,
                      ),
                    ],
            ),
            child: widget.itemBuilder(context, from, true),
          ),
        ),
      ),
    );
  }
}

/// 把 [list] 的第 [from] 項移到第 [to] 項的位置（其餘依序挪動）。
void moveListItem<T>(List<T> list, int from, int to) {
  if (from == to || from < 0 || to < 0) return;
  if (from >= list.length || to >= list.length) return;
  list.insert(to, list.removeAt(from));
}
