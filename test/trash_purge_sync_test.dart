import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/trash_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// D-120：最近刪除清掉（永久刪除／過期）後，雲端的原圖和縮圖、本機檔案一起刪；
/// 垃圾桶裡還在的、或別處還在用的檔案不動。
void main() {
  late AppDatabase db;
  late Directory dir;
  late MemoryRemote remote;
  late SyncEngine engine;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('trash_sync');
    remote = MemoryRemote();
    engine = SyncEngine(db: db, remote: remote, images: ImageStore(dir));
  });
  tearDown(() => db.close());

  NewImage img(String name) {
    File('${dir.path}/$name').writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    return NewImage(file: name, width: 10, height: 20);
  }

  Future<String> idea(String pit, String title, String file) => db.saveIdea(
    pitId: pit,
    title: title,
    body: '',
    images: [img(file)],
    tagIds: const [],
    draftIds: const [],
    pieceIds: const [],
  );

  test('垃圾桶還在＝雲端還在；永久刪除後才刪雲端和本機；共用的檔案留著', () async {
    final pit = await db.createPit(name: '坑A');
    final a = await idea(pit, 'A', 'only_a.png');
    final b = await idea(pit, 'B', 'shared.png');
    final c = await idea(pit, 'C', 'shared.png');
    await engine.sync();
    expect(remote.files.keys, contains('images__only_a.png'));
    expect(remote.files.keys, contains('images__shared.png'));

    // 刪進垃圾桶：雲端不動。
    await db.deleteIdeas([a, b]);
    await engine.sync();
    expect(remote.files.keys, contains('images__only_a.png'));
    expect(File('${dir.path}/only_a.png').existsSync(), isTrue);

    // 永久刪除 A、B：A 獨有的檔案被刪，B、C 共用的（C 還在）留著。
    final t = await db.loadTrash();
    await db.purgeTrash(items: t.items);
    await engine.sync();
    expect(remote.files.keys, isNot(contains('images__only_a.png')));
    expect(remote.deleted, contains('images__only_a.png'));
    expect(File('${dir.path}/only_a.png').existsSync(), isFalse);
    expect(remote.files.keys, contains('images__shared.png'));
    expect(File('${dir.path}/shared.png').existsSync(), isTrue);

    // C 也刪掉並永久刪除：共用的檔案這時才刪。
    await db.deleteIdeas([c]);
    await db.purgeTrash(items: (await db.loadTrash()).items);
    await engine.sync();
    expect(remote.files.keys, isNot(contains('images__shared.png')));
  });

  test('過期 30 天自動清理後，下一次同步刪雲端檔案', () async {
    final pit = await db.createPit(name: '坑A');
    final a = await idea(pit, 'A', 'old.png');
    await engine.sync();
    await db.deleteIdeas([a]);
    await (db.update(db.ideas)).write(
      IdeasCompanion(
        deletedAt: Value(DateTime.now().subtract(const Duration(days: 31))),
      ),
    );
    await db.purgeExpiredTrash();
    await engine.sync();
    expect(remote.files.keys, isNot(contains('images__old.png')));
  });
}
