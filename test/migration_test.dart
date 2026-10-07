import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';

/// 舊版（v1）資料庫：官方圖與同人圖沒有寬高，entity_images 沒有寬高，沒有 sync_docs。
void main() {
  test('v1 → v4：補上 width/height 與同步記錄表，舊資料保留', () async {
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
}
