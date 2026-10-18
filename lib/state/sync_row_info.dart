import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync_row_info.dart';
import 'providers.dart';

/// 同步 sheet 各行的位置資料快取（D-099）：檔名 → 所屬實體；查過沒找到的存 null。
/// [ensure] 把還沒查過的檔名**一次批次查完**（見 `AppDatabase.syncRowInfos`），不逐張查。
class SyncRowInfoCache extends Notifier<Map<String, SyncRowInfo?>> {
  final _inflight = <String>{};

  /// 快取上限；超過就丟掉舊的重來（sheet 只看得到最前面幾行，資料很便宜）。
  static const maxEntries = 300;

  @override
  Map<String, SyncRowInfo?> build() => const {};

  Future<void> ensure(Iterable<String> files) async {
    final need = {
      for (final f in files)
        if (!state.containsKey(f) && !_inflight.contains(f)) f,
    }.toList();
    if (need.isEmpty) return;
    _inflight.addAll(need);
    try {
      final found = await ref.read(databaseProvider).syncRowInfos(need);
      final base = state.length > maxEntries
          ? const <String, SyncRowInfo?>{}
          : state;
      state = {...base, for (final f in need) f: found[f]};
    } catch (_) {
      // 查不到就當作未知（占位＋只有「上傳／下載」），不影響同步。
    } finally {
      _inflight.removeAll(need);
    }
  }
}

final syncRowInfoProvider =
    NotifierProvider<SyncRowInfoCache, Map<String, SyncRowInfo?>>(
      SyncRowInfoCache.new,
    );
