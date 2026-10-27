import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 長按＋拖曳＝連續多選（D-081）。九宮格、瀑布、時間軸都能用。
///
/// ## 用法
/// 1. 用 [DragSelectArea] 包住「含捲動區的那塊」（ListView／GridView／CustomScrollView
///    都可以，區域邊緣＝自動捲動的邊緣）。
/// 2. 列表裡每一個可選的項目外面包 [DragSelectItem]，`index` ＝它在**整份列表順序**裡的位置
///    （九宮格＝左→右、上→下；瀑布＝資料 index 順序；時間軸分段＝攤平後的順序，
///    所以推活要自己把「分段＋項目」攤平成一個連續 index）。
/// 3. 項目本身**不要再放 onLongPress**（祖先的長按辨識器會跟它搶）；點一下仍用原本的 onTap 切換。
/// 4. [DragSelectArea.onChanged] 每次都給「完整的已選 index 集合」，頁面把它對應回自己的 id 集合：
///    ```dart
///    DragSelectArea(
///      itemCount: images.length,
///      isSelected: (i) => _selected.contains(images[i].id),
///      onChanged: (idx, finished) => setState(() {
///        _selected..clear()..addAll(idx.map((i) => images[i].id));
///        _selecting = !finished || _selected.isNotEmpty; // 放手時一個都沒有才離開多選
///      }),
///      child: MasonryGridView.count(... itemBuilder: (_, i) => DragSelectItem(index: i, child: tile)),
///    )
///    ```
///
/// ## 行為
/// - 長按項目：進入多選並選中它（起點若已是選中 → 這次拖曳是連續「取消選取」）。
/// - 手指不放開拖動：起點到手指所在項目（依 index 順序）全部選中／取消；拖回去就還原超出的部分，
///   起點之前已選的項目不受影響。手指在項目間隙時沿用上一個項目。
/// - 手指離 [DragSelectArea] 上／下邊緣 [DragSelectArea.edgeExtent]px 內自動捲動，越靠邊越快。
/// - 每多選中一個項目輕震一下（[HapticFeedback.selectionClick]）。
/// - 放手後 `onChanged(..., finished: true)`；之後維持多選，由頁面決定。
/// - 只有長按成立後才接管手勢；一般捲動與點擊不受影響。手指按在項目以外的地方時完全不參與。
/// - 拖曳途中項目可以換版面（D-095：摸魚列表長按後換成九宮格），選取以 index 為準。
///
/// 命中判斷：項目向最近的 [DragSelectArea] 註冊自己的 RenderBox，用全域座標矩形找手指下的項目，
/// 所以不依賴版面（網格、瀑布、任意高度都行）。
class DragSelectArea extends StatefulWidget {
  const DragSelectArea({
    super.key,
    required this.child,
    required this.itemCount,
    required this.isSelected,
    required this.onChanged,
    this.enabled = true,
    this.edgeExtent = 64,
    this.maxSpeed = 1400,
    this.haptics = true,
  });

  final Widget child;

  /// 列表項目總數（index 範圍 0..itemCount-1）。
  final int itemCount;

  /// 目前（拖曳開始時）某 index 是否已選。
  final bool Function(int index) isSelected;

  /// 選取集合改變；[finished] 為 true＝手指放開（最後一次）。
  final void Function(Set<int> selected, bool finished) onChanged;

  final bool enabled;

  /// 距上／下邊緣多少 px 內開始自動捲動。
  final double edgeExtent;

  /// 貼著邊緣時的捲動速度（px／秒）。
  final double maxSpeed;

  /// 每多選中一個項目是否震動。
  final bool haptics;

  @override
  State<DragSelectArea> createState() => DragSelectAreaState();
}

class DragSelectAreaState extends State<DragSelectArea>
    with SingleTickerProviderStateMixin {
  final Map<int, _DragSelectItemState> _items = {};
  late final Ticker _ticker = createTicker(_onTick);

  // 一次拖曳的狀態
  bool _active = false;
  int _start = 0;
  int _current = 0;
  bool _deselect = false;
  Set<int> _base = const {};
  Set<int> _applied = const {};
  Offset _finger = Offset.zero;
  ScrollPosition? _position;
  Duration _lastTick = Duration.zero;
  double _scrollVelocity = 0;

  @visibleForTesting
  bool get dragging => _active;

  void _register(int index, _DragSelectItemState s) => _items[index] = s;

  void _unregister(int index, _DragSelectItemState s) {
    if (identical(_items[index], s)) _items.remove(index);
  }

  /// 手指（全域座標）下的項目 index；不在任何項目上回傳 null。
  int? _indexAt(Offset global) {
    for (final e in _items.entries) {
      final box = e.value.box;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return e.key;
    }
    return null;
  }

  void _onStart(LongPressStartDetails d) {
    if (!widget.enabled) return;
    final i = _indexAt(d.globalPosition);
    if (i == null || i >= widget.itemCount) return;
    _active = true;
    _start = _current = i;
    _finger = d.globalPosition;
    _deselect = widget.isSelected(i);
    _base = {
      for (var k = 0; k < widget.itemCount; k++)
        if (widget.isSelected(k)) k,
    };
    _applied = _base;
    _position = Scrollable.maybeOf(_items[i]!.context)?.position;
    _scrollVelocity = 0;
    _apply(finished: false, force: true);
  }

  void _onMove(LongPressMoveUpdateDetails d) {
    if (!_active) return;
    _finger = d.globalPosition;
    _hitUpdate();
    _updateAutoScroll();
  }

  void _onEnd([Offset? _]) {
    if (!_active) return;
    _active = false;
    _ticker.stop();
    _scrollVelocity = 0;
    _apply(finished: true);
    _position = null;
  }

  void _hitUpdate() {
    final i = _indexAt(_finger);
    if (i == null || i >= widget.itemCount || i == _current) return;
    _current = i;
    _apply(finished: false);
  }

  void _apply({required bool finished, bool force = false}) {
    final lo = math.min(_start, _current);
    final hi = math.max(_start, _current);
    final range = {for (var k = lo; k <= hi; k++) k};
    final next = _deselect ? _base.difference(range) : _base.union(range);
    if (widget.haptics && !_deselect) {
      for (var n = next.difference(_applied).length; n > 0; n--) {
        HapticFeedback.selectionClick();
      }
    }
    final changed =
        next.length != _applied.length || !next.containsAll(_applied);
    _applied = next;
    if (changed || finished || force) widget.onChanged(Set.of(next), finished);
  }

  /// 手指離上／下緣 [edgeExtent] 內 → 啟動 ticker 自動捲動；越靠邊越快。
  void _updateAutoScroll() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final ext = math.min(widget.edgeExtent, box.size.height / 2);
    double v = 0;
    if (_finger.dy < top + ext) {
      v = -widget.maxSpeed * ((top + ext - _finger.dy) / ext).clamp(0.0, 1.0);
    } else if (_finger.dy > bottom - ext) {
      v =
          widget.maxSpeed *
          ((_finger.dy - (bottom - ext)) / ext).clamp(0.0, 1.0);
    }
    _scrollVelocity = v;
    if (v == 0) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  /// 拖曳途中捲動區可能被換掉（例如列表切成九宮格）：舊的失效就改抓現有項目所在的捲動區。
  ScrollPosition? _livePosition() {
    final p = _position;
    if (p != null && _alive(p)) return p;
    for (final item in _items.values) {
      if (item.box == null) continue;
      final next = Scrollable.maybeOf(item.context)?.position;
      if (next != null) return _position = next;
    }
    return null;
  }

  /// 捲動區的 State 卸載後再讀它的 context 會 assert（debug），所以先擋掉。
  bool _alive(ScrollPosition p) {
    try {
      return p.context.storageContext.mounted;
    } catch (_) {
      return false;
    }
  }

  void _onTick(Duration elapsed) {
    final pos = _livePosition();
    if (!_active || pos == null || !pos.hasPixels || _scrollVelocity == 0) {
      return;
    }
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final target = (pos.pixels + _scrollVelocity * dt).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target != pos.pixels) {
      pos.jumpTo(target);
      // 版面更新後，手指下的項目變了
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _active) _hitUpdate();
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Scope(
      state: this,
      child: RawGestureDetector(
        gestures: {
          _ItemLongPress: GestureRecognizerFactoryWithHandlers<_ItemLongPress>(
            () => _ItemLongPress(
              (global) => widget.enabled && _indexAt(global) != null,
            ),
            (r) => r
              ..onLongPressStart = _onStart
              ..onLongPressMoveUpdate = _onMove
              ..onLongPressEnd = ((d) => _onEnd())
              ..onLongPressCancel = _onEnd,
          ),
        },
        child: widget.child,
      ),
    );
  }
}

/// 只在手指按在項目上時才參與手勢競爭（按在項目以外的地方，例如並排的詳情區，不搶手勢）。
class _ItemLongPress extends LongPressGestureRecognizer {
  _ItemLongPress(this.hit);
  final bool Function(Offset global) hit;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      hit(event.position) && super.isPointerAllowed(event);
}

class _Scope extends InheritedWidget {
  const _Scope({required this.state, required super.child});
  final DragSelectAreaState state;

  @override
  bool updateShouldNotify(_Scope old) => state != old.state;
}

/// 列表項目：向最近的 [DragSelectArea] 登記自己，供命中判斷。沒有 Area 時什麼都不做。
class DragSelectItem extends StatefulWidget {
  const DragSelectItem({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<DragSelectItem> createState() => _DragSelectItemState();
}

class _DragSelectItemState extends State<DragSelectItem> {
  DragSelectAreaState? _area;

  RenderBox? get box {
    final ro = context.findRenderObject();
    return ro is RenderBox && ro.attached && ro.hasSize ? ro : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final area = context.getInheritedWidgetOfExactType<_Scope>()?.state;
    if (area != _area) {
      _area?._unregister(widget.index, this);
      _area = area;
    }
    _area?._register(widget.index, this);
  }

  @override
  void didUpdateWidget(DragSelectItem old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _area?._unregister(old.index, this);
      _area?._register(widget.index, this);
    }
  }

  @override
  void dispose() {
    _area?._unregister(widget.index, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
