import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/album_set_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/junk_queries.dart';

/// D-136：官方圖／同人圖多圖（一組）。
void main() {
  late AppDatabase db;
  late String pitId;
  late String groupId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '測試坑');
    groupId = (await db.watchGroups(pitId).first).first.id;
  });
  tearDown(() => db.close());

  NewImage im(String f) => NewImage(file: f, width: 10, height: 20);

  test('合成一組：一筆、第 1 張在列上、其餘是額外圖', () async {
    await db.addOfficialSet(pitId, groupId, [im('a'), im('b'), im('c')]);
    final rows = await db.watchOfficial(pitId).first;
    expect(rows.length, 1);
    expect(rows.single.imageFile, 'a');
    final all = await db.albumSetImages(AlbumCell.official, rows.single.id);
    expect(all.map((e) => e.file), ['a', 'b', 'c']);
    final counts = await db.watchAlbumExtraCounts().first;
    expect(counts[rows.single.imageKey], 2);
  });

  test('編輯：換次序、刪一張、加一張', () async {
    await db.addOfficialSet(pitId, groupId, [im('a'), im('b'), im('c')]);
    final id = (await db.watchOfficial(pitId).first).single.id;
    await db.setAlbumSetImages(AlbumCell.official, id, [
      im('c'),
      im('a'),
      im('d'),
    ]);
    final row = (await db.watchOfficial(pitId).first).single;
    expect(row.imageFile, 'c');
    final all = await db.albumSetImages(AlbumCell.official, id);
    expect(all.map((e) => e.file), ['c', 'a', 'd']);
  });

  test('拆開：每張一筆，tag 照抄', () async {
    final tag = await db.createTag(pitId, '角色1');
    await db.addFanArtSet(
      pitId,
      [im('a'), im('b')],
      author: '某某',
      tagIds: [tag],
    );
    final id = (await db.watchFanArts(pitId).first).single.id;
    final created = await db.splitAlbumSet(AlbumCell.fan, id);
    expect(created.length, 1);
    final rows = await db.watchFanArts(pitId).first;
    expect(rows.length, 2);
    expect(rows.map((r) => r.imageFile).toSet(), {'a', 'b'});
    expect(rows.every((r) => r.author == '某某'), isTrue);
    expect(await db.watchTagIds(TagTarget.fanArt, created.single).first, [tag]);
    expect(await db.albumExtrasOf(id), isEmpty);
  });

  test('合併：第 1 筆留下，其餘的圖接在後面、tag 合併，其餘筆不進最近刪除', () async {
    final t1 = await db.createTag(pitId, 't1');
    final t2 = await db.createTag(pitId, 't2');
    final a = await db.addOfficial(pitId, groupId, [im('a')], tagIds: [t1]);
    await db.addOfficialSet(pitId, groupId, [im('b'), im('c')], tagIds: [t2]);
    final rows = await db.watchOfficial(pitId).first;
    final b = rows.firstWhere((r) => r.imageFile == 'b').id;
    final keep = await db.mergeAlbumSets(AlbumCell.official, [a.single, b]);
    expect(keep, a.single);
    final left = await db.watchOfficial(pitId).first;
    expect(left.single.id, a.single);
    final all = await db.albumSetImages(AlbumCell.official, a.single);
    expect(all.map((e) => e.file), ['a', 'b', 'c']);
    expect((await db.watchTagIds(TagTarget.official, a.single).first).toSet(), {
      t1,
      t2,
    });
  });

  test('移到同人圖：整組跟著走', () async {
    await db.addOfficialSet(pitId, groupId, [im('a'), im('b')]);
    final id = (await db.watchOfficial(pitId).first).single.id;
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [id],
      to: AlbumCell.fan,
    );
    final fan = (await db.watchFanArts(pitId).first).single;
    final all = await db.albumSetImages(AlbumCell.fan, fan.id);
    expect(all.map((e) => e.file), ['a', 'b']);
  });
}
