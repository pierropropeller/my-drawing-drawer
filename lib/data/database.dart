import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart' show GoalKind, GoalPeriod, OwnerType, TagTarget;

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'huakeng'));

  @override
  int get schemaVersion => 6;

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
    },
  );

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
        COALESCE((SELECT MAX(updated_at) FROM pieces WHERE pit_id = p.id), 0)
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

  /// 軟刪除（同步用）；坑內的雜物一併軟刪除。
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
      },
    ).watchSingle().map(
      (r) => PitStats(
        official: r.read<int>('official'),
        fanArts: r.read<int>('fan_arts'),
        junk: r.read<int>('junk'),
        drafts: r.read<int>('drafts'),
        ideas: r.read<int>('ideas'),
        pieces: r.read<int>('pieces'),
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
