import '../../data/batch_tag_queries.dart';
import '../../data/database.dart';
import '../../data/oshi_queries.dart';
import '../album/tag_batch_sheet.dart' show BatchTagBackend;

/// 推活多選的資料動作（D-079）。UI 只透過這一層呼叫資料層的批次 API。
class OshiSelectActions {
  const OshiSelectActions(this.db);
  final AppDatabase db;

  /// 把 [ids] 移到 [groupId]（null＝不分組）。
  Future<void> setGroup(Iterable<String> ids, String? groupId) =>
      db.setOshiGroupBatch(ids, groupId);

  /// 刪除（軟刪除）。
  Future<void> delete(Iterable<String> ids) => db.deleteOshiBatch(ids);

  /// tag sheet 的接法：推活沒有 AlbumCell，走通用版批次 tag（`TagTarget.oshi`）。
  static final tagBackend = BatchTagBackend(
    watch: (db, ids) => db.watchTagCoverageFor(TagTarget.oshi, ids),
    apply: (db, ids, {required add, required remove, required newNames}) =>
        db.applyBatchTagsFor(
          TagTarget.oshi,
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
