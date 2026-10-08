import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/junk_queries.dart';

/// 舊版（v1）資料庫：官方圖與同人圖沒有寬高，entity_images 沒有寬高，沒有 sync_docs。
void main() {
  test('v1 → v6：補上 width/height、同步記錄表與分組欄位，舊資料保留', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 1');
          for (final t in ['official_images', 'fan_arts']) {
            raw.execute('''
          CREATE TABLE $t (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER NULL,
            device_id TEXT NOT NULL DEFAULT '',
            pit_id TEXT NOT NULL,
            ${t == 'official_images' ? 'group_id TEXT NOT NULL,' : "author TEXT NOT NULL DEFAULT '', source TEXT NOT NULL DEFAULT '',"}
            image_file TEXT NOT NULL
          )''');
          }
          raw.execute('''
        CREATE TABLE pits (
          id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT '',
          name TEXT NOT NULL, description TEXT NULL, cover_image_id TEXT NULL,
          archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)))''');
          raw.execute(
            '''
        CREATE TABLE official_groups (
          id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT '',
          pit_id TEXT NOT NULL, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0)''',
          );
          raw.execute('''
        CREATE TABLE entity_images (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          device_id TEXT NOT NULL DEFAULT '',
          owner_type TEXT NOT NULL,
          owner_id TEXT NOT NULL,
          image_file TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0
        )''');
          raw.execute(
            "INSERT INTO official_images (id, created_at, updated_at, pit_id, group_id, image_file) VALUES ('o1', 1, 1, 'p', 'g', 'old.png')",
          );
          raw.execute(
            "INSERT INTO entity_images (id, created_at, updated_at, owner_type, owner_id, image_file) VALUES ('e1', 1, 1, 'idea', 'i', 'e.png')",
          );
        },
      ),
    );
    final rows = await db.select(db.officialImages).get();
    expect(rows.single.imageFile, 'old.png');
    expect(rows.single.width, 0);
    expect(await db.select(db.fanArts).get(), isEmpty);
    final e = await db.select(db.entityImages).get();
    expect(e.single.imageFile, 'e.png');
    expect(e.single.height, 0);
    expect(await db.select(db.syncDocs).get(), isEmpty); // 表已建立
    await db.close();
  });

  test('v4 → v6：「自定義」改名為「圖透」並補「官方周邊」，同人圖建立分組並對應舊出處', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 4');
          raw.execute('''
        CREATE TABLE pits (
          id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT '',
          name TEXT NOT NULL, description TEXT NULL, cover_image_id TEXT NULL,
          archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)))''');
          raw.execute(
            '''
        CREATE TABLE official_groups (
          id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT '',
          pit_id TEXT NOT NULL, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0)''',
          );
          raw.execute(
            '''
        CREATE TABLE fan_arts (
          id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT '',
          pit_id TEXT NOT NULL, image_file TEXT NOT NULL, width INTEGER NOT NULL DEFAULT 0,
          height INTEGER NOT NULL DEFAULT 0, author TEXT NOT NULL DEFAULT '', source TEXT NOT NULL DEFAULT '')''',
          );
          raw.execute(
            "INSERT INTO pits (id, created_at, updated_at, name) VALUES ('p1', 1, 1, '舊坑')",
          );
          var order = 0;
          for (final n in ['設定圖', '海報宣傳', '素材', '自用截圖', '自定義']) {
            raw.execute(
              "INSERT INTO official_groups (id, created_at, updated_at, pit_id, name, sort_order) VALUES ('g$order', 1, 1, 'p1', '$n', ${order++})",
            );
          }
          raw.execute(
            "INSERT INTO fan_arts (id, created_at, updated_at, pit_id, image_file, author, source) VALUES ('f1', 1, 1, 'p1', 'f.png', '@a', 'lofter')",
          );
          raw.execute(
            "INSERT INTO fan_arts (id, created_at, updated_at, pit_id, image_file, author, source) VALUES ('f2', 1, 1, 'p1', 'g.png', '', '')",
          );
        },
      ),
    );
    final official =
        await (db.select(db.officialGroups)
              ..where((g) => g.kind.equals('official'))
              ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
            .get();
    expect(official.map((g) => g.name), [
      '設定圖',
      '海報宣傳',
      '素材',
      '自用截圖',
      '圖透',
      '官方周邊',
    ]);
    final fan = await (db.select(
      db.officialGroups,
    )..where((g) => g.kind.equals('fan'))).get();
    expect(fan.length, 5);
    final f1 = await (db.select(
      db.fanArts,
    )..where((f) => f.id.equals('f1'))).getSingle();
    expect(
      fan.firstWhere((g) => g.id == f1.groupId).name,
      'lofter',
    ); // 舊出處對應到分組
    final f2 = await (db.select(
      db.fanArts,
    )..where((f) => f.id.equals('f2'))).getSingle();
    expect(f2.groupId, isNull); // 沒有出處的維持沒有分組
    final pit = await db.select(db.pits).getSingle();
    expect(pit.officialCoverId, isNull);
    await db.close();
  });

  // 從每一個舊版本（v1~v5）升到 v6：舊資料保留、新欄位有正確的預設／回填值。
  for (var from = 1; from <= 5; from++) {
    test('v$from → v6：imageKey 回填、成圖視為已公開、新表與新欄位可用', () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: (raw) => _legacySchema(raw, from)),
      );
      // 官方圖／同人圖：imageKey = 自己的 id，沒有隱藏
      final o = await (db.select(
        db.officialImages,
      )..where((i) => i.id.equals('o1'))).getSingle();
      expect(o.imageKey, 'o1');
      expect(o.hidden, isFalse);
      expect(o.imageFile, 'o.png');
      final f = await (db.select(
        db.fanArts,
      )..where((i) => i.id.equals('f1'))).getSingle();
      expect(f.imageKey, 'f1');
      expect(f.hidden, isFalse);
      // 成圖：舊成圖一律已公開，發佈日期＝完成日期，商稿欄位預設
      final pc = await (db.select(
        db.pieces,
      )..where((p) => p.id.equals('pc1'))).getSingle();
      expect(pc.isPublished, isTrue);
      expect(pc.publishedAt, pc.finishedAt);
      expect(pc.isCommission, isFalse);
      expect(pc.client, '');
      expect(pc.amount, isNull);
      expect(pc.currency, 'CNY');
      expect(pc.receivedAmount, 0);
      expect(pc.dueAt, isNull);
      // 坑：雜物預設關閉
      final pit = await (db.select(
        db.pits,
      )..where((p) => p.id.equals('p1'))).getSingle();
      expect(pit.junkEnabled, isFalse);
      // 回顧設定：月份對齊預設 null（依月份位置決定）
      final rs = await db.select(db.reviewSettings).getSingle();
      expect(rs.monthAlign, isNull);
      expect(rs.updatedAt, isNull);
      expect(rs.year, 2026);
      // 新表與新 API 可用
      await db.addJunk('p1', [const NewImage(file: 'j.png')]);
      expect((await db.watchJunk('p1').first).single.imageKey, isNotEmpty);
      await db
          .into(db.pieces)
          .insert(
            PiecesCompanion.insert(
              pitId: 'p1',
              title: '商稿',
              isCommission: const Value(true),
              amount: const Value(100),
            ),
          );
      expect((await db.select(db.pieces).get()).length, 2);
      await db.close();
    });
  }
}

/// 建出第 [v] 版的舊資料庫結構並放入一筆種子資料。
void _legacySchema(dynamic raw, int v) {
  raw.execute('PRAGMA user_version = $v');
  const base =
      "id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER NULL, device_id TEXT NOT NULL DEFAULT ''";
  final wh = v >= 2
      ? 'width INTEGER NOT NULL DEFAULT 0, height INTEGER NOT NULL DEFAULT 0, '
      : '';
  final entityWh = v >= 3
      ? 'width INTEGER NOT NULL DEFAULT 0, height INTEGER NOT NULL DEFAULT 0, '
      : '';
  raw.execute(
    'CREATE TABLE pits ($base, name TEXT NOT NULL, description TEXT NULL, cover_image_id TEXT NULL, '
    "${v >= 5 ? 'official_cover_id TEXT NULL, fan_art_cover_id TEXT NULL, ' : ''}"
    'archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)))',
  );
  raw.execute(
    'CREATE TABLE official_groups ($base, pit_id TEXT NOT NULL, '
    "${v >= 5 ? "kind TEXT NOT NULL DEFAULT 'official', " : ''}"
    'name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0)',
  );
  raw.execute(
    'CREATE TABLE official_images ($base, pit_id TEXT NOT NULL, group_id TEXT NOT NULL, '
    '${wh}image_file TEXT NOT NULL)',
  );
  raw.execute(
    'CREATE TABLE fan_arts ($base, pit_id TEXT NOT NULL, image_file TEXT NOT NULL, '
    "${wh}author TEXT NOT NULL DEFAULT '', source TEXT NOT NULL DEFAULT ''"
    "${v >= 5 ? ', group_id TEXT NULL' : ''})",
  );
  raw.execute(
    'CREATE TABLE entity_images ($base, owner_type TEXT NOT NULL, owner_id TEXT NOT NULL, image_file TEXT NOT NULL, '
    '${entityWh}sort_order INTEGER NOT NULL DEFAULT 0)',
  );
  raw.execute(
    "CREATE TABLE pieces ($base, pit_id TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', "
    'target_likes INTEGER NOT NULL DEFAULT 0, actual_likes INTEGER NOT NULL DEFAULT 0, finished_at INTEGER NOT NULL)',
  );
  raw.execute(
    'CREATE TABLE review_settings (year INTEGER NOT NULL PRIMARY KEY, columns INTEGER NOT NULL DEFAULT 4, '
    "ratio TEXT NOT NULL DEFAULT '1:1', month_format TEXT NOT NULL DEFAULT 'Jan', month_on_image INTEGER NOT NULL DEFAULT 1)",
  );
  if (v >= 4) {
    raw.execute(
      'CREATE TABLE sync_docs (kind TEXT NOT NULL, id TEXT NOT NULL, updated_at_ms INTEGER NOT NULL, '
      "remote_modified TEXT NOT NULL DEFAULT '', PRIMARY KEY (kind, id))",
    );
  }
  raw.execute(
    "INSERT INTO pits (id, created_at, updated_at, name) VALUES ('p1', 1, 1, '舊坑')",
  );
  raw.execute(
    "INSERT INTO official_images (id, created_at, updated_at, pit_id, group_id, image_file) VALUES ('o1', 1, 1, 'p1', 'g', 'o.png')",
  );
  raw.execute(
    "INSERT INTO fan_arts (id, created_at, updated_at, pit_id, image_file) VALUES ('f1', 1, 1, 'p1', 'f.png')",
  );
  raw.execute(
    "INSERT INTO pieces (id, created_at, updated_at, pit_id, title, finished_at) VALUES ('pc1', 1, 1, 'p1', '舊成圖', 1700000000)",
  );
  raw.execute('INSERT INTO review_settings (year) VALUES (2026)');
}
