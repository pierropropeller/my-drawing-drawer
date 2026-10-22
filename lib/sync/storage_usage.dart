import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote_size_queries.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import 'remote.dart';
import 'sync_controller.dart';
import 'sync_log.dart';

/// 「備份與同步」頁的儲存空間（D-101）：帳號用量／總量＋畫匣自己的用量。
class StorageInfo {
  const StorageInfo({required this.quota, required this.drawerBytes});

  final StorageQuota quota;

  /// 畫匣在 Drive 上佔的位元組（本機記錄的總和，見 `RemoteFileSizes`）。
  final int drawerBytes;

  int get usage => quota.usage;
  int? get limit => quota.limit;

  /// 帳號用量已經到達上限（D-103）。無上限的帳號永遠不會滿。
  bool get isFull => limit != null && usage >= limit!;

  /// 畫匣以外的用量（Drive 其他檔案、Gmail、相簿…）；畫匣記錄比帳號用量還大時（記錄過時）為 0。
  int get otherBytes => usage > drawerBytes ? usage - drawerBytes : 0;

  /// 進度條分段占總量的比例（0～1）。無上限帳號沒有進度條：兩者皆 0。
  double get drawerFraction =>
      _fraction(drawerBytes > usage ? usage : drawerBytes);
  double get otherFraction => _fraction(otherBytes);

  double _fraction(int bytes) {
    final l = limit;
    if (l == null || l <= 0) return 0;
    return (bytes / l).clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is StorageInfo &&
      other.quota == quota &&
      other.drawerBytes == drawerBytes;

  @override
  int get hashCode => Object.hash(quota, drawerBytes);
}

/// 最近一次取得的儲存空間；還沒取得過（或換了帳號）為 null，這時卡片不顯示。
///
/// [refresh] 在進入頁面時呼叫一次，同步結束（成功或失敗）後也自動更新一次。
/// 載入中、離線或失敗一律**保留上一次的值**，不閃爍、不報錯（設計稿沒有畫這些狀態）；
/// 畫匣自己的用量讀本機記錄，所以即使帳號用量更新失敗也會跟著更新。
class StorageUsageNotifier extends Notifier<StorageInfo?> {
  int _gen = 0;

  @override
  StorageInfo? build() {
    // 換帳號／取消連結：舊帳號的數字作廢。
    ref.listen(settingsProvider.select((s) => s.accountEmail), (prev, next) {
      if (prev != next) {
        _gen++;
        state = null;
      }
    });
    // 同步結束後更新（用量變了）。
    ref.listen(syncControllerProvider.select((s) => s.phase), (prev, next) {
      if (prev == SyncPhase.syncing && next != SyncPhase.syncing) refresh();
    });
    return null;
  }

  Future<void> refresh() async {
    final remote = ref.read(syncRemoteProvider);
    if (remote is! StorageQuotaRemote) return;
    final gen = ++_gen;
    try {
      final drawer = await ref.read(databaseProvider).drawerRemoteBytes();
      StorageQuota? quota;
      try {
        quota = await (remote as StorageQuotaRemote).storageQuota();
      } catch (e) {
        syncLog('storage quota failed (${e.runtimeType})');
      }
      if (gen != _gen || !ref.mounted) return;
      final last = state;
      final q = quota ?? last?.quota;
      if (q == null) return;
      final next = StorageInfo(quota: q, drawerBytes: drawer);
      if (next != last) state = next;
    } catch (e) {
      syncLog('storage usage failed (${e.runtimeType})');
    }
  }
}

/// Drive 已滿（D-103）：最近一次同步的上傳被拒絕，或帳號用量已到上限。
/// 備份頁的儲存空間卡、自動同步的小字用它；頭像紅點只看同步結果（[SyncState.quotaFull]）。
final driveFullProvider = Provider<bool>((ref) {
  final byUpload = ref.watch(syncControllerProvider.select((s) => s.quotaFull));
  final byUsage = ref.watch(
    storageUsageProvider.select((i) => i?.isFull ?? false),
  );
  return byUpload || byUsage;
});

final storageUsageProvider =
    NotifierProvider<StorageUsageNotifier, StorageInfo?>(
      StorageUsageNotifier.new,
    );
