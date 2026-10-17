import 'dart:async';

import '../../data/database.dart';
import '../../data/ref_view_queries.dart';

/// 參考圖檢視的狀態暫存與存檔（每張圖一份 [RefViewSnapshot]，只存本機）。
///
/// - [load]：先看記憶體，再看資料庫，都沒有就是預設（完整顯示、未鎖定）。
/// - [update]：先更新記憶體，稍後（[debounce]）寫入資料庫；連續手勢不會狂寫。
/// - [flush]：馬上寫入所有待存的；離開頁面、App 切到背景前呼叫。
class RefViewStore {
  RefViewStore(this.db, {this.debounce = const Duration(milliseconds: 400)});

  final AppDatabase db;
  final Duration debounce;

  final _cache = <String, RefViewSnapshot>{};
  final _dirty = <String>{};
  Timer? _timer;
  bool _disposed = false;

  /// 記憶體裡的狀態（還沒載入過回傳 null）。
  RefViewSnapshot? peek(String file) => _cache[file];

  Future<RefViewSnapshot> load(String file) async {
    final hit = _cache[file];
    if (hit != null) return hit;
    final fromDb = await db.getRefViewState(file) ?? RefViewSnapshot.initial;
    // 等待期間若已被 update 寫入較新的值，以記憶體為準。
    return _cache.putIfAbsent(file, () => fromDb);
  }

  void update(String file, RefViewSnapshot s) {
    if (_disposed) return;
    if (_cache[file] == s) return;
    _cache[file] = s;
    _dirty.add(file);
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_dirty.isEmpty) return;
    final files = _dirty.toList();
    _dirty.clear();
    for (final f in files) {
      final s = _cache[f];
      if (s == null) continue;
      try {
        await db.saveRefViewState(f, s);
      } catch (_) {
        // 資料庫已關閉等情況：檢視狀態遺失不影響其他功能。
      }
    }
  }

  /// 圖片被刪除後忘掉它的狀態。
  Future<void> forget(String file) async {
    _cache.remove(file);
    _dirty.remove(file);
    try {
      await db.deleteRefViewState(file);
    } catch (_) {}
  }

  /// 結束：把待存的寫完。
  Future<void> dispose() async {
    await flush();
    _disposed = true;
  }
}
