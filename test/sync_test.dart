import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 兩台裝置（兩個資料庫＋兩個圖片資料夾）透過同一個遠端同步。
void main() {
  late AppDatabase a;
  late AppDatabase b;
  late Directory dirA;
  late Directory dirB;
  late MemoryRemote remote;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    dirA = await Directory.systemTemp.createTemp('sync_a');
    dirB = await Directory.systemTemp.createTemp('sync_b');
    remote = MemoryRemote();
    engineA = SyncEngine(db: a, remote: remote, images: ImageStore(dirA));
    engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<NewImage> imageOnA(String name) async {
    await dirA.create(recursive: true);
    File('${dirA.path}/$name')
        .writeAsBytesSync(Uint8List.fromList([1, 2, 3, name.length]));
    return NewImage(file: name, width: 10, height: 20);
  }

  test('A 建立資料 → 同步 → B 拉到相同內容（含圖片檔、連接、tag、成圖連結）', () async {
    final pitId = await a.createPit(name: '同步坑', description: '描述');
    final tag = await a.createTag(pitId, '角色1');
    final draftId = await a.saveDraft(
      pitId: pitId,
      title: '草稿',
      images: [await imageOnA('d.png')],
      tagIds: [tag],
      ideaIds: const [],
    );
    final ideaId = await a.saveIdea(
      pitId: pitId,
      title: '腦洞',
      body: '內文',
      images: [await imageOnA('i.png')],
      tagIds: [tag],
      draftIds: [draftId],
      pieceIds: const [],
    );
    final pieceId = await a.savePiece(
      pitId: pitId,
      title: '成圖',
      body: '',
      images: [await imageOnA('p.png')],
      tagIds: [tag],
      links: const [SocialLink('推特', 'https://x.com/a')],
      targetLikes: 50,
      finishedAt: DateTime(2026, 5, 1),
      ideaIds: [ideaId],
      draftIds: [draftId],
    );
    await a.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 3,
      pitId: pitId,
      tagIds: [tag],
    );

    final up = await engineA.sync();
    expect(up.pushed, greaterThan(5));
    expect(up.imagesUp, 3);

    final down = await engineB.sync();
    expect(down.pulled, up.pushed);
    expect(down.imagesDown, 3);
    expect(File('${dirB.path}/p.png').readAsBytesSync(), [1, 2, 3, 5]);

    final pit = (await b.watchPits(archived: false).first).single;
    expect(pit.name, '同步坑');
    expect((await b.watchGroups(pitId).first).length, 6); // 預設分組一併同步
    expect((await b.watchGroups(pitId, kind: 'fan').first).length, 5);
    final idea = (await b.watchIdeaView(ideaId).first)!;
    expect(idea.status, IdeaStatus.hatched);
    expect(idea.draftIds, [draftId]);
    expect(idea.tags.single.name, '角色1');
    final piece = (await b.watchPieceView(pieceId).first)!;
    expect(piece.links.single.url, 'https://x.com/a');
    expect(piece.ideaIds, [ideaId]);
    expect(piece.draftIds, [draftId]);
    expect(piece.images.single.file, 'p.png');
    final goal = (await b.watchGoalViews(GoalPeriod.year, 2026).first).single;
    expect(goal.progress, 1);
    expect(goal.tags.single.name, '角色1');
  });

  test('第二次同步沒有變動就不再傳輸', () async {
    final pitId = await a.createPit(name: 'x');
    await a.saveIdea(
      pitId: pitId,
      title: 't',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await engineA.sync();
    final again = await engineA.sync();
    expect(again.changed, isFalse);
    await engineB.sync();
    expect((await engineB.sync()).changed, isFalse);
  });

  test('衝突：updatedAt 較新者勝（last-write-wins）', () async {
    final pitId = await a.createPit(name: '原名');
    await engineA.sync();
    await engineB.sync();
    // B 先改，A 後改（A 較新）
    await b.updatePit(pitId, name: 'B 的名字', archived: false);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await a.updatePit(pitId, name: 'A 的名字', archived: false);
    await engineB.sync(); // B 先上傳
    await engineA.sync(); // A 較新：不會被覆蓋，並上傳
    await engineB.sync();
    expect((await a.watchPit(pitId).first)!.name, 'A 的名字');
    expect((await b.watchPit(pitId).first)!.name, 'A 的名字');
  });

  test('刪除會同步（軟刪除）；從草稿側修改連接也會同步到腦洞', () async {
    final pitId = await a.createPit(name: 'x');
    final ideaId = await a.saveIdea(
      pitId: pitId,
      title: 'i',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    final draftId = await a.saveDraft(
      pitId: pitId,
      images: [await imageOnA('d.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await engineA.sync();
    await engineB.sync();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // 從草稿側連接腦洞：腦洞文件擁有這個關係，必須跟著被同步
    await a.saveDraft(
      id: draftId,
      pitId: pitId,
      images: [await imageOnA('d.png')],
      tagIds: const [],
      ideaIds: [ideaId],
    );
    await engineA.sync();
    await engineB.sync();
    expect((await b.watchIdeaView(ideaId).first)!.draftIds, [draftId]);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await a.deleteIdeas([ideaId]);
    await engineA.sync();
    await engineB.sync();
    expect(await b.watchIdeaView(ideaId).first, isNull);
    expect(await b.watchIdeaViews(pitId).first, isEmpty);
  });

  test('更換帳號：重設同步記錄後整個重新上傳', () async {
    final pitId = await a.createPit(name: 'x');
    await a.saveIdea(
      pitId: pitId,
      title: 't',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await engineA.sync();
    final newRemote = MemoryRemote();
    final other = SyncEngine(
      db: a,
      remote: newRemote,
      images: ImageStore(dirA),
    );
    await other.resetState();
    final r = await other.sync();
    expect(r.pushed, greaterThan(0));
    expect(
      newRemote.files.keys.any((k) => k.startsWith('meta__ideas__')),
      isTrue,
    );
  });

  test('雜物、移動後的隱藏列、成圖新欄位、回顧設定都會同步到另一台', () async {
    final pitId = await a.createPit(name: '坑', junkEnabled: true);
    final groups = await a.watchGroups(pitId).first;
    final fanGroups = await a.watchGroups(pitId, kind: 'fan').first;
    await a.addOfficial(pitId, groups[1].id, [await imageOnA('o.png')]);
    final o = (await a.watchOfficial(pitId).first).single;
    await a.addJunk(pitId, [await imageOnA('j.png')]);
    final pieceId = await a.savePiece(
      pitId: pitId,
      title: '商稿',
      body: '',
      images: [await imageOnA('p.png')],
      tagIds: const [],
      links: const [SocialLink('推特', 'https://x.com/a')],
      targetLikes: 10,
      finishedAt: DateTime(2026, 5, 1),
      ideaIds: const [],
      draftIds: const [],
      isPublished: true,
      publishedAt: DateTime(2026, 5, 3),
      isCommission: true,
      client: '@某某',
      amount: 800.5,
      currency: 'HKD',
      receivedAmount: 300,
      dueAt: DateTime(2026, 5, 20),
    );
    await a.saveReviewSettings(
      (await a.watchReviewSettings(2026).first).copyWith(
        monthAlign: const Value('end'),
      ),
    );
    // 官方 → 同人圖：來源隱藏＋新建同人圖列，兩列都要同步
    await a.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
      groupId: fanGroups[2].id,
    );

    await engineA.sync();
    final down = await engineB.sync();
    expect(down.imagesDown, 3);

    expect((await b.watchPit(pitId).first)!.junkEnabled, isTrue);
    final junk = (await b.watchJunk(pitId).first).single;
    expect(junk.imageFile, 'j.png');
    expect(junk.imageKey, junk.id);
    expect(File('${dirB.path}/j.png').existsSync(), isTrue);

    expect(await b.watchOfficial(pitId).first, isEmpty); // 隱藏列同步後仍是隱藏
    final hidden = await b.select(b.officialImages).getSingle();
    expect(hidden.hidden, isTrue);
    expect(hidden.groupId, groups[1].id); // 官方分組保留在隱藏列
    final fan = (await b.watchFanArts(pitId).first).single;
    expect(fan.imageKey, o.imageKey);
    expect(fan.groupId, fanGroups[2].id);
    // 在 B 移回官方：恢復原分組
    await b.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [fan.id],
      to: AlbumCell.official,
    );
    expect((await b.watchOfficial(pitId).first).single.groupId, groups[1].id);

    final p = (await b.watchPieceView(pieceId).first)!;
    expect(p.piece.isPublished, isTrue);
    expect(p.piece.publishedAt, DateTime(2026, 5, 3));
    expect(p.piece.isCommission, isTrue);
    expect(p.piece.client, '@某某');
    expect(p.piece.amount, 800.5);
    expect(p.piece.currency, 'HKD');
    expect(p.piece.receivedAmount, 300);
    expect(p.piece.dueAt, DateTime(2026, 5, 20));
    expect(p.payment.isPartial, isTrue);
    expect(p.links.single.url, 'https://x.com/a');

    final rs = await b.watchReviewSettings(2026).first;
    expect(rs.monthAlign, 'end');
  });

  test('舊版文件（沒有新欄位）仍能讀入並補上預設值', () async {
    final pitId = 'pit-old';
    Future<void> put(String kind, String id, Map<String, dynamic> data) =>
        remote.upload(
          'meta__${kind}__$id.json',
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'v': 1,
                'kind': kind,
                'id': id,
                'updatedAt': 1700000000000,
                'data': data,
              }),
            ),
          ),
        );
    const t = 1700000000000;
    await put('pits', pitId, {
      'id': pitId,
      'createdAt': t,
      'updatedAt': t,
      'deletedAt': null,
      'deviceId': '',
      'name': '舊坑',
      'description': null,
      'coverImageId': null,
      'officialCoverId': null,
      'fanArtCoverId': null,
      'archived': false,
    });
    await put('official', 'o-old', {
      'id': 'o-old',
      'createdAt': t,
      'updatedAt': t,
      'deletedAt': null,
      'deviceId': '',
      'pitId': pitId,
      'groupId': 'g',
      'imageFile': 'old.png',
      'width': 1,
      'height': 2,
    });
    await put('pieces', 'pc-old', {
      'id': 'pc-old',
      'createdAt': t,
      'updatedAt': t,
      'deletedAt': null,
      'deviceId': '',
      'pitId': pitId,
      'title': '舊成圖',
      'body': '',
      'targetLikes': 0,
      'actualLikes': 7,
      'finishedAt': t,
      'tagIds': <String>[],
      'images': <Map<String, dynamic>>[],
      'links': <Map<String, dynamic>>[],
      'draftIds': <String>[],
    });
    await engineB.sync();
    expect((await b.watchPit(pitId).first)!.junkEnabled, isFalse);
    final o = (await b.watchOfficial(pitId).first).single;
    expect(o.imageKey, 'o-old');
    expect(o.hidden, isFalse);
    final p = (await b.watchPieceView('pc-old').first)!.piece;
    expect(p.isPublished, isTrue); // 舊成圖一律已公開
    expect(p.publishedAt, DateTime.fromMillisecondsSinceEpoch(t));
    expect(p.isCommission, isFalse);
    expect(p.currency, 'CNY');
    expect(p.receivedAmount, 0);
  });

  test('較新格式的備份：停下來並提示更新 App，不動本機資料', () async {
    final pitId = await a.createPit(name: 'A 的坑');
    await engineA.sync();
    // 模擬未來版本寫入：格式標記與文件都是更高的版本
    remote.files['meta__app__format.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode({'formatVersion': syncFormatVersion + 1})),
    );
    await expectLater(
      engineB.sync(),
      throwsA(
        isA<SyncFormatException>().having(
          (e) => e.message,
          'message',
          '此備份由較新版本建立，請先更新 App',
        ),
      ),
    );
    expect(await b.watchPits(archived: false).first, isEmpty);

    // 沒有標記但文件本身標了較新版本：同樣停下來
    remote.files.remove('meta__app__format.json');
    final key = 'meta__pits__$pitId.json';
    final doc =
        jsonDecode(utf8.decode(remote.files[key]!)) as Map<String, dynamic>;
    doc['formatVersion'] = syncFormatVersion + 1;
    remote.files[key] = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
    await expectLater(engineB.sync(), throwsA(isA<SyncAuthException>()));
    expect(await b.watchPits(archived: false).first, isEmpty);
  });

  test('這版寫出的文件與遠端都帶 formatVersion', () async {
    final pitId = await a.createPit(name: 'x');
    await engineA.sync();
    final doc = jsonDecode(
      utf8.decode(remote.files['meta__pits__$pitId.json']!),
    ) as Map<String, dynamic>;
    expect(doc['formatVersion'], syncFormatVersion);
    final marker = jsonDecode(
      utf8.decode(remote.files['meta__app__format.json']!),
    ) as Map<String, dynamic>;
    expect(marker['formatVersion'], syncFormatVersion);
    expect((await engineA.sync()).changed, isFalse); // 標記不影響「沒變動」
  });

  test('進度回報：下載階段 N / M 逐張遞增，上傳階段有總數', () async {
    final pitId = await a.createPit(name: 'x');
    final groups = await a.watchGroups(pitId).first;
    await a.addOfficial(pitId, groups.first.id, [
      await imageOnA('1.png'),
      await imageOnA('2.png'),
      await imageOnA('3.png'),
    ]);
    final up = <SyncProgress>[];
    await engineA.sync(onProgress: up.add);
    final upload = up.where((p) => p.stage == SyncStage.uploading).toList();
    expect(upload.first.imagesTotal, 3);
    expect(upload.last.imagesDone, 3);

    final down = <SyncProgress>[];
    final names = <String>[];
    final store = ImageStore(dirB);
    final sub = store.changes.listen(names.add);
    final engine = SyncEngine(db: b, remote: remote, images: store);
    await engine.sync(onProgress: down.add);
    await sub.cancel();
    expect(down.first.stage, SyncStage.pulling);
    final dl = down
        .where((p) => p.stage == SyncStage.downloadingImages)
        .toList();
    expect(dl.first.imagesTotal, 3);
    expect(dl.first.imagesDone, 0);
    expect([for (final p in dl) p.imagesDone], [0, 1, 2, 3]);
    expect(dl.every((p) => p.imagesTotal == 3), isTrue);
    expect(names.toSet(), {'1.png', '2.png', '3.png'}); // 每張下載完成都有通知
  });

  test('ImageStore.watchExists：檔案下載完成時更新', () async {
    final store = ImageStore(dirB);
    final seen = <bool>[];
    final sub = store.watchExists('later.png').listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [false]);
    await store.save('later.png', Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);
    expect(seen, [false, true]);
    await sub.cancel();
  });
}
