import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 返回鍵／返回手勢的統一護欄：最上層 Navigator 上有東西（bottom sheet、對話框、
/// 蓋滿全螢幕的頁面）時，返回只能作用在它身上，不能動到後面的頁面或分頁。
///
/// 為什麼需要：App 的每個分頁各有一個巢狀 Navigator。Android 開了預測式返回
/// （手勢導覽、Android 14+；targetSdk 36 起預設開啟）後，Flutter 會讓**每一個**
/// 「在自己的 Navigator 裡是最上層」的頁面各自去認領返回手勢（見
/// `PredictiveBackPageTransitionsBuilder`），而不是先問最上層 Navigator。分享進來的
/// 「加入到」sheet、同步 sheet 開在最上層 Navigator，後面分頁裡的頁面照樣認領手勢，
/// 於是 sheet 還在、後面的頁面卻被退掉。
///
/// 做法：用 [RootOverlayTracker] 追蹤最上層 Navigator 上除了首頁之外的路由數量；
/// [RootOverlayGuardTransitionsBuilder] 在每個頁面外面包一層 `PopScope`，
/// 有最上層路由時 `canPop: false`，頁面就不認領手勢，Flutter 會退回一般的返回流程，
/// 由最上層 Navigator 關掉最上面的 sheet。被 IndexedStack 藏起來的分頁（[TabBackScope]）
/// 同理，不該認領返回手勢。

/// 追蹤最上層 Navigator 上（首頁以外）的路由。掛在 `MaterialApp.navigatorObservers`。
class RootOverlayTracker extends NavigatorObserver {
  final Set<Route<dynamic>> _routes = <Route<dynamic>>{};

  /// 最上層 Navigator 上首頁以外的路由數量。
  final ValueNotifier<int> depth = ValueNotifier<int>(0);

  void _publish() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      // build 期間不能通知 listener，延到 microtask。
      scheduleMicrotask(() => depth.value = _routes.length);
    } else {
      depth.value = _routes.length;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return; // 首頁
    _routes.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_routes.remove(route)) _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    var changed = false;
    if (oldRoute != null) changed = _routes.remove(oldRoute) || changed;
    // 被換掉的若是首頁（oldRoute 不在集合內），新路由就是新的首頁，不計數。
    if (newRoute != null && oldRoute != null && changed) {
      _routes.add(newRoute);
    }
    if (changed) _publish();
  }
}

/// 把 [RootOverlayTracker] 提供給底下的頁面轉場。
class RootOverlayScope extends InheritedWidget {
  const RootOverlayScope({
    super.key,
    required this.tracker,
    required super.child,
  });

  final RootOverlayTracker tracker;

  static RootOverlayTracker? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RootOverlayScope>()?.tracker;

  @override
  bool updateShouldNotify(RootOverlayScope oldWidget) =>
      tracker != oldWidget.tracker;
}

/// 標記某個分頁目前是不是顯示中的分頁；IndexedStack 藏起來的分頁裡的頁面
/// 在自己的 Navigator 裡仍是「最上層」，不能讓它們認領返回手勢。
class TabBackScope extends InheritedWidget {
  const TabBackScope({super.key, required this.active, required super.child});

  final bool active;

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBackScope>()?.active ??
      true;

  @override
  bool updateShouldNotify(TabBackScope oldWidget) => active != oldWidget.active;
}

/// 擁有 [RootOverlayTracker] 並提供給底下的 App（放在 MaterialApp 外面）。
class RootOverlayHost extends StatefulWidget {
  const RootOverlayHost({super.key, required this.builder});

  final Widget Function(BuildContext context, RootOverlayTracker tracker)
  builder;

  @override
  State<RootOverlayHost> createState() => _RootOverlayHostState();
}

class _RootOverlayHostState extends State<RootOverlayHost> {
  final _tracker = RootOverlayTracker();

  @override
  Widget build(BuildContext context) => RootOverlayScope(
    tracker: _tracker,
    child: widget.builder(context, _tracker),
  );
}

/// 頁面轉場照用 Android 預設的預測式返回，外面多包返回護欄。
class RootOverlayGuardTransitionsBuilder extends PageTransitionsBuilder {
  const RootOverlayGuardTransitionsBuilder([
    this.inner = const PredictiveBackPageTransitionsBuilder(),
  ]);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions<T>(
    route,
    context,
    animation,
    secondaryAnimation,
    _BackGuard(child: child),
  );
}

class _BackGuard extends StatelessWidget {
  const _BackGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 被 IndexedStack 藏起來的分頁（Shell 用 [TabBackScope] 標記）不認領返回手勢。
    final active = TabBackScope.isActive(context);
    final tracker = RootOverlayScope.maybeOf(context);
    if (tracker == null) return _scope(active, child);
    return ValueListenableBuilder<int>(
      valueListenable: tracker.depth,
      builder: (_, depth, _) => _scope(active && depth == 0, child),
      child: child,
    );
  }

  Widget _scope(bool canPop, Widget child) => PopScope(
    // 只用來讓這一頁不認領預測式返回手勢；實際的返回仍走 Navigator／Shell。
    canPop: canPop,
    child: child,
  );
}
