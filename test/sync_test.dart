import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
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
}
