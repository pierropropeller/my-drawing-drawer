import '../../data/database.dart';
import '../../data/oshi_extra_queries.dart';
import '../../data/oshi_queries.dart';
import '../album/tag_batch_sheet.dart' show BatchTagBackend;

/// 推活多選的資料動作（D-079）。UI 只透過這一層呼叫資料層。
///
/// 資料層工程師的批次 API（`setOshiGroupBatch(ids, groupId?)`、`deleteOshiBatch(ids)`）
/// 還沒進來，目前先用現有查詢實作（[AppDatabase.oshiSetGroupLoop]、[AppDatabase.deleteOshiRecords]，
/// 都是單一 transaction／單一 update）。整合時只要把 [setGroup]、[delete] 兩個方法的本體換成正式 API，
/// 並刪掉 `lib/data/oshi_extra_queries.dart` 的 `oshiSetGroupLoop`。
class OshiSelectActions {
  const OshiSelectActions(this.db);
  final AppDatabase db;

  /// 把 [ids] 移到 [groupId]（null＝不分組）。
  Future<void> setGroup(Iterable<String> ids, String? groupId) =>
      db.oshiSetGroupLoop(
        ids,
        groupId,
      ); // TODO(integrator): db.setOshiGroupBatch(ids, groupId)

  /// 刪除（軟刪除）。
  Future<void> delete(Iterable<String> ids) =>
      db.deleteOshiRecords(ids); // TODO(integrator): db.deleteOshiBatch(ids)

  /// tag sheet 的接法：推活沒有 AlbumCell，三態與套用走 [OshiExtraQueries]。
  static final tagBackend = BatchTagBackend(
    watch: (db, ids) => db.watchOshiTagCoverage(ids),
    apply: (db, ids, {required add, required remove, required newNames}) =>
        db.applyOshiBatchTags(
          ids,
          addTagIds: add,
          removeTagIds: remove,
          newTagNames: newNames,
        ),
    countText: (l, n) => l.oshiCountRecords(n),
  );
}

/// 選取的紀錄共同的分組：全部同一組＝那組的 id（可能是 null＝都沒分組）；不一致＝不預選。
({bool uniform, String? groupId}) commonOshiGroup(
  Iterable<OshiRecordView> picked,
) {
  final ids = {for (final v in picked) v.record.groupId};
  return ids.length == 1
      ? (uniform: true, groupId: ids.first)
      : (uniform: false, groupId: null);
}
