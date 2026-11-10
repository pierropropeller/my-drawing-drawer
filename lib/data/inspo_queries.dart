import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'junk_queries.dart' show AlbumCell;
import 'material_queries.dart';
import 'trash_queries.dart' show kTrashPurgedAt;

/// 廣場圖放進的坑（id、坑名）。
typedef PlacedPit = ({String id, String name});

/// 靈感廣場（原素材庫）：自訂分類（D-143）、說明（D-141）、放進坑（D-142）、坑圖移到廣場（D-144）。
extension InspoQueries on AppDatabase {
  // ---- 分類 ----

  /// 未刪除的分類，依拖曳順序。
  Stream<List<InspoCategory>> watchInspoCategories() {
    return (select(materialCategories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([
            (c) => OrderingTerm.asc(c.sortOrder),
            (c) => OrderingTerm.asc(c.createdAt),
          ]))
        .watch();
  }

  Future<List<InspoCategory>> loadInspoCategories() =>
      watchInspoCategories().first;

  /// 新增分類（排在最後）。回傳新分類的 id。
  Future<String> addInspoCategory(String name) async {
    final last =
        await (select(materialCategories)
              ..where((c) => c.deletedAt.isNull())
              ..orderBy([(c) => OrderingTerm.desc(c.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    final row = await into(materialCategories).insertReturning(
      MaterialCategoriesCompanion.insert(
        name: name,
        sortOrder: Value((last?.sortOrder ?? -1) + 1),
      ),
    );
    return row.id;
  }

  Future<void> renameInspoCategory(String id, String name) {
    return (update(materialCategories)..where((c) => c.id.equals(id))).write(
      MaterialCategoriesCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 刪除分類；分類裡的圖改歸剩下的第一個分類。至少要留一個分類（回傳 false＝不能刪）。
  Future<bool> deleteInspoCategory(String id) {
    return transaction(() async {
      final rest =
          await (select(materialCategories)
                ..where((c) => c.deletedAt.isNull() & c.id.equals(id).not())
                ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
              .get();
      if (rest.isEmpty) return false;
      final inCat = [
        for (final m in await (select(
          materialImages,
        )..where((m) => m.deletedAt.isNull())).get())
          if (m.categoryKey == id) m.id,
      ];
      await moveMaterials(inCat, rest.first.id);
      final now = DateTime.now();
      await (update(materialCategories)..where((c) => c.id.equals(id))).write(
        MaterialCategoriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return true;
    });
  }

  /// 拖曳排序；只有位置有變的才蓋 updatedAt（跟著同步）。
  Future<void> reorderInspoCategories(List<String> orderedIds) {
    return transaction(() async {
      final now = DateTime.now();
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(materialCategories)..where(
              (c) => c.id.equals(orderedIds[i]) & c.sortOrder.equals(i).not(),
            ))
            .write(
              MaterialCategoriesCompanion(
                sortOrder: Value(i),
                updatedAt: Value(now),
              ),
            );
      }
    });
  }

  // ---- 說明 ----

  /// 廣場圖的說明（放進各坑的參考圖共用這一份）。空字串存成 null。
  Future<void> setMaterialNote(String id, String? note) {
    return (update(materialImages)..where((m) => m.id.equals(id))).write(
      MaterialImagesCompanion(
        note: Value(_clean(note)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 參考圖的說明。從廣場放進來的圖改的是廣場那張（共用一份）。
  Future<void> setOfficialNote(String id, String? note) async {
    final row = await (select(
      officialImages,
    )..where((o) => o.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    if (row.materialId != null) {
      await setMaterialNote(row.materialId!, note);
      return;
    }
    await (update(officialImages)..where((o) => o.id.equals(id))).write(
      OfficialImagesCompanion(
        note: Value(_clean(note)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setFanArtNote(String id, String? note) {
    return (update(fanArts)..where((f) => f.id.equals(id))).write(
      FanArtsCompanion(
        note: Value(_clean(note)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 參考圖顯示用的說明：放進來的圖讀廣場那張的。
  Stream<String?> watchOfficialNote(String id) {
    final q = customSelect(
      'SELECT COALESCE(m.note, o.note) AS note FROM official_images o '
      'LEFT JOIN material_images m ON m.id = o.material_id '
      'WHERE o.id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {officialImages, materialImages},
    );
    return q.watch().map(
      (rows) => rows.isEmpty ? null : rows.first.readNullable<String>('note'),
    );
  }

  /// 一個坑所有參考圖的說明（列表縮圖下的兩行）。key＝參考圖 id，沒有說明的不列。
  Stream<Map<String, String>> watchOfficialNotes(String pitId) {
    final q = customSelect(
      'SELECT o.id AS id, CASE WHEN o.material_id IS NULL THEN o.note '
      'ELSE m.note END AS note FROM official_images o '
      'LEFT JOIN material_images m ON m.id = o.material_id '
      'WHERE o.pit_id = ?1 AND o.deleted_at IS NULL',
      variables: [Variable<String>(pitId)],
      readsFrom: {officialImages, materialImages},
    );
    return q.watch().map(
      (rows) => {
        for (final r in rows)
          if ((r.readNullable<String>('note') ?? '').trim().isNotEmpty)
            r.read<String>('id'): r.read<String>('note'),
      },
    );
  }

  // ---- 放進坑 ----

  /// 廣場圖放進了哪些坑：key＝廣場圖 id，value＝坑（依坑名）。
  Stream<Map<String, List<PlacedPit>>> watchPlacedPits() {
    final q = customSelect(
      'SELECT DISTINCT o.material_id AS mid, o.pit_id AS pid, p.name AS pname '
      'FROM official_images o JOIN pits p ON p.id = o.pit_id '
      'WHERE o.material_id IS NOT NULL AND o.deleted_at IS NULL '
      'AND o.hidden = 0 AND p.deleted_at IS NULL ORDER BY p.name',
      readsFrom: {officialImages, pits},
    );
    return q.watch().map((rows) {
      final out = <String, List<PlacedPit>>{};
      for (final r in rows) {
        (out[r.read<String>('mid')] ??= []).add((
          id: r.read<String>('pid'),
          name: r.read<String>('pname'),
        ));
      }
      return out;
    });
  }

  /// 把廣場圖放進 [pitId] 的參考圖（[groupId] 分組）。是連結：檔案共用，分組、tag 屬於這個坑。
  /// 已經在這個坑的跳過。回傳實際新增的參考圖 id。
  Future<List<String>> placeMaterials(
    Iterable<String> materialIds,
    String pitId,
    String groupId, {
    List<String> tagIds = const [],
  }) {
    final list = materialIds.toList();
    return transaction(() async {
      if (list.isEmpty) return const <String>[];
      final already = {
        for (final o
            in await (select(officialImages)..where(
                  (o) =>
                      o.pitId.equals(pitId) &
                      o.materialId.isIn(list) &
                      o.deletedAt.isNull() &
                      o.hidden.equals(false),
                ))
                .get())
          o.materialId!,
      };
      final mats = {
        for (final m in await (select(
          materialImages,
        )..where((m) => m.id.isIn(list) & m.deletedAt.isNull())).get())
          m.id: m,
      };
      final added = <String>[];
      for (final id in list) {
        final m = mats[id];
        if (m == null || already.contains(id)) continue;
        final row = await into(officialImages).insertReturning(
          OfficialImagesCompanion.insert(
            pitId: pitId,
            groupId: groupId,
            imageFile: m.imageFile,
            width: Value(m.width),
            height: Value(m.height),
            kind: Value(m.kind),
            durationMs: Value(m.durationMs),
            posterFile: Value(m.posterFile),
            sensitive: Value(m.sensitive),
            materialId: Value(m.id),
          ),
        );
        await (update(officialImages)..where((o) => o.id.equals(row.id))).write(
          OfficialImagesCompanion(imageKey: Value(row.id)),
        );
        if (tagIds.isNotEmpty) {
          await setTags(TagTarget.official, row.id, tagIds);
        }
        added.add(row.id);
      }
      return added;
    });
  }

  /// 從坑裡「移出」廣場放進來的圖：只解除連結，廣場那張不動，也不進最近刪除。
  Future<void> unplaceOfficial(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await transaction(() async {
      await (update(
        officialImages,
      )..where((o) => o.id.isIn(list) & o.materialId.isNotNull())).write(
        OfficialImagesCompanion(
          deletedAt: Value(kTrashPurgedAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (update(pits)..where((p) => p.coverImageId.isIn(list))).write(
        const PitsCompanion(coverImageId: Value(null)),
      );
      await (update(pits)..where((p) => p.officialCoverId.isIn(list))).write(
        const PitsCompanion(officialCoverId: Value(null)),
      );
    });
  }

  // ---- 坑圖移到廣場 ----

  /// 坑裡的圖（參考圖／好看同人圖／雜物）移到靈感廣場的 [categoryId] 分類（D-144）：
  /// 廣場新增一張（檔案共用、說明帶過去），原本那張從坑裡拿走（不進最近刪除）。
  /// 本來就是從廣場放進來的參考圖：只解除連結（廣場已經有了，不重複建立）。
  Future<void> moveToInspo(
    AlbumCell from,
    Iterable<String> ids,
    String categoryId,
  ) {
    final list = ids.toList();
    return transaction(() async {
      if (list.isEmpty) return;
      final now = DateTime.now();
      final fresh = <NewImage>[];
      final notes = <String?>[];
      final linked = <String>[];
      switch (from) {
        case AlbumCell.official:
          for (final o in await (select(
            officialImages,
          )..where((o) => o.id.isIn(list) & o.deletedAt.isNull())).get()) {
            if (o.materialId != null) {
              linked.add(o.id);
              continue;
            }
            fresh.add(
              _newImage(
                o.imageFile,
                o.width,
                o.height,
                o.kind,
                o.durationMs,
                o.posterFile,
                o.sensitive,
              ),
            );
            notes.add(o.note);
          }
        case AlbumCell.fan:
          for (final f in await (select(
            fanArts,
          )..where((f) => f.id.isIn(list) & f.deletedAt.isNull())).get()) {
            fresh.add(
              _newImage(
                f.imageFile,
                f.width,
                f.height,
                f.kind,
                f.durationMs,
                f.posterFile,
                f.sensitive,
              ),
            );
            notes.add(f.note);
          }
        case AlbumCell.junk:
          for (final j in await (select(
            junkImages,
          )..where((j) => j.id.isIn(list) & j.deletedAt.isNull())).get()) {
            fresh.add(
              _newImage(
                j.imageFile,
                j.width,
                j.height,
                j.kind,
                j.durationMs,
                j.posterFile,
                j.sensitive,
              ),
            );
            notes.add(null);
          }
      }
      for (var i = 0; i < fresh.length; i++) {
        await addMaterials(categoryId, [fresh[i]], note: notes[i]);
      }
      await unplaceOfficial(linked);
      // 原本那張：標成永久刪除（不進最近刪除；檔案還被廣場那張用著，同步時不會被清掉）。
      final gone = Value<DateTime?>(kTrashPurgedAt);
      switch (from) {
        case AlbumCell.official:
          await (update(
            officialImages,
          )..where((o) => o.id.isIn(list) & o.materialId.isNull())).write(
            OfficialImagesCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case AlbumCell.fan:
          await (update(fanArts)..where((f) => f.id.isIn(list))).write(
            FanArtsCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case AlbumCell.junk:
          await (update(junkImages)..where((j) => j.id.isIn(list))).write(
            JunkImagesCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
      }
      await (update(pits)..where((p) => p.coverImageId.isIn(list))).write(
        const PitsCompanion(coverImageId: Value(null)),
      );
      await (update(pits)..where((p) => p.officialCoverId.isIn(list))).write(
        const PitsCompanion(officialCoverId: Value(null)),
      );
      await (update(pits)..where((p) => p.fanArtCoverId.isIn(list))).write(
        const PitsCompanion(fanArtCoverId: Value(null)),
      );
    });
  }
}

NewImage _newImage(
  String file,
  int width,
  int height,
  MediaKind kind,
  int? durationMs,
  String? posterFile,
  bool sensitive,
) => NewImage(
  file: file,
  width: width,
  height: height,
  kind: kind,
  durationMs: durationMs,
  posterFile: posterFile,
  sensitive: sensitive,
);

String? _clean(String? note) {
  final t = note?.trim() ?? '';
  return t.isEmpty ? null : t;
}
