import 'package:drift/drift.dart';

import 'database.dart';

/// 畫匣在 Google Drive 上的用量（D-101）：本機記下的每個遠端檔大小加總，
/// 不用每次去 Drive 逐個查。
extension RemoteSizeQueries on AppDatabase {
  /// 所有已記錄遠端檔（原圖、占位圖、meta、格式標記）的位元組總和；沒有記錄為 0。
  Future<int> drawerRemoteBytes() async {
    final sum = remoteFileSizes.size.sum();
    final row = await (selectOnly(
      remoteFileSizes,
    )..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }
}
