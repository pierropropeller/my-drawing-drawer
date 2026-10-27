import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart' show ImageRef, entityImageRef, watchAssembled;

/// 最近刪除（D-120）：刪除後保留的天數。
const kTrashKeepDays = 30;

/// 「永久刪除」的標記：把 deletedAt 改成這個時間（遠早於保留期），列從最近刪除消失；
/// 刪除狀態照常同步（LWW 以 updatedAt 為準），兩台裝置看到同一個結果。
final kTrashPurgedAt = DateTime.utc(2000);

/// 最近刪除裡的內容種類。
enum TrashKind { official, fan, junk, idea, draft, piece, oshi, material }

/// 還剩幾天會被清掉（剛刪除＝30；最少 1）。
int trashDaysLeft(DateTime deletedAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = n.difference(deletedAt).inDays;
  return (kTrashKeepDays - days).clamp(1, kTrashKeepDays);
}

/// 已過保留期（或被永久刪除）的界線：deletedAt 早於這個時間就不列出。
DateTime trashCutoff({DateTime? now}) =>
    (now ?? DateTime.now()).subtract(const Duration(days: kTrashKeepDays));

/// 最近刪除的一項（單張圖，或一筆腦洞／摸魚／成圖／推活）。
class TrashItem {
  const TrashItem({
    required this.kind,
    required this.id,
    required this.pitId,
    required this.deletedAt,
    required this.images,
    this.title,
    this.body,
    this.date,
  });
  final TrashKind kind;
  final String id;

  /// 素材庫沒有坑（null）。
  final String? pitId;
  final DateTime deletedAt;

  /// 這項的圖（官方圖／同人圖／雜物／素材庫＝一張；其他＝依排序，可能是空的）。
  final List<ImageRef> images;

  /// 腦洞／摸魚／成圖／推活的標題、內文（沒有圖時顯示文字格）。
  final String? title;
  final String? body;

  /// 腦洞／摸魚／成圖自己的日期（沒有標題也沒有內文時，名稱用「日期＋類型」，D-129）。
  final DateTime? date;

  /// 多選、還原用的鍵（種類＋id；不同表的 id 理論上不重複，保險起見帶種類）。
  String get key => '${kind.name}:$id';
}

/// 最近刪除裡的坑（坑內內容跟著坑一起，不另外列出）。
class TrashPit {
  const TrashPit({
    required this.id,
    required this.name,
    required this.deletedAt,
    required this.itemCount,
    this.coverFile,
  });
  final String id;
  final String name;
  final DateTime deletedAt;

  /// 還原時會一起回來的內容數（「N 項」）。
  final int itemCount;
  final String? coverFile;

  String get key => 'pit:$id';
}

class TrashContents {
  const TrashContents({required this.pits, required this.items});
  static const empty = TrashContents(pits: [], items: []);
  final List<TrashPit> pits;

  /// 新刪的在前。
  final List<TrashItem> items;

  int get count => pits.length + items.length;
  bool get isEmpty => count == 0;
}

extension TrashQueries on AppDatabase {
  Set<TableInfo> get _trashTables => {
    pits,
    officialImages,
    fanArts,
    junkImages,
    materialImages,
    ideas,
    drafts,
    pieces,
    oshiRecords,
    entityImages,
  };

  Stream<TrashContents> watchTrash() =>
      watchAssembled(this, _trashTables, loadTrash);

  /// 最近刪除的全部內容：已刪除的坑（含封面與項目數），以及**所屬的坑還在**的已刪除內容。
  Future<TrashContents> loadTrash({DateTime? now}) async {
    final cutoff = trashCutoff(now: now);
    final deletedPits =
        await (select(pits)
              ..where(
                (p) =>
                    p.deletedAt.isNotNull() &
                    p.deletedAt.isBiggerThanValue(cutoff),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.deletedAt)]))
            .get();
    // 所有已刪除的坑（不論多久以前）：它們的內容不在下方格子出現。
    final goneIds = {
      for (final p in await (select(
        pits,
      )..where((p) => p.deletedAt.isNotNull())).get())
        p.id,
    };

    final trashPits = <TrashPit>[];
    for (final p in deletedPits) {
      trashPits.add(
        TrashPit(
          id: p.id,
          name: p.name,
          deletedAt: p.deletedAt!,
          itemCount: await _pitItemCount(p.id, p.deletedAt!),
          coverFile: await _pitCoverFile(p),
        ),
      );
    }

    Expression<bool> recent(GeneratedColumn<DateTime> c) =>
        c.isNotNull() & c.isBiggerThanValue(cutoff);
    final items = <TrashItem>[];

    for (final r in await (select(
      officialImages,
    )..where((o) => recent(o.deletedAt) & o.hidden.equals(false))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.official,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: [
            ImageRef(
              r.imageFile,
              r.width,
              r.height,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
              sensitive: r.sensitive,
            ),
          ],
        ),
      );
    }
    for (final r in await (select(
      fanArts,
    )..where((o) => recent(o.deletedAt) & o.hidden.equals(false))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.fan,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: [
            ImageRef(
              r.imageFile,
              r.width,
              r.height,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
              sensitive: r.sensitive,
            ),
          ],
        ),
      );
    }
    for (final r in await (select(
      junkImages,
    )..where((o) => recent(o.deletedAt) & o.hidden.equals(false))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.junk,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: [
            ImageRef(
              r.imageFile,
              r.width,
              r.height,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
              sensitive: r.sensitive,
            ),
          ],
        ),
      );
    }
    for (final r in await (select(
      materialImages,
    )..where((o) => recent(o.deletedAt))).get()) {
      items.add(
        TrashItem(
          kind: TrashKind.material,
          id: r.id,
          pitId: null,
          deletedAt: r.deletedAt!,
          images: [
            ImageRef(
              r.imageFile,
              r.width,
              r.height,
              kind: r.kind,
              durationMs: r.durationMs,
              poster: r.posterFile,
              sensitive: r.sensitive,
            ),
          ],
        ),
      );
    }
    for (final r in await (select(
      ideas,
    )..where((o) => recent(o.deletedAt))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.idea,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: await _ownerImages(OwnerType.idea, r.id),
          title: r.title,
          body: r.body,
          date: r.date,
        ),
      );
    }
    for (final r in await (select(
      drafts,
    )..where((o) => recent(o.deletedAt))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.draft,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: await _ownerImages(OwnerType.draft, r.id),
          title: r.title,
          body: r.body,
          date: r.date,
        ),
      );
    }
    for (final r in await (select(
      pieces,
    )..where((o) => recent(o.deletedAt))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.piece,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: await _ownerImages(OwnerType.piece, r.id),
          title: r.title,
          body: r.body,
          date: r.finishedAt,
        ),
      );
    }
    for (final r in await (select(
      oshiRecords,
    )..where((o) => recent(o.deletedAt))).get()) {
      if (goneIds.contains(r.pitId)) continue;
      items.add(
        TrashItem(
          kind: TrashKind.oshi,
          id: r.id,
          pitId: r.pitId,
          deletedAt: r.deletedAt!,
          images: await _ownerImages(OwnerType.oshi, r.id),
          title: r.title,
          body: r.description,
        ),
      );
    }
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return TrashContents(pits: trashPits, items: items);
  }

  Future<List<ImageRef>> _ownerImages(OwnerType type, String id) async {
    final rows =
        await (select(entityImages)
              ..where(
                (e) =>
                    e.ownerType.equalsValue(type) &
                    e.ownerId.equals(id) &
                    e.deletedAt.isNull(),
              )
              ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
            .get();
    return [for (final r in rows) entityImageRef(r)];
  }

  /// 坑的封面檔名（坑本身已刪除，所以不經 `watchPit`）。
  Future<String?> _pitCoverFile(Pit p) async {
    final own = p.coverFile;
    if (own != null && own.isNotEmpty) return own;
    final id = p.coverImageId;
    if (id == null) return null;
    for (final t in <TableInfo>[officialImages, fanArts]) {
      final r = await (customSelect(
        'SELECT image_file, poster_file, kind FROM ${t.actualTableName} '
        'WHERE id = ? LIMIT 1',
        variables: [Variable<String>(id)],
        readsFrom: {t},
      )).getSingleOrNull();
      if (r != null) {
        final kind = r.read<String>('kind');
        return kind == 'video'
            ? r.readNullable<String>('poster_file')
            : r.read<String>('image_file');
      }
    }
    return null;
  }

  /// 還原坑時會一起回來的內容：坑內沒刪除的，加上跟坑同一刻被刪的。
  Future<int> _pitItemCount(String pitId, DateTime at) async {
    final row = await customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM official_images WHERE pit_id = ?1 AND hidden = 0 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM fan_arts WHERE pit_id = ?1 AND hidden = 0 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM junk_images WHERE pit_id = ?1 AND hidden = 0 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM ideas WHERE pit_id = ?1 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM drafts WHERE pit_id = ?1 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM pieces WHERE pit_id = ?1 AND (deleted_at IS NULL OR deleted_at = ?2)) +
        (SELECT COUNT(*) FROM oshi_records WHERE pit_id = ?1 AND (deleted_at IS NULL OR deleted_at = ?2))
        AS n
      ''',
      variables: [Variable<String>(pitId), Variable<DateTime>(at)],
      readsFrom: _trashTables,
    ).getSingle();
    return row.read<int>('n');
  }

  /// 還原坑：坑本身，加上跟坑同一刻被刪的內容（刪除坑時一併移入的雜物、推活）。
  Future<void> restorePit(String pitId) => transaction(() async {
    final p = await (select(
      pits,
    )..where((x) => x.id.equals(pitId))).getSingleOrNull();
    final at = p?.deletedAt;
    if (p == null || at == null) return;
    final now = DateTime.now();
    await (update(pits)..where((x) => x.id.equals(pitId))).write(
      PitsCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
    );
    await (update(
      junkImages,
    )..where((x) => x.pitId.equals(pitId) & x.deletedAt.equals(at))).write(
      JunkImagesCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
    );
    await (update(
      oshiRecords,
    )..where((x) => x.pitId.equals(pitId) & x.deletedAt.equals(at))).write(
      OshiRecordsCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
    );
  });

  /// 還原內容：回到原本的坑和相冊；那一格在淺坑被關掉了就自動重新開啟（雜物同時打開開關）。
  /// 官方圖／同人圖／雜物連同同一刻被刪的隱藏分身（同 imageKey）一起還原。
  Future<void> restoreItems(Iterable<TrashItem> items) => transaction(() async {
    final now = DateTime.now();
    final reopen = <String, Set<PitSectionKey>>{};
    void need(String? pitId, PitSectionKey k) {
      if (pitId != null) (reopen[pitId] ??= {}).add(k);
    }

    for (final it in items) {
      const clear = Value<DateTime?>(null);
      switch (it.kind) {
        case TrashKind.official:
          await _restoreAlbumRow(officialImages, it.id, it.deletedAt, now);
          need(it.pitId, PitSectionKey.official);
        case TrashKind.fan:
          await _restoreAlbumRow(fanArts, it.id, it.deletedAt, now);
          need(it.pitId, PitSectionKey.fan);
        case TrashKind.junk:
          await _restoreAlbumRow(junkImages, it.id, it.deletedAt, now);
          need(it.pitId, PitSectionKey.junk);
        case TrashKind.material:
          await (update(
            materialImages,
          )..where((x) => x.id.equals(it.id))).write(
            MaterialImagesCompanion(deletedAt: clear, updatedAt: Value(now)),
          );
        case TrashKind.idea:
          await (update(ideas)..where((x) => x.id.equals(it.id))).write(
            IdeasCompanion(deletedAt: clear, updatedAt: Value(now)),
          );
          need(it.pitId, PitSectionKey.idea);
        case TrashKind.draft:
          await (update(drafts)..where((x) => x.id.equals(it.id))).write(
            DraftsCompanion(deletedAt: clear, updatedAt: Value(now)),
          );
          need(it.pitId, PitSectionKey.draft);
        case TrashKind.piece:
          await (update(pieces)..where((x) => x.id.equals(it.id))).write(
            PiecesCompanion(deletedAt: clear, updatedAt: Value(now)),
          );
          need(it.pitId, PitSectionKey.piece);
        case TrashKind.oshi:
          await (update(oshiRecords)..where((x) => x.id.equals(it.id))).write(
            OshiRecordsCompanion(deletedAt: clear, updatedAt: Value(now)),
          );
          need(it.pitId, PitSectionKey.oshi);
      }
    }
    for (final e in reopen.entries) {
      await _reopenSections(e.key, e.value, now);
    }
  });

  Future<void> _restoreAlbumRow(
    TableInfo<Table, dynamic> table,
    String id,
    DateTime at,
    DateTime now,
  ) async {
    final name = table.actualTableName;
    final row = await customSelect(
      'SELECT image_key FROM $name WHERE id = ?',
      variables: [Variable<String>(id)],
      readsFrom: {table},
    ).getSingleOrNull();
    final key = row?.read<String>('image_key') ?? '';
    // 這一列，加上同一刻被刪的隱藏分身（任何一格）。
    await customUpdate(
      'UPDATE $name SET deleted_at = NULL, updated_at = ?2 WHERE id = ?1',
      variables: [Variable<String>(id), Variable<DateTime>(now)],
      updates: {table},
    );
    if (key.isEmpty) return;
    for (final t in <TableInfo>[officialImages, fanArts, junkImages]) {
      await customUpdate(
        'UPDATE ${t.actualTableName} SET deleted_at = NULL, updated_at = ?3 '
        'WHERE image_key = ?1 AND hidden = 1 AND deleted_at = ?2',
        variables: [
          Variable<String>(key),
          Variable<DateTime>(at),
          Variable<DateTime>(now),
        ],
        updates: {t},
      );
    }
  }

  /// 淺坑被關掉的格子重新開啟；雜物另外打開 `junkEnabled`（現坑的雜物入口靠它）。
  Future<void> _reopenSections(
    String pitId,
    Set<PitSectionKey> keys,
    DateTime now,
  ) async {
    final p = await (select(
      pits,
    )..where((x) => x.id.equals(pitId))).getSingleOrNull();
    if (p == null) return;
    final sections = {...p.enabledSections};
    var changed = false;
    if (p.status != PitStatus.active) {
      for (final k in keys) {
        changed |= sections.add(k);
      }
    }
    final junk = keys.contains(PitSectionKey.junk) && !p.junkEnabled;
    if (!changed && !junk) return;
    await (update(pits)..where((x) => x.id.equals(pitId))).write(
      PitsCompanion(
        enabledSections: Value(sections),
        junkEnabled: junk ? const Value(true) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  /// 永久刪除：從最近刪除拿走（deletedAt 改成 [kTrashPurgedAt]）。坑連同坑內所有內容。
  Future<void> purgeTrash({
    Iterable<TrashItem> items = const [],
    Iterable<String> pitIds = const [],
  }) => transaction(() async {
    final now = DateTime.now();
    final gone = Value<DateTime?>(kTrashPurgedAt);
    for (final it in items) {
      switch (it.kind) {
        case TrashKind.official:
        case TrashKind.fan:
        case TrashKind.junk:
          final t = switch (it.kind) {
            TrashKind.official => officialImages,
            TrashKind.fan => fanArts,
            _ => junkImages,
          } as TableInfo<Table, dynamic>;
          await customUpdate(
            'UPDATE ${t.actualTableName} SET deleted_at = ?2, updated_at = ?3 '
            'WHERE id = ?1',
            variables: [
              Variable<String>(it.id),
              Variable<DateTime>(kTrashPurgedAt),
              Variable<DateTime>(now),
            ],
            updates: {t},
          );
        case TrashKind.material:
          await (update(
            materialImages,
          )..where((x) => x.id.equals(it.id))).write(
            MaterialImagesCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case TrashKind.idea:
          await (update(ideas)..where((x) => x.id.equals(it.id))).write(
            IdeasCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case TrashKind.draft:
          await (update(drafts)..where((x) => x.id.equals(it.id))).write(
            DraftsCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case TrashKind.piece:
          await (update(pieces)..where((x) => x.id.equals(it.id))).write(
            PiecesCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
        case TrashKind.oshi:
          await (update(oshiRecords)..where((x) => x.id.equals(it.id))).write(
            OshiRecordsCompanion(deletedAt: gone, updatedAt: Value(now)),
          );
      }
    }
    for (final id in pitIds) {
      await (update(pits)..where((x) => x.id.equals(id))).write(
        PitsCompanion(deletedAt: gone, updatedAt: Value(now)),
      );
      // 坑內還沒刪的內容一併標成刪除（坑已經永久刪除，它們不會再出現）。
      for (final t in <TableInfo>[
        officialImages,
        fanArts,
        junkImages,
        ideas,
        drafts,
        pieces,
        oshiRecords,
      ]) {
        await customUpdate(
          'UPDATE ${t.actualTableName} SET deleted_at = ?2, updated_at = ?3 '
          'WHERE pit_id = ?1 AND (deleted_at IS NULL OR deleted_at > ?2)',
          variables: [
            Variable<String>(id),
            Variable<DateTime>(kTrashPurgedAt),
            Variable<DateTime>(now),
          ],
          updates: {t},
        );
      }
    }
  });

  /// 清掉過了保留期的項目（D-120）：deletedAt 早於 [trashCutoff] 的一律標成永久刪除
  /// （坑連同坑內內容）。App 啟動和每次同步前各跑一次；狀態隨同步帶到另一台裝置。
  /// 回傳清掉的列數。
  Future<int> purgeExpiredTrash({DateTime? now}) => transaction(() async {
    final at = now ?? DateTime.now();
    final cutoff = trashCutoff(now: at);
    final expiredPits =
        await (select(pits)..where(
              (p) =>
                  p.deletedAt.isNotNull() &
                  p.deletedAt.isBiggerThanValue(kTrashPurgedAt) &
                  p.deletedAt.isSmallerOrEqualValue(cutoff),
            ))
            .get();
    if (expiredPits.isNotEmpty) {
      await purgeTrash(pitIds: [for (final p in expiredPits) p.id]);
    }
    var n = expiredPits.length;
    for (final t in <TableInfo>[
      officialImages,
      fanArts,
      junkImages,
      materialImages,
      ideas,
      drafts,
      pieces,
      oshiRecords,
    ]) {
      n += await customUpdate(
        'UPDATE ${t.actualTableName} SET deleted_at = ?1, updated_at = ?2 '
        'WHERE deleted_at IS NOT NULL AND deleted_at > ?1 AND deleted_at <= ?3',
        variables: [
          Variable<DateTime>(kTrashPurgedAt),
          Variable<DateTime>(at),
          Variable<DateTime>(cutoff),
        ],
        updates: {t},
      );
    }
    return n;
  });
}
