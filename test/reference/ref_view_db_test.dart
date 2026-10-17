import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/ref_view_queries.dart';
import 'package:huakeng/ui/reference/ref_view_store.dart';

/// 參考圖檢視的每張圖檢視狀態：純本機表的讀寫、v9 → v10 遷移、不碰同步。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('沒存過＝null；存了讀得回來；再存是覆蓋不是新增', () async {
    expect(await db.getRefViewState('a.png'), isNull);
    const s = RefViewSnapshot(
      zoom: 1.8,
      scale: 0.9,
      centerX: 0.3,
      centerY: 0.7,
      locked: true,
      flipped: true,
      gray: true,
      lightBg: true,
    );
    await db.saveRefViewState('a.png', s);
    expect(await db.getRefViewState('a.png'), s);
    await db.saveRefViewState('a.png', s.copyWith(zoom: 3, locked: false));
    final again = await db.getRefViewState('a.png');
    expect(again!.zoom, 3);
    expect(again.locked, isFalse);
    expect(again.flipped, isTrue);
    expect(await db.select(db.refViewStates).get(), hasLength(1));
  });

  test('每張圖各自一份，getRefViewStates 一次讀多張', () async {
    await db.saveRefViewState('a.png', const RefViewSnapshot(zoom: 2));
    await db.saveRefViewState('b.png', const RefViewSnapshot(zoom: 4));
    final m = await db.getRefViewStates(['a.png', 'b.png', 'c.png']);
    expect(m.keys.toSet(), {'a.png', 'b.png'});
    expect(m['a.png']!.zoom, 2);
    expect(m['b.png']!.zoom, 4);
    expect(await db.getRefViewStates([]), isEmpty);
  });

  test('刪除檢視狀態', () async {
    await db.saveRefViewState('a.png', const RefViewSnapshot(zoom: 2));
    await db.deleteRefViewState('a.png');
    expect(await db.getRefViewState('a.png'), isNull);
  });

  test('只在本機：寫入檢視狀態不產生同步佇列（Outbox）也不動 SyncDocs', () async {
    await db.saveRefViewState('a.png', const RefViewSnapshot(zoom: 2));
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await db.select(db.syncDocs).get(), isEmpty);
  });

  test('schemaVersion 是 10', () {
    expect(db.schemaVersion, 10);
  });

  test('v9 → v10：建立 ref_view_states，舊資料保留', () async {
    final upgraded = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 9');
          raw.execute(
            '''
            CREATE TABLE pits (
              id TEXT NOT NULL PRIMARY KEY, created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL, deleted_at INTEGER NULL,
              device_id TEXT NOT NULL DEFAULT '', name TEXT NOT NULL,
              description TEXT NULL, cover_image_id TEXT NULL,
              official_cover_id TEXT NULL, fan_art_cover_id TEXT NULL,
              draft_cover_file TEXT NULL, idea_cover_file TEXT NULL,
              piece_cover_file TEXT NULL, oshi_cover_file TEXT NULL,
              archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
              junk_enabled INTEGER NOT NULL DEFAULT 0 CHECK (junk_enabled IN (0, 1)))''',
          );
          raw.execute(
            "INSERT INTO pits (id, created_at, updated_at, name) VALUES ('p1', 1, 1, '舊的坑')",
          );
        },
      ),
    );
    addTearDown(upgraded.close);
    // 表已建立，可以讀寫。
    expect(await upgraded.select(upgraded.refViewStates).get(), isEmpty);
    await upgraded.saveRefViewState('x.png', const RefViewSnapshot(zoom: 2.5));
    expect((await upgraded.getRefViewState('x.png'))!.zoom, 2.5);
    final pits = await upgraded.select(upgraded.pits).get();
    expect(pits.single.name, '舊的坑');
  });

  group('RefViewStore', () {
    test('load：沒存過給預設；update 後 flush 寫進資料庫；重開讀得回來', () async {
      final store = RefViewStore(db, debounce: const Duration(hours: 1));
      expect(await store.load('a.png'), RefViewSnapshot.initial);
      store.update('a.png', const RefViewSnapshot(zoom: 2, locked: true));
      // 還沒 flush：資料庫沒有，記憶體有。
      expect(await db.getRefViewState('a.png'), isNull);
      expect(store.peek('a.png')!.zoom, 2);
      await store.flush();
      expect((await db.getRefViewState('a.png'))!.locked, isTrue);

      final reopened = RefViewStore(db);
      final s = await reopened.load('a.png');
      expect(s.zoom, 2);
      expect(s.locked, isTrue);
      await store.dispose();
      await reopened.dispose();
    });

    test('debounce 到時自動存檔', () async {
      final store = RefViewStore(
        db,
        debounce: const Duration(milliseconds: 20),
      );
      store.update('a.png', const RefViewSnapshot(zoom: 3));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect((await db.getRefViewState('a.png'))!.zoom, 3);
      await store.dispose();
    });

    test('dispose 會把還沒存的寫完', () async {
      final store = RefViewStore(db, debounce: const Duration(hours: 1));
      store.update('a.png', const RefViewSnapshot(zoom: 5));
      await store.dispose();
      expect((await db.getRefViewState('a.png'))!.zoom, 5);
    });
  });
}
