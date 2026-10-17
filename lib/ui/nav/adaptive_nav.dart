/// 自適應導覽（手機底部列／平板 icon rail／橫向 sidebar）的公開 API。
///
/// ## 三種導覽（依視窗闊度，見 `WindowClass`）
/// - compact（＜600）：底部導覽列（手機版面，不變）。
/// - medium（600–839）：左側 icon rail 84，一律如此。
/// - expanded／large（≥840）：由「目前最上層頁面」宣告的 [SideNavStyle] 決定：
///   [SideNavStyle.sidebar]＝完整 sidebar 260（頭像、坑／目標／我的、現坑清單、開新坑；
///   目標頁另有年份），[SideNavStyle.rail]＝icon rail 84。**沒有宣告就是 rail**。
///
/// 導覽的顯示規則不變：任何頁面只要掛了 `HidesNavBar`／`HideNavBar`（`navBarHiddenCount` > 0），
/// 底部列、rail、sidebar 一起藏起來。
///
/// ## 頁面怎麼宣告要用 sidebar（給其他區塊的工程師）
/// 要用 sidebar 的頁面（設計稿：Main、Pit、Goal）把整頁包一層：
///
/// ```dart
/// @override
/// Widget build(BuildContext context) => SideNavStyleHint.sidebar(
///   currentPitId: widget.pitId, // 選填：sidebar 的現坑清單把這個坑標成目前所在
///   child: Scaffold(...),
/// );
/// ```
///
/// 用 rail 的頁面（分區頁、我的）什麼都不用做，預設就是 rail。
///
/// - 只有「所屬分頁 Navigator 上最上層的那個頁面路由」宣告的 hint 有效；彈出的 bottom sheet
///   與對話框不算，所以 sheet 打開時導覽不會變。頁面被別的頁面蓋住時，看蓋住它的頁面。
/// - 一個頁面可以自帶 sidebar 的下半部（取代預設的現坑清單／年份）：`sidebarSection` 在 sidebar
///   build 時呼叫；內容隨頁面狀態變時請用 setState 重建這個 hint（舊／新 builder 不同就會刷新），
///   或自己監聽 Listenable。
/// - 目標頁的預設年份清單由 [goalSidebarYearProvider] 驅動：頁面切年份時寫入它，
///   sidebar 點年份時它會改變，頁面監聽它即可。
/// - 狀態（分頁 index、每個分頁的頁面堆疊）都在 Shell 的 State，不受 rail／sidebar／底部列
///   切換影響，拉窗不會重建頁面。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// sidebar（完整 260）或 rail（icon 84）。
enum SideNavStyle { rail, sidebar }

/// 目標頁 sidebar 的年份選擇（null＝今年）。頁面與 sidebar 共用。
class GoalSidebarYear extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void select(int year) => state = year;
}

final goalSidebarYearProvider = NotifierProvider<GoalSidebarYear, int>(
  GoalSidebarYear.new,
);

/// 解析後的目前導覽設定。
class SideNavSpec {
  const SideNavSpec({
    this.style = SideNavStyle.rail,
    this.sidebarSection,
    this.currentPitId,
  });

  final SideNavStyle style;

  /// 取代 sidebar 預設下半部的內容（null＝用所屬分頁的預設：坑＝現坑清單、目標＝年份）。
  final WidgetBuilder? sidebarSection;

  /// sidebar 現坑清單中標成目前所在的坑。
  final String? currentPitId;

  static const rail = SideNavSpec();
}

class _Entry {
  _Entry(this.tab, this.order);
  final int tab;
  final int order;
  Route<dynamic>? route;
  SideNavSpec spec = SideNavSpec.rail;
}

/// Shell 擁有：收集各頁面的 [SideNavStyleHint]，並依各分頁最上層頁面路由解析出目前設定。
class SideNavController extends ChangeNotifier {
  final List<_Entry> _entries = [];
  final Map<int, Route<dynamic>?> _tops = {};
  int _seq = 0;
  bool _pending = false;
  bool _disposed = false;

  /// [tab] 目前的導覽設定；最上層頁面沒宣告就是 rail。
  SideNavSpec specFor(int tab) {
    final top = _tops[tab];
    _Entry? best;
    for (final e in _entries) {
      if (e.tab != tab) continue;
      if (e.route != null && e.route != top) continue;
      if (best == null || e.order > best.order) best = e;
    }
    return best?.spec ?? SideNavSpec.rail;
  }

  _Entry _register(int tab) {
    final e = _Entry(tab, _seq++);
    _entries.add(e);
    return e;
  }

  void _unregister(_Entry e) {
    if (_entries.remove(e)) _changed();
  }

  void _setTop(int tab, Route<dynamic>? route) {
    if (_tops[tab] == route) return;
    _tops[tab] = route;
    _changed();
  }

  void _changed() {
    // build／導航過程中不能直接通知 listener，延到 microtask。
    if (_pending || _disposed) return;
    _pending = true;
    scheduleMicrotask(() {
      _pending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 掛在各分頁 Navigator 的 observer：記錄最上層的頁面路由（彈出式的 sheet／對話框不算）。
class SideNavObserver extends NavigatorObserver {
  SideNavObserver(this.controller, this.tab);
  final SideNavController controller;
  final int tab;
  final List<Route<dynamic>> _stack = [];

  void _publish() {
    Route<dynamic>? top;
    for (final r in _stack.reversed) {
      if (r is PageRoute) {
        top = r;
        break;
      }
    }
    controller._setTop(tab, top);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route);
    _publish();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    _publish();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute != null) {
        _stack[i] = newRoute;
      } else {
        _stack.removeAt(i);
      }
    } else if (newRoute != null) {
      _stack.add(newRoute);
    }
    _publish();
  }
}

/// 提供 [SideNavController] 與所屬分頁 index 給分頁內的頁面。
class SideNavTabScope extends InheritedWidget {
  const SideNavTabScope({
    super.key,
    required this.controller,
    required this.tab,
    required super.child,
  });

  final SideNavController controller;
  final int tab;

  static SideNavTabScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SideNavTabScope>();

  @override
  bool updateShouldNotify(SideNavTabScope oldWidget) =>
      controller != oldWidget.controller || tab != oldWidget.tab;
}

/// 頁面宣告「我在 expanded 以上要用哪種導覽」。包住整個頁面；沒有 [SideNavTabScope]
/// （例如單獨 pump 頁面的測試）時什麼都不做。
class SideNavStyleHint extends StatefulWidget {
  const SideNavStyleHint({
    super.key,
    this.style = SideNavStyle.rail,
    this.sidebarSection,
    this.currentPitId,
    required this.child,
  });

  /// 宣告用完整 sidebar（Main、Pit、Goal 型頁面）。
  const SideNavStyleHint.sidebar({
    Key? key,
    WidgetBuilder? sidebarSection,
    String? currentPitId,
    required Widget child,
  }) : this(
         key: key,
         style: SideNavStyle.sidebar,
         sidebarSection: sidebarSection,
         currentPitId: currentPitId,
         child: child,
       );

  final SideNavStyle style;
  final WidgetBuilder? sidebarSection;
  final String? currentPitId;
  final Widget child;

  @override
  State<SideNavStyleHint> createState() => _SideNavStyleHintState();
}

class _SideNavStyleHintState extends State<SideNavStyleHint> {
  SideNavController? _controller;
  _Entry? _entry;

  SideNavSpec get _spec => SideNavSpec(
    style: widget.style,
    sidebarSection: widget.sidebarSection,
    currentPitId: widget.currentPitId,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SideNavTabScope.maybeOf(context);
    if (scope?.controller != _controller) {
      if (_entry != null) _controller?._unregister(_entry!);
      _controller = scope?.controller;
      _entry = null;
      if (scope != null) _entry = scope.controller._register(scope.tab);
    }
    _entry?.route = ModalRoute.of(context);
    _publish();
  }

  @override
  void didUpdateWidget(SideNavStyleHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  void _publish() {
    final e = _entry;
    if (e == null) return;
    e.spec = _spec;
    _controller?._changed();
  }

  @override
  void dispose() {
    if (_entry != null) _controller?._unregister(_entry!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
