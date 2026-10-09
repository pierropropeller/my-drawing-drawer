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
    this.author = '',
    this.source = '',
  });
  final String id;
  final String pitId;
  final String file;
  final int width;
  final int height;
  final String key;
  final DateTime createdAt;

  /// 只有同人圖來源列有（跨坑移動同人圖時一併帶過去）。
  final String author;
  final String source;
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
    // imageKey 是整張圖的身分（跨格、跨坑都共用），所以按 key 找分身，不限定坑。
    final keys = <String>{};
    for (final r in await (select(
      officialImages,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add(r.imageKey);
    }
    for (final r in await (select(
      fanArts,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add(r.imageKey);
    }
    for (final r in await (select(
      junkImages,
    )..where((i) => i.id.isIn(idList))).get()) {
      keys.add(r.imageKey);
    }
    keys.remove('');

    await (update(officialImages)..where((i) => i.id.isIn(idList))).write(
      OfficialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (update(fanArts)..where((i) => i.id.isIn(idList))).write(
      FanArtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await (update(junkImages)..where((i) => i.id.isIn(idList))).write(
      JunkImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    for (final key in keys) {
      await (update(
        officialImages,
      )..where((i) => i.imageKey.equals(key) & i.deletedAt.isNull())).write(
        OfficialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(
        fanArts,
      )..where((i) => i.imageKey.equals(key) & i.deletedAt.isNull())).write(
        FanArtsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(
        junkImages,
      )..where((i) => i.imageKey.equals(key) & i.deletedAt.isNull())).write(
        JunkImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    }
  }

  // ---- 移動 ----

  /// 把 [ids]（都在 [from] 格）移到 [to] 格；[targetPitId] 給了就是**跨坑**移動（D-054）。
  ///
  /// - 同一格同一坑（官方→官方、同人圖→同人圖）：只更新 [groupId]（換分組／出處）；
  ///   沒給 [groupId] 就不做事；雜物→雜物不做事。
  /// - 其他情況：在目標坑的目標格建立一列（目標坑的目標格若有同一張圖〔同 imageKey〕被隱藏的列
  ///   就取消隱藏，恢復它原本的欄位），並把來源列隱藏。新列的 `pitId` 是目標坑；隱藏列保持
  ///   原本的坑，所以圖再移回原坑時會恢復原本的分組／作者／出處／tag。
  /// - [groupId]：目標是官方圖冊＝官方分組；目標是好看同人圖＝出處分組（可為 null）。必須屬於
  ///   **目標坑**，否則丟 [ArgumentError]。沒指定時，取消隱藏的列沿用原本的分組，新建的官方列
  ///   用目標坑第一個官方分組、同人圖列沒有出處。
  /// - tag 按坑獨立：同人圖跨坑移到好看同人圖格時，來源的 tag 按**名稱**對應目標坑已有的 tag，
  ///   目標坑沒有的自動新增同名 tag（作者、舊版出處文字也一併帶過去）。取消隱藏的列保留它自己的
  ///   tag，不重新對應。
  /// - 封面：被移動的圖若是來源坑的坑封面且目標是同一個坑的官方／同人圖→改指向新列；
  ///   其餘（移到雜物、跨坑）清成 null。各格封面一律清掉。移進目標坑**不會**設定任何封面。
  Future<void> moveAlbumImages({
    required AlbumCell from,
    required List<String> ids,
    required AlbumCell to,
    String? groupId,
    String? targetPitId,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final sources = await _sources(from, ids);
      for (final src in sources) {
        final pit = targetPitId ?? src.pitId;
        final samePit = pit == src.pitId;
        if (to != AlbumCell.junk && groupId != null) {
          await _requireGroup(pit, groupId);
        }
        if (from == to && samePit) {
          if (groupId == null) continue;
          if (from == AlbumCell.official) {
            await (update(
              officialImages,
            )..where((i) => i.id.equals(src.id))).write(
              OfficialImagesCompanion(
                groupId: Value(groupId),
                updatedAt: Value(now),
              ),
            );
          } else if (from == AlbumCell.fan) {
            await (update(fanArts)..where((i) => i.id.equals(src.id))).write(
              FanArtsCompanion(groupId: Value(groupId), updatedAt: Value(now)),
            );
          }
          continue;
        }

        final twin = await _twinOf(to, src, pit);
        String targetId;
        if (twin != null) {
          targetId = twin.id;
          if (twin.hidden) await _unhide(to, twin.id, groupId, now);
        } else {
          targetId = await _createCopy(to, src, pit, groupId, now);
          if (from == AlbumCell.fan && to == AlbumCell.fan) {
            await _copyFanTags(src.id, targetId, pit);
          }
        }
        await _hide(from, src.id, now);
        await _fixCovers(
          src.id,
          (to == AlbumCell.junk || !samePit) ? null : targetId,
        );
      }
    });
  }

  /// 分組必須存在、未刪除且屬於 [pitId]。
  Future<void> _requireGroup(String pitId, String groupId) async {
    final g =
        await (select(officialGroups)..where(
              (x) =>
                  x.id.equals(groupId) &
                  x.pitId.equals(pitId) &
                  x.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (g == null) {
      throw ArgumentError.value(groupId, 'groupId', '分組不屬於目標坑 $pitId');
    }
  }

  /// 同人圖跨坑：把來源的 tag 按名稱對應到目標坑（沒有就新增同名 tag），掛到新列上。
  Future<void> _copyFanTags(String srcId, String newId, String pitId) async {
    final links =
        await (select(tagLinks)..where(
              (l) =>
                  l.targetType.equalsValue(TagTarget.fanArt) &
                  l.targetId.equals(srcId),
            ))
            .get();
    if (links.isEmpty) return;
    final srcTags =
        await (select(tags)..where(
              (t) =>
                  t.id.isIn(links.map((l) => l.tagId).toList()) &
                  t.deletedAt.isNull(),
            ))
            .get();
    srcTags.sort((a, b) => a.name.compareTo(b.name));
    final mapped = <String>{};
    for (final t in srcTags) {
      mapped.add(await createTag(pitId, t.name));
    }
    await setTags(TagTarget.fanArt, newId, mapped.toList());
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
              author: r.author,
              source: r.source,
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
    DateTime createdAt, {
    String author = '',
    String source = '',
  }) => _Src(
    id: id,
    pitId: pitId,
    file: file,
    width: w,
    height: h,
    key: key.isEmpty ? id : key, // 防呆：舊列沒有 imageKey 就用 id
    createdAt: createdAt,
    author: author,
    source: source,
  );

  /// 目標坑 [pitId] 的目標格裡同一張圖（同 imageKey）的既有列。
  Future<_Twin?> _twinOf(AlbumCell cell, _Src src, String pitId) async {
    switch (cell) {
      case AlbumCell.official:
        final r =
            await (select(officialImages)
                  ..where(
                    (i) =>
                        i.pitId.equals(pitId) &
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
                        i.pitId.equals(pitId) &
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
                        i.pitId.equals(pitId) &
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
    String pitId,
    String? groupId,
    DateTime now,
  ) async {
    final id = uuid.v4();
    switch (cell) {
      case AlbumCell.official:
        await into(officialImages).insert(
          OfficialImagesCompanion.insert(
            id: Value(id),
            pitId: pitId,
            groupId: groupId ?? await _firstGroupId(pitId, 'official'),
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
            pitId: pitId,
            imageFile: src.file,
            width: Value(src.width),
            height: Value(src.height),
            author: Value(src.author),
            source: Value(src.source),
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
            pitId: pitId,
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
