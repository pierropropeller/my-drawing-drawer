import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';

/// 舊版（v1）資料庫：官方圖與同人圖沒有寬高，entity_images 沒有寬高，沒有 sync_docs。
void main() {
  test('v1 → v5：補上 width/height、同步記錄表與分組欄位，舊資料保留', () async {
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

  test('v4 → v5：「自定義」改名為「圖透」並補「官方周邊」，同人圖建立分組並對應舊出處', () async {
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
}
