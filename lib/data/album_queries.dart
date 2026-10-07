import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart' show watchAssembled;

/// 匯入後待寫入資料庫的圖片。
class NewImage {
  const NewImage({required this.file, this.width = 0, this.height = 0});
  final String file; // 相對於圖片資料夾的檔名
  final int width;
  final int height;
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
  /// [kind]：`official`（官方圖冊）或 `fan`（好看同人圖）。
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

  /// 刪除分組；組內圖片改歸入剩下的第一個分組。至少要保留一個分組。
  Future<bool> deleteGroup(String id) {
    return transaction(() async {
      final g = await (select(
        officialGroups,
      )..where((x) => x.id.equals(id))).getSingle();
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
  Stream<List<OfficialImage>> watchOfficial(String pitId, {String? groupId}) {
    return (select(officialImages)
          ..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.deletedAt.isNull() &
                (groupId == null
                    ? const Constant(true)
                    : i.groupId.equals(groupId)),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .watch();
  }

  Future<void> addOfficial(
    String pitId,
    String groupId,
    List<NewImage> images,
  ) {
    return batch((b) {
      b.insertAll(officialImages, [
        for (final im in images)
          OfficialImagesCompanion.insert(
            pitId: pitId,
            groupId: groupId,
            imageFile: im.file,
            width: Value(im.width),
            height: Value(im.height),
          ),
      ]);
    });
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
      await (update(officialImages)..where((i) => i.id.isIn(ids))).write(
        OfficialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
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
  Stream<List<FanArt>> watchFanArts(String pitId, {String? groupId}) {
    return (select(fanArts)
          ..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.deletedAt.isNull() &
                (groupId == null
                    ? const Constant(true)
                    : i.groupId.equals(groupId)),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .watch();
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
        final row = await into(fanArts).insertReturning(
          FanArtsCompanion.insert(
            pitId: pitId,
            imageFile: im.file,
            width: Value(im.width),
            height: Value(im.height),
            author: Value(author),
            groupId: Value(groupId),
          ),
        );
        await setTags(TagTarget.fanArt, row.id, tagIds);
      }
    });
  }

  Future<void> updateFanArt(
    String id, {
    required String author,
    String? groupId,
    required List<String> tagIds,
  }) {
    return transaction(() async {
      await (update(fanArts)..where((i) => i.id.equals(id))).write(
        FanArtsCompanion(
          author: Value(author),
          groupId: Value(groupId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await setTags(TagTarget.fanArt, id, tagIds);
    });
  }

  Future<void> deleteFanArts(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(fanArts)..where((i) => i.id.isIn(ids))).write(
        FanArtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
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

  Stream<List<TagUsage>> watchTagUsage(String pitId) {
    return watchTags(pitId).asyncMap((list) async {
      final out = <TagUsage>[];
      for (final t in list) {
        final n =
            await (selectOnly(tagLinks)
                  ..addColumns([tagLinks.targetId.count()])
                  ..where(tagLinks.tagId.equals(t.id)))
                .map((r) => r.read(tagLinks.targetId.count()) ?? 0)
                .getSingle();
        out.add(TagUsage(t, n));
      }
      return out;
    });
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

  /// 以圖片 id 找出檔名（官方圖或同人圖）。找不到回傳 null。
  Future<String?> imageFileOf(String imageId) async {
    final o =
        await (select(officialImages)
              ..where((i) => i.id.equals(imageId) & i.deletedAt.isNull()))
            .getSingleOrNull();
    if (o != null) return o.imageFile;
    final f =
        await (select(fanArts)
              ..where((i) => i.id.equals(imageId) & i.deletedAt.isNull()))
            .getSingleOrNull();
    if (f != null) return f.imageFile;
    final e =
        await (select(entityImages)
              ..where((x) => x.id.equals(imageId) & x.deletedAt.isNull()))
            .getSingleOrNull();
    return e?.imageFile;
  }
}

/// 坑內頁五格的封面（檔名）。
class CellCovers {
  const CellCovers({
    this.official,
    this.fanArt,
    this.draft,
    this.idea,
    this.piece,
  });
  final String? official;
  final String? fanArt;
  final String? draft;
  final String? idea;
  final String? piece;
}

extension CellCoverQueries on AppDatabase {
  /// 官方圖冊／好看同人圖：優先用「設為封面」指定的圖，沒有就用最新一張；
  /// 草稿／腦洞／成圖：最新一筆的第一張圖。
  Stream<CellCovers> watchCellCovers(String pitId) {
    return watchAssembled(
      this,
      {pits, officialImages, fanArts, drafts, ideas, pieces, entityImages},
      () async {
        final pit = await (select(
          pits,
        )..where((p) => p.id.equals(pitId))).getSingleOrNull();

        Future<String?> official() async {
          final set = pit?.officialCoverId;
          if (set != null) {
            final f =
                await (select(officialImages)
                      ..where((i) => i.id.equals(set) & i.deletedAt.isNull()))
                    .getSingleOrNull();
            if (f != null) return f.imageFile;
          }
          return (await (select(officialImages)
                    ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)])
                    ..limit(1))
                  .getSingleOrNull())
              ?.imageFile;
        }

        Future<String?> fan() async {
          final set = pit?.fanArtCoverId;
          if (set != null) {
            final f =
                await (select(fanArts)
                      ..where((i) => i.id.equals(set) & i.deletedAt.isNull()))
                    .getSingleOrNull();
            if (f != null) return f.imageFile;
          }
          return (await (select(fanArts)
                    ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)])
                    ..limit(1))
                  .getSingleOrNull())
              ?.imageFile;
        }

        Future<String?> firstImageOf(OwnerType type, List<String> ids) async {
          for (final id in ids) {
            final im =
                await (select(entityImages)
                      ..where(
                        (e) =>
                            e.ownerType.equalsValue(type) &
                            e.ownerId.equals(id),
                      )
                      ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)])
                      ..limit(1))
                    .getSingleOrNull();
            if (im != null) return im.imageFile;
          }
          return null;
        }

        final draftIds =
            (await (select(drafts)
                      ..where(
                        (d) => d.pitId.equals(pitId) & d.deletedAt.isNull(),
                      )
                      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                    .get())
                .map((d) => d.id)
                .toList();
        final ideaIds =
            (await (select(ideas)
                      ..where(
                        (d) => d.pitId.equals(pitId) & d.deletedAt.isNull(),
                      )
                      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                    .get())
                .map((d) => d.id)
                .toList();
        final pieceIds =
            (await (select(pieces)
                      ..where(
                        (d) => d.pitId.equals(pitId) & d.deletedAt.isNull(),
                      )
                      ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                    .get())
                .map((d) => d.id)
                .toList();

        return CellCovers(
          official: await official(),
          fanArt: await fan(),
          draft: await firstImageOf(OwnerType.draft, draftIds),
          idea: await firstImageOf(OwnerType.idea, ideaIds),
          piece: await firstImageOf(OwnerType.piece, pieceIds),
        );
      },
    );
  }
}

/// 可選作坑封面的圖。
class CoverCandidate {
  const CoverCandidate({
    required this.id,
    required this.file,
    required this.width,
    required this.height,
  });
  final String id;
  final String file;
  final int width;
  final int height;
}

extension CoverCandidateQueries on AppDatabase {
  /// 列出「這一格」內的圖（長按坑內頁的格子進入選擇封面）。
  /// [kind]：`official`／`fan`／`draft`／`idea`／`piece`；null＝全部。
  Stream<List<CoverCandidate>> watchCoverCandidates(
    String pitId, {
    String? kind,
  }) {
    return watchAssembled(
      this,
      {officialImages, fanArts, drafts, ideas, pieces, entityImages},
      () async {
        final out = <CoverCandidate>[];
        if (kind == null || kind == 'official') {
          for (final r
              in await (select(officialImages)
                    ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                  .get()) {
            out.add(
              CoverCandidate(
                id: r.id,
                file: r.imageFile,
                width: r.width,
                height: r.height,
              ),
            );
          }
        }
        if (kind == null || kind == 'fan') {
          for (final r
              in await (select(fanArts)
                    ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
                    ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
                  .get()) {
            out.add(
              CoverCandidate(
                id: r.id,
                file: r.imageFile,
                width: r.width,
                height: r.height,
              ),
            );
          }
        }
        Future<void> entity(
          String k,
          OwnerType type,
          List<String> ownerIds,
        ) async {
          if (kind != null && kind != k) return;
          for (final id in ownerIds) {
            for (final r
                in await (select(entityImages)
                      ..where(
                        (e) =>
                            e.ownerType.equalsValue(type) &
                            e.ownerId.equals(id),
                      )
                      ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
                    .get()) {
              out.add(
                CoverCandidate(
                  id: r.id,
                  file: r.imageFile,
                  width: r.width,
                  height: r.height,
                ),
              );
            }
          }
        }

        await entity(
          'draft',
          OwnerType.draft,
          (await (select(drafts)
                    ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
                    ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                  .get())
              .map((d) => d.id)
              .toList(),
        );
        await entity(
          'idea',
          OwnerType.idea,
          (await (select(ideas)
                    ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
                    ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                  .get())
              .map((d) => d.id)
              .toList(),
        );
        await entity(
          'piece',
          OwnerType.piece,
          (await (select(pieces)
                    ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
                    ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
                  .get())
              .map((d) => d.id)
              .toList(),
        );
        return out;
      },
    );
  }
}
