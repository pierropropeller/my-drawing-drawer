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

/// 官方圖冊、好看同人圖多選後的批量 tag（D-060）；推活多選（D-079）、摸魚／成圖多選（D-095）用 `...For(TagTarget.oshi／draft／piece, ids)` 版本。
extension BatchTagQueries on AppDatabase {
  TagTarget _batchTarget(AlbumCell cell) => switch (cell) {
    AlbumCell.official => TagTarget.official,
    AlbumCell.fan => TagTarget.fanArt,
    AlbumCell.junk => throw ArgumentError.value(cell, 'cell', '雜物沒有 tag'),
  };

  /// 選取的項目（目前可見、未刪除）的 id → pitId。[ids] 是官方圖／同人圖的圖片列 id，或推活紀錄 id。
  Future<Map<String, String>> _pitsOf(
    TagTarget target,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    return switch (target) {
      TagTarget.official => {
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
      TagTarget.fanArt => {
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
      TagTarget.oshi => {
        for (final r in await (select(
          oshiRecords,
        )..where((i) => i.id.isIn(ids) & i.deletedAt.isNull())).get())
          r.id: r.pitId,
      },
      TagTarget.draft => {
        for (final r in await (select(
          drafts,
        )..where((i) => i.id.isIn(ids) & i.deletedAt.isNull())).get())
          r.id: r.pitId,
      },
      TagTarget.piece => {
        for (final r in await (select(
          pieces,
        )..where((i) => i.id.isIn(ids) & i.deletedAt.isNull())).get())
          r.id: r.pitId,
      },
      TagTarget.idea => {
        for (final r in await (select(
          ideas,
        )..where((i) => i.id.isIn(ids) & i.deletedAt.isNull())).get())
          r.id: r.pitId,
      },
      _ => throw ArgumentError.value(target, 'target', '這種項目不支援批量 tag'),
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
  ) async => tagCoverageFor(_batchTarget(cell), ids);

  /// [tagCoverage] 的通用版：[target] 可以是 `official`／`fanArt`／`oshi`／`draft`／`piece`（[ids] 是推活紀錄、摸魚、成圖的 id）。
  Future<List<TagCoverageEntry>> tagCoverageFor(
    TagTarget target,
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList();
    final pitOf = await _pitsOf(target, idList);
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
  ) => watchTagCoverageFor(_batchTarget(cell), ids);

  Stream<List<TagCoverageEntry>> watchTagCoverageFor(
    TagTarget target,
    Iterable<String> ids,
  ) {
    final idList = ids.toList();
    return watchAssembled(this, {
      tags,
      tagLinks,
      officialImages,
      fanArts,
      oshiRecords,
      drafts,
      pieces,
    }, () => tagCoverageFor(target, idList));
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
  }) async => applyBatchTagsFor(
    _batchTarget(cell),
    ids,
    addTagIds: addTagIds,
    removeTagIds: removeTagIds,
    newTagNames: newTagNames,
  );

  /// [applyBatchTags] 的通用版（D-079 推活多選的 tag sheet 用 `TagTarget.oshi`，[ids] 是推活紀錄 id）；
  /// 規則相同。推活紀錄有實際變動時更新該紀錄的 updatedAt（tag 隨紀錄文件同步）。
  Future<List<String>> applyBatchTagsFor(
    TagTarget target,
    Iterable<String> ids, {
    Iterable<String> addTagIds = const [],
    Iterable<String> removeTagIds = const [],
    Iterable<String> newTagNames = const [],
  }) {
    final idList = ids.toSet().toList();
    return transaction(() async {
      final pitOf = await _pitsOf(target, idList);
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
        switch (target) {
          case TagTarget.official:
            await (update(officialImages)..where((i) => i.id.isIn(changed)))
                .write(OfficialImagesCompanion(updatedAt: Value(now)));
          case TagTarget.oshi:
            await (update(oshiRecords)..where((i) => i.id.isIn(changed))).write(
              OshiRecordsCompanion(updatedAt: Value(now)),
            );
          case TagTarget.draft:
            await (update(drafts)..where((i) => i.id.isIn(changed))).write(
              DraftsCompanion(updatedAt: Value(now)),
            );
          case TagTarget.piece:
            await (update(pieces)..where((i) => i.id.isIn(changed))).write(
              PiecesCompanion(updatedAt: Value(now)),
            );
          case TagTarget.idea:
            await (update(ideas)..where((i) => i.id.isIn(changed))).write(
              IdeasCompanion(updatedAt: Value(now)),
            );
          default:
            await (update(fanArts)..where((i) => i.id.isIn(changed))).write(
              FanArtsCompanion(updatedAt: Value(now)),
            );
        }
      }
      return created;
    });
  }

  Future<Map<TagTarget, List<String>>> _groupRefs(Iterable<TagRef> refs) async {
    final out = <TagTarget, List<String>>{};
    for (final r in refs) {
      out.putIfAbsent(r.target, () => []).add(r.id);
    }
    return out;
  }

  /// 混合種類的批量 tag（坑內搜尋結果的多選，D-108）：坑內所有 tag 在選取項目上的三種狀態
  /// （同 [tagCoverageFor]，對象可以是多種項目）。選取的項目必須在同一個坑。
  Future<List<TagCoverageEntry>> tagCoverageMixed(Iterable<TagRef> refs) async {
    final groups = await _groupRefs(refs);
    final pitIds = <String>{};
    var total = 0;
    final counts = <String, int>{};
    for (final e in groups.entries) {
      final pitOf = await _pitsOf(e.key, e.value.toSet().toList());
      pitIds.addAll(pitOf.values);
      total += pitOf.length;
      if (pitOf.isEmpty) continue;
      final links =
          await (select(tagLinks)..where(
                (l) =>
                    l.targetType.equalsValue(e.key) &
                    l.targetId.isIn(pitOf.keys.toList()),
              ))
              .get();
      for (final l in links) {
        counts[l.tagId] = (counts[l.tagId] ?? 0) + 1;
      }
    }
    if (pitIds.length > 1) throw ArgumentError('選取的項目不在同一個坑');
    if (pitIds.isEmpty) return const [];
    final tagList =
        await (select(tags)
              ..where(
                (t) => t.pitId.equals(pitIds.first) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
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

  Stream<List<TagCoverageEntry>> watchTagCoverageMixed(Iterable<TagRef> refs) {
    final list = refs.toList();
    return watchAssembled(this, {
      tags,
      tagLinks,
      officialImages,
      fanArts,
      oshiRecords,
      drafts,
      pieces,
      ideas,
    }, () => tagCoverageMixed(list));
  }

  /// 套用 sheet 的變更到選取的每個項目（規則同 [applyBatchTagsFor]）；新 tag 只建立一次。
  Future<void> applyBatchTagsMixed(
    Iterable<TagRef> refs, {
    Iterable<String> addTagIds = const [],
    Iterable<String> removeTagIds = const [],
    Iterable<String> newTagNames = const [],
  }) {
    return transaction(() async {
      final groups = await _groupRefs(refs);
      String? pitId;
      for (final e in groups.entries) {
        final pitOf = await _pitsOf(e.key, e.value.toSet().toList());
        for (final p in pitOf.values) {
          if (pitId != null && pitId != p) {
            throw ArgumentError('選取的項目不在同一個坑');
          }
          pitId = p;
        }
      }
      if (pitId == null) return;
      final created = <String>[];
      for (final raw in newTagNames) {
        final name = raw.trim().replaceFirst(RegExp(r'^#'), '');
        if (name.isEmpty) continue;
        created.add(await createTag(pitId, name));
      }
      for (final e in groups.entries) {
        await applyBatchTagsFor(
          e.key,
          e.value,
          addTagIds: [...addTagIds, ...created],
          removeTagIds: removeTagIds,
        );
      }
    });
  }
}

/// 搜尋結果裡混合多選的一個項目（種類＋id）。字串形式 `種類:id` 讓它可以放進 [BatchTagSheet]
/// 的 `ids`（D-108：結果裡的成圖、官方圖、腦洞…可以一起補 tag）。
class TagRef {
  const TagRef(this.target, this.id);
  final TagTarget target;
  final String id;

  String get key => '${target.name}:$id';

  static TagRef parse(String key) {
    final i = key.indexOf(':');
    return TagRef(
      TagTarget.values.byName(key.substring(0, i)),
      key.substring(i + 1),
    );
  }
}
