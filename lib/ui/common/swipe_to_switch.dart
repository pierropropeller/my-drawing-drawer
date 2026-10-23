import 'package:flutter/material.dart';

/// 在列表區域左右滑動＝切換上方篩選 pills 的上一個／下一個（沒有畫在設計稿，介面上看不到）。
///
/// 做法：只用 [Listener] 看原始指標事件，**不進手勢競技場**，所以垂直捲動、點擊、長按多選、
/// 長按拖曳選取（D-081）、子層橫向捲動都不會被它搶走。放開手指時才判斷是否算一次「橫滑」：
/// - 起點在螢幕左右邊緣 [edgeInset] 內不算（iOS 邊緣滑動返回／Android 手勢返回）；
/// - 這次觸碰期間，子層有任何捲動被使用者拖動（橫向輪播、橫向 chips、日曆、垂直列表）就不算；
/// - [enabled] 為 false（多選中）不算——按下與放開時各檢查一次；
/// - 位移 ≥ [minDistance]，且橫向位移 ≥ 縱向的 [dominance] 倍，費時 ≤ [maxDuration]；
/// - 多指不算。
/// 往右滑（手指向右）＝上一個，往左滑＝下一個；[onPrev]／[onNext] 為 null＝已在端點，什麼都不做（不循環）。
///
/// 不做切換動畫（內容直接換，減少動態偏好下也一致）。
class SwipeToSwitch extends StatefulWidget {
  const SwipeToSwitch({
    super.key,
    required this.child,
    this.onPrev,
    this.onNext,
    this.enabled = true,
    this.edgeInset = 24,
    this.minDistance = 64,
    this.dominance = 1.5,
    this.maxDuration = const Duration(milliseconds: 800),
  });

  /// 在 [order] 裡以 [current] 的相鄰項目切換；端點不循環。
  static SwipeToSwitch among<T>({
    Key? key,
    required Widget child,
    required List<T> order,
    required T current,
    required ValueChanged<T> onChanged,
    bool enabled = true,
  }) {
    final i = order.indexOf(current);
    return SwipeToSwitch(
      key: key,
      enabled: enabled && i >= 0,
      onPrev: i > 0 ? () => onChanged(order[i - 1]) : null,
      onNext: i >= 0 && i < order.length - 1
          ? () => onChanged(order[i + 1])
          : null,
      child: child,
    );
  }

  final Widget child;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final bool enabled;
  final double edgeInset;
  final double minDistance;
  final double dominance;
  final Duration maxDuration;

  @override
  State<SwipeToSwitch> createState() => _SwipeToSwitchState();
}

class _SwipeToSwitchState extends State<SwipeToSwitch> {
  int _pointers = 0;
  int? _tracked;
  Offset _down = Offset.zero;
  Duration _downAt = Duration.zero;
  bool _cancelled = false;

  void _onDown(PointerDownEvent e) {
    _pointers++;
    if (_pointers > 1) {
      _cancelled = true;
      return;
    }
    _tracked = e.pointer;
    _down = e.position;
    _downAt = e.timeStamp;
    final width = MediaQuery.sizeOf(context).width;
    _cancelled =
        !widget.enabled ||
        e.position.dx < widget.edgeInset ||
        e.position.dx > width - widget.edgeInset;
  }

  void _onUp(PointerUpEvent e) {
    final mine = e.pointer == _tracked;
    final cancelled = _cancelled;
    _release();
    if (!mine || cancelled || !widget.enabled) return;
    final d = e.position - _down;
    final dt = e.timeStamp - _downAt;
    if (d.dx.abs() < widget.minDistance) return;
    if (d.dx.abs() < d.dy.abs() * widget.dominance) return;
    if (dt > widget.maxDuration) return;
    (d.dx > 0 ? widget.onPrev : widget.onNext)?.call();
  }

  void _onCancel(PointerCancelEvent e) => _release();

  void _release() {
    if (_pointers > 0) _pointers--;
    if (_pointers == 0) {
      _tracked = null;
      _cancelled = false;
    }
  }

  bool _onScroll(ScrollNotification n) {
    // 使用者正在拖動某個子層捲動區，這次觸碰屬於它：
    // - 橫向捲動區（輪播、chips、日曆）：一開始拖就算（到端點捲不動也算）；
    // - 垂直捲動區：真的捲了（或在端點拉伸）才算。放手時垂直拖曳辨識器會在競技場「掃尾獲勝」，
    //   單純的橫向滑動也會收到一個 ScrollStart（位移 0），不能因此取消。
    final user = switch (n) {
      ScrollStartNotification() => n.dragDetails != null,
      ScrollUpdateNotification() => n.dragDetails != null,
      OverscrollNotification() => n.dragDetails != null,
      _ => false,
    };
    if (!user) return false;
    if (n.metrics.axis == Axis.horizontal) {
      _cancelled = true;
    } else if ((n is ScrollUpdateNotification && (n.scrollDelta ?? 0) != 0) ||
        (n is OverscrollNotification && n.overscroll != 0)) {
      _cancelled = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onDown,
    onPointerUp: _onUp,
    onPointerCancel: _onCancel,
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    ),
  );
}

/// 被選中（false→true）時，把自己捲進最近的**橫向**捲動區內完全可見（pills 列用）。
/// 沒有橫向捲動祖先、或該列不會捲動時什麼都不做。減少動態時直接跳過去。
class EnsureVisibleWhenSelected extends StatefulWidget {
  const EnsureVisibleWhenSelected({
    super.key,
    required this.selected,
    required this.child,
  });
  final bool selected;
  final Widget child;

  @override
  State<EnsureVisibleWhenSelected> createState() =>
      _EnsureVisibleWhenSelectedState();
}

class _EnsureVisibleWhenSelectedState extends State<EnsureVisibleWhenSelected> {
  @override
  void didUpdateWidget(EnsureVisibleWhenSelected old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final scrollable = Scrollable.maybeOf(context);
        if (scrollable == null ||
            scrollable.axisDirection == AxisDirection.up ||
            scrollable.axisDirection == AxisDirection.down) {
          return;
        }
        final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
