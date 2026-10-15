import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'batch_tag_queries.dart' show TagCoverage, TagCoverageEntry;
import 'database.dart';
import 'entity_queries.dart' show watchAssembled;

/// 推活多選（D-079）用的純新增查詢。批次分組／刪除在資料層的正式 API
/// （`setOshiGroupBatch`／`deleteOshiBatch`）合併進來之前，先用這裡的版本；
/// 整合時把 `lib/ui/oshi/oshi_select_actions.dart` 換成呼叫正式 API 即可，這個檔案可刪。
extension OshiExtraQueries on AppDatabase {
  /// 把 [ids] 的推活紀錄一次移到 [groupId]（null＝不分組），同一個 transaction。
  /// [groupId] 必須是紀錄所在坑、未刪除的推活分組，否則丟 [ArgumentError] 並回滾。
  /// 只有分組真的有變的紀錄才更新 updatedAt。
  Future<void> oshiSetGroupLoop(Iterable<String> ids, String? groupId) {
    final idList = ids.toSet().toList();
    if (idList.isEmpty) return Future.value();
    return transaction(() async {
      final rows = await (select(
        oshiRecords,
      )..where((o) => o.id.isIn(idList) & o.deletedAt.isNull())).get();
      if (groupId != null) {
        final pits = rows.map((r) => r.pitId).toSet();
        final g =
            await (select(officialGroups)..where(
                  (x) =>
                      x.id.equals(groupId) &
                      x.kind.equals('oshi') &
                      x.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (g == null || pits.any((p) => p != g.pitId)) {
          throw ArgumentError.value(groupId, 'groupId', '不是這些紀錄所在坑的推活分組');
        }
      }
      final now = DateTime.now();
      for (final r in rows) {
        if (r.groupId == groupId) continue;
        await (update(oshiRecords)..where((o) => o.id.equals(r.id))).write(
          OshiRecordsCompanion(groupId: Value(groupId), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<List<OshiRecord>> _oshiRows(Iterable<String> ids) => (select(
    oshiRecords,
  )..where((o) => o.id.isIn(ids.toList()) & o.deletedAt.isNull())).get();

  /// 坑內所有 tag 在選取的推活紀錄上的三種狀態（同 [tagCoverage]，對象是推活）。
  Future<List<TagCoverageEntry>> oshiTagCoverage(Iterable<String> ids) async {
    final rows = await _oshiRows(ids);
    if (rows.isEmpty) return const [];
    final pitId = rows.first.pitId;
    final total = rows.length;
    final tagList =
        await (select(tags)
              ..where((t) => t.pitId.equals(pitId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    final links =
        await (select(tagLinks)..where(
              (l) =>
                  l.targetType.equalsValue(TagTarget.oshi) &
                  l.targetId.isIn(rows.map((r) => r.id).toList()),
            ))
            .get();
    final counts = <String, int>{};
    for (final l in links) {
      counts[l.tagId] = (counts[l.tagId] ?? 0) + 1;
    }
    return [
      for (final t in tagList)
        TagCoverageEntry(
          tag: t,
          count: counts[t.id] ?? 0,
          total: total,
          coverage: (counts[t.id] ?? 0) == 0
              ? TagCoverage.none
              : (counts[t.id]! >= total ? TagCoverage.all : TagCoverage.some),
        ),
    ];
  }

  Stream<List<TagCoverageEntry>> watchOshiTagCoverage(Iterable<String> ids) {
    final idList = ids.toList();
    return watchAssembled(this, {
      tags,
      tagLinks,
      oshiRecords,
    }, () => oshiTagCoverage(idList));
  }

  /// 套用 sheet 裡的所有 tag 變更（同 [applyBatchTags]，對象是推活），同一個 transaction。
  /// 回傳新建 tag 的 id；實際有變動的紀錄才更新 updatedAt。
  Future<List<String>> applyOshiBatchTags(
    Iterable<String> ids, {
    Iterable<String> addTagIds = const [],
    Iterable<String> removeTagIds = const [],
    Iterable<String> newTagNames = const [],
  }) {
    return transaction(() async {
      final rows = await _oshiRows(ids);
      if (rows.isEmpty) return <String>[];
      final pitId = rows.first.pitId;
      if (rows.any((r) => r.pitId != pitId)) {
        throw ArgumentError('選取的紀錄不在同一個坑');
      }
      final created = <String>[];
      for (final raw in newTagNames) {
        final name = raw.trim().replaceFirst(RegExp(r'^#'), '');
        if (name.isEmpty) continue;
        created.add(await createTag(pitId, name));
      }
      final add = {...addTagIds, ...created};
      final remove = removeTagIds.toSet()..removeAll(add);
      final valid =
          (await (select(tags)..where(
                    (t) =>
                        t.id.isIn([...add, ...remove]) &
                        t.pitId.equals(pitId) &
                        t.deletedAt.isNull(),
                  ))
                  .get())
              .map((t) => t.id)
              .toSet();
      for (final t in [...add, ...remove]) {
        if (!valid.contains(t)) {
          throw ArgumentError.value(t, 'tagId', 'tag 不屬於這個坑');
        }
      }
      final existing =
          await (select(tagLinks)..where(
                (l) =>
                    l.targetType.equalsValue(TagTarget.oshi) &
                    l.targetId.isIn(rows.map((r) => r.id).toList()),
              ))
              .get();
      final has = <String, Set<String>>{};
      for (final l in existing) {
        has.putIfAbsent(l.targetId, () => {}).add(l.tagId);
      }
      final changed = <String>{};
      for (final r in rows) {
        final cur = has[r.id] ?? <String>{};
        for (final t in remove) {
          if (cur.contains(t)) {
            await (delete(tagLinks)..where(
                  (l) =>
                      l.tagId.equals(t) &
                      l.targetType.equalsValue(TagTarget.oshi) &
                      l.targetId.equals(r.id),
                ))
                .go();
            changed.add(r.id);
          }
        }
        for (final t in add) {
          if (!cur.contains(t)) {
            await into(tagLinks).insert(
              TagLinksCompanion.insert(
                tagId: t,
                targetType: TagTarget.oshi,
                targetId: r.id,
              ),
            );
            changed.add(r.id);
          }
        }
      }
      if (changed.isNotEmpty) {
        await (update(oshiRecords)..where((o) => o.id.isIn(changed))).write(
          OshiRecordsCompanion(updatedAt: Value(DateTime.now())),
        );
      }
      return created;
    });
  }
}
