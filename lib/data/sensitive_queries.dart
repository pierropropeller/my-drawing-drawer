import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart' show watchAssembled;

/// 敏感內容標記（D-104，HANDOFF 3.13）的資料層。
///
/// 標記存在每張圖自己的資料列（`sensitive`），坑有自己的開關（`Pits.sensitiveEnabled`），
/// 裝置另有總開關與安全模式（`AppSettings`，不同步）。**這裡只處理標記本身**：
/// 開關關掉時標記保留，顯示與否由 UI 依「總開關＋坑開關」決定。

/// 多選「敏感」動作要處理的對象種類。
/// - 圖片列（官方圖、同人圖、雜物、素材庫）：ids 是圖片列 id；
/// - 腦洞／草稿／成圖／推活：ids 是**紀錄**的 id，動作作用在紀錄底下的每一張圖。
enum SensitiveSource { official, fan, junk, material, idea, draft, piece, oshi }

extension SensitiveSourceX on SensitiveSource {
  OwnerType? get ownerType => switch (this) {
    SensitiveSource.idea => OwnerType.idea,
    SensitiveSource.draft => OwnerType.draft,
    SensitiveSource.piece => OwnerType.piece,
    SensitiveSource.oshi => OwnerType.oshi,
    _ => null,
  };
}

/// 需要判斷「有效敏感」的圖：標記為敏感，且（有所屬坑時）該坑的敏感內容開關是開的。
/// 只回傳**檔名**（原檔與影片截圖都列），UI 的縮圖元件用檔名查它，不必把坑 id 一路傳下去。
/// 總開關是裝置設定，不在這裡處理。
const _effectiveSensitiveSql = '''
SELECT o.image_file AS f, o.poster_file AS p FROM official_images o
  JOIN pits t ON t.id = o.pit_id
  WHERE o.sensitive = 1 AND o.deleted_at IS NULL AND o.hidden = 0 AND t.sensitive_enabled = 1
UNION
SELECT o.image_file, o.poster_file FROM fan_arts o
  JOIN pits t ON t.id = o.pit_id
  WHERE o.sensitive = 1 AND o.deleted_at IS NULL AND o.hidden = 0 AND t.sensitive_enabled = 1
UNION
SELECT o.image_file, o.poster_file FROM junk_images o
  JOIN pits t ON t.id = o.pit_id
  WHERE o.sensitive = 1 AND o.deleted_at IS NULL AND o.hidden = 0 AND t.sensitive_enabled = 1
UNION
SELECT m.image_file, m.poster_file FROM material_images m
  WHERE m.sensitive = 1 AND m.deleted_at IS NULL
UNION
SELECT e.image_file, e.poster_file FROM entity_images e
  JOIN ideas x ON e.owner_type = 'idea' AND x.id = e.owner_id
  JOIN pits t ON t.id = x.pit_id
  WHERE e.sensitive = 1 AND e.deleted_at IS NULL AND t.sensitive_enabled = 1
UNION
SELECT e.image_file, e.poster_file FROM entity_images e
  JOIN drafts x ON e.owner_type = 'draft' AND x.id = e.owner_id
  JOIN pits t ON t.id = x.pit_id
  WHERE e.sensitive = 1 AND e.deleted_at IS NULL AND t.sensitive_enabled = 1
UNION
SELECT e.image_file, e.poster_file FROM entity_images e
  JOIN pieces x ON e.owner_type = 'piece' AND x.id = e.owner_id
  JOIN pits t ON t.id = x.pit_id
  WHERE e.sensitive = 1 AND e.deleted_at IS NULL AND t.sensitive_enabled = 1
UNION
SELECT e.image_file, e.poster_file FROM entity_images e
  JOIN oshi_records x ON e.owner_type = 'oshi' AND x.id = e.owner_id
  JOIN pits t ON t.id = x.pit_id
  WHERE e.sensitive = 1 AND e.deleted_at IS NULL AND t.sensitive_enabled = 1
''';

extension SensitiveQueries on AppDatabase {
  Set<TableInfo> get _sensitiveTables => {
    pits,
    officialImages,
    fanArts,
    junkImages,
    materialImages,
    entityImages,
    ideas,
    drafts,
    pieces,
    oshiRecords,
  };

  /// 目前「有效敏感」的圖檔名集合（見 [_effectiveSensitiveSql]）。每次相關資料表有變動就重算，
  /// 內容沒變時不重送。
  Stream<Set<String>> watchSensitiveFiles() {
    Set<String>? last;
    return watchAssembled(this, _sensitiveTables, () async {
      final rows = await customSelect(
        _effectiveSensitiveSql,
        readsFrom: _sensitiveTables,
      ).get();
      return {
        for (final r in rows) ...{
          r.read<String>('f'),
          if ((r.readNullable<String>('p') ?? '').isNotEmpty)
            r.read<String>('p'),
        },
      };
    }).where((s) {
      final same =
          last != null && last!.length == s.length && last!.containsAll(s);
      last = s;
      return !same;
    });
  }

  // ---- 目標圖片列 ----

  /// 多選對象底下的所有圖片列：(表, 列 id, 目前是否已標記)。
  Future<List<_ImgRow>> _imageRows(
    SensitiveSource src,
    Iterable<String> ids,
  ) async {
    final list = ids.toList();
    switch (src) {
      case SensitiveSource.official:
        return [
          for (final r in await (select(
            officialImages,
          )..where((i) => i.id.isIn(list) & i.deletedAt.isNull())).get())
            _ImgRow(r.id, r.pitId, r.sensitive),
        ];
      case SensitiveSource.fan:
        return [
          for (final r in await (select(
            fanArts,
          )..where((i) => i.id.isIn(list) & i.deletedAt.isNull())).get())
            _ImgRow(r.id, r.pitId, r.sensitive),
        ];
      case SensitiveSource.junk:
        return [
          for (final r in await (select(
            junkImages,
          )..where((i) => i.id.isIn(list) & i.deletedAt.isNull())).get())
            _ImgRow(r.id, r.pitId, r.sensitive),
        ];
      case SensitiveSource.material:
        return [
          for (final r in await (select(
            materialImages,
          )..where((i) => i.id.isIn(list) & i.deletedAt.isNull())).get())
            _ImgRow(r.id, null, r.sensitive),
        ];
      case SensitiveSource.idea:
      case SensitiveSource.draft:
      case SensitiveSource.piece:
      case SensitiveSource.oshi:
        final type = src.ownerType!;
        final pitOf = await _ownerPits(type, list);
        return [
          for (final r
              in await (select(entityImages)..where(
                    (e) =>
                        e.ownerType.equalsValue(type) &
                        e.ownerId.isIn(list) &
                        e.deletedAt.isNull(),
                  ))
                  .get())
            _ImgRow(r.id, pitOf[r.ownerId], r.sensitive),
        ];
    }
  }

  Future<Map<String, String>> _ownerPits(
    OwnerType type,
    List<String> ids,
  ) async {
    switch (type) {
      case OwnerType.idea:
        return {
          for (final r in await (select(
            ideas,
          )..where((x) => x.id.isIn(ids))).get())
            r.id: r.pitId,
        };
      case OwnerType.draft:
        return {
          for (final r in await (select(
            drafts,
          )..where((x) => x.id.isIn(ids))).get())
            r.id: r.pitId,
        };
      case OwnerType.piece:
        return {
          for (final r in await (select(
            pieces,
          )..where((x) => x.id.isIn(ids))).get())
            r.id: r.pitId,
        };
      case OwnerType.oshi:
        return {
          for (final r in await (select(
            oshiRecords,
          )..where((x) => x.id.isIn(ids))).get())
            r.id: r.pitId,
        };
    }
  }

  /// 這些對象底下的圖：共幾張、其中幾張已標記。
  Future<({int total, int marked})> sensitiveCounts(
    SensitiveSource src,
    Iterable<String> ids,
  ) async {
    final rows = await _imageRows(src, ids);
    return (total: rows.length, marked: rows.where((r) => r.marked).length);
  }

  /// 多選的「敏感」動作該做什麼：有任何一張還沒標 → 全部標上（`true`）；
  /// 全部都標了 → 全部取消（`false`）。沒有任何圖＝null（沒事可做）。
  Future<bool?> nextSensitiveValue(
    SensitiveSource src,
    Iterable<String> ids,
  ) async {
    final c = await sensitiveCounts(src, ids);
    if (c.total == 0) return null;
    return c.marked < c.total;
  }

  /// 這些對象裡有幾張是**坑封面**（主頁卡片的封面 `Pits.coverImageId`）。
  /// 多選標敏感前用它決定要不要跳「標為敏感內容？…會從封面移除」確認。
  Future<int> coverCountAmong(SensitiveSource src, Iterable<String> ids) async {
    final rows = await _imageRows(src, ids);
    if (rows.isEmpty) return 0;
    final covers = await (select(
      pits,
    )..where((p) => p.coverImageId.isIn(rows.map((r) => r.id)))).get();
    return covers.length;
  }

  /// 把 [ids] 底下的圖標成敏感（[value]＝true）或取消。回傳實際改動的張數。
  /// - 只動狀態不同的列，並更新 updatedAt（同步）；腦洞／草稿／成圖／推活則一併更新紀錄的 updatedAt。
  /// - 標上敏感時：若有圖是**坑封面**，封面改用坑內最新一張沒有標記敏感的圖，沒有就清成 null
  ///   （顯示坑名第一個字）；各格自己選的封面若是被標的圖也清掉（回到「該格最新一張沒標記的」）。
  Future<int> setSensitive(
    SensitiveSource src,
    Iterable<String> ids,
    bool value,
  ) => transaction(() async {
    final rows = await _imageRows(src, ids);
    final todo = rows.where((r) => r.marked != value).toList();
    if (todo.isEmpty) return 0;
    final now = DateTime.now();
    final todoIds = todo.map((r) => r.id).toList();
    switch (src) {
      case SensitiveSource.official:
        await (update(officialImages)..where((i) => i.id.isIn(todoIds))).write(
          OfficialImagesCompanion(
            sensitive: Value(value),
            updatedAt: Value(now),
          ),
        );
      case SensitiveSource.fan:
        await (update(fanArts)..where((i) => i.id.isIn(todoIds))).write(
          FanArtsCompanion(sensitive: Value(value), updatedAt: Value(now)),
        );
      case SensitiveSource.junk:
        await (update(junkImages)..where((i) => i.id.isIn(todoIds))).write(
          JunkImagesCompanion(sensitive: Value(value), updatedAt: Value(now)),
        );
      case SensitiveSource.material:
        await (update(materialImages)..where((i) => i.id.isIn(todoIds))).write(
          MaterialImagesCompanion(
            sensitive: Value(value),
            updatedAt: Value(now),
          ),
        );
      case SensitiveSource.idea:
      case SensitiveSource.draft:
      case SensitiveSource.piece:
      case SensitiveSource.oshi:
        await (update(entityImages)..where((e) => e.id.isIn(todoIds))).write(
          EntityImagesCompanion(sensitive: Value(value)),
        );
        final owners = await (select(
          entityImages,
        )..where((e) => e.id.isIn(todoIds))).get();
        final ownerIds = {for (final e in owners) e.ownerId}.toList();
        switch (src.ownerType!) {
          case OwnerType.idea:
            await (update(ideas)..where((x) => x.id.isIn(ownerIds))).write(
              IdeasCompanion(updatedAt: Value(now)),
            );
          case OwnerType.draft:
            await (update(drafts)..where((x) => x.id.isIn(ownerIds))).write(
              DraftsCompanion(updatedAt: Value(now)),
            );
          case OwnerType.piece:
            await (update(pieces)..where((x) => x.id.isIn(ownerIds))).write(
              PiecesCompanion(updatedAt: Value(now)),
            );
          case OwnerType.oshi:
            await (update(oshiRecords)..where((x) => x.id.isIn(ownerIds)))
                .write(OshiRecordsCompanion(updatedAt: Value(now)));
        }
    }
    if (value) {
      for (final pitId in {
        for (final r in todo)
          if (r.pitId != null) r.pitId!,
      }) {
        await _dropSensitiveCovers(pitId, todoIds);
      }
    }
    return todo.length;
  });

  /// 編輯單張圖時標成敏感：處理封面（見 [setSensitive]）。[table] 是官方圖或同人圖的表。
  Future<void> dropCoversOfSensitiveRow(
    TableInfo<Table, dynamic> table,
    String id,
  ) async {
    final pitId = table == officialImages
        ? (await (select(
            officialImages,
          )..where((i) => i.id.equals(id))).getSingleOrNull())?.pitId
        : (await (select(
            fanArts,
          )..where((i) => i.id.equals(id))).getSingleOrNull())?.pitId;
    if (pitId != null) await _dropSensitiveCovers(pitId, [id]);
  }

  /// 腦洞／草稿／成圖／推活的表單存檔後：這筆紀錄底下有標成敏感的圖時，處理封面（見 [setSensitive]）。
  Future<void> dropCoversOfSensitiveOwner(
    OwnerType type,
    String ownerId,
  ) async {
    final pitId = (await _ownerPits(type, [ownerId]))[ownerId];
    if (pitId == null) return;
    final ids = [
      for (final e
          in await (select(entityImages)..where(
                (x) =>
                    x.ownerType.equalsValue(type) &
                    x.ownerId.equals(ownerId) &
                    x.deletedAt.isNull() &
                    x.sensitive.equals(true),
              ))
              .get())
        e.id,
    ];
    if (ids.isNotEmpty) await _dropSensitiveCovers(pitId, ids);
  }

  /// 圖被標成敏感之後，處理封面：見 [setSensitive]。
  Future<void> _dropSensitiveCovers(
    String pitId,
    List<String> markedIds,
  ) async {
    final pit = await (select(
      pits,
    )..where((p) => p.id.equals(pitId))).getSingleOrNull();
    if (pit == null) return;
    final now = DateTime.now();
    var companion = const PitsCompanion();
    var changed = false;
    if (pit.coverImageId != null && markedIds.contains(pit.coverImageId)) {
      companion = companion.copyWith(
        coverImageId: Value(await newestPlainImageId(pitId)),
      );
      changed = true;
    }
    if (pit.officialCoverId != null &&
        markedIds.contains(pit.officialCoverId)) {
      companion = companion.copyWith(officialCoverId: const Value(null));
      changed = true;
    }
    if (pit.fanArtCoverId != null && markedIds.contains(pit.fanArtCoverId)) {
      companion = companion.copyWith(fanArtCoverId: const Value(null));
      changed = true;
    }
    // 草稿／腦洞／成圖／推活格的封面存的是檔名。
    final markedFiles = <String>{
      for (final e in await (select(
        entityImages,
      )..where((e) => e.id.isIn(markedIds))).get())
        e.imageFile,
    };
    if (markedFiles.contains(pit.draftCoverFile)) {
      companion = companion.copyWith(draftCoverFile: const Value(null));
      changed = true;
    }
    if (markedFiles.contains(pit.ideaCoverFile)) {
      companion = companion.copyWith(ideaCoverFile: const Value(null));
      changed = true;
    }
    if (markedFiles.contains(pit.pieceCoverFile)) {
      companion = companion.copyWith(pieceCoverFile: const Value(null));
      changed = true;
    }
    if (markedFiles.contains(pit.oshiCoverFile)) {
      companion = companion.copyWith(oshiCoverFile: const Value(null));
      changed = true;
    }
    if (!changed) return;
    await (update(pits)..where((p) => p.id.equals(pitId))).write(
      companion.copyWith(updatedAt: Value(now)),
    );
  }

  /// 坑內「最新一張沒有標記敏感」、可當坑封面的圖 id（官方圖、同人圖、腦洞、草稿、成圖的圖；
  /// 不含雜物與推活；影片要有截圖才算）。「最新」＝圖片加入的時間最晚。沒有＝null。
  Future<String?> newestPlainImageId(String pitId) async {
    ({DateTime at, String id})? best;
    void consider(DateTime at, String id) {
      if (best == null || at.isAfter(best!.at)) best = (at: at, id: id);
    }

    bool usable(MediaKind k, String? poster) =>
        k != MediaKind.video || (poster ?? '').isNotEmpty;

    for (final r
        in await (select(officialImages)..where(
              (i) =>
                  i.pitId.equals(pitId) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false) &
                  i.sensitive.equals(false),
            ))
            .get()) {
      if (usable(r.kind, r.posterFile)) consider(r.createdAt, r.id);
    }
    for (final r
        in await (select(fanArts)..where(
              (i) =>
                  i.pitId.equals(pitId) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false) &
                  i.sensitive.equals(false),
            ))
            .get()) {
      if (usable(r.kind, r.posterFile)) consider(r.createdAt, r.id);
    }
    final owners = <OwnerType, List<String>>{
      OwnerType.idea: [
        for (final x in await (select(
          ideas,
        )..where((x) => x.pitId.equals(pitId) & x.deletedAt.isNull())).get())
          x.id,
      ],
      OwnerType.draft: [
        for (final x in await (select(
          drafts,
        )..where((x) => x.pitId.equals(pitId) & x.deletedAt.isNull())).get())
          x.id,
      ],
      OwnerType.piece: [
        for (final x in await (select(
          pieces,
        )..where((x) => x.pitId.equals(pitId) & x.deletedAt.isNull())).get())
          x.id,
      ],
    };
    for (final e in owners.entries) {
      if (e.value.isEmpty) continue;
      for (final r
          in await (select(entityImages)..where(
                (x) =>
                    x.ownerType.equalsValue(e.key) &
                    x.ownerId.isIn(e.value) &
                    x.deletedAt.isNull() &
                    x.sensitive.equals(false),
              ))
              .get()) {
        if (usable(r.kind, r.posterFile)) consider(r.createdAt, r.id);
      }
    }
    return best?.id;
  }

  // ---- 坑的開關 ----

  /// 坑內已標記敏感的圖張數（關閉坑的敏感內容開關前，確認視窗的「N 張」）。
  /// 官方圖、同人圖、雜物，以及腦洞／草稿／成圖／推活底下的圖。
  Future<int> sensitiveCountInPit(String pitId) async {
    final row = await customSelect(
      '''
SELECT
 (SELECT COUNT(*) FROM official_images WHERE pit_id = ?1 AND sensitive = 1 AND deleted_at IS NULL AND hidden = 0) +
 (SELECT COUNT(*) FROM fan_arts WHERE pit_id = ?1 AND sensitive = 1 AND deleted_at IS NULL AND hidden = 0) +
 (SELECT COUNT(*) FROM junk_images WHERE pit_id = ?1 AND sensitive = 1 AND deleted_at IS NULL AND hidden = 0) +
 (SELECT COUNT(*) FROM entity_images e WHERE e.sensitive = 1 AND e.deleted_at IS NULL AND (
    (e.owner_type = 'idea' AND e.owner_id IN (SELECT id FROM ideas WHERE pit_id = ?1 AND deleted_at IS NULL)) OR
    (e.owner_type = 'draft' AND e.owner_id IN (SELECT id FROM drafts WHERE pit_id = ?1 AND deleted_at IS NULL)) OR
    (e.owner_type = 'piece' AND e.owner_id IN (SELECT id FROM pieces WHERE pit_id = ?1 AND deleted_at IS NULL)) OR
    (e.owner_type = 'oshi' AND e.owner_id IN (SELECT id FROM oshi_records WHERE pit_id = ?1 AND deleted_at IS NULL)))
 ) AS n
''',
      variables: [Variable.withString(pitId)],
      readsFrom: _sensitiveTables,
    ).getSingle();
    return row.read<int>('n');
  }

  /// 開關坑的敏感內容（只改開關，標記一律保留）。
  Future<void> setPitSensitiveEnabled(String pitId, bool enabled) {
    return (update(pits)..where((p) => p.id.equals(pitId))).write(
      PitsCompanion(
        sensitiveEnabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

class _ImgRow {
  const _ImgRow(this.id, this.pitId, this.marked);
  final String id;
  final String? pitId;
  final bool marked;
}
