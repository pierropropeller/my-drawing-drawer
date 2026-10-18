import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 「看大圖」的深色預覽頁共用手勢（官方圖冊／同人圖／雜物預覽、詳情輪播進來的全螢幕、
/// 參考圖／影片檢視）：
///
/// - **點一下圖片＝收起／叫出所有 UI**（標題列、頁碼、底部操作列、資訊區），收起後只剩圖片；
/// - **垂直拖曳退出**（同 iOS 相簿／Telegram）：圖片跟手位移、縮小，背景漸淡露出後面的頁面，
///   放手超過距離門檻或速度夠就關閉，不夠就彈回；
/// - 多張圖用 PageView 左右切換，所以水平拖曳不能一律當成退出：只有在**第一張再往右拖／
///   最後一張再往左拖**（PageView 已經沒地方捲）時，水平拖曳才退出；
/// - 圖片放大（縮放 >1）時不退出，兩指操作也不退出。
///
/// 用法：頁面最外層包 [DismissiblePreview]（畫背景、提供狀態），標題列／資訊區／操作列各包一層
/// [PreviewChrome]，圖片區包 [PreviewMediaArea]。可縮放的圖用 `MediaViewer(zoomable: true)`
/// 會自動回報縮放狀態；自己做縮放的（參考圖舞台）呼叫 [PreviewController.setZoomed]。

/// 垂直（或到邊緣的水平）拖曳超過這個距離放手就關閉。
const double kPreviewDismissDistance = 100;

/// 放手時沿拖曳方向的速度超過這個值（px/s）就關閉（距離至少 [kPreviewMinFlingDistance]）。
const double kPreviewDismissVelocity = 700;
const double kPreviewMinFlingDistance = 24;

/// 拖曳多遠才算開始（避免和點一下混淆）。
const double kPreviewDragSlop = 12;

/// 拖到這麼遠時，背景完全透明、圖縮到最小。
const double kPreviewFullFadeDistance = 300;

abstract interface class PreviewController {
  /// 標題列等 UI 目前是否顯示。
  ValueListenable<bool> get chromeVisible;

  /// 拖曳退出的進度 0～1（0＝沒在拖）。
  ValueListenable<double> get dragProgress;

  /// 是否正在拖曳退出（PageView 此時不該捲動）。
  ValueListenable<bool> get dragging;

  void toggleChrome();
  void setChrome(bool visible);

  /// 回報某個可縮放的圖目前是否放大中（[owner] 用來區分多頁）。放大中不觸發拖曳退出。
  void setZoomed(Object owner, bool zoomed);
  bool get zoomed;

  /// 關閉預覽（預設 `Navigator.maybePop`）。回傳是否真的關掉（被攔截返回時為 false）。
  Future<bool> dismiss();
}

class PreviewScope extends InheritedWidget {
  const PreviewScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PreviewController controller;

  static PreviewController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PreviewScope>()?.controller;

  @override
  bool updateShouldNotify(PreviewScope oldWidget) =>
      controller != oldWidget.controller;
}

/// 預覽頁最外層：畫背景（拖曳時漸淡）、持有 UI 顯示狀態。
class DismissiblePreview extends StatefulWidget {
  const DismissiblePreview({
    super.key,
    required this.background,
    required this.child,
    this.onDismiss,
  });

  /// 預覽頁的底色。拖曳時它的透明度跟著降低，露出後面的頁面。
  final Color background;
  final Widget child;

  /// 關閉預覽；null＝`Navigator.maybePop`。
  final VoidCallback? onDismiss;

  @override
  State<DismissiblePreview> createState() => _DismissiblePreviewState();
}

class _DismissiblePreviewState extends State<DismissiblePreview>
    implements PreviewController {
  final _chrome = ValueNotifier<bool>(true);
  final _progress = ValueNotifier<double>(0);
  final _dragging = ValueNotifier<bool>(false);
  final _zoomedOwners = <Object>{};
  bool _dismissed = false;

  @override
  ValueListenable<bool> get chromeVisible => _chrome;
  @override
  ValueListenable<double> get dragProgress => _progress;
  @override
  ValueListenable<bool> get dragging => _dragging;

  @override
  void toggleChrome() => _chrome.value = !_chrome.value;
  @override
  void setChrome(bool visible) => _chrome.value = visible;

  @override
  void setZoomed(Object owner, bool zoomed) {
    if (zoomed) {
      _zoomedOwners.add(owner);
    } else {
      _zoomedOwners.remove(owner);
    }
  }

  @override
  bool get zoomed => _zoomedOwners.isNotEmpty;

  /// 拖曳進度由 [PreviewMediaArea] 回報。
  void _setDrag({required bool dragging, required double progress}) {
    _dragging.value = dragging;
    _progress.value = progress;
    // 拖曳時讓出後面的頁面：預設不透明的路由不會畫後面的頁面，要先改成透明。
    final route = ModalRoute.of(context);
    final entries = route?.overlayEntries;
    if (route != null && entries != null && entries.isNotEmpty) {
      entries.first.opaque = (dragging || progress > 0) ? false : route.opaque;
    }
  }

  @override
  Future<bool> dismiss() async {
    if (_dismissed) return true;
    _dismissed = true;
    if (widget.onDismiss != null) {
      widget.onDismiss!();
      return true;
    }
    final route = ModalRoute.of(context);
    await Navigator.of(context).maybePop();
    // `maybePop` 被 PopScope 擋下時也回傳 true，所以改看路由是否真的離開了。
    final popped = route == null || !route.isActive;
    // 被擋下來（例如頁面攔截返回）：回到原位。
    if (!popped && mounted) _dismissed = false;
    return popped;
  }

  bool get isDismissed => _dismissed;

  @override
  void dispose() {
    _chrome.dispose();
    _progress.dispose();
    _dragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PreviewScope(
      controller: this,
      child: ValueListenableBuilder<double>(
        valueListenable: _progress,
        builder: (context, p, child) => ColoredBox(
          color: widget.background.withValues(
            alpha: widget.background.a * (1 - p).clamp(0.0, 1.0),
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 標題列、頁碼、資訊區、底部操作列：點一下圖片時跟著收起／叫出（版面不變，只是淡出且不可點）；
/// 拖曳退出時也會先淡出。
class PreviewChrome extends StatelessWidget {
  const PreviewChrome({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = PreviewScope.maybeOf(context);
    if (c == null) return child;
    return ListenableBuilder(
      listenable: Listenable.merge([c.chromeVisible, c.dragProgress]),
      builder: (context, child) {
        final visible = c.chromeVisible.value;
        final opacity = visible
            ? (1 - c.dragProgress.value * 4).clamp(0.0, 1.0)
            : 0.0;
        return IgnorePointer(
          ignoring: !visible,
          child: ExcludeSemantics(
            excluding: !visible,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: opacity,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 圖片區：點一下切換 UI、垂直拖曳（或到邊緣的水平拖曳）退出。
///
/// 手勢用 [Listener] 直接看指標事件，不進手勢競技場，所以不會和 PageView 的水平捲動、
/// InteractiveViewer 的雙指縮放／平移互相搶。
class PreviewMediaArea extends StatefulWidget {
  const PreviewMediaArea({super.key, required this.child, this.pageController});

  final Widget child;

  /// 圖片區裡的 PageView 控制器；用來判斷是不是在第一張／最後一張的邊緣。
  /// null＝只有一張（兩個方向都是邊緣）。
  final PageController? pageController;

  @override
  State<PreviewMediaArea> createState() => _PreviewMediaAreaState();
}

class _PreviewMediaAreaState extends State<PreviewMediaArea>
    with SingleTickerProviderStateMixin {
  final _pointers = <int>{};
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(_onBack);
  Offset _from = Offset.zero;
  Offset _offset = Offset.zero;
  final _offsetListenable = ValueNotifier<Offset>(Offset.zero);

  Offset _start = Offset.zero;
  Offset _origin = Offset.zero;
  bool _engaged = false;
  bool _blocked = false;
  bool _didDrag = false;
  VelocityTracker? _tracker;

  _DismissiblePreviewState? get _state =>
      context.findAncestorStateOfType<_DismissiblePreviewState>();
  PreviewController? get _scope => PreviewScope.maybeOf(context);

  @override
  void dispose() {
    _back.dispose();
    _offsetListenable.dispose();
    super.dispose();
  }

  double get _progressNow =>
      (_offset.distance / kPreviewFullFadeDistance).clamp(0.0, 1.0);

  void _apply(Offset offset, {required bool dragging}) {
    _offset = offset;
    _offsetListenable.value = offset;
    _state?._setDrag(dragging: dragging, progress: _progressNow);
  }

  void _onBack() {
    final t = Curves.easeOut.transform(_back.value);
    _apply(Offset.lerp(_from, Offset.zero, t)!, dragging: false);
  }

  bool _atEdge(double dx) {
    final c = widget.pageController;
    if (c == null || !c.hasClients) return true;
    final p = c.position;
    if (dx > 0) return p.pixels <= p.minScrollExtent + 0.5;
    if (dx < 0) return p.pixels >= p.maxScrollExtent - 0.5;
    return false;
  }

  void _onDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      // 第二根手指（縮放）：放棄這次拖曳，已經在拖的彈回去。
      _blocked = true;
      if (_engaged) _release(cancel: true);
      return;
    }
    _back.stop();
    _blocked = _scope?.zoomed ?? false;
    _engaged = false;
    _didDrag = false;
    _start = e.position;
    _tracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
    if (_offset != Offset.zero) {
      // 彈回途中又按下：接手繼續拖。
      _origin = e.position - _offset;
      _engaged = true;
      _blocked = false;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (_blocked || _pointers.length != 1 || _state?.isDismissed == true) {
      return;
    }
    _tracker?.addPosition(e.timeStamp, e.position);
    if (!_engaged) {
      final d = e.position - _start;
      if (d.distance < kPreviewDragSlop) return;
      if (_scope?.zoomed ?? false) {
        _blocked = true;
        return;
      }
      final vertical = d.dy.abs() > d.dx.abs();
      if (!vertical && !_atEdge(d.dx)) {
        // 一般的左右切圖：交給 PageView。
        _blocked = true;
        return;
      }
      _engaged = true;
      _didDrag = true;
      _origin = _start; // 位移從按下的位置算起（不會在開始時突然跳掉）
    }
    _apply(e.position - _origin, dragging: true);
  }

  void _onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_engaged && _pointers.isEmpty) {
      _tracker?.addPosition(e.timeStamp, e.position);
      _release();
    }
    if (_pointers.isEmpty) _blocked = false;
  }

  void _onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_engaged && _pointers.isEmpty) _release(cancel: true);
    if (_pointers.isEmpty) _blocked = false;
  }

  void _release({bool cancel = false}) {
    _engaged = false;
    final off = _offset;
    final dist = off.distance;
    var along = 0.0;
    final v = _tracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
    if (dist > 0) along = (v.dx * off.dx + v.dy * off.dy) / dist;
    final close =
        !cancel &&
        (dist >= kPreviewDismissDistance ||
            (along >= kPreviewDismissVelocity &&
                dist >= kPreviewMinFlingDistance));
    if (close) {
      _state?._setDrag(dragging: false, progress: _progressNow);
      _scope?.dismiss().then((closed) {
        if (!closed && mounted) _bounce();
      });
    } else {
      _bounce();
    }
  }

  void _bounce() {
    _from = _offset;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_didDrag || _offset != Offset.zero) return;
          _scope?.toggleChrome();
        },
        child: ValueListenableBuilder<Offset>(
          valueListenable: _offsetListenable,
          builder: (context, offset, child) {
            final p = math.min(offset.distance / kPreviewFullFadeDistance, 1.0);
            final scale = 1 - 0.3 * p;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.translationValues(offset.dx, offset.dy, 0)
                ..scaleByDouble(scale, scale, 1, 1),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
