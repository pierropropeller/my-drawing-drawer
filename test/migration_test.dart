import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';

void main() {
  test('v1 → v2：官方圖與同人圖補上 width/height，舊資料保留', () async {
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
          raw.execute(
            "INSERT INTO official_images (id, created_at, updated_at, pit_id, group_id, image_file) VALUES ('o1', 1, 1, 'p', 'g', 'old.png')",
          );
        },
      ),
    );
    final rows = await db.select(db.officialImages).get();
    expect(rows.single.imageFile, 'old.png');
    expect(rows.single.width, 0);
    expect(rows.single.height, 0);
    expect(await db.select(db.fanArts).get(), isEmpty);
    await db.close();
  });
}
