import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart';
import 'junk_queries.dart';
import 'trash_queries.dart' show kTrashPurgedAt;
import 'tables.dart' show uuid;

/// 多圖的官方圖／同人圖（D-136）。
///
/// 一筆官方圖／同人圖（以及被移到雜物的同一張，見 D-044 的 imageKey）＝**一組圖**：
/// - 第 1 張仍存在那一列本身（imageFile／寬高／媒體欄位），列表、封面、搜尋等全部照舊；
/// - 第 2 張起存在 [EntityImages]（ownerType＝[OwnerType.album]、ownerId＝那一列的 **imageKey**），
///   依 sortOrder 排。用 imageKey 當 owner，所以在官方圖冊／同人圖／雜物之間、跨坑移動時整組跟著走。
/// - 同步：放在那一列的文件裡（`extras`），見 sync_kinds.dart。
extension AlbumSetQueries on AppDatabase {
  /// 這一組第 2 張起的圖（依次序）。
  Stream<List<EntityImage>> watchAlbumExtras(String imageKey) =>
      (select(entityImages)
            ..where(
              (e) =>
                  e.ownerType.equalsValue(OwnerType.album) &
                  e.ownerId.equals(imageKey) &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .watch();

  Future<List<EntityImage>> albumExtrasOf(String imageKey) =>
      (select(entityImages)
            ..where(
              (e) =>
                  e.ownerType.equalsValue(OwnerType.album) &
                  e.ownerId.equals(imageKey) &
                  e.deletedAt.isNull(),
            )
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .get();

  /// 每一組（imageKey）有幾張「額外」的圖；沒有的不列。列表右上角「⧉ N」小標用（N＝額外＋1）。
  Stream<Map<String, int>> watchAlbumExtraCounts() {
    final count = entityImages.id.count();
    final q = selectOnly(entityImages)
      ..addColumns([entityImages.ownerId, count])
      ..where(
        entityImages.ownerType.equalsValue(OwnerType.album) &
            entityImages.deletedAt.isNull(),
      )
      ..groupBy([entityImages.ownerId]);
    return q.watch().map(
      (rows) => {
        for (final r in rows) r.read(entityImages.ownerId)!: r.read(count) ?? 0,
      },
    );
  }

  /// 新增時「合成一組」：第 1 張成為那一列，其餘放進這一組。
  Future<void> addOfficialSet(
    String pitId,
    String groupId,
    List<NewImage> images, {
    List<String> tagIds = const [],
  }) async {
    if (images.isEmpty) return;
    await transaction(() async {
      final ids = await addOfficial(pitId, groupId, [
        images.first,
      ], tagIds: tagIds);
      // 新列的 imageKey＝自己的 id。
      await replaceEntityImages(OwnerType.album, ids.first, images.sublist(1));
    });
  }

  Future<void> addFanArtSet(
    String pitId,
    List<NewImage> images, {
    required String author,
    String? groupId,
    List<String> tagIds = const [],
  }) async {
    if (images.isEmpty) return;
    await transaction(() async {
      final ids = await addFanArts(
        pitId,
        [images.first],
        author: author,
        groupId: groupId,
        tagIds: tagIds,
      );
      await replaceEntityImages(OwnerType.album, ids.first, images.sublist(1));
    });
  }

  /// 整組的圖（第 1 張＝那一列）。
  Future<List<NewImage>> albumSetImages(AlbumCell cell, String id) async {
    final row = await _albumRow(cell, id);
    if (row == null) return const [];
    return [
      row.image,
      for (final e in await albumExtrasOf(row.key)) _newImageOf(e),
    ];
  }

  /// 編輯頁存檔（D-136）：依 [images] 的次序重寫這一組。第 1 張寫回那一列（連同其他格被隱藏的分身），
  /// 其餘是這一組的額外圖。[images] 不可為空（全部移除＝刪除，由呼叫端處理）。
  Future<void> setAlbumSetImages(
    AlbumCell cell,
    String id,
    List<NewImage> images,
  ) async {
    if (images.isEmpty) return;
    await transaction(() async {
      final row = await _albumRow(cell, id);
      if (row == null) return;
      final first = images.first;
      if (first.file != row.image.file) {
        await _writeFirstImage(row.key, first);
      }
      await replaceEntityImages(OwnerType.album, row.key, images.sublist(1));
      await _touch(cell, id);
    });
  }

  /// 拆開（D-136）：這一組每一張都變成獨立一筆，留在同一格，分組／作者／出處／tag 照抄。
  /// 回傳拆出來的新列 id（不含原本那一筆）。
  Future<List<String>> splitAlbumSet(AlbumCell cell, String id) async {
    return transaction(() async {
      final row = await _albumRow(cell, id);
      if (row == null) return const <String>[];
      final extras = await albumExtrasOf(row.key);
      if (extras.isEmpty) return const <String>[];
      final created = <String>[];
      final tagTarget = switch (cell) {
        AlbumCell.official => TagTarget.official,
        AlbumCell.fan => TagTarget.fanArt,
        AlbumCell.junk => null,
      };
      final tagIds = tagTarget == null
          ? const <String>[]
          : await watchTagIds(tagTarget, id).first;
      final now = DateTime.now();
      for (var i = 0; i < extras.length; i++) {
        final e = extras[i];
        final newId = uuid.v4();
        // 依原本次序往後排：越後面的圖 updatedAt 越早，列表（新的在前）裡緊跟在原本那一筆後面。
        final stamp = now.subtract(Duration(milliseconds: i + 1));
        switch (cell) {
          case AlbumCell.official:
            final src = row.official!;
            await into(officialImages).insert(
              OfficialImagesCompanion.insert(
                id: Value(newId),
                imageKey: Value(newId),
                pitId: src.pitId,
                groupId: src.groupId,
                imageFile: e.imageFile,
                width: Value(e.width),
                height: Value(e.height),
                kind: Value(e.kind),
                durationMs: Value(e.durationMs),
                posterFile: Value(e.posterFile),
                sensitive: Value(e.sensitive),
                createdAt: Value(src.createdAt),
                updatedAt: Value(stamp),
              ),
            );
          case AlbumCell.fan:
            final src = row.fan!;
            await into(fanArts).insert(
              FanArtsCompanion.insert(
                id: Value(newId),
                imageKey: Value(newId),
                pitId: src.pitId,
                imageFile: e.imageFile,
                width: Value(e.width),
                height: Value(e.height),
                kind: Value(e.kind),
                durationMs: Value(e.durationMs),
                posterFile: Value(e.posterFile),
                sensitive: Value(e.sensitive),
                author: Value(src.author),
                source: Value(src.source),
                groupId: Value(src.groupId),
                createdAt: Value(src.createdAt),
                updatedAt: Value(stamp),
              ),
            );
          case AlbumCell.junk:
            final src = row.junk!;
            await into(junkImages).insert(
              JunkImagesCompanion.insert(
                id: Value(newId),
                imageKey: Value(newId),
                pitId: src.pitId,
                imageFile: e.imageFile,
                width: Value(e.width),
                height: Value(e.height),
                kind: Value(e.kind),
                durationMs: Value(e.durationMs),
                posterFile: Value(e.posterFile),
                sensitive: Value(e.sensitive),
                createdAt: Value(src.createdAt),
                updatedAt: Value(stamp),
              ),
            );
        }
        if (tagTarget != null && tagIds.isNotEmpty) {
          await setTags(tagTarget, newId, tagIds);
        }
        created.add(newId);
      }
      await replaceEntityImages(OwnerType.album, row.key, const []);
      await _touch(cell, id, at: now);
      return created;
    });
  }

  /// 合併（D-136，多選「合併」）：[ids] 依列表次序，第 1 筆留下，其餘各筆的圖依次接在後面；
  /// 其餘各筆的 tag 併進第 1 筆，然後這些筆（連同其他格被隱藏的分身）直接拿掉（不進最近刪除）。
  /// 回傳留下的那一筆 id；不足兩筆時什麼都不做，回傳 null。
  Future<String?> mergeAlbumSets(AlbumCell cell, List<String> ids) async {
    if (ids.length < 2) return null;
    return transaction(() async {
      final rows = <_AlbumRow>[];
      for (final id in ids) {
        final r = await _albumRow(cell, id);
        if (r != null) rows.add(r);
      }
      if (rows.length < 2) return null;
      final keeper = rows.first;
      final images = <NewImage>[
        for (final e in await albumExtrasOf(keeper.key)) _newImageOf(e),
      ];
      final tagTarget = switch (cell) {
        AlbumCell.official => TagTarget.official,
        AlbumCell.fan => TagTarget.fanArt,
        AlbumCell.junk => null,
      };
      final tagIds = <String>{
        if (tagTarget != null) ...await watchTagIds(tagTarget, keeper.id).first,
      };
      for (final r in rows.skip(1)) {
        images.add(r.image);
        for (final e in await albumExtrasOf(r.key)) {
          images.add(_newImageOf(e));
        }
        if (tagTarget != null) {
          tagIds.addAll(await watchTagIds(tagTarget, r.id).first);
        }
      }
      // 同一個檔案只留一次（同一張圖被加過兩次時）。
      final seen = <String>{keeper.image.file};
      final extras = [
        for (final n in images)
          if (seen.add(n.file)) n,
      ];
      await replaceEntityImages(OwnerType.album, keeper.key, extras);
      if (tagTarget != null) {
        await setTags(tagTarget, keeper.id, tagIds.toList());
      }
      final gone = Value<DateTime?>(kTrashPurgedAt);
      final now = Value(DateTime.now());
      for (final r in rows.skip(1)) {
        await replaceEntityImages(OwnerType.album, r.key, const []);
        await (update(officialImages)..where((i) => i.imageKey.equals(r.key)))
            .write(OfficialImagesCompanion(deletedAt: gone, updatedAt: now));
        await (update(fanArts)..where((i) => i.imageKey.equals(r.key))).write(
          FanArtsCompanion(deletedAt: gone, updatedAt: now),
        );
        await (update(junkImages)..where((i) => i.imageKey.equals(r.key)))
            .write(JunkImagesCompanion(deletedAt: gone, updatedAt: now));
      }
      await _clearCoversOf([for (final r in rows.skip(1)) r.id]);
      await _touch(cell, keeper.id);
      return keeper.id;
    });
  }

  Future<void> _clearCoversOf(List<String> ids) async {
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

  /// 第 1 張換了：寫回同一張圖（imageKey）在官方／同人圖／雜物的每一列。
  Future<void> _writeFirstImage(String key, NewImage n) async {
    await (update(officialImages)..where((i) => i.imageKey.equals(key))).write(
      OfficialImagesCompanion(
        imageFile: Value(n.file),
        width: Value(n.width),
        height: Value(n.height),
        kind: Value(n.kind),
        durationMs: Value(n.durationMs),
        posterFile: Value(n.posterFile),
        sensitive: Value(n.sensitive),
      ),
    );
    await (update(fanArts)..where((i) => i.imageKey.equals(key))).write(
      FanArtsCompanion(
        imageFile: Value(n.file),
        width: Value(n.width),
        height: Value(n.height),
        kind: Value(n.kind),
        durationMs: Value(n.durationMs),
        posterFile: Value(n.posterFile),
        sensitive: Value(n.sensitive),
      ),
    );
    await (update(junkImages)..where((i) => i.imageKey.equals(key))).write(
      JunkImagesCompanion(
        imageFile: Value(n.file),
        width: Value(n.width),
        height: Value(n.height),
        kind: Value(n.kind),
        durationMs: Value(n.durationMs),
        posterFile: Value(n.posterFile),
        sensitive: Value(n.sensitive),
      ),
    );
  }

  Future<void> _touch(AlbumCell cell, String id, {DateTime? at}) {
    final now = Value(at ?? DateTime.now());
    return switch (cell) {
      AlbumCell.official =>
        (update(officialImages)..where((i) => i.id.equals(id))).write(
          OfficialImagesCompanion(updatedAt: now),
        ),
      AlbumCell.fan => (update(
        fanArts,
      )..where((i) => i.id.equals(id))).write(FanArtsCompanion(updatedAt: now)),
      AlbumCell.junk =>
        (update(junkImages)..where((i) => i.id.equals(id))).write(
          JunkImagesCompanion(updatedAt: now),
        ),
    };
  }

  Future<_AlbumRow?> _albumRow(AlbumCell cell, String id) async {
    switch (cell) {
      case AlbumCell.official:
        final r = await (select(
          officialImages,
        )..where((i) => i.id.equals(id))).getSingleOrNull();
        if (r == null) return null;
        return _AlbumRow(
          id: r.id,
          key: r.imageKey.isEmpty ? r.id : r.imageKey,
          image: NewImage(
            file: r.imageFile,
            width: r.width,
            height: r.height,
            kind: r.kind,
            durationMs: r.durationMs,
            posterFile: r.posterFile,
            sensitive: r.sensitive,
          ),
          official: r,
        );
      case AlbumCell.fan:
        final r = await (select(
          fanArts,
        )..where((i) => i.id.equals(id))).getSingleOrNull();
        if (r == null) return null;
        return _AlbumRow(
          id: r.id,
          key: r.imageKey.isEmpty ? r.id : r.imageKey,
          image: NewImage(
            file: r.imageFile,
            width: r.width,
            height: r.height,
            kind: r.kind,
            durationMs: r.durationMs,
            posterFile: r.posterFile,
            sensitive: r.sensitive,
          ),
          fan: r,
        );
      case AlbumCell.junk:
        final r = await (select(
          junkImages,
        )..where((i) => i.id.equals(id))).getSingleOrNull();
        if (r == null) return null;
        return _AlbumRow(
          id: r.id,
          key: r.imageKey.isEmpty ? r.id : r.imageKey,
          image: NewImage(
            file: r.imageFile,
            width: r.width,
            height: r.height,
            kind: r.kind,
            durationMs: r.durationMs,
            posterFile: r.posterFile,
            sensitive: r.sensitive,
          ),
          junk: r,
        );
    }
  }
}

NewImage _newImageOf(EntityImage e) => NewImage(
  file: e.imageFile,
  width: e.width,
  height: e.height,
  kind: e.kind,
  durationMs: e.durationMs,
  posterFile: e.posterFile,
  sensitive: e.sensitive,
);

class _AlbumRow {
  const _AlbumRow({
    required this.id,
    required this.key,
    required this.image,
    this.official,
    this.fan,
    this.junk,
  });
  final String id;
  final String key;
  final NewImage image;
  final OfficialImage? official;
  final FanArt? fan;
  final JunkImage? junk;
}
