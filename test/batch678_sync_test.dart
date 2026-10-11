import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 批次 6–8 的同步：兩台裝置（兩個資料庫）透過同一個遠端。
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
    dirA = await Directory.systemTemp.createTemp('sync678_a');
    dirB = await Directory.systemTemp.createTemp('sync678_b');
    remote = MemoryRemote();
    engineA = SyncEngine(db: a, remote: remote, images: ImageStore(dirA));
    engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<NewImage> imageOn(Directory dir, String name) async {
    await dir.create(recursive: true);
    File(
      '${dir.path}/$name',
    ).writeAsBytesSync(Uint8List.fromList([9, 8, 7, name.length]));
    return NewImage(file: name, width: 10, height: 20);
  }

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 1100));

  test('推活：A 建立紀錄（圖、tag、分組）→ B 拉到；B 編輯 → A 拉到；刪除與分組刪除也會同步', () async {
    final pitId = await a.createPit(name: '坑');
    final groups = await a.watchGroups(pitId, kind: 'oshi').first;
    final tag = await a.createTag(pitId, '角色1');
    final id = await a.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 10, 5),
      groupId: groups[0].id,
      title: '一週年展',
      description: '現場',
      images: [await imageOn(dirA, 'o1.png'), await imageOn(dirA, 'o2.png')],
      tagIds: [tag],
    );
    final up = await engineA.sync();
    expect(up.imagesUp, 2);
    final down = await engineB.sync();
    expect(down.imagesDown, 2);
    expect(File('${dirB.path}/o1.png').existsSync(), isTrue);

    // 分組（kind=oshi）與紀錄都到了
    expect(
      (await b.watchGroups(pitId, kind: 'oshi').first).map((g) => g.name),
      ['線下照片', '遊戲截圖', '對話記錄'],
    );
    var v = (await b.getOshiRecord(id))!;
    expect(v.record.date, DateTime(2026, 10, 5));
    expect(v.record.title, '一週年展');
    expect(v.record.description, '現場');
    expect(v.group!.name, '線下照片');
    expect(v.images.map((i) => i.file), ['o1.png', 'o2.png']);
    expect(v.images.first.width, 10);
    expect(v.tags.single.name, '角色1');
    expect((await b.watchPitStats(pitId).first).oshi, 1);
    expect(
      (await b.watchTagUsage(pitId).first).single.count,
      1,
    ); // 推活計入 tag 次數

    // B 編輯：換分組、換日期、少一張圖
    await tick();
    await b.saveOshiRecord(
      id: id,
      pitId: pitId,
      date: DateTime(2026, 10, 6),
      groupId: groups[1].id,
      title: '一週年展（改）',
      images: [
        NewImage(file: 'o2.png', width: 10, height: 20),
      ],
      tagIds: const [],
    );
    await engineB.sync();
    await engineA.sync();
    v = (await a.getOshiRecord(id))!;
    expect(v.record.title, '一週年展（改）');
    expect(v.record.date, DateTime(2026, 10, 6));
    expect(v.group!.name, '遊戲截圖');
    expect(v.images.map((i) => i.file), ['o2.png']);
    expect(v.tags, isEmpty);

    // A 刪分組 → 紀錄變成沒有分組（紀錄也被蓋 updatedAt，另一台拉得到）
    await tick();
    await a.deleteGroup(groups[1].id);
    await engineA.sync();
    await engineB.sync();
    v = (await b.getOshiRecord(id))!;
    expect(v.record.groupId, isNull);
    expect(v.group, isNull);
    expect(
      (await b.watchGroups(pitId, kind: 'oshi').first).map((g) => g.name),
      ['線下照片', '對話記錄'],
    );

    // 刪除
    await tick();
    await b.deleteOshiRecords([id]);
    await engineB.sync();
    await engineA.sync();
    expect(await a.getOshiRecord(id), isNull);
    expect((await a.watchPitStats(pitId).first).oshi, 0);
  });

  test('雙機各自升級／補預設推活分組：決定性 id，同步後不會重複', () async {
    // 一個沒有推活分組的坑（模擬舊版同步進來）同時出現在兩台
    final pitId = await a.createPit(name: '舊坑');
    await a.customStatement("DELETE FROM official_groups WHERE kind = 'oshi'");
    await engineA.sync();
    await engineB.sync();
    expect(await a.watchGroups(pitId, kind: 'oshi').first, isEmpty);
    expect(await b.watchGroups(pitId, kind: 'oshi').first, isEmpty);
    await a.ensureOshiGroups(pitId);
    await b.ensureOshiGroups(pitId);
    await engineA.sync();
    await engineB.sync();
    await engineA.sync();
    expect((await a.watchGroups(pitId, kind: 'oshi').first).length, 3);
    expect((await b.watchGroups(pitId, kind: 'oshi').first).length, 3);
  });

  test('D-070 date 會同步；舊文件（沒有 date）補成 createdAt', () async {
    final pitId = await a.createPit(name: '坑');
    final i = await a.saveIdea(
      pitId: pitId,
      title: '腦洞',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
      date: DateTime(2026, 3, 1, 9, 15),
    );
    final d = await a.saveDraft(
      pitId: pitId,
      title: '草稿',
      images: [await imageOn(dirA, 'd.png')],
      tagIds: const [],
      ideaIds: const [],
      date: DateTime(2026, 4, 2),
    );
    await engineA.sync();
    await engineB.sync();
    expect((await b.watchIdeaView(i).first)!.idea.date, DateTime(2026, 3, 1, 9, 15));
    expect((await b.watchDraftView(d).first)!.draft.date, DateTime(2026, 4, 2));

    // 舊版文件
    const t = 1700000000000;
    Future<void> put(String kind, String id, Map<String, dynamic> data) =>
        remote.upload(
          'meta__${kind}__$id.json',
          Uint8List.fromList(
            utf8.encode(
              jsonEncode({
                'v': 1,
                'kind': kind,
                'id': id,
                'updatedAt': t + 5000,
                'data': data,
              }),
            ),
          ),
        );
    await put('ideas', 'i-old', {
      'id': 'i-old',
      'createdAt': t,
      'updatedAt': t + 5000,
      'deletedAt': null,
      'deviceId': '',
      'pitId': pitId,
      'title': '舊腦洞',
      'body': '',
      'tagIds': <String>[],
      'draftIds': <String>[],
      'pieceIds': <String>[],
      'images': <Map<String, dynamic>>[],
    });
    await put('drafts', 'd-old', {
      'id': 'd-old',
      'createdAt': t + 1000,
      'updatedAt': t + 5000,
      'deletedAt': null,
      'deviceId': '',
      'pitId': pitId,
      'title': null,
      'body': null,
      'tagIds': <String>[],
      'images': <Map<String, dynamic>>[],
    });
    await engineB.sync();
    expect(
      (await b.watchIdeaView('i-old').first)!.idea.date,
      DateTime.fromMillisecondsSinceEpoch(t),
    );
    expect(
      (await b.watchDraftView('d-old').first)!.draft.date,
      DateTime.fromMillisecondsSinceEpoch(t + 1000),
    );
  });

  test('D-069 草稿↔成圖：兩邊任一側修改都同步到另一台，並在兩側顯示', () async {
    final pitId = await a.createPit(name: '坑');
    final p1 = await a.savePiece(
      pitId: pitId,
      title: '成圖',
      body: '',
      images: [await imageOn(dirA, 'p.png')],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 3, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    final d1 = await a.saveDraft(
      pitId: pitId,
      title: '草稿',
      images: [await imageOn(dirA, 'd.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await engineA.sync();
    await engineB.sync();
    expect((await b.watchDraftView(d1).first)!.linkedPieces, isEmpty);

    // A 從草稿側關聯成圖
    await tick();
    await a.saveDraft(
      id: d1,
      pitId: pitId,
      title: '草稿',
      images: [await imageOn(dirA, 'd.png')],
      tagIds: const [],
      ideaIds: const [],
      pieceIds: [p1],
    );
    await engineA.sync();
    await engineB.sync();
    final dv = (await b.watchDraftView(d1).first)!;
    expect(dv.linkedPieces.single.title, '成圖');
    expect(dv.linkedPieces.single.firstImage!.file, 'p.png');
    final pv = (await b.watchPieceView(p1).first)!;
    expect(pv.linkedDrafts.single.id, d1);
    expect(pv.linkedDrafts.single.firstImage!.file, 'd.png');

    // B 從成圖側改成不關聯
    await tick();
    await b.savePiece(
      id: p1,
      pitId: pitId,
      title: '成圖',
      body: '',
      images: [NewImage(file: 'p.png', width: 10, height: 20)],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 3, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    await engineB.sync();
    await engineA.sync();
    expect((await a.watchDraftView(d1).first)!.pieceIds, isEmpty);
    expect((await a.watchPieceView(p1).first)!.draftIds, isEmpty);

    // B 從草稿側再關聯回來；A 在同一輪從草稿側把關係清掉再加上第二份（互不衝突的順序）
    await tick();
    await b.setDraftPieces(d1, [p1]);
    await engineB.sync();
    await engineA.sync();
    expect((await a.watchPieceView(p1).first)!.linkedDrafts.single.id, d1);

    // 草稿被刪：成圖那邊的關係也要消失並同步（成圖文件擁有關係，刪除時會被更新）
    await tick();
    await a.deleteDrafts([d1]);
    await engineA.sync();
    await engineB.sync();
    expect((await b.watchPieceView(p1).first)!.linkedDrafts, isEmpty);
    expect((await b.watchPieceView(p1).first)!.draftIds, isEmpty);
  });

  test('D-060 官方圖 tag 會同步；批次 tag 之後另一台看得到；舊文件（沒有 tagIds）不清掉本機 tag', () async {
    final pitId = await a.createPit(name: '坑');
    final og = await a.watchGroups(pitId).first;
    final t1 = await a.createTag(pitId, '角色1');
    await a.addOfficial(pitId, og.first.id, [
      await imageOn(dirA, '1.png'),
      await imageOn(dirA, '2.png'),
    ], tagIds: [t1]);
    final ims = await a.watchOfficial(pitId).first;
    await engineA.sync();
    await engineB.sync();
    for (final i in ims) {
      expect(await b.watchTagIds(TagTarget.official, i.id).first, [t1]);
    }
    expect((await b.watchTagUsage(pitId).first).single.count, 2);

    // A 批次：移除 t1、新增 t2
    await tick();
    final created = await a.applyBatchTags(
      AlbumCell.official,
      ims.map((i) => i.id),
      removeTagIds: [t1],
      newTagNames: ['新的'],
    );
    await engineA.sync();
    await engineB.sync();
    for (final i in ims) {
      expect(await b.watchTagIds(TagTarget.official, i.id).first, created);
    }
    expect(
      {
        for (final u in await b.watchTagUsage(pitId).first) u.tag.name: u.count,
      },
      {'角色1': 0, '新的': 2},
    );

    // 舊版文件（沒有 tagIds）覆蓋：B 本機的 tag 要保留
    final first = ims.first;
    final key = 'meta__official__${first.id}.json';
    final doc = jsonDecode(utf8.decode(remote.files[key]!)) as Map<String, dynamic>;
    (doc['data'] as Map<String, dynamic>).remove('tagIds');
    doc['updatedAt'] = (doc['updatedAt'] as int) + 60000;
    (doc['data'] as Map<String, dynamic>)['updatedAt'] = doc['updatedAt'];
    remote.files[key] = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
    await engineB.sync();
    expect(await b.watchTagIds(TagTarget.official, first.id).first, created);
  });

  test('官方圖跨坑移動（帶 tag）→ 同步：另一台的新列、隱藏列與 tag 都一致，移回恢復', () async {
    final p1 = await a.createPit(name: 'A');
    final p2 = await a.createPit(name: 'B');
    final g1 = await a.watchGroups(p1).first;
    final g2 = await a.watchGroups(p2).first;
    final tag = await a.createTag(p1, '角色1');
    await a.addOfficial(p1, g1.first.id, [await imageOn(dirA, 'x.png')], tagIds: [tag]);
    final img = (await a.watchOfficial(p1).first).single;
    await a.moveAlbumImages(
      from: AlbumCell.official,
      ids: [img.id],
      to: AlbumCell.official,
      targetPitId: p2,
      groupId: g2[2].id,
    );
    await engineA.sync();
    await engineB.sync();

    expect(await b.watchOfficial(p1).first, isEmpty);
    final inB = (await b.watchOfficial(p2).first).single;
    expect(inB.groupId, g2[2].id);
    final names = {
      for (final t in await b.watchTags(p2).first) t.id: t.name,
    };
    expect(
      (await b.watchTagIds(TagTarget.official, inB.id).first).map((i) => names[i]),
      ['角色1'],
    );
    // 在 B 移回原坑：恢復原本的列與 tag
    await b.moveAlbumImages(
      from: AlbumCell.official,
      ids: [inB.id],
      to: AlbumCell.official,
      targetPitId: p1,
    );
    final back = (await b.watchOfficial(p1).first).single;
    expect(back.id, img.id);
    expect(await b.watchTagIds(TagTarget.official, back.id).first, [tag]);
  });

  test('把欄位清成空（null）也會同步到另一台（整列覆寫，不略過 null）', () async {
    final pitId = await a.createPit(name: '坑');
    final groups = await a.watchGroups(pitId, kind: 'oshi').first;
    final d = await a.saveDraft(
      pitId: pitId,
      title: '有標題',
      body: '有內文',
      images: [await imageOn(dirA, 'd.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    final o = await a.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 10, 1),
      groupId: groups.first.id,
      title: '有標題',
      description: '有描述',
      images: [await imageOn(dirA, 'o.png')],
    );
    await engineA.sync();
    await engineB.sync();
    expect((await b.watchDraftView(d).first)!.draft.title, '有標題');
    await tick();
    await a.saveDraft(
      id: d,
      pitId: pitId,
      images: [await imageOn(dirA, 'd.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await a.saveOshiRecord(
      id: o,
      pitId: pitId,
      date: DateTime(2026, 10, 1),
      images: [await imageOn(dirA, 'o.png')],
    );
    await engineA.sync();
    await engineB.sync();
    final dv = (await b.watchDraftView(d).first)!.draft;
    expect(dv.title, isNull);
    expect(dv.body, isNull);
    final ov = (await b.getOshiRecord(o))!.record;
    expect(ov.title, isNull);
    expect(ov.description, isNull);
    expect(ov.groupId, isNull);
  });

  test('第二次同步沒有變動（含推活、官方 tag）就不再傳輸', () async {
    final pitId = await a.createPit(name: '坑');
    await a.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 10, 1),
      images: [await imageOn(dirA, 'o.png')],
    );
    await engineA.sync();
    expect((await engineA.sync()).changed, isFalse);
    await engineB.sync();
    expect((await engineB.sync()).changed, isFalse);
    expect((await engineA.sync()).changed, isFalse);
  });
}
