import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/author_link.dart';
import 'package:huakeng/data/author_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/media/thumbnail_maker.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/sync/sync_kinds.dart';

import 'dart:typed_data';

class _Maker implements ThumbnailMaker {
  @override
  Future<Uint8List?> make(File source, {bool placeholder = false}) async =>
      Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
}

/// 作者系統（D-156）：舊文字轉作者、列表（主坑、最新三張、坑分頁）、排序、刪除、同步。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late String pitA, pitB;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitA = await db.createPit(name: '坑A');
    pitB = await db.createPit(name: '坑B');
  });
  tearDown(() => db.close());

  NewImage img(String f) => NewImage(file: f, width: 10, height: 10);

  test('只帶作者文字的同人圖：同名合併成一位作者，id 由名字決定', () async {
    await db.addFanArts(pitA, [img('1.png'), img('2.png')], author: '雪見');
    await db.addFanArts(pitB, [img('3.png')], author: ' 雪見 ');
    final authors = await db.loadAuthors();
    expect(authors.length, 1);
    expect(authors.single.id, authorIdForName('雪見'));
    final arts = await db.select(db.fanArts).get();
    expect(arts.every((f) => f.authorId == authors.single.id), isTrue);
  });

  test('已有同名作者就歸給他，不另建', () async {
    final id = await db.addAuthor(AuthorsCompanion.insert(name: 'Renko'));
    await db.addFanArts(pitA, [img('1.png')], author: 'Renko');
    expect((await db.loadAuthors()).length, 1);
    expect((await db.select(db.fanArts).getSingle()).authorId, id);
  });

  test('列表：主坑＝同人圖最多的坑、最新三張、坑分頁只列有主坑的坑；新增的排最前面', () async {
    final a = await db.addAuthor(AuthorsCompanion.insert(name: 'A'));
    await db.addFanArts(pitB, [img('b1.png')], author: 'A', authorId: a);
    await db.addFanArts(
      pitA,
      [img('a1.png'), img('a2.png'), img('a3.png'), img('a4.png')],
      author: 'A',
      authorId: a,
    );
    final empty = await db.addAuthor(AuthorsCompanion.insert(name: 'Z'));
    final list = await db.loadAuthorList();
    expect(list.authors.first.author.id, empty);
    final sa = list.authors.firstWhere((s) => s.author.id == a);
    expect(sa.mainPitId, pitA);
    expect(sa.count, 5);
    expect(sa.latest.length, 3);
    expect([for (final p in list.pits) p.id], [pitA]);
    final z = list.authors.firstWhere((s) => s.author.id == empty);
    expect(z.mainPitId, isNull);

    final detail = (await db.loadAuthorDetail(a))!;
    expect(detail.groups.length, 2);
    expect(detail.count, 5);
  });

  test('改名：同人圖的作者文字跟著換；刪除：同人圖留著、作者欄清空', () async {
    final a = await db.addAuthor(AuthorsCompanion.insert(name: '舊名'));
    await db.addFanArts(pitA, [img('1.png')], author: '舊名', authorId: a);
    await db.updateAuthor(a, const AuthorsCompanion(name: Value('新名')));
    expect((await db.select(db.fanArts).getSingle()).author, '新名');
    await db.deleteAuthors([a]);
    final f = await db.select(db.fanArts).getSingle();
    expect(f.authorId, isNull);
    expect(f.author, '');
    expect(f.deletedAt, isNull);
    expect(await db.loadAuthors(), isEmpty);
  });

  test('排序：照給的順序寫 sortOrder', () async {
    final x = await db.addAuthor(AuthorsCompanion.insert(name: 'x'));
    final y = await db.addAuthor(AuthorsCompanion.insert(name: 'y'));
    expect([for (final a in await db.loadAuthors()) a.id], [y, x]);
    await db.reorderAuthors([x, y]);
    expect([for (final a in await db.loadAuthors()) a.id], [x, y]);
  });

  test('連結輸入解析', () {
    expect(
      parseLinkInput(LinkPlatform.x, 'https://x.com/yukimi_ill?s=20'),
      'yukimi_ill',
    );
    expect(parseLinkInput(LinkPlatform.x, 'twitter.com/abc'), 'abc');
    expect(parseLinkInput(LinkPlatform.x, '@abc_1'), 'abc_1');
    expect(parseLinkInput(LinkPlatform.x, 'x.com/home'), isNull);
    expect(
      parseLinkInput(
        LinkPlatform.xhs,
        'https://www.xiaohongshu.com/user/profile/5f1234567890abcdef123456?xsec=1',
      ),
      '5f1234567890abcdef123456',
    );
    expect(parseLinkInput(LinkPlatform.xhs, 'hello'), isNull);
  });

  test('同步：作者與頭像檔上傳，另一台下載後同人圖的作者文字一致', () async {
    final b = AppDatabase(NativeDatabase.memory());
    final dirA = await Directory.systemTemp.createTemp('au_a');
    final dirB = await Directory.systemTemp.createTemp('au_b');
    addTearDown(() async {
      await b.close();
      await dirA.delete(recursive: true);
      await dirB.delete(recursive: true);
    });
    final remote = MemoryRemote();
    SyncEngine eng(AppDatabase d, Directory dir) => SyncEngine(
      db: d,
      remote: remote,
      images: ImageStore(dir),
      thumbnails: _Maker(),
      kinds: allSyncKinds,
    );
    File('${dirA.path}/av.jpg').writeAsBytesSync([1, 2, 3]);
    File('${dirA.path}/1.png').writeAsBytesSync([1]);
    final a = await db.addAuthor(
      AuthorsCompanion.insert(name: '雪見', avatarFile: const Value('av.jpg')),
    );
    await db.addFanArts(pitA, [img('1.png')], author: '雪見', authorId: a);
    await eng(db, dirA).sync();
    expect(remote.files.containsKey('meta__author__$a.json'), isTrue);
    expect(remote.files.containsKey('images__av.jpg'), isTrue);
    await eng(b, dirB).sync();
    final got = await b.loadAuthors();
    expect(got.single.name, '雪見');
    expect(File('${dirB.path}/av.jpg').existsSync(), isTrue);

    // 時間存到秒：等過一秒，版本才會不同。
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await db.updateAuthor(a, const AuthorsCompanion(name: Value('雪見2')));
    await eng(db, dirA).sync();
    await eng(b, dirB).sync();
    expect((await b.select(b.fanArts).getSingle()).author, '雪見2');
  });
}
