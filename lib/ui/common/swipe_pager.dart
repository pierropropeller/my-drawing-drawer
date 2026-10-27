import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'swipe_to_switch.dart';

/// 左右滑切換 tab／pills，內容跟著手指走（D-118，canvas `SwipeTabsSpec`）。
///
/// - 拉的時候目前這頁和隔壁那頁一起橫向移動；放手時拉過頁寬 30% 或撥得夠快（fling）
///   就順勢滑到隔壁頁（250ms，ease-out），不夠就彈回。
/// - 第一頁／最後一頁再拉只有彈性回彈，不循環。
/// - 手勢判定沿用 [SwipeToSwitch] 的規則：進手勢競技場、邊緣 24px 不收、
///   子層橫向捲動區優先、[enabled] 為 false（多選、長按拖選）不收。
/// - 外部改 [current]（點 pill）也滑過去；一次跳幾格時直接滑到目標，不逐頁經過。
/// - 隔壁頁面預先建好、每頁各自保留（記住上下捲動位置、不閃白）。
/// - [progress] 回報「小數頁碼」（0＝第一頁），給 [SlidingPillBar]／[ChipRow] 畫深色膠囊。
///   跳格時回報的是從起點直接滑到目標的進度。
class SwipePager<T> extends StatefulWidget {
  const SwipePager({
    super.key,
    required this.order,
    required this.current,
    required this.onChanged,
    required this.itemBuilder,
    this.progress,
    this.enabled = true,
    this.edgeInset = 24,
  });

  final List<T> order;
  final T current;
  final ValueChanged<T> onChanged;
  final Widget Function(BuildContext context, T value) itemBuilder;
  final ValueNotifier<double>? progress;
  final bool enabled;
  final double edgeInset;

  @override
  State<SwipePager<T>> createState() => _SwipePagerState<T>();
}

/// 放手後滑完／彈回的時間（D-118：約 250ms，尾段減速）。
const kSwipePagerDuration = Duration(milliseconds: 250);

/// 拉過頁寬的這個比例就換頁。
const kSwipePagerThreshold = 0.3;

/// 撥動速度至少這麼快（px/s）就換頁（與 [SwipeToSwitch] 一致）。
const kSwipePagerFling = 400.0;

class _SwipePagerState<T> extends State<SwipePager<T>>
    with SingleTickerProviderStateMixin {
  late PageController _controller;

  /// 每頁一把 GlobalKey：跳格互換時頁面狀態（捲動位置、內部 GlobalKey）跟著搬。
  final _pageKeys = <int, GlobalKey>{};
  GlobalKey _pageKey(int i) => _pageKeys.putIfAbsent(i, GlobalKey.new);

  /// 已經「定下來」的頁（放手決定的目標，或外部指定的目標）。
  late int _index;

  /// 跳格動畫中：某一格暫時顯示另一頁的內容（[_swapSlot] 顯示 [_swapShows]）。
  int? _swapSlot;
  int? _swapShows;

  /// 跳格動畫的起點／終點（回報進度時把「隔壁→目標」換算成「起點→目標」）。
  int? _jumpFrom;
  int? _jumpTo;

  /// 端點再拉的彈性位移（px，往右為正）。
  late final AnimationController _bounce = AnimationController.unbounded(
    vsync: this,
  );

  bool _dragging = false;
  double _dragDx = 0;
  double _dragDy = 0;
  double _startPixels = 0;
  int _animSerial = 0;

  int _indexOf(T v) => math.max(0, widget.order.indexOf(v));

  @override
  void initState() {
    super.initState();
    _index = _indexOf(widget.current);
    _controller = PageController(initialPage: _index);
    _controller.addListener(_report);
    _bounce.addListener(() => setState(() {}));
    widget.progress?.value = _index.toDouble();
  }

  @override
  void didUpdateWidget(SwipePager<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      widget.progress?.value = _index.toDouble();
    }
    final target = _indexOf(widget.current);
    if (target != _index && !_dragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(target);
      });
      _index = target;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounce.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _report() {
    final p = widget.progress;
    if (p == null || !_controller.hasClients) return;
    final page = _controller.page ?? _index.toDouble();
    final from = _jumpFrom, to = _jumpTo, slot = _swapSlot;
    if (from != null && to != null && slot != null) {
      // 格子 slot（目標的隔壁）→ 目標 的進度，換算成 起點 → 目標。
      final t = ((page - slot) / (to - slot)).clamp(0.0, 1.0);
      p.value = from + (to - from) * t;
    } else {
      p.value = page.clamp(0.0, (widget.order.length - 1).toDouble());
    }
  }

  /// 滑到第 [target] 頁；隔超過一格時先把目標的隔壁格換成目前這頁的內容，再滑一格。
  Future<void> _goTo(int target) async {
    if (!_controller.hasClients) return;
    final serial = ++_animSerial;
    final cur = (_controller.page ?? target.toDouble()).round();
    if (_reduceMotion) {
      _clearSwap();
      _controller.jumpToPage(target);
      return;
    }
    if ((target - cur).abs() > 1) {
      final slot = target > cur ? target - 1 : target + 1;
      setState(() {
        _swapSlot = slot;
        _swapShows = cur;
        _jumpFrom = cur;
        _jumpTo = target;
      });
      _controller.jumpToPage(slot);
    }
    await _controller.animateToPage(
      target,
      duration: kSwipePagerDuration,
      curve: Curves.easeOut,
    );
    if (!mounted || serial != _animSerial) return;
    _clearSwap();
    _report();
  }

  void _clearSwap() {
    if (_swapSlot == null) return;
    setState(() {
      _swapSlot = null;
      _swapShows = null;
      _jumpFrom = null;
      _jumpTo = null;
    });
  }

  double get _width =>
      _controller.hasClients ? _controller.position.viewportDimension : 1;

  void _onDown(DragDownDetails d) {
    _dragDx = 0;
    _dragDy = 0;
  }

  void _onStart(DragStartDetails d) {
    if (!_controller.hasClients) return;
    _animSerial++;
    _clearSwap();
    _bounce.stop();
    _dragging = true;
    _startPixels = _index * _width;
    // 動畫進行中被抓住：從目前位置接手。
    final pos = _controller.position;
    _startPixels = pos.pixels;
    _controller.jumpTo(pos.pixels);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging || !_controller.hasClients) return;
    _dragDx += d.delta.dx;
    _dragDy += d.delta.dy;
    final pos = _controller.position;
    final want = _startPixels - _dragDx;
    final clamped = want.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    _controller.jumpTo(clamped);
    // 端點再拉：彈性位移，越拉阻力越大。
    final over = clamped - want; // 正＝往右拉超過第一頁
    _bounce.value = over == 0
        ? 0
        : over.sign * _width * 0.25 * (1 - 1 / (1 + over.abs() / _width));
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    _settle(d.velocity.pixelsPerSecond);
  }

  void _onCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(Offset.zero);
  }

  void _settle(Offset v) {
    if (_bounce.value != 0) {
      _bounce.animateTo(
        0,
        duration: kSwipePagerDuration,
        curve: Curves.easeOut,
      );
    }
    if (!_controller.hasClients) return;
    final from = (_startPixels / _width).round();
    final page = _controller.page ?? from.toDouble();
    final moved = page - from;
    var target = from;
    final fling = v.dx.abs() >= kSwipePagerFling && v.dx.abs() > v.dy.abs();
    if (fling) {
      // 撥的方向：手指往左撥＝下一頁。
      target = v.dx < 0 ? from + 1 : from - 1;
      // 拉的方向跟撥的方向相反（拉過去又撥回來）時以撥的方向為準。
    } else if (moved.abs() >= kSwipePagerThreshold &&
        _dragDx.abs() >= _dragDy.abs()) {
      target = moved > 0 ? from + 1 : from - 1;
    }
    target = target.clamp(0, widget.order.length - 1);
    _index = target;
    _goTo(target);
    if (target != _indexOf(widget.current)) {
      widget.onChanged(widget.order[target]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final canDrag = widget.enabled && widget.order.length > 1;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        SwipeEdgeAwareDrag:
            GestureRecognizerFactoryWithHandlers<SwipeEdgeAwareDrag>(
              () => SwipeEdgeAwareDrag(debugOwner: this),
              (r) {
                r
                  ..enabled = canDrag
                  ..edgeInset = widget.edgeInset
                  ..viewWidth = width
                  ..onDown = _onDown
                  ..onStart = _onStart
                  ..onUpdate = _onUpdate
                  ..onEnd = _onEnd
                  ..onCancel = _onCancel
                  ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                    context,
                  );
              },
            ),
      },
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(_bounce.value, 0),
          child: PageView.builder(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(),
            // 隔壁頁預先建好，滑動時不閃白。
            allowImplicitScrolling: true,
            itemCount: widget.order.length,
            itemBuilder: (context, i) {
              // 跳格時目標的隔壁格和起點格互換內容（GlobalKey 搬家，狀態跟著走、不重建）。
              final shows = i == _swapSlot
                  ? _swapShows!
                  : i == _swapShows
                  ? _swapSlot!
                  : i;
              return _KeepAlivePage(
                key: _pageKey(shows),
                child: widget.itemBuilder(context, widget.order[shows]),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 每頁各自保留（記住上下捲動位置）。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
