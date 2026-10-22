import 'package:drift/drift.dart';

import 'database.dart';
import 'junk_queries.dart';
import 'media.dart';
import 'sensitive_queries.dart' show SensitiveQueries;
import 'entity_queries.dart' show watchAssembled;
import 'tables.dart' show uuid;

/// 同人圖列表篩選用的假出處 id：代表「無出處」（沒有選出處的同人圖）。
const fanArtNoSourceFilter = '__nosource__';

/// 匯入後待寫入資料庫的圖片。
class NewImage {
  const NewImage({
    required this.file,
    this.width = 0,
    this.height = 0,
    this.kind = MediaKind.image,
    this.durationMs,
    this.posterFile,
    this.sensitive = false,
  });
  final String file; // 相對於圖片資料夾的檔名
  final int width;
  final int height;

  /// 媒體種類（D-080）；`ImageStore.import` 會依內容判斷。
  final MediaKind kind;

  /// 影片長度（毫秒）；只有影片。匯入後由 UI 探測再補上。
  final int? durationMs;

  /// 影片第一格截圖的檔名；尚未產生時為 null。
  final String? posterFile;

  /// 敏感內容標記（D-104）；新增／編輯表單裡逐張標記，存進資料列的 `sensitive`。
  final bool sensitive;

  NewImage copyWith({
    int? width,
    int? height,
    MediaKind? kind,
    int? durationMs,
    String? posterFile,
    bool? sensitive,
  }) => NewImage(
    file: file,
    width: width ?? this.width,
    height: height ?? this.height,
    kind: kind ?? this.kind,
    durationMs: durationMs ?? this.durationMs,
    posterFile: posterFile ?? this.posterFile,
    sensitive: sensitive ?? this.sensitive,
  );
}

/// 標籤與使用次數（TagManage 顯示）。
class TagUsage {
  const TagUsage(this.tag, this.count);
  final Tag tag;
  final int count;
}

/// 官方圖冊、同人圖、tag、封面相關查詢（HANDOFF 3.2、3.3、3.7）。
extension AlbumQueries on AppDatabase {
  // ---- 分組 ----
  /// [kind]：`official`（官方圖冊）、`fan`（好看同人圖）或 `oshi`（推活，D-057）。
  Stream<List<OfficialGroup>> watchGroups(
    String pitId, {
    String kind = 'official',
  }) {
    return (select(officialGroups)
          ..where(
            (g) =>
                g.pitId.equals(pitId) &
                g.kind.equals(kind) &
                g.deletedAt.isNull(),
          )
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .watch();
  }

  Future<void> addGroup(
    String pitId,
    String name, {
    String kind = 'official',
  }) async {
    final last =
        await (select(officialGroups)
              ..where(
                (g) =>
                    g.pitId.equals(pitId) &
                    g.kind.equals(kind) &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => OrderingTerm.desc(g.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    await into(officialGroups).insert(
      OfficialGroupsCompanion.insert(
        pitId: pitId,
        kind: Value(kind),
        name: name,
        sortOrder: Value((last?.sortOrder ?? -1) + 1),
      ),
    );
  }

  Future<void> renameGroup(String id, String name) {
    return (update(officialGroups)..where((g) => g.id.equals(id))).write(
      OfficialGroupsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 刪除分組；組內圖片改歸入剩下的第一個分組。官方圖冊／好看同人圖至少要保留一個分組。
  /// 推活（kind=oshi）的分組是選填的：可以刪光，組內紀錄變成「沒有分組」（groupId = null）。
  Future<bool> deleteGroup(String id) {
    return transaction(() async {
      final g = await (select(
        officialGroups,
      )..where((x) => x.id.equals(id))).getSingle();
      if (g.kind == 'oshi') {
        final now = DateTime.now();
        await (update(oshiRecords)..where((r) => r.groupId.equals(id))).write(
          OshiRecordsCompanion(
            groupId: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await (update(officialGroups)..where((x) => x.id.equals(id))).write(
          OfficialGroupsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
        return true;
      }
      final rest =
          await (select(officialGroups)
                ..where(
                  (x) =>
                      x.pitId.equals(g.pitId) &
                      x.kind.equals(g.kind) &
                      x.deletedAt.isNull() &
                      x.id.equals(id).not(),
                )
                ..orderBy([(x) => OrderingTerm.asc(x.sortOrder)]))
              .get();
      if (rest.isEmpty) return false;
      if (g.kind == 'fan') {
        await (update(fanArts)..where((i) => i.groupId.equals(id))).write(
          FanArtsCompanion(groupId: Value(rest.first.id)),
        );
      } else {
        await (update(officialImages)..where((i) => i.groupId.equals(id)))
            .write(OfficialImagesCompanion(groupId: Value(rest.first.id)));
      }
      final now = DateTime.now();
      await (update(officialGroups)..where((x) => x.id.equals(id))).write(
        OfficialGroupsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      return true;
    });
  }

  Future<void> reorderGroups(List<String> orderedIds) {
    return batch((b) {
      for (var i = 0; i < orderedIds.length; i++) {
        b.update(
          officialGroups,
          OfficialGroupsCompanion(sortOrder: Value(i)),
          where: (g) => g.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ---- 官方圖 ----
  /// [tagId]：只列出有這個 tag 的官方圖（D-089，點 tag 回到官方圖冊的篩選；同 [watchFanArts]）。
  Stream<List<OfficialImage>> watchOfficial(
    String pitId, {
    String? groupId,
    String? tagId,
  }) {
    return (select(officialImages)
          ..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.deletedAt.isNull() &
                i.hidden.equals(false) &
                (groupId == null
                    ? const Constant(true)
                    : i.groupId.equals(groupId)) &
                (tagId == null
                    ? const Constant(true)
                    : i.id.isInQuery(
                        selectOnly(tagLinks)
                          ..addColumns([tagLinks.targetId])
                          ..where(
                            tagLinks.tagId.equals(tagId) &
                                tagLinks.targetType.equalsValue(
                                  TagTarget.official,
                                ),
                          ),
                      )),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .watch();
  }

  /// [tagIds]：同一批圖都掛上這些 tag（分享進來／批次新增，D-059；D-060 起官方圖可以有 tag）。
  Future<void> addOfficial(
    String pitId,
    String groupId,
    List<NewImage> images, {
    List<String> tagIds = const [],
  }) {
    return transaction(() async {
      for (final im in images) {
        final row = _newOfficial(pitId, groupId, im);
        await into(officialImages).insert(row);
        if (tagIds.isNotEmpty) {
          await setTags(TagTarget.official, row.id.value, tagIds);
        }
      }
    });
  }

  /// 整組替換一張官方圖的 tag，並更新 updatedAt（tag 隨官方圖文件同步）。
  Future<void> setOfficialTags(String id, List<String> tagIds) {
    return transaction(() async {
      await setTags(TagTarget.official, id, tagIds);
      await (update(officialImages)..where((i) => i.id.equals(id))).write(
        OfficialImagesCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  /// 編輯一張官方圖（D-089）：分組與 tag 一次存；tag 隨官方圖文件同步，所以一併更新 updatedAt。
  /// [sensitive]（D-104）：null＝不變；標成敏感時若這張是封面，封面改用別張（見 [setSensitive]）。
  Future<void> updateOfficial(
    String id, {
    required String groupId,
    required List<String> tagIds,
    bool? sensitive,
  }) {
    return transaction(() async {
      await (update(officialImages)..where((i) => i.id.equals(id))).write(
        OfficialImagesCompanion(
          groupId: Value(groupId),
          sensitive: sensitive == null
              ? const Value.absent()
              : Value(sensitive),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await setTags(TagTarget.official, id, tagIds);
      if (sensitive == true) await dropCoversOfSensitiveRow(officialImages, id);
    });
  }

  /// 新增一張官方圖：imageKey 先設成自己的 id（之後移動時跟著走）。
  OfficialImagesCompanion _newOfficial(
    String pitId,
    String groupId,
    NewImage im,
  ) {
    final id = uuid.v4();
    return OfficialImagesCompanion.insert(
      id: Value(id),
      pitId: pitId,
      groupId: groupId,
      imageFile: im.file,
      width: Value(im.width),
      height: Value(im.height),
      kind: Value(im.kind),
      durationMs: Value(im.durationMs),
      posterFile: Value(im.posterFile),
      sensitive: Value(im.sensitive),
      imageKey: Value(id),
    );
  }

  Future<void> setOfficialGroup(String id, String groupId) {
    return (update(officialImages)..where((i) => i.id.equals(id))).write(
      OfficialImagesCompanion(
        groupId: Value(groupId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteOfficial(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await deleteAlbumImageRows(ids, now);
      await _clearCoverIn(ids);
    });
  }

  /// 被刪除的圖若是封面，一併清掉封面。
  Future<void> _clearCoverIn(Iterable<String> ids) async {
    await (update(pits)..where((p) => p.coverImageId.isIn(ids))).write(
      const PitsCompanion(coverImageId: Value(null)),
    );
    await (update(pits)..where((p) => p.officialCoverId.isIn(ids))).write(
      const PitsCompanion(officialCoverId: Value(null)),
    );
    await (update(pits)..where((p) => p.fanArtCoverId.isIn(ids))).write(
      const PitsCompanion(fanArtCoverId: Value(null)),
    );
  }

  // ---- 好看同人圖 ----
  /// [tagId]：只列出有這個 tag 的同人圖（D-043，點 tag 回到列表的篩選）。
  Stream<List<FanArt>> watchFanArts(
    String pitId, {
    String? groupId,
    String? tagId,
  }) {
    final q = select(fanArts)
      ..where(
        (i) =>
            i.pitId.equals(pitId) &
            i.deletedAt.isNull() &
            i.hidden.equals(false) &
            (groupId == null
                ? const Constant(true)
                : groupId == fanArtNoSourceFilter
                ? i.groupId.isNull()
                : i.groupId.equals(groupId)) &
            (tagId == null
                ? const Constant(true)
                : i.id.isInQuery(
                    selectOnly(tagLinks)
                      ..addColumns([tagLinks.targetId])
                      ..where(
                        tagLinks.tagId.equals(tagId) &
                            tagLinks.targetType.equalsValue(TagTarget.fanArt),
                      ),
                  )),
      )
      ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]);
    return q.watch();
  }

  Future<void> addFanArts(
    String pitId,
    List<NewImage> images, {
    required String author,
    String? groupId,
    List<String> tagIds = const [],
  }) {
    return transaction(() async {
      for (final im in images) {
        final id = uuid.v4();
        final row = await into(fanArts).insertReturning(
          FanArtsCompanion.insert(
            id: Value(id),
            imageKey: Value(id),
            pitId: pitId,
            imageFile: im.file,
            width: Value(im.width),
            height: Value(im.height),
            kind: Value(im.kind),
            durationMs: Value(im.durationMs),
            posterFile: Value(im.posterFile),
            sensitive: Value(im.sensitive),
            author: Value(author),
            groupId: Value(groupId),
          ),
        );
        await setTags(TagTarget.fanArt, row.id, tagIds);
      }
    });
  }

  /// [sensitive]（D-104）：null＝不變；標成敏感時若這張是封面，封面改用別張（見 [setSensitive]）。
  Future<void> updateFanArt(
    String id, {
    required String author,
    String? groupId,
    required List<String> tagIds,
    bool? sensitive,
  }) {
    return transaction(() async {
      await (update(fanArts)..where((i) => i.id.equals(id))).write(
        FanArtsCompanion(
          author: Value(author),
          groupId: Value(groupId),
          sensitive: sensitive == null
              ? const Value.absent()
              : Value(sensitive),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await setTags(TagTarget.fanArt, id, tagIds);
      if (sensitive == true) await dropCoversOfSensitiveRow(fanArts, id);
    });
  }

  Future<void> deleteFanArts(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await deleteAlbumImageRows(ids, now);
      await _clearCoverIn(ids);
    });
  }

  // ---- Tag（按坑獨立；角色也是 tag）----
  Stream<List<Tag>> watchTags(String pitId) {
    return (select(tags)
          ..where((t) => t.pitId.equals(pitId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// 使用次數只算還存在的項目（已刪除、被移走而隱藏的官方圖／同人圖不算）；
  /// 含官方圖（D-060）與推活紀錄（D-057）。
  /// [byUsage]：true＝常用的在前（次數相同按名稱）；false＝按名稱。
  Stream<List<TagUsage>> watchTagUsage(String pitId, {bool byUsage = false}) {
    return watchAssembled(this, {
      tags,
      tagLinks,
      fanArts,
      officialImages,
      oshiRecords,
      ideas,
      drafts,
      pieces,
      goals,
    }, () => loadTagUsage(pitId, byUsage: byUsage));
  }

  /// [watchTagUsage] 的一次性版本（全坑搜尋逐坑載入用）。
  Future<List<TagUsage>> loadTagUsage(
    String pitId, {
    bool byUsage = false,
  }) async {
    final list =
        await (select(tags)
              ..where((t) => t.pitId.equals(pitId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    final counts = await _tagCounts(list.map((t) => t.id).toList());
    final out = [for (final t in list) TagUsage(t, counts[t.id] ?? 0)];
    if (byUsage) {
      out.sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.tag.name.compareTo(b.tag.name);
      });
    }
    return out;
  }

  Future<Map<String, int>> _tagCounts(List<String> tagIds) async {
    if (tagIds.isEmpty) return {};
    final rows = await (select(
      tagLinks,
    )..where((l) => l.tagId.isIn(tagIds))).get();

    Future<Set<String>> live(TagTarget type) async {
      final ids = [
        for (final r in rows)
          if (r.targetType == type) r.targetId,
      ];
      if (ids.isEmpty) return {};
      final found = switch (type) {
        TagTarget.fanArt =>
          (await (select(fanArts)..where(
                    (x) =>
                        x.id.isIn(ids) &
                        x.deletedAt.isNull() &
                        x.hidden.equals(false),
                  ))
                  .get())
              .map((x) => x.id),
        TagTarget.official =>
          (await (select(officialImages)..where(
                    (x) =>
                        x.id.isIn(ids) &
                        x.deletedAt.isNull() &
                        x.hidden.equals(false),
                  ))
                  .get())
              .map((x) => x.id),
        TagTarget.oshi =>
          (await (select(
            oshiRecords,
          )..where((x) => x.id.isIn(ids) & x.deletedAt.isNull())).get()).map(
            (x) => x.id,
          ),
        TagTarget.idea =>
          (await (select(
            ideas,
          )..where((x) => x.id.isIn(ids) & x.deletedAt.isNull())).get()).map(
            (x) => x.id,
          ),
        TagTarget.draft =>
          (await (select(
            drafts,
          )..where((x) => x.id.isIn(ids) & x.deletedAt.isNull())).get()).map(
            (x) => x.id,
          ),
        TagTarget.piece =>
          (await (select(
            pieces,
          )..where((x) => x.id.isIn(ids) & x.deletedAt.isNull())).get()).map(
            (x) => x.id,
          ),
        TagTarget.goal =>
          (await (select(
            goals,
          )..where((x) => x.id.isIn(ids) & x.deletedAt.isNull())).get()).map(
            (x) => x.id,
          ),
      };
      return found.toSet();
    }

    final alive = {for (final t in TagTarget.values) t: await live(t)};
    final out = <String, int>{};
    for (final r in rows) {
      if (alive[r.targetType]!.contains(r.targetId)) {
        out[r.tagId] = (out[r.tagId] ?? 0) + 1;
      }
    }
    return out;
  }

  /// 已存在同名 tag 則回傳既有的 id。
  Future<String> createTag(String pitId, String name) async {
    final existing =
        await (select(tags)..where(
              (t) =>
                  t.pitId.equals(pitId) &
                  t.name.equals(name) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final row = await into(tags)
        .insertReturning(TagsCompanion.insert(pitId: pitId, name: name));
    return row.id;
  }

  Future<void> renameTag(String id, String name) {
    return (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteTag(String id) {
    return transaction(() async {
      await (delete(tagLinks)..where((l) => l.tagId.equals(id))).go();
      final now = DateTime.now();
      await (update(tags)..where((t) => t.id.equals(id))).write(
        TagsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  Stream<List<String>> watchTagIds(TagTarget type, String targetId) {
    return (select(tagLinks)..where(
          (l) => l.targetType.equalsValue(type) & l.targetId.equals(targetId),
        ))
        .watch()
        .map((rows) => rows.map((r) => r.tagId).toList());
  }

  Future<void> setTags(TagTarget type, String targetId, List<String> tagIds) {
    return transaction(() async {
      await (delete(tagLinks)..where(
            (l) => l.targetType.equalsValue(type) & l.targetId.equals(targetId),
          ))
          .go();
      for (final id in tagIds) {
        await into(tagLinks).insert(
          TagLinksCompanion.insert(
            tagId: id,
            targetType: type,
            targetId: targetId,
          ),
        );
      }
    });
  }

  // ---- 封面 ----
  Future<void> setCover(String pitId, String? imageId) {
    return (update(pits)..where((p) => p.id.equals(pitId))).write(
      PitsCompanion(
        coverImageId: Value(imageId),
        // 現坑的封面從坑內的圖挑；淺坑自己選的封面檔（Pits.coverFile）不能再蓋過它。
        coverFile: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 官方圖冊／好看同人圖「這一格」的封面（預覽頁的「設為封面」）。
  Future<void> setOfficialCover(String pitId, String? imageId) {
    return (update(pits)..where((p) => p.id.equals(pitId))).write(
      PitsCompanion(
        officialCoverId: Value(imageId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFanArtCover(String pitId, String? imageId) {
    return (update(pits)..where((p) => p.id.equals(pitId))).write(
      PitsCompanion(
        fanArtCoverId: Value(imageId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 以圖片 id 找出封面用的檔名（官方圖、同人圖或腦洞／草稿／成圖的圖）。找不到回傳 null；
  /// 影片回傳它的截圖（D-080，還沒有截圖＝null）。
  Future<String?> imageFileOf(String imageId) async {
    final o =
        await (select(officialImages)..where(
              (i) =>
                  i.id.equals(imageId) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false),
            ))
            .getSingleOrNull();
    if (o != null) return staticFileOf(o.kind, o.imageFile, o.posterFile);
    final f =
        await (select(fanArts)..where(
              (i) =>
                  i.id.equals(imageId) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false),
            ))
            .getSingleOrNull();
    if (f != null) return staticFileOf(f.kind, f.imageFile, f.posterFile);
    final e =
        await (select(entityImages)
              ..where((x) => x.id.equals(imageId) & x.deletedAt.isNull()))
            .getSingleOrNull();
    return e == null ? null : staticFileOf(e.kind, e.imageFile, e.posterFile);
  }
}

/// 坑內頁各格的封面（檔名；需要靜態圖，所以影片給的是它的截圖 poster）。
///
/// 每格優先用使用者在該格長按「選擇封面」挑的圖（[AppDatabase.setCellCover]），
/// 挑的圖不存在了（已刪除、移到別格或別的坑）就退回該格最新的一張；格子是空的或只有還沒有截圖的影片＝null（顯示 icon）。
/// - 官方圖冊／好看同人圖：最新＝更新時間最晚的一張。
/// - 草稿／腦洞：最新一筆（日期最晚）的第一張圖。
/// - 成圖（D-058）：最新一張成圖（完成日期最晚）的第一張圖。
/// - 推活（批次 10）：最新一筆紀錄（日期最晚）的第一張圖。
class CellCovers {
  const CellCovers({
    this.official,
    this.fanArt,
    this.draft,
    this.idea,
    this.piece,
    this.oshi,
  });
  final String? official;
  final String? fanArt;
  final String? draft;
  final String? idea;
  final String? piece;
  final String? oshi;
}

/// 格子的種類字串（`setCellCover`／`coverCandidatesProvider` 的 kind）。
const cellKinds = ['official', 'fan', 'draft', 'idea', 'piece', 'oshi'];

extension CellCoverQueries on AppDatabase {
  /// 各格目前顯示的封面，見 [CellCovers]。
  ///
  /// [excludeSensitive]（D-104，總開關開著時傳 true）：這個坑開了敏感內容時，標記為敏感的圖不當封面
  /// （不管是使用者選的或自動挑的最新一張）。
  Stream<CellCovers> watchCellCovers(
    String pitId, {
    bool excludeSensitive = false,
  }) {
    return watchAssembled(
      this,
      {
        pits,
        officialImages,
        fanArts,
        drafts,
        ideas,
        pieces,
        oshiRecords,
        entityImages,
      },
      () async {
        final pit = await (select(
          pits,
        )..where((p) => p.id.equals(pitId))).getSingleOrNull();
        final skip = excludeSensitive && (pit?.sensitiveEnabled ?? false);

        // 官方圖冊／好看同人圖：列 id 為準。
        Future<String?> album({
          required String? chosenId,
          required Future<List<String?>> Function() latest,
          required Future<String?> Function(String id) chosen,
        }) async {
          if (chosenId != null) {
            final f = await chosen(chosenId);
            if (f != null) return f;
          }
          for (final s in await latest()) {
            if (s != null) return s;
          }
          return null;
        }

        final official = await album(
          chosenId: pit?.officialCoverId,
          chosen: (id) async {
            final r =
                await (select(officialImages)..where(
                      (i) =>
                          i.id.equals(id) &
                          i.pitId.equals(pitId) &
                          i.deletedAt.isNull() &
                          i.hidden.equals(false) &
                          (i.sensitive.equals(false) | Constant<bool>(!skip)),
                    ))
                    .getSingleOrNull();
            return r == null
                ? null
                : staticFileOf(r.kind, r.imageFile, r.posterFile);
          },
          latest: () async => [
            for (final r
                in await (select(officialImages)
                      ..where(
                        (i) =>
                            i.pitId.equals(pitId) &
                            i.deletedAt.isNull() &
                            i.hidden.equals(false) &
                            (i.sensitive.equals(false) | Constant<bool>(!skip)),
                      )
                      ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                    .get())
              staticFileOf(r.kind, r.imageFile, r.posterFile),
          ],
        );
        final fan = await album(
          chosenId: pit?.fanArtCoverId,
          chosen: (id) async {
            final r =
                await (select(fanArts)..where(
                      (i) =>
                          i.id.equals(id) &
                          i.pitId.equals(pitId) &
                          i.deletedAt.isNull() &
                          i.hidden.equals(false) &
                          (i.sensitive.equals(false) | Constant<bool>(!skip)),
                    ))
                    .getSingleOrNull();
            return r == null
                ? null
                : staticFileOf(r.kind, r.imageFile, r.posterFile);
          },
          latest: () async => [
            for (final r
                in await (select(fanArts)
                      ..where(
                        (i) =>
                            i.pitId.equals(pitId) &
                            i.deletedAt.isNull() &
                            i.hidden.equals(false) &
                            (i.sensitive.equals(false) | Constant<bool>(!skip)),
                      )
                      ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                    .get())
              staticFileOf(r.kind, r.imageFile, r.posterFile),
          ],
        );

        // 草稿／腦洞／成圖／推活：存的是圖片檔名（見 Pits.draftCoverFile 的說明）。
        Future<String?> entity(
          OwnerType type,
          List<String> ownerIds,
          String? chosenFile,
        ) async {
          if (chosenFile != null && ownerIds.isNotEmpty) {
            final rows =
                await (select(entityImages)..where(
                      (e) =>
                          e.ownerType.equalsValue(type) &
                          e.ownerId.isIn(ownerIds) &
                          e.imageFile.equals(chosenFile) &
                          e.deletedAt.isNull() &
                          (e.sensitive.equals(false) | Constant<bool>(!skip)),
                    ))
                    .get();
            for (final r in rows) {
              final s = staticFileOf(r.kind, r.imageFile, r.posterFile);
              if (s != null) return s;
            }
          }
          for (final id in ownerIds) {
            final rows =
                await (select(entityImages)
                      ..where(
                        (e) =>
                            e.ownerType.equalsValue(type) &
                            e.ownerId.equals(id) &
                            e.deletedAt.isNull() &
                            (e.sensitive.equals(false) | Constant<bool>(!skip)),
                      )
                      ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
                    .get();
            for (final r in rows) {
              final s = staticFileOf(r.kind, r.imageFile, r.posterFile);
              if (s != null) return s;
            }
          }
          return null;
        }

        return CellCovers(
          official: official,
          fanArt: fan,
          draft: await entity(
            OwnerType.draft,
            await _draftOwnerIds(pitId),
            pit?.draftCoverFile,
          ),
          idea: await entity(
            OwnerType.idea,
            await _ideaOwnerIds(pitId),
            pit?.ideaCoverFile,
          ),
          piece: await entity(
            OwnerType.piece,
            await _pieceOwnerIds(pitId),
            pit?.pieceCoverFile,
          ),
          oshi: await entity(
            OwnerType.oshi,
            await _oshiOwnerIds(pitId),
            pit?.oshiCoverFile,
          ),
        );
      },
    );
  }

  // 各格的擁有者 id，順序＝該格「最新在前」。
  Future<List<String>> _draftOwnerIds(String pitId) async => [
    for (final d
        in await (select(drafts)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([
                (d) => OrderingTerm.desc(d.date),
                (d) => OrderingTerm.desc(d.createdAt),
              ]))
            .get())
      d.id,
  ];

  Future<List<String>> _ideaOwnerIds(String pitId) async => [
    for (final d
        in await (select(ideas)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([
                (d) => OrderingTerm.desc(d.date),
                (d) => OrderingTerm.desc(d.createdAt),
              ]))
            .get())
      d.id,
  ];

  // 成圖格的封面＝最新一張成圖（完成日期最晚；D-058）。
  Future<List<String>> _pieceOwnerIds(String pitId) async => [
    for (final d
        in await (select(pieces)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([
                (d) => OrderingTerm.desc(d.finishedAt),
                (d) => OrderingTerm.desc(d.createdAt),
              ]))
            .get())
      d.id,
  ];

  Future<List<String>> _oshiOwnerIds(String pitId) async => [
    for (final d
        in await (select(oshiRecords)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([
                (d) => OrderingTerm.desc(d.date),
                (d) => OrderingTerm.desc(d.createdAt),
                (d) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
              ]))
            .get())
      d.id,
  ];

  /// 設定「這一格」在坑內頁顯示的封面（長按格子→選擇封面）。
  ///
  /// - [kind]：`official`／`fan`／`draft`／`idea`／`piece`／`oshi`（見 [cellKinds]），其他值丟 [ArgumentError]。
  /// - [imageId]：`coverCandidatesProvider((pitId, kind))` 給的候選圖 id；null＝清除（回到自動：該格最新一張）。
  ///   不是這個坑這一格裡的圖（含已刪除、被移走）丟 [ArgumentError]。
  /// - 官方圖冊／好看同人圖存圖片列 id（`Pits.officialCoverId`／`fanArtCoverId`，與預覽頁的「設為封面」是同一份）；
  ///   草稿／腦洞／成圖／推活存圖片**檔名**（`Pits.draftCoverFile` 等），因為這些圖片列的 id 各裝置不同。
  /// - 會更新坑的 updatedAt，所以跟著坑的文件同步。**不影響**主頁坑卡片的封面（`Pits.coverImageId`／[setCover]）。
  Future<void> setCellCover(String pitId, String kind, String? imageId) async {
    if (!cellKinds.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', '不是坑內頁的格子');
    }
    final now = Value(DateTime.now());
    PitsCompanion companion(String? value) => switch (kind) {
      'official' => PitsCompanion(
        officialCoverId: Value(value),
        updatedAt: now,
      ),
      'fan' => PitsCompanion(fanArtCoverId: Value(value), updatedAt: now),
      'draft' => PitsCompanion(draftCoverFile: Value(value), updatedAt: now),
      'idea' => PitsCompanion(ideaCoverFile: Value(value), updatedAt: now),
      'piece' => PitsCompanion(pieceCoverFile: Value(value), updatedAt: now),
      _ => PitsCompanion(oshiCoverFile: Value(value), updatedAt: now),
    };

    String? stored;
    if (imageId != null) {
      final cands = await _cellCandidates(pitId, kind);
      final hit = cands.where((c) => c.id == imageId).firstOrNull;
      if (hit == null) {
        throw ArgumentError.value(imageId, 'imageId', '不是這個坑這一格裡的圖');
      }
      stored = (kind == 'official' || kind == 'fan') ? hit.id : hit.file;
    }
    await (update(
      pits,
    )..where((p) => p.id.equals(pitId))).write(companion(stored));
  }

  /// 目前這一格有沒有指定封面（供 UI 在選擇封面頁標出「目前的封面」）：
  /// 回傳候選圖 id（官方／同人圖是列 id；其餘是第一個檔名相符的候選圖 id），沒有或已失效＝null。
  Future<String?> chosenCellCoverId(String pitId, String kind) async {
    final pit = await (select(
      pits,
    )..where((p) => p.id.equals(pitId))).getSingleOrNull();
    if (pit == null) return null;
    final cands = await _cellCandidates(pitId, kind);
    switch (kind) {
      case 'official':
        return cands.where((c) => c.id == pit.officialCoverId).firstOrNull?.id;
      case 'fan':
        return cands.where((c) => c.id == pit.fanArtCoverId).firstOrNull?.id;
      default:
        final file = switch (kind) {
          'draft' => pit.draftCoverFile,
          'idea' => pit.ideaCoverFile,
          'piece' => pit.pieceCoverFile,
          'oshi' => pit.oshiCoverFile,
          _ => throw ArgumentError.value(kind, 'kind', '不是坑內頁的格子'),
        };
        if (file == null) return null;
        return cands.where((c) => c.file == file).firstOrNull?.id;
    }
  }
}

/// 可選作封面的圖（坑封面、各格封面）。
class CoverCandidate {
  const CoverCandidate({
    required this.id,
    required this.file,
    required this.width,
    required this.height,
    this.groupId,
    this.kind = MediaKind.image,
    this.durationMs,
    this.poster,
  });
  final String id;
  final String file;
  final int width;
  final int height;

  /// 官方圖／同人圖所屬分組（選封面頁的分組篩選用）；其他種類為 null。
  final String? groupId;

  /// 媒體種類（D-080）；影片的縮圖用 [poster]（可能是 null＝還沒有截圖）。
  final MediaKind kind;
  final int? durationMs;
  final String? poster;

  /// 縮圖／封面用的靜態圖檔名；影片還沒有截圖時為 null。
  String? get staticFile => staticFileOf(kind, file, poster);
}

extension CoverCandidateQueries on AppDatabase {
  /// 列出「這一格」內的圖（長按坑內頁的格子進入選擇封面）。
  /// [kind]：`official`／`fan`／`draft`／`idea`／`piece`／`oshi`；
  /// null＝坑封面用的全部（官方、同人圖、草稿、腦洞、成圖；**不含推活**，推活不能當主頁的坑封面）。
  ///
  /// [excludeSensitive]（D-104，總開關開著時傳 true）：這個坑開了敏感內容時，不列出標記為敏感的圖。
  Stream<List<CoverCandidate>> watchCoverCandidates(
    String pitId, {
    String? kind,
    bool excludeSensitive = false,
  }) {
    return watchAssembled(
      this,
      {
        officialImages,
        fanArts,
        drafts,
        ideas,
        pieces,
        oshiRecords,
        entityImages,
      },
      () async {
        if (kind != null) {
          return _cellCandidates(
            pitId,
            kind,
            excludeSensitive: excludeSensitive,
          );
        }
        return [
          for (final k in const ['official', 'fan', 'draft', 'idea', 'piece'])
            ...await _cellCandidates(
              pitId,
              k,
              excludeSensitive: excludeSensitive,
            ),
        ];
      },
    );
  }

  Future<List<CoverCandidate>> _cellCandidates(
    String pitId,
    String kind, {
    bool excludeSensitive = false,
  }) async {
    final skip =
        excludeSensitive &&
        ((await (select(
                  pits,
                )..where((p) => p.id.equals(pitId))).getSingleOrNull())
                ?.sensitiveEnabled ??
            false);
    switch (kind) {
      case 'official':
        return [
          for (final r
              in await (select(officialImages)
                    ..where(
                      (i) =>
                          i.pitId.equals(pitId) &
                          i.deletedAt.isNull() &
                          i.hidden.equals(false) &
                          (i.sensitive.equals(false) | Constant<bool>(!skip)),
                    )
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                  .get())
            CoverCandidate(
              id: r.id,
              file: r.imageFile,
              width: r.width,
              height: r.height,
              groupId: r.groupId,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
            ),
        ];
      case 'fan':
        return [
          for (final r
              in await (select(fanArts)
                    ..where(
                      (i) =>
                          i.pitId.equals(pitId) &
                          i.deletedAt.isNull() &
                          i.hidden.equals(false) &
                          (i.sensitive.equals(false) | Constant<bool>(!skip)),
                    )
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                  .get())
            CoverCandidate(
              id: r.id,
              file: r.imageFile,
              width: r.width,
              height: r.height,
              groupId: r.groupId,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
            ),
        ];
    }

    final (type, owners) = switch (kind) {
      'draft' => (OwnerType.draft, await _draftCandidateOwners(pitId)),
      'idea' => (OwnerType.idea, await _ideaCandidateOwners(pitId)),
      'piece' => (OwnerType.piece, await _pieceCandidateOwners(pitId)),
      'oshi' => (OwnerType.oshi, await _oshiOwnerIds(pitId)),
      _ => throw ArgumentError.value(kind, 'kind', '不是坑內頁的格子'),
    };
    final out = <CoverCandidate>[];
    for (final id in owners) {
      for (final r
          in await (select(entityImages)
                ..where(
                  (e) =>
                      e.ownerType.equalsValue(type) &
                      e.ownerId.equals(id) &
                      e.deletedAt.isNull() &
                      (e.sensitive.equals(false) | Constant<bool>(!skip)),
                )
                ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
              .get()) {
        out.add(
          CoverCandidate(
            id: r.id,
            file: r.imageFile,
            width: r.width,
            height: r.height,
            kind: r.kind,
            durationMs: r.durationMs,
            poster: r.posterFile,
          ),
        );
      }
    }
    return out;
  }

  // 候選圖的擁有者順序沿用舊行為：更新時間新到舊。
  Future<List<String>> _draftCandidateOwners(String pitId) async => [
    for (final d
        in await (select(drafts)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
            .get())
      d.id,
  ];

  Future<List<String>> _ideaCandidateOwners(String pitId) async => [
    for (final d
        in await (select(ideas)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
            .get())
      d.id,
  ];

  Future<List<String>> _pieceCandidateOwners(String pitId) async => [
    for (final d
        in await (select(pieces)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
            .get())
      d.id,
  ];
}
