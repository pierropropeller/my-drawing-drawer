import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 在列表區域左右滑動＝切換上方篩選 pills 的上一個／下一個（沒有畫在設計稿，介面上看不到）。
///
/// 做法：跟 [TabBarView]／[PageView] 一樣，用 [RawGestureDetector] 放一個水平拖曳辨識器
/// **進手勢競技場**競爭：
/// - 手指位移先超過水平 touch slop（而且垂直還沒超過）→ 水平辨識器勝出，列表不會跟著捲；
///   先超過垂直 slop → 列表的垂直辨識器勝出，照常捲動。真手指橫滑時幾 px 的垂直抖動不會影響結果。
/// - 起點在子層橫向捲動區（輪播、chips、日曆）上：子層的水平辨識器在命中測試中更深、先處理事件，
///   所以由子層勝出，這裡不會動。
/// - 點擊、長按多選、長按拖曳選取（D-081）：長按辨識器勝出後本辨識器會被取消，互不影響。
///
/// 放開時才決定要不要切換：
/// - 起點在螢幕左右邊緣 [edgeInset] 內不收（iOS 邊緣滑動返回／Android 手勢返回）；
/// - [enabled] 為 false（多選中）不收；
/// - 橫向位移 ≥ [minDistance]，或橫向甩動速度 ≥ [minVelocity]，且方向以橫向為主；
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
    this.minDistance = 48,
    this.minVelocity = 400,
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

  /// 放開時橫向位移至少這麼多（px）。
  final double minDistance;

  /// 或放開時橫向速度至少這麼快（px/s）。
  final double minVelocity;

  @override
  State<SwipeToSwitch> createState() => _SwipeToSwitchState();
}

/// 只負責「起點不在邊緣、enabled」的篩選；其餘交給 [HorizontalDragGestureRecognizer]。
class _EdgeAwareHorizontalDrag extends HorizontalDragGestureRecognizer {
  _EdgeAwareHorizontalDrag({super.debugOwner});

  bool enabled = true;
  double edgeInset = 24;
  double viewWidth = double.infinity;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (!enabled) return false;
    final x = event.position.dx;
    if (x < edgeInset || x > viewWidth - edgeInset) return false;
    return super.isPointerAllowed(event);
  }
}

class _SwipeToSwitchState extends State<SwipeToSwitch> {
  Offset _down = Offset.zero;
  Offset _last = Offset.zero;

  void _onDown(DragDownDetails d) {
    _down = d.globalPosition;
    _last = d.globalPosition;
  }

  void _onUpdate(DragUpdateDetails d) => _last = d.globalPosition;

  void _onEnd(DragEndDetails d) {
    if (!widget.enabled) return;
    final dx = _last.dx - _down.dx;
    final dy = _last.dy - _down.dy;
    final v = d.velocity.pixelsPerSecond;
    // 以橫向為主：位移或速度，橫向都要大於縱向。
    final byDistance = dx.abs() >= widget.minDistance && dx.abs() >= dy.abs();
    final byFling = v.dx.abs() >= widget.minVelocity && v.dx.abs() > v.dy.abs();
    if (!byDistance && !byFling) return;
    // 方向：位移夠就看位移，只靠甩動就看速度。
    final right = byDistance ? dx > 0 : v.dx > 0;
    (right ? widget.onPrev : widget.onNext)?.call();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        _EdgeAwareHorizontalDrag:
            GestureRecognizerFactoryWithHandlers<_EdgeAwareHorizontalDrag>(
              () => _EdgeAwareHorizontalDrag(debugOwner: this),
              (r) {
                r
                  ..enabled = widget.enabled
                  ..edgeInset = widget.edgeInset
                  ..viewWidth = width
                  ..onDown = _onDown
                  ..onUpdate = _onUpdate
                  ..onEnd = _onEnd
                  ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                    context,
                  );
              },
            ),
      },
      child: widget.child,
    );
  }
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
