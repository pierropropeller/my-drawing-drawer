import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart';

/// 一筆推活紀錄與它的圖片、分組、tag（D-057／D-062，HANDOFF 3.11）。
class OshiRecordView {
  const OshiRecordView({
    required this.record,
    required this.images,
    required this.tags,
    this.group,
  });

  final OshiRecord record;

  /// 至少一張，依 sortOrder。
  final List<ImageRef> images;
  final List<Tag> tags;

  /// 所屬分組；沒有分組或分組已刪除＝null。
  final OfficialGroup? group;

  DateTime get date => record.date;
  ImageRef get cover => images.first;
}

/// 推活（D-057）：紀錄的查詢與儲存。分組沿用 [AlbumQueries] 的分組函式，`kind: 'oshi'`。
extension OshiQueries on AppDatabase {
  Set<TableInfo> get _oshiTables => {
    oshiRecords,
    entityImages,
    tagLinks,
    tags,
    officialGroups,
  };

  // 日期新到舊；同日建立較晚的在前（createdAt 只到秒，rowid 當最後的決勝）。
  List<OrderClauseGenerator<$OshiRecordsTable>> get _oshiOrder => [
    (o) => OrderingTerm.desc(o.date),
    (o) => OrderingTerm.desc(o.createdAt),
    (o) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
  ];

  Future<OshiRecordView> _oshiView(OshiRecord r) async {
    OfficialGroup? group;
    if (r.groupId != null) {
      group =
          await (select(officialGroups)
                ..where((g) => g.id.equals(r.groupId!) & g.deletedAt.isNull()))
              .getSingleOrNull();
    }
    final imageRows =
        await (select(entityImages)
              ..where(
                (e) =>
                    e.ownerType.equalsValue(OwnerType.oshi) &
                    e.ownerId.equals(r.id),
              )
              ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
            .get();
    final tagRows =
        await (select(tags)
                .join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
              ..where(
                tagLinks.targetType.equalsValue(TagTarget.oshi) &
                    tagLinks.targetId.equals(r.id) &
                    tags.deletedAt.isNull(),
              )
              ..orderBy([OrderingTerm.asc(tags.name)]))
            .get();
    return OshiRecordView(
      record: r,
      images: [
        for (final e in imageRows) ImageRef(e.imageFile, e.width, e.height),
      ],
      tags: [for (final t in tagRows) t.readTable(tags)],
      group: group,
    );
  }

  /// 一次性載入（搜尋用）：[pitId] 的全部推活紀錄，日期新到舊。
  Future<List<OshiRecordView>> loadOshiViews(String pitId) async => [
    for (final r
        in await (select(oshiRecords)
              ..where((o) => o.pitId.equals(pitId) & o.deletedAt.isNull())
              ..orderBy(_oshiOrder))
            .get())
      await _oshiView(r),
  ];

  /// 坑內的推活紀錄，日期新到舊（同日以建立時間新到舊）。
  /// [groupId]：只看某個分組；[tagId]：只看有某個 tag 的（兩者可並用；
  /// 搜尋結果「+N」與詳情頁點 tag 用 [tagId]，D-065）。
  /// 按月份分段、段首「N 筆」是 UI 的事（資料已依日期排好）。
  Stream<List<OshiRecordView>> watchOshiRecords(
    String pitId, {
    String? groupId,
    String? tagId,
  }) {
    return watchAssembled(this, _oshiTables, () async {
      final rows =
          await (select(oshiRecords)
                ..where(
                  (o) =>
                      o.pitId.equals(pitId) &
                      o.deletedAt.isNull() &
                      (groupId == null
                          ? const Constant(true)
                          : o.groupId.equals(groupId)) &
                      (tagId == null
                          ? const Constant(true)
                          : o.id.isInQuery(
                              selectOnly(tagLinks)
                                ..addColumns([tagLinks.targetId])
                                ..where(
                                  tagLinks.tagId.equals(tagId) &
                                      tagLinks.targetType.equalsValue(
                                        TagTarget.oshi,
                                      ),
                                ),
                            )),
                )
                ..orderBy(_oshiOrder))
              .get();
      return [for (final r in rows) await _oshiView(r)];
    });
  }

  Stream<OshiRecordView?> watchOshiRecord(String id) {
    return watchAssembled(this, _oshiTables, () => getOshiRecord(id));
  }

  Future<OshiRecordView?> getOshiRecord(String id) async {
    final r = await (select(
      oshiRecords,
    )..where((o) => o.id.equals(id) & o.deletedAt.isNull())).getSingleOrNull();
    return r == null ? null : _oshiView(r);
  }

  /// 坑內推活筆數（坑內頁第六格「N 筆」；`watchPitStats(...).oshi` 也有同一個數字）。
  Stream<int> watchOshiCount(String pitId) {
    final count = oshiRecords.id.count();
    return (selectOnly(oshiRecords)
          ..addColumns([count])
          ..where(
            oshiRecords.pitId.equals(pitId) & oshiRecords.deletedAt.isNull(),
          ))
        .watchSingle()
        .map((r) => r.read(count) ?? 0);
  }

  /// 每個分組的紀錄筆數（key＝groupId）與沒有分組的筆數（key＝null）。
  Stream<Map<String?, int>> watchOshiGroupCounts(String pitId) {
    return watchAssembled(this, {oshiRecords}, () async {
      final out = <String?, int>{};
      for (final r in await (select(
        oshiRecords,
      )..where((o) => o.pitId.equals(pitId) & o.deletedAt.isNull())).get()) {
        out[r.groupId] = (out[r.groupId] ?? 0) + 1;
      }
      return out;
    });
  }

  /// 新增（[id] 為 null）或編輯一筆推活紀錄；回傳紀錄 id。
  ///
  /// - [images] 至少一張，否則丟 [ArgumentError]（D-057）。
  /// - [date] 只取年月日（存當天 00:00）。
  /// - [groupId] 必須是同一個坑、未刪除的推活分組，否則丟 [ArgumentError]；null＝不分組。
  /// - 標題／描述 trim 後空字串存成 null。
  /// - 編輯會更新 updatedAt（推活圖片與 tag 隨紀錄文件同步）。
  Future<String> saveOshiRecord({
    String? id,
    required String pitId,
    required DateTime date,
    String? groupId,
    String? title,
    String? description,
    required List<NewImage> images,
    List<String> tagIds = const [],
  }) {
    if (images.isEmpty) {
      throw ArgumentError.value(images, 'images', '推活紀錄至少要有一張圖');
    }
    String? clean(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    final day = DateTime(date.year, date.month, date.day);
    return transaction(() async {
      if (groupId != null) {
        final g =
            await (select(officialGroups)..where(
                  (x) =>
                      x.id.equals(groupId) &
                      x.pitId.equals(pitId) &
                      x.kind.equals('oshi') &
                      x.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (g == null) {
          throw ArgumentError.value(groupId, 'groupId', '不是這個坑的推活分組');
        }
      }
      String recordId;
      if (id == null) {
        final row = await into(oshiRecords).insertReturning(
          OshiRecordsCompanion.insert(
            pitId: pitId,
            date: day,
            groupId: Value(groupId),
            title: Value(clean(title)),
            description: Value(clean(description)),
          ),
        );
        recordId = row.id;
      } else {
        recordId = id;
        await (update(oshiRecords)..where((o) => o.id.equals(id))).write(
          OshiRecordsCompanion(
            date: Value(day),
            groupId: Value(groupId),
            title: Value(clean(title)),
            description: Value(clean(description)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await replaceEntityImages(OwnerType.oshi, recordId, images);
      await setTags(TagTarget.oshi, recordId, tagIds);
      return recordId;
    });
  }

  /// 軟刪除（同步用）。圖片列與 tag 關聯保留（跟腦洞／草稿一樣），統計與查詢都會排除。
  Future<void> deleteOshiRecords(Iterable<String> ids) {
    final now = DateTime.now();
    return (update(oshiRecords)..where((o) => o.id.isIn(ids))).write(
      OshiRecordsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// 確保這個坑有預設的推活分組（線下照片、遊戲截圖、對話記錄）。
  /// 只在這個坑**從沒有過**推活分組時才建立（使用者刪光後不會補回來）。
  /// 遷移與 [AppDatabase.createPit] 已處理；從舊版 App 同步進來的坑沒有推活分組，
  /// 進推活頁時呼叫一次即可（便宜，可重複呼叫）。
  Future<void> ensureOshiGroups(String pitId) =>
      seedOshiGroups(pitId, deterministic: true);
}
