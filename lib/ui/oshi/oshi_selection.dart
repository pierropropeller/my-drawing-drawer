import 'package:flutter/widgets.dart';

/// 推活多選的選取狀態（D-079）。
///
/// 給拖曳連續多選（D-081）預留的接口：
/// - [order]：目前列表上所有紀錄 id，照畫面順序（左→右、上→下 / 新→舊），每次 build 由頁面更新；
/// - [keyOf]：每一筆（時間軸卡片／九宮格的格子）的 [GlobalKey]，量位置用；
/// - [setRange]／[ids]：把起點到終點之間的紀錄一次選中（或取消）。
class OshiSelection extends ChangeNotifier {
  /// 是否在多選模式（選到 0 筆時自動離開）。
  bool get active => _active;
  bool _active = false;

  /// 選中的紀錄 id。
  final Set<String> ids = {};

  List<String> get order => _order;
  List<String> _order = const [];

  final Map<String, GlobalKey> _keys = {};
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 列表資料更新時呼叫：記下順序，並丟掉已不存在的 id 與 key。
  void updateOrder(List<String> order) {
    _order = order;
    final alive = order.toSet();
    _keys.removeWhere((k, _) => !alive.contains(k));
    final before = ids.length;
    ids.retainAll(alive);
    if (ids.length != before && _active) {
      if (ids.isEmpty) _active = false;
      // 在 build 期間呼叫，延到下一個 microtask 通知。
      Future.microtask(() {
        if (!_disposed) notifyListeners();
      });
    }
  }

  GlobalKey keyOf(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'oshi-$id'));

  bool isSelected(String id) => ids.contains(id);

  bool get allSelected => _order.isNotEmpty && ids.length >= _order.length;

  /// 長按：進入多選並選中這一筆。
  void begin(String id) {
    _active = true;
    ids.add(id);
    notifyListeners();
  }

  void toggle(String id) {
    if (!ids.remove(id)) ids.add(id);
    if (ids.isEmpty) _active = false;
    notifyListeners();
  }

  void selectAll() {
    ids
      ..clear()
      ..addAll(_order);
    _active = _order.isNotEmpty;
    notifyListeners();
  }

  /// [from]～[to]（含）之間，照 [order] 的順序全部選中（[select]＝false 則取消）。
  void setRange(String from, String to, {bool select = true}) {
    final a = _order.indexOf(from), b = _order.indexOf(to);
    if (a < 0 || b < 0) return;
    final lo = a < b ? a : b, hi = a < b ? b : a;
    for (final id in _order.sublist(lo, hi + 1)) {
      select ? ids.add(id) : ids.remove(id);
    }
    _active = ids.isNotEmpty;
    notifyListeners();
  }

  /// 離開多選（清空選取）。
  void exit() {
    ids.clear();
    _active = false;
    notifyListeners();
  }
}
