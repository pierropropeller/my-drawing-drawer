import 'dart:convert';

import 'database.dart';

/// 圖冊手動排序（D-134）的範圍：哪一個列表的哪一頁（「全部」或某個分組）。
/// 「全部」和每個分組各存一套順序，在分組裡排不會動到「全部」。
abstract final class AlbumOrderScope {
  static const _all = 'all';

  /// 坑內參考圖。[groupId] null＝全部。
  static String official(String pitId, String? groupId) =>
      'official:$pitId:${groupId ?? _all}';

  /// 坑內好看同人圖。[groupId] null＝全部（「無出處」用它的篩選值）。
  static String fan(String pitId, String? groupId) =>
      'fan:$pitId:${groupId ?? _all}';

  /// 靈感廣場。[categoryId] null＝全部。
  static String inspo(String? categoryId) => 'inspo:${categoryId ?? _all}';
}

/// 依存好的順序排 [items]：還沒排過的（新加的、從別處移進來的）放最前面，
/// 照原本次序（更新日期新→舊）；排過的照存的順序接在後面。[ids]＝null 表示這頁從沒排過。
List<T> applyAlbumOrder<T>(
  List<T> items,
  List<String>? ids,
  String Function(T) idOf,
) {
  if (ids == null || ids.isEmpty) return items;
  final pos = {for (var i = 0; i < ids.length; i++) ids[i]: i};
  final fresh = <T>[];
  final placed = <T>[];
  for (final it in items) {
    (pos.containsKey(idOf(it)) ? placed : fresh).add(it);
  }
  placed.sort((a, b) => pos[idOf(a)]!.compareTo(pos[idOf(b)]!));
  return [...fresh, ...placed];
}

extension AlbumOrderQueries on AppDatabase {
  /// 某一頁存的順序；沒排過＝null。
  Stream<List<String>?> watchAlbumOrder(String scope) =>
      (select(albumOrders)..where((t) => t.scope.equals(scope)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : decodeAlbumOrder(r.ids));

  /// 存這一頁的新順序（拖動放手時）。只寫這張表，不動圖本身（排序不算「更新」）。
  Future<void> saveAlbumOrder(String scope, List<String> ids) =>
      into(albumOrders).insertOnConflictUpdate(
        AlbumOrdersCompanion.insert(
          scope: scope,
          ids: jsonEncode(ids),
          updatedAt: DateTime.now(),
        ),
      );
}

List<String> decodeAlbumOrder(String raw) {
  try {
    return [for (final e in jsonDecode(raw) as List) e as String];
  } catch (_) {
    return const [];
  }
}
