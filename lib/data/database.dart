import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'ref_view_queries.dart' show RefViewStates;
import 'tables.dart';

export 'tables.dart'
    show
        GoalKind,
        GoalPeriod,
        MaterialCategory,
        MediaKind,
        OwnerType,
        TagTarget;

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Pits,
    OfficialGroups,
    OfficialImages,
    FanArts,
    JunkImages,
    Tags,
    Ideas,
    Drafts,
    Pieces,
    OshiRecords,
    MaterialImages,
    EntityImages,
    PieceLinks,
    TagLinks,
    IdeaDrafts,
    IdeaPieces,
    DraftPieces,
    Goals,
    YearReviewMonths,
    ReviewSettings,
    Outbox,
    SyncDocs,
    RefViewStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'huakeng'));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v2：圖片記錄寬高，瀑布流不需解碼就能排版。
        await m.addColumn(officialImages, officialImages.width);
        await m.addColumn(officialImages, officialImages.height);
        await m.addColumn(fanArts, fanArts.width);
        await m.addColumn(fanArts, fanArts.height);
      }
      if (from < 3) {
        // v3：腦洞／草稿／成圖的圖片也記錄寬高。
        await m.addColumn(entityImages, entityImages.width);
        await m.addColumn(entityImages, entityImages.height);
      }
      if (from < 4) {
        // v4：同步記錄（已同步到遠端的文件版本）。
        await m.createTable(syncDocs);
      }
      if (from < 5) {
        // v5：坑內兩格各自的封面、分組種類（官方／同人圖）、同人圖改用分組。
        await m.addColumn(pits, pits.officialCoverId);
        await m.addColumn(pits, pits.fanArtCoverId);
        await m.addColumn(officialGroups, officialGroups.kind);
        await m.addColumn(fanArts, fanArts.groupId);
        await _migrateGroupsV5();
      }
      if (from < 6) {
        await _migrateV6(m);
      }
      if (from < 7) {
        await _migrateV7(m);
      }
      if (from < 8) {
        // v8：素材庫（D-071）。全新的表，沒有舊資料要回填。
        await m.createTable(materialImages);
      }
      if (from < 9) {
        await _migrateV9(m);
      }
      if (from < 10) {
        // v10：參考圖檢視的每張圖檢視狀態（純本機、不同步）。全新的表，沒有舊資料。
        await m.createTable(refViewStates);
      }
    },
  );

  /// v9：坑內其餘四格的封面（Pits 四欄）、所有放圖的表加媒體欄位（kind／durationMs／posterFile，D-080）。
  /// 每個欄位先確認存在與否再加（較舊版本的遷移若是整張建表，已經帶有新欄位）。
  /// 既有圖片一律是 `image`；副檔名是 .gif 的回填成 `gif`，讓升級後 GIF 馬上能播放。
  Future<void> _migrateV9(Migrator m) async {
    Future<Set<String>> columnsOf(String table) async => {
      for (final r in await customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'),
    };

    Future<void> ensure(
      TableInfo<Table, dynamic> table,
      List<GeneratedColumn> cols,
    ) async {
      final have = await columnsOf(table.actualTableName);
      if (have.isEmpty) {
        await m.createTable(table);
        return;
      }
      for (final c in cols) {
        if (!have.contains(c.$name)) await m.addColumn(table, c);
      }
    }

    await ensure(pits, [
      pits.draftCoverFile,
      pits.ideaCoverFile,
      pits.pieceCoverFile,
      pits.oshiCoverFile,
    ]);
    await ensure(officialImages, [
      officialImages.kind,
      officialImages.durationMs,
      officialImages.posterFile,
    ]);
    await ensure(fanArts, [
      fanArts.kind,
      fanArts.durationMs,
      fanArts.posterFile,
    ]);
    await ensure(junkImages, [
      junkImages.kind,
      junkImages.durationMs,
      junkImages.posterFile,
    ]);
    await ensure(materialImages, [
      materialImages.kind,
      materialImages.durationMs,
      materialImages.posterFile,
    ]);
    await ensure(entityImages, [
      entityImages.kind,
      entityImages.durationMs,
      entityImages.posterFile,
    ]);
    // 不改 updated_at：每台裝置各自升級都會得到同樣的結果，不需要同步。
    for (final t in [
      'official_images',
      'fan_arts',
      'junk_images',
      'material_images',
      'entity_images',
    ]) {
      await customStatement(
        "UPDATE $t SET kind = 'gif' WHERE kind = 'image' AND lower(image_file) LIKE '%.gif'",
      );
    }
  }

  /// v7：推活（OshiRecords 表＋每個既有坑補三個預設推活分組）、
  /// 腦洞／草稿的 `date`（回填成 createdAt，D-070）。
  /// 官方圖 tag、草稿↔成圖關係不需要改結構（TagLinks／DraftPieces 早就有）。
  Future<void> _migrateV7(Migrator m) async {
    Future<Set<String>> columnsOf(String table) async => {
      for (final r in await customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'),
    };

    // 腦洞／草稿加 date：NOT NULL 欄位必須有常數預設才能 ALTER，加完立刻用 created_at 回填。
    // 缺表（極舊的測試資料庫）就整張建立。
    for (final t in <TableInfo<Table, dynamic>>[ideas, drafts]) {
      final name = t.actualTableName;
      final have = await columnsOf(name);
      if (have.isEmpty) {
        await m.createTable(t);
      } else if (!have.contains('date')) {
        await customStatement(
          'ALTER TABLE $name ADD COLUMN date INTEGER NOT NULL DEFAULT 0',
        );
        await customStatement('UPDATE $name SET date = created_at');
      }
    }

    await m.createTable(oshiRecords);

    // 既有坑補預設推活分組。id 由坑 id 決定（兩台裝置各自升級也會得到同一批列，
    // 同步後不會重複）；updated_at 設成最小值，使用者在別台改過或刪過的版本永遠勝出。
    if ((await columnsOf('pits')).isEmpty) return;
    for (final r in await customSelect('SELECT id FROM pits').get()) {
      await seedOshiGroups(r.read<String>('id'), deterministic: true);
    }
  }

  /// 在 [pitId] 建立預設推活分組。[deterministic]＝id 由坑 id 推得（遷移用，可重複執行）。
  /// 只在這個坑**從沒有過**推活分組（連已刪除的都算）時才建立，
  /// 所以使用者刪光分組後不會被補回來。
  Future<void> seedOshiGroups(
    String pitId, {
    bool deterministic = false,
  }) async {
    final any = await customSelect(
      "SELECT 1 FROM official_groups WHERE pit_id = ? AND kind = 'oshi' LIMIT 1",
      variables: [Variable<String>(pitId)],
    ).get();
    if (any.isNotEmpty) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (var i = 0; i < defaultOshiGroups.length; i++) {
      final id = deterministic ? 'oshi-default-$pitId-$i' : uuid.v4();
      await customStatement(
        'INSERT OR IGNORE INTO official_groups '
        '(id, created_at, updated_at, device_id, pit_id, kind, name, sort_order) '
        "VALUES (?, ?, ?, '', ?, 'oshi', ?, ?)",
        [
          id,
          nowSec,
          deterministic ? 1 : nowSec,
          pitId,
          defaultOshiGroups[i],
          i,
        ],
      );
    }
    // customStatement 不會自動通知 drift 的 watch 串流。
    notifyUpdates({
      TableUpdate.onTable(officialGroups, kind: UpdateKind.insert),
    });
  }

  /// v6：雜物、移動（imageKey／hidden）、成圖公開發佈與商稿欄位、回顧月份對齊。
  /// 每個欄位先確認存在與否再加，缺表時整張建立，讓任何舊版本都能升上來。
  Future<void> _migrateV6(Migrator m) async {
    Future<Set<String>> columnsOf(String table) async => {
      for (final r in await customSelect('PRAGMA table_info($table)').get())
        r.read<String>('name'),
    };

    Future<void> ensure(
      TableInfo<Table, dynamic> table,
      List<GeneratedColumn> cols,
    ) async {
      final have = await columnsOf(table.actualTableName);
      if (have.isEmpty) {
        await m.createTable(table);
        return;
      }
      for (final c in cols) {
        if (!have.contains(c.$name)) await m.addColumn(table, c);
      }
    }

    await ensure(pits, [pits.junkEnabled]);
    await ensure(officialImages, [
      officialImages.imageKey,
      officialImages.hidden,
    ]);
    await ensure(fanArts, [fanArts.imageKey, fanArts.hidden]);
    await m.createTable(junkImages);
    // 既有圖片的 imageKey 回填成自己的 id。
    await customStatement(
      "UPDATE official_images SET image_key = id WHERE image_key = ''",
    );
    await customStatement(
      "UPDATE fan_arts SET image_key = id WHERE image_key = ''",
    );

    final hadPieces = (await columnsOf('pieces')).isNotEmpty;
    await ensure(pieces, [
      pieces.isPublished,
      pieces.publishedAt,
      pieces.isCommission,
      pieces.client,
      pieces.amount,
      pieces.currency,
      pieces.receivedAmount,
      pieces.dueAt,
    ]);
    if (hadPieces) {
      // 舊版的成圖一律是公開的；發佈日期沿用完成日期。
      await customStatement(
        'UPDATE pieces SET is_published = 1, published_at = finished_at',
      );
    }
    await ensure(reviewSettings, [
      reviewSettings.monthAlign,
      reviewSettings.updatedAt,
    ]);
  }

  /// 官方圖預設分組。
  static const defaultGroups = ['設定圖', '海報宣傳', '素材', '自用截圖', '圖透', '官方周邊'];

  /// 好看同人圖預設分組（＝各出處）。
  static const defaultFanGroups = ['推特', '小紅書', 'lofter', '朋友發的', '網上搜的'];

  /// 推活預設分組（D-057）。
  static const defaultOshiGroups = ['線下照片', '遊戲截圖', '對話記錄'];

  /// 舊坑：「自定義」改名為「圖透」（圖片保留），補上「官方周邊」；
  /// 建立同人圖分組並把舊的出處文字對應過去。
  Future<void> _migrateGroupsV5() async {
    // 只取 id：升級途中 pits 還沒有後來新增的欄位，不能用資料類別整列讀。
    final pitIds = [
      for (final r in await customSelect('SELECT id FROM pits').get())
        r.read<String>('id'),
    ];
    for (final pitId in pitIds) {
      final official =
          await (select(officialGroups)
                ..where(
                  (g) =>
                      g.pitId.equals(pitId) &
                      g.kind.equals('official') &
                      g.deletedAt.isNull(),
                )
                ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
              .get();
      for (final g in official.where((g) => g.name == '自定義')) {
        await (update(officialGroups)..where((x) => x.id.equals(g.id))).write(
          const OfficialGroupsCompanion(name: Value('圖透')),
        );
      }
      if (!official.any((g) => g.name == '官方周邊')) {
        await into(officialGroups).insert(
          OfficialGroupsCompanion.insert(
            pitId: pitId,
            name: '官方周邊',
            sortOrder: Value(official.length),
          ),
        );
      }
      for (var i = 0; i < defaultFanGroups.length; i++) {
        final g = await into(officialGroups).insertReturning(
          OfficialGroupsCompanion.insert(
            pitId: pitId,
            kind: const Value('fan'),
            name: defaultFanGroups[i],
            sortOrder: Value(i),
          ),
        );
        await (update(fanArts)..where(
              (f) =>
                  f.pitId.equals(pitId) & f.source.equals(defaultFanGroups[i]),
            ))
            .write(FanArtsCompanion(groupId: Value(g.id)));
      }
    }
  }

  /// 新增坑並建立預設官方圖分組。
  Future<String> createPit({
    required String name,
    String? description,
    bool junkEnabled = false,
  }) {
    return transaction(() async {
      final pit = await into(pits).insertReturning(
        PitsCompanion.insert(
          name: name,
          description: Value(description),
          junkEnabled: Value(junkEnabled),
        ),
      );
      for (var i = 0; i < defaultGroups.length; i++) {
        await into(officialGroups).insert(
          OfficialGroupsCompanion.insert(
            pitId: pit.id,
            name: defaultGroups[i],
            sortOrder: Value(i),
          ),
        );
      }
      for (var i = 0; i < defaultFanGroups.length; i++) {
        await into(officialGroups).insert(
          OfficialGroupsCompanion.insert(
            pitId: pit.id,
            kind: const Value('fan'),
            name: defaultFanGroups[i],
            sortOrder: Value(i),
          ),
        );
      }
      for (var i = 0; i < defaultOshiGroups.length; i++) {
        await into(officialGroups).insert(
          OfficialGroupsCompanion.insert(
            pitId: pit.id,
            kind: const Value('oshi'),
            name: defaultOshiGroups[i],
            sortOrder: Value(i),
          ),
        );
      }
      return pit.id;
    });
  }

  /// 主頁的坑依「最後更新」排序：坑本身，或坑內任何內容（圖、同人圖、腦洞、草稿、成圖）有更新都算。
  Stream<List<Pit>> watchPits({required bool archived}) {
    return customSelect(
      '''
      SELECT p.*, MAX(
        p.updated_at,
        COALESCE((SELECT MAX(updated_at) FROM official_images WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM fan_arts WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM junk_images WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM ideas WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM drafts WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM pieces WHERE pit_id = p.id), 0),
        COALESCE((SELECT MAX(updated_at) FROM oshi_records WHERE pit_id = p.id), 0)
      ) AS last_activity
      FROM pits p
      WHERE p.deleted_at IS NULL AND p.archived = ?
      ORDER BY last_activity DESC, p.created_at DESC
      ''',
      variables: [Variable<bool>(archived)],
      readsFrom: {
        pits,
        officialImages,
        fanArts,
        junkImages,
        ideas,
        drafts,
        pieces,
        oshiRecords,
      },
    ).watch().map((rows) => [for (final r in rows) pits.map(r.data)]);
  }

  Stream<Pit?> watchPit(String id) {
    return (select(pits)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  Future<void> updatePit(
    String id, {
    required String name,
    String? description,
    required bool archived,
    bool? junkEnabled, // null＝不變
  }) {
    return (update(pits)..where((p) => p.id.equals(id))).write(
      PitsCompanion(
        name: Value(name),
        description: Value(description),
        archived: Value(archived),
        junkEnabled: junkEnabled == null
            ? const Value.absent()
            : Value(junkEnabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 軟刪除（同步用）；坑內的雜物、推活紀錄一併軟刪除。
  Future<void> deletePit(String id) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(pits)..where((p) => p.id.equals(id))).write(
        PitsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(
        junkImages,
      )..where((j) => j.pitId.equals(id) & j.deletedAt.isNull())).write(
        JunkImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(
        oshiRecords,
      )..where((o) => o.pitId.equals(id) & o.deletedAt.isNull())).write(
        OshiRecordsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// 坑內各分類數量；`openIdeas` 為未孵腦洞（沒有連接草稿或成圖）。
  Stream<PitStats> watchPitStats(String pitId) {
    return customSelect(
      '''
      WITH p(id) AS (SELECT ?1)
      SELECT
        (SELECT COUNT(*) FROM official_images WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL AND hidden = 0) AS official,
        (SELECT COUNT(*) FROM fan_arts WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL AND hidden = 0) AS fan_arts,
        (SELECT COUNT(*) FROM junk_images WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL AND hidden = 0) AS junk,
        (SELECT COUNT(*) FROM drafts WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL) AS drafts,
        (SELECT COUNT(*) FROM ideas WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL) AS ideas,
        (SELECT COUNT(*) FROM pieces WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL) AS pieces,
        (SELECT COUNT(*) FROM oshi_records WHERE pit_id = (SELECT id FROM p) AND deleted_at IS NULL) AS oshi,
        (SELECT COUNT(*) FROM ideas i
          WHERE i.pit_id = (SELECT id FROM p) AND i.deleted_at IS NULL
            AND NOT EXISTS (SELECT 1 FROM idea_drafts d WHERE d.idea_id = i.id)
            AND NOT EXISTS (SELECT 1 FROM idea_pieces x WHERE x.idea_id = i.id)) AS open_ideas,
        (SELECT COUNT(*) FROM entity_images e
          WHERE e.deleted_at IS NULL AND e.owner_id IN (
            SELECT id FROM ideas WHERE pit_id = (SELECT id FROM p)
            UNION SELECT id FROM drafts WHERE pit_id = (SELECT id FROM p)
            UNION SELECT id FROM pieces WHERE pit_id = (SELECT id FROM p))) AS entity_images
      ''',
      variables: [Variable<String>(pitId)],
      readsFrom: {
        officialImages,
        fanArts,
        junkImages,
        drafts,
        ideas,
        pieces,
        ideaDrafts,
        ideaPieces,
        entityImages,
        oshiRecords,
      },
    ).watchSingle().map(
      (r) => PitStats(
        official: r.read<int>('official'),
        fanArts: r.read<int>('fan_arts'),
        junk: r.read<int>('junk'),
        drafts: r.read<int>('drafts'),
        ideas: r.read<int>('ideas'),
        pieces: r.read<int>('pieces'),
        oshi: r.read<int>('oshi'),
        openIdeas: r.read<int>('open_ideas'),
        imageCount:
            r.read<int>('official') +
            r.read<int>('fan_arts') +
            r.read<int>('entity_images'),
      ),
    );
  }
}

class PitStats {
  const PitStats({
    required this.official,
    required this.fanArts,
    this.junk = 0,
    required this.drafts,
    required this.ideas,
    required this.pieces,
    this.oshi = 0,
    required this.openIdeas,
    required this.imageCount,
  });

  final int official;
  final int fanArts;

  /// 雜物數量（只有坑的 junkEnabled 為 true 時才有意義；不計入 [imageCount]）。
  final int junk;
  final int drafts;
  final int ideas;
  final int pieces;

  /// 推活紀錄筆數（坑內頁第六格「N 筆」）。不計入 [imageCount]。
  final int oshi;
  final int openIdeas;
  final int imageCount;

  static const empty = PitStats(
    official: 0,
    fanArts: 0,
    drafts: 0,
    ideas: 0,
    pieces: 0,
    openIdeas: 0,
    imageCount: 0,
  );
}
