import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'tables.dart' show uuid;

/// 可以互相移動圖片的三個「格」（D-044）。
enum AlbumCell { official, fan, junk }

/// 移動時暫存來源列的共同欄位。
class _Src {
  const _Src({
    required this.id,
    required this.pitId,
    required this.file,
    required this.width,
    required this.height,
    required this.key,
    required this.createdAt,
  });
  final String id;
  final String pitId;
  final String file;
  final int width;
  final int height;
  final String key;
  final DateTime createdAt;
}

/// 目標格裡同一張圖（同 imageKey）的既有列。
class _Twin {
  const _Twin(this.id, this.hidden);
  final String id;
  final bool hidden;
}

/// 雜物（D-034）與官方圖冊／好看同人圖／雜物之間的移動（D-044）。
extension JunkQueries on AppDatabase {
  // ---- 雜物 ----
  Stream<List<JunkImage>> watchJunk(String pitId) {
    return (select(junkImages)
          ..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.deletedAt.isNull() &
                i.hidden.equals(false),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .watch();
  }

  Future<void> addJunk(String pitId, List<NewImage> images) {
    return batch((b) {
      b.insertAll(junkImages, [for (final im in images) _newJunk(pitId, im)]);
    });
  }

  JunkImagesCompanion _newJunk(String pitId, NewImage im) {
    final id = uuid.v4();
    return JunkImagesCompanion.insert(
      id: Value(id),
      pitId: pitId,
      imageFile: im.file,
      width: Value(im.width),
      height: Value(im.height),
      imageKey: Value(id),
    );
  }

  Future<void> deleteJunk(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() => deleteAlbumImageRows(ids, now));
  }

  /// 軟刪除圖片列（官方／同人圖／雜物共用 id 空間），連同被隱藏的同 imageKey 分身一起刪，
  /// 免得留下永遠看不到的孤兒列。
  Future<void> deleteAlbumImageRows(Iterable<String> ids, DateTime now) async {
    final idList = ids.toList();
    if (idList.isEmpty) return;
    final keys = <(String, String)>{};
    for (final r in await (select(
      officialImages,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add((r.pitId, r.imageKey));
    }
    for (final r in await (select(
      fanArts,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add((r.pitId, r.imageKey));
    }
    for (final r in await (select(
      junkImages,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add((r.pitId, r.imageKey));
    }
    keys.removeWhere((k) => k.$2.isEmpty);

    await (update(officialImages)..where((i) => i.id.isIn(idList))).write(
      OfficialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (update(fanArts)..where((i) => i.id.isIn(idList))).write(
      FanArtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (update(junkImages)..where((i) => i.id.isIn(idList))).write(
      JunkImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final (pitId, key) in keys) {
      await (update(officialImages)..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.imageKey.equals(key) &
                i.deletedAt.isNull(),
          ))
          .write(
            OfficialImagesCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await (update(fanArts)..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.imageKey.equals(key) &
                i.deletedAt.isNull(),
          ))
          .write(
            FanArtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
      await (update(junkImages)..where(
            (i) =>
                i.pitId.equals(pitId) &
                i.imageKey.equals(key) &
                i.deletedAt.isNull(),
          ))
          .write(
            JunkImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
    }
  }

  // ---- 移動 ----

  /// 把 [ids]（都在 [from] 格）移到 [to] 格。
  ///
  /// - 同一格（官方→官方、同人圖→同人圖）：只更新 [groupId]（換分組／出處）；雜物→雜物不做事。
  /// - 不同格：在目標格建立一列（若目標格有同一張圖被隱藏的列就取消隱藏、恢復它原本的欄位），
  ///   並把來源列隱藏。各格獨有的欄位（官方分組、同人圖作者／出處／tag）留在隱藏列上，
  ///   移回時恢復；目標格沒有的欄位保持空白（例如同人圖作者為空字串）。
  /// - [groupId]：目標是官方圖冊＝官方分組；目標是好看同人圖＝出處分組（可為 null）。
  ///   沒指定時，取消隱藏的列沿用原本的分組，新建的官方列用第一個分組、同人圖列沒有出處。
  /// - 被移動的圖若是坑封面：移到官方／同人圖時封面改指向新列；移到雜物時清掉封面
  ///   （雜物不能當封面）。各格封面（官方／同人圖）一律清掉。
  Future<void> moveAlbumImages({
    required AlbumCell from,
    required List<String> ids,
    required AlbumCell to,
    String? groupId,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      if (from == to) {
        if (groupId == null) return;
        if (from == AlbumCell.official) {
          await (update(officialImages)..where((i) => i.id.isIn(ids))).write(
            OfficialImagesCompanion(
              groupId: Value(groupId),
              updatedAt: Value(now),
            ),
          );
        } else if (from == AlbumCell.fan) {
          await (update(fanArts)..where((i) => i.id.isIn(ids))).write(
            FanArtsCompanion(groupId: Value(groupId), updatedAt: Value(now)),
          );
        }
        return;
      }

      final sources = await _sources(from, ids);
      for (final src in sources) {
        final twin = await _twinOf(to, src);
        String targetId;
        if (twin != null) {
          targetId = twin.id;
          if (twin.hidden) await _unhide(to, twin.id, groupId, now);
        } else {
          targetId = await _createCopy(to, src, groupId, now);
        }
        await _hide(from, src.id, now);
        await _fixCovers(src.id, to == AlbumCell.junk ? null : targetId);
      }
    });
  }

  Future<List<_Src>> _sources(AlbumCell cell, List<String> ids) async {
    final out = <_Src>[];
    switch (cell) {
      case AlbumCell.official:
        final rows =
            await (select(officialImages)..where(
                  (i) =>
                      i.id.isIn(ids) &
                      i.deletedAt.isNull() &
                      i.hidden.equals(false),
                ))
                .get();
        for (final r in rows) {
          out.add(
            _fromRow(
              r.id,
              r.pitId,
              r.imageFile,
              r.width,
              r.height,
              r.imageKey,
              r.createdAt,
            ),
          );
        }
      case AlbumCell.fan:
        final rows =
            await (select(fanArts)..where(
                  (i) =>
                      i.id.isIn(ids) &
                      i.deletedAt.isNull() &
                      i.hidden.equals(false),
                ))
                .get();
        for (final r in rows) {
          out.add(
            _fromRow(
              r.id,
              r.pitId,
              r.imageFile,
              r.width,
              r.height,
              r.imageKey,
              r.createdAt,
            ),
          );
        }
      case AlbumCell.junk:
        final rows =
            await (select(junkImages)..where(
                  (i) =>
                      i.id.isIn(ids) &
                      i.deletedAt.isNull() &
                      i.hidden.equals(false),
                ))
                .get();
        for (final r in rows) {
          out.add(
            _fromRow(
              r.id,
              r.pitId,
              r.imageFile,
              r.width,
              r.height,
              r.imageKey,
              r.createdAt,
            ),
          );
        }
    }
    // 照呼叫端給的順序處理。
    out.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return out;
  }

  _Src _fromRow(
    String id,
    String pitId,
    String file,
    int w,
    int h,
    String key,
    DateTime createdAt,
  ) => _Src(
    id: id,
    pitId: pitId,
    file: file,
    width: w,
    height: h,
    key: key.isEmpty ? id : key, // 防呆：舊列沒有 imageKey 就用 id
    createdAt: createdAt,
  );

  Future<_Twin?> _twinOf(AlbumCell cell, _Src src) async {
    switch (cell) {
      case AlbumCell.official:
        final r =
            await (select(officialImages)
                  ..where(
                    (i) =>
                        i.pitId.equals(src.pitId) &
                        i.imageKey.equals(src.key) &
                        i.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        return r == null ? null : _Twin(r.id, r.hidden);
      case AlbumCell.fan:
        final r =
            await (select(fanArts)
                  ..where(
                    (i) =>
                        i.pitId.equals(src.pitId) &
                        i.imageKey.equals(src.key) &
                        i.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        return r == null ? null : _Twin(r.id, r.hidden);
      case AlbumCell.junk:
        final r =
            await (select(junkImages)
                  ..where(
                    (i) =>
                        i.pitId.equals(src.pitId) &
                        i.imageKey.equals(src.key) &
                        i.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        return r == null ? null : _Twin(r.id, r.hidden);
    }
  }

  /// 坑裡某種分組的第一個（官方圖冊新建列的預設分組）。
  Future<String> _firstGroupId(String pitId, String kind) async {
    final g =
        await (select(officialGroups)
              ..where(
                (x) =>
                    x.pitId.equals(pitId) &
                    x.kind.equals(kind) &
                    x.deletedAt.isNull(),
              )
              ..orderBy([(x) => OrderingTerm.asc(x.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return g?.id ?? '';
  }

  Future<void> _unhide(
    AlbumCell cell,
    String id,
    String? groupId,
    DateTime now,
  ) async {
    switch (cell) {
      case AlbumCell.official:
        await (update(officialImages)..where((i) => i.id.equals(id))).write(
          OfficialImagesCompanion(
            hidden: const Value(false),
            groupId: groupId == null ? const Value.absent() : Value(groupId),
            updatedAt: Value(now),
          ),
        );
      case AlbumCell.fan:
        await (update(fanArts)..where((i) => i.id.equals(id))).write(
          FanArtsCompanion(
            hidden: const Value(false),
            groupId: groupId == null ? const Value.absent() : Value(groupId),
            updatedAt: Value(now),
          ),
        );
      case AlbumCell.junk:
        await (update(junkImages)..where((i) => i.id.equals(id))).write(
          JunkImagesCompanion(
            hidden: const Value(false),
            updatedAt: Value(now),
          ),
        );
    }
  }

  Future<void> _hide(AlbumCell cell, String id, DateTime now) async {
    switch (cell) {
      case AlbumCell.official:
        await (update(officialImages)..where((i) => i.id.equals(id))).write(
          OfficialImagesCompanion(
            hidden: const Value(true),
            updatedAt: Value(now),
          ),
        );
      case AlbumCell.fan:
        await (update(fanArts)..where((i) => i.id.equals(id))).write(
          FanArtsCompanion(hidden: const Value(true), updatedAt: Value(now)),
        );
      case AlbumCell.junk:
        await (update(junkImages)..where((i) => i.id.equals(id))).write(
          JunkImagesCompanion(hidden: const Value(true), updatedAt: Value(now)),
        );
    }
  }

  Future<String> _createCopy(
    AlbumCell cell,
    _Src src,
    String? groupId,
    DateTime now,
  ) async {
    final id = uuid.v4();
    switch (cell) {
      case AlbumCell.official:
        await into(officialImages).insert(
          OfficialImagesCompanion.insert(
            id: Value(id),
            pitId: src.pitId,
            groupId: groupId ?? await _firstGroupId(src.pitId, 'official'),
            imageFile: src.file,
            width: Value(src.width),
            height: Value(src.height),
            imageKey: Value(src.key),
            createdAt: Value(src.createdAt),
            updatedAt: Value(now),
          ),
        );
      case AlbumCell.fan:
        await into(fanArts).insert(
          FanArtsCompanion.insert(
            id: Value(id),
            pitId: src.pitId,
            imageFile: src.file,
            width: Value(src.width),
            height: Value(src.height),
            groupId: Value(groupId),
            imageKey: Value(src.key),
            createdAt: Value(src.createdAt),
            updatedAt: Value(now),
          ),
        );
      case AlbumCell.junk:
        await into(junkImages).insert(
          JunkImagesCompanion.insert(
            id: Value(id),
            pitId: src.pitId,
            imageFile: src.file,
            width: Value(src.width),
            height: Value(src.height),
            imageKey: Value(src.key),
            createdAt: Value(src.createdAt),
            updatedAt: Value(now),
          ),
        );
    }
    return id;
  }

  /// 來源列被隱藏後，指向它的封面要處理：坑封面改指向新列（[newId]＝null 時清掉）；
  /// 官方圖冊／同人圖格的封面一律清掉。
  Future<void> _fixCovers(String oldId, String? newId) async {
    await (update(pits)..where((p) => p.coverImageId.equals(oldId))).write(
      PitsCompanion(coverImageId: Value(newId)),
    );
    await (update(pits)..where((p) => p.officialCoverId.equals(oldId))).write(
      const PitsCompanion(officialCoverId: Value(null)),
    );
    await (update(pits)..where((p) => p.fanArtCoverId.equals(oldId))).write(
      const PitsCompanion(fanArtCoverId: Value(null)),
    );
  }
}
