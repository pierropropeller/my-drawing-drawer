import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/junk_queries.dart';

/// 雜物（D-034）與官方圖冊／好看同人圖／雜物之間的移動（D-044）。
void main() {
  late AppDatabase db;
  late String pitId;
  late List<OfficialGroup> groups;
  late List<OfficialGroup> fanGroups;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: 'A');
    groups = await db.watchGroups(pitId).first;
    fanGroups = await db.watchGroups(pitId, kind: 'fan').first;
  });
  tearDown(() => db.close());

  Future<OfficialImage> addOfficial(String file, {int group = 0}) async {
    await db.addOfficial(pitId, groups[group].id, [
      NewImage(file: file, width: 4, height: 3),
    ]);
    return (await db.watchOfficial(pitId).first).firstWhere(
      (i) => i.imageFile == file,
    );
  }

  test('雜物：新增、列出、刪除；坑可開關雜物；統計有雜物數但不計入圖片總數', () async {
    expect((await db.watchPit(pitId).first)!.junkEnabled, isFalse);
    await db.updatePit(pitId, name: 'A', archived: false, junkEnabled: true);
    expect((await db.watchPit(pitId).first)!.junkEnabled, isTrue);
    // junkEnabled 不傳＝不變
    await db.updatePit(pitId, name: 'A2', archived: false);
    expect((await db.watchPit(pitId).first)!.junkEnabled, isTrue);

    await db.addJunk(pitId, [
      const NewImage(file: 'j1.png', width: 1, height: 2),
      const NewImage(file: 'j2.png'),
    ]);
    final list = await db.watchJunk(pitId).first;
    expect(list.length, 2);
    expect(list.every((j) => j.imageKey == j.id), isTrue);
    final s = await db.watchPitStats(pitId).first;
    expect(s.junk, 2);
    expect(s.imageCount, 0);

    await db.deleteJunk([list.first.id]);
    expect((await db.watchJunk(pitId).first).length, 1);

    final other = await db.createPit(name: 'B', junkEnabled: true);
    expect((await db.watchPit(other).first)!.junkEnabled, isTrue);
  });

  test('刪除坑：雜物一併軟刪除', () async {
    await db.addJunk(pitId, [const NewImage(file: 'j.png')]);
    await db.deletePit(pitId);
    expect(await db.watchJunk(pitId).first, isEmpty);
    final raw = await db.select(db.junkImages).get();
    expect(raw.single.deletedAt, isNotNull);
  });

  test('官方 → 同人圖：來源隱藏、目標新建（作者空白）；移回恢復原分組', () async {
    final o = await addOfficial('a.png', group: 2);
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
      groupId: fanGroups[1].id,
    );
    expect(await db.watchOfficial(pitId).first, isEmpty);
    final fan = (await db.watchFanArts(pitId).first).single;
    expect(fan.imageFile, 'a.png');
    expect(fan.author, '');
    expect(fan.groupId, fanGroups[1].id);
    expect(fan.imageKey, o.imageKey);
    expect(fan.width, 4);

    var s = await db.watchPitStats(pitId).first;
    expect((s.official, s.fanArts, s.imageCount), (0, 1, 1));

    // 在同人圖那邊編輯作者後移回官方：回到原本的分組（素材），同一列
    await db.updateFanArt(
      fan.id,
      author: '@x',
      groupId: fan.groupId,
      tagIds: const [],
    );
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [fan.id],
      to: AlbumCell.official,
    );
    final back = (await db.watchOfficial(pitId).first).single;
    expect(back.id, o.id);
    expect(back.groupId, groups[2].id);
    expect(await db.watchFanArts(pitId).first, isEmpty);

    // 再移到同人圖：取消隱藏同一列，作者、出處都還在
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
    );
    final again = (await db.watchFanArts(pitId).first).single;
    expect(again.id, fan.id);
    expect(again.author, '@x');
    expect(again.groupId, fanGroups[1].id);
    s = await db.watchPitStats(pitId).first;
    expect((s.official, s.fanArts), (0, 1));
    // 資料庫裡沒有重複的列
    expect((await db.select(db.fanArts).get()).length, 1);
    expect((await db.select(db.officialImages).get()).length, 1);
  });

  test('同人圖 tag 隨隱藏列保留、不計入使用次數；移回恢復', () async {
    final t = await db.createTag(pitId, '角色1');
    await db.addFanArts(
      pitId,
      [const NewImage(file: 'f.png')],
      author: '@a',
      groupId: fanGroups[0].id,
      tagIds: [t],
    );
    final fan = (await db.watchFanArts(pitId).first).single;
    expect((await db.watchTagUsage(pitId).first).single.count, 1);

    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [fan.id],
      to: AlbumCell.official,
      groupId: groups[1].id,
    );
    expect((await db.watchTagUsage(pitId).first).single.count, 0);
    expect(await db.watchFanArts(pitId, tagId: t).first, isEmpty);
    expect(
      (await db.watchOfficial(pitId, groupId: groups[1].id).first).length,
      1,
    );

    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [(await db.watchOfficial(pitId).first).single.id],
      to: AlbumCell.fan,
    );
    expect((await db.watchTagUsage(pitId).first).single.count, 1);
    final back = (await db.watchFanArts(pitId, tagId: t).first).single;
    expect(back.author, '@a');
    expect(back.groupId, fanGroups[0].id);
  });

  test('官方 → 官方（換分組）只更新 groupId；雜物 → 雜物不做事', () async {
    final o = await addOfficial('a.png');
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.official,
      groupId: groups[3].id,
    );
    final r = (await db.watchOfficial(pitId).first).single;
    expect((r.id, r.groupId), (o.id, groups[3].id));
    expect((await db.select(db.officialImages).get()).length, 1);

    await db.addJunk(pitId, [const NewImage(file: 'j.png')]);
    final j = (await db.watchJunk(pitId).first).single;
    await db.moveAlbumImages(
      from: AlbumCell.junk,
      ids: [j.id],
      to: AlbumCell.junk,
    );
    expect((await db.select(db.junkImages).get()).length, 1);
  });

  test('移到雜物：封面被清掉、不可當封面候選；移回官方恢復', () async {
    final o = await addOfficial('a.png');
    final keep = await addOfficial('b.png');
    await db.setCover(pitId, o.id);
    await db.setOfficialCover(pitId, o.id);
    expect(await db.imageFileOf(o.id), 'a.png');

    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.junk,
    );
    final pit = (await db.watchPit(pitId).first)!;
    expect(pit.coverImageId, isNull);
    expect(pit.officialCoverId, isNull);
    expect(await db.imageFileOf(o.id), isNull); // 隱藏列不再解析成檔名
    final cands = await db.watchCoverCandidates(pitId).first;
    expect(cands.map((c) => c.file), ['b.png']);
    expect((await db.watchCellCovers(pitId).first).official, 'b.png');
    expect((await db.watchJunk(pitId).first).single.imageFile, 'a.png');

    await db.moveAlbumImages(
      from: AlbumCell.junk,
      ids: [(await db.watchJunk(pitId).first).single.id],
      to: AlbumCell.official,
    );
    expect(
      (await db.watchOfficial(pitId).first).map((i) => i.imageFile).toSet(),
      {'a.png', 'b.png'},
    );
    expect(keep.groupId, groups[0].id);
  });

  test('坑封面在官方 ↔ 同人圖之間移動時改指向新列', () async {
    final o = await addOfficial('a.png');
    await db.setCover(pitId, o.id);
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
    );
    final fan = (await db.watchFanArts(pitId).first).single;
    expect((await db.watchPit(pitId).first)!.coverImageId, fan.id);
    expect(await db.imageFileOf(fan.id), 'a.png');
  });

  test('隱藏列不出現在封面候選與格封面；刪除一張圖會連同隱藏分身一起刪', () async {
    final o = await addOfficial('a.png');
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
    );
    expect(
      (await db.watchCoverCandidates(pitId, kind: 'official').first),
      isEmpty,
    );
    expect((await db.watchCellCovers(pitId).first).official, isNull);
    expect((await db.watchCellCovers(pitId).first).fanArt, 'a.png');

    await db.deleteFanArts([(await db.watchFanArts(pitId).first).single.id]);
    expect(await db.watchFanArts(pitId).first, isEmpty);
    final hiddenTwin = await db.select(db.officialImages).getSingle();
    expect(hiddenTwin.deletedAt, isNotNull); // 隱藏的官方分身也已刪除
    // 之後不會有東西能「移回」來
    await db.addJunk(pitId, [const NewImage(file: 'j.png')]);
  });

  test('所有新增圖片的路徑都設定 imageKey', () async {
    await addOfficial('a.png');
    await db.addFanArts(pitId, [
      const NewImage(file: 'f1.png'),
      const NewImage(file: 'f2.png'),
    ], author: '');
    await db.addJunk(pitId, [const NewImage(file: 'j.png')]);
    for (final r in await db.select(db.officialImages).get()) {
      expect(r.imageKey, r.id);
    }
    final fans = await db.select(db.fanArts).get();
    expect(fans.map((r) => r.imageKey).toSet().length, 2);
    for (final r in fans) {
      expect(r.imageKey, r.id);
    }
    for (final r in await db.select(db.junkImages).get()) {
      expect(r.imageKey, r.id);
    }
  });
}
