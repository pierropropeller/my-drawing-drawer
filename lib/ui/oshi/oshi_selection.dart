import 'package:flutter/widgets.dart';

/// 推活多選的選取狀態（D-079）。
///
/// 選取狀態的唯一來源。拖曳連續多選（D-081）由 `DragSelectArea` 負責手勢與命中，
/// 這裡只做 index ↔ id 的對應：
/// - [order]：目前列表上所有紀錄 id，照畫面順序（時間軸＝攤平後的新→舊、九宮格＝左→右上→下），
///   每次 build 由頁面更新；`DragSelectItem.index` ＝ 該紀錄在 [order] 的位置；
/// - [applyIndices]：把拖曳給的完整 index 集合套回 id 集合；
/// - [setRange]：起點到終點之間的紀錄一次選中（或取消）。
class OshiSelection extends ChangeNotifier {
  /// 是否在多選模式（選到 0 筆時自動離開）。
  bool get active => _active;
  bool _active = false;

  /// 選中的紀錄 id。
  final Set<String> ids = {};

  List<String> get order => _order;
  List<String> _order = const [];

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

  /// 拖曳連續多選：[indices] 是完整的已選 index 集合（對應 [order]）。
  /// 拖曳進行中（[finished]＝false）即使暫時一筆都沒有也維持多選；放手時一筆都沒有才離開。
  void applyIndices(Set<int> indices, {required bool finished}) {
    ids
      ..clear()
      ..addAll([
        for (final i in indices)
          if (i >= 0 && i < _order.length) _order[i],
      ]);
    _active = !finished || ids.isNotEmpty;
    notifyListeners();
  }

  /// 離開多選（清空選取）。
  void exit() {
    ids.clear();
    _active = false;
    notifyListeners();
  }
}
