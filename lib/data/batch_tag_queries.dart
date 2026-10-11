import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart' show watchAssembled;
import 'junk_queries.dart' show AlbumCell;

/// 多選後「tag」sheet 的三種狀態（D-060）。
enum TagCoverage {
  /// 白底：選取的圖都沒有這個 tag。
  none,

  /// 虛線框＋橫線：部分有。
  some,

  /// 實色＋勾：選取的圖全部都有。
  all,
}

class TagCoverageEntry {
  const TagCoverageEntry({
    required this.tag,
    required this.coverage,
    required this.count,
    required this.total,
  });

  final Tag tag;
  final TagCoverage coverage;

  /// 選取的圖裡有這個 tag 的張數。
  final int count;

  /// 選取的張數。
  final int total;

  /// 點一下的行為：部分有／都沒有 → 全部加上；全部有 → 全部移除。
  bool get tapAdds => coverage != TagCoverage.all;
}

/// 官方圖冊、好看同人圖多選後的批量 tag（D-060）。
extension BatchTagQueries on AppDatabase {
  TagTarget _batchTarget(AlbumCell cell) => switch (cell) {
    AlbumCell.official => TagTarget.official,
    AlbumCell.fan => TagTarget.fanArt,
    AlbumCell.junk => throw ArgumentError.value(cell, 'cell', '雜物沒有 tag'),
  };

  /// 選取的圖（目前可見、未刪除）的 id → pitId。
  Future<Map<String, String>> _pitsOf(AlbumCell cell, List<String> ids) async {
    if (ids.isEmpty) return {};
    return switch (cell) {
      AlbumCell.official => {
        for (final r
            in await (select(officialImages)..where(
                  (i) =>
                      i.id.isIn(ids) &
                      i.deletedAt.isNull() &
                      i.hidden.equals(false),
                ))
                .get())
          r.id: r.pitId,
      },
      AlbumCell.fan => {
        for (final r
            in await (select(fanArts)..where(
                  (i) =>
                      i.id.isIn(ids) &
                      i.deletedAt.isNull() &
                      i.hidden.equals(false),
                ))
                .get())
          r.id: r.pitId,
      },
      AlbumCell.junk => throw ArgumentError.value(cell, 'cell', '雜物沒有 tag'),
    };
  }

  /// 選取的圖都在同一個坑才有意義（多選本來就在同一個坑的同一格）；回傳那個坑。
  Future<String?> _singlePit(Map<String, String> pitOf) async {
    final pits = pitOf.values.toSet();
    if (pits.length > 1) {
      throw ArgumentError('選取的圖不在同一個坑');
    }
    return pits.isEmpty ? null : pits.first;
  }

  /// 坑內**所有 tag**（依名稱排序）在選取的圖上的三種狀態。[ids] 是 [cell] 格的圖片列 id。
  /// 沒有選取任何有效的圖時回傳空清單。
  Future<List<TagCoverageEntry>> tagCoverage(
    AlbumCell cell,
    Iterable<String> ids,
  ) async {
    final target = _batchTarget(cell);
    final idList = ids.toSet().toList();
    final pitOf = await _pitsOf(cell, idList);
    final pitId = await _singlePit(pitOf);
    if (pitId == null) return const [];
    final total = pitOf.length;
    final tagList =
        await (select(tags)
              ..where((t) => t.pitId.equals(pitId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    final links =
        await (select(tagLinks)..where(
              (l) =>
                  l.targetType.equalsValue(target) &
                  l.targetId.isIn(pitOf.keys.toList()),
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

  /// [tagCoverage] 的即時版（sheet 裡新增 tag 後列表會自動更新）。
  Stream<List<TagCoverageEntry>> watchTagCoverage(
    AlbumCell cell,
    Iterable<String> ids,
  ) {
    final idList = ids.toList();
    return watchAssembled(
      this,
      {tags, tagLinks, officialImages, fanArts},
      () => tagCoverage(cell, idList),
    );
  }

  /// 一次套用 sheet 裡的所有變更（按「完成」時呼叫），全部在同一個 transaction：
  /// - [removeTagIds]：從**每一張**選取的圖移除；
  /// - [addTagIds]：加到**每一張**選取的圖；
  /// - [newTagNames]：在坑內新增 tag（同名已存在就重用）並加到每一張，回傳這些 tag 的 id（照傳入順序）。
  /// 同一個 tag 同時在 remove 和 add 時以 add 為準。
  /// 只有實際有變動的圖才會更新 updatedAt（tag 隨圖片文件同步）。
  /// tag 必須屬於選取的圖所在的坑，否則丟 [ArgumentError] 並回滾。
  Future<List<String>> applyBatchTags(
    AlbumCell cell,
    Iterable<String> ids, {
    Iterable<String> addTagIds = const [],
    Iterable<String> removeTagIds = const [],
    Iterable<String> newTagNames = const [],
  }) {
    final target = _batchTarget(cell);
    final idList = ids.toSet().toList();
    return transaction(() async {
      final pitOf = await _pitsOf(cell, idList);
      final pitId = await _singlePit(pitOf);
      if (pitId == null) return <String>[];

      final created = <String>[];
      for (final raw in newTagNames) {
        final name = raw.trim().replaceFirst(RegExp(r'^#'), '');
        if (name.isEmpty) continue;
        created.add(await createTag(pitId, name));
      }
      final add = {...addTagIds, ...created};
      final remove = removeTagIds.toSet()..removeAll(add);

      final valid = (await (select(tags)..where(
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
                    l.targetType.equalsValue(target) &
                    l.targetId.isIn(pitOf.keys.toList()),
              ))
              .get();
      final has = <String, Set<String>>{};
      for (final l in existing) {
        has.putIfAbsent(l.targetId, () => {}).add(l.tagId);
      }

      final changed = <String>{};
      for (final imageId in pitOf.keys) {
        final cur = has[imageId] ?? <String>{};
        for (final t in remove) {
          if (cur.contains(t)) {
            await (delete(tagLinks)..where(
                  (l) =>
                      l.tagId.equals(t) &
                      l.targetType.equalsValue(target) &
                      l.targetId.equals(imageId),
                ))
                .go();
            changed.add(imageId);
          }
        }
        for (final t in add) {
          if (!cur.contains(t)) {
            await into(tagLinks).insert(
              TagLinksCompanion.insert(
                tagId: t,
                targetType: target,
                targetId: imageId,
              ),
            );
            changed.add(imageId);
          }
        }
      }

      if (changed.isNotEmpty) {
        final now = DateTime.now();
        if (cell == AlbumCell.official) {
          await (update(officialImages)..where((i) => i.id.isIn(changed))).write(
            OfficialImagesCompanion(updatedAt: Value(now)),
          );
        } else {
          await (update(fanArts)..where((i) => i.id.isIn(changed))).write(
            FanArtsCompanion(updatedAt: Value(now)),
          );
        }
      }
      return created;
    });
  }
}
