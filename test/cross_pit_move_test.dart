import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 跨坑移動（D-054）：tag 按名稱對應、移回恢復、封面、隱藏列、同步。
void main() {
  late AppDatabase db;
  late String a;
  late String b;
  late List<OfficialGroup> aOfficial;
  late List<OfficialGroup> bOfficial;
  late List<OfficialGroup> bFan;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    a = await db.createPit(name: 'A');
    b = await db.createPit(name: 'B');
    aOfficial = await db.watchGroups(a).first;
    bOfficial = await db.watchGroups(b).first;
    bFan = await db.watchGroups(b, kind: 'fan').first;
  });
  tearDown(() => db.close());

  Future<OfficialImage> official(String pit, String groupId, String f) async {
    await db.addOfficial(pit, groupId, [
      NewImage(file: f, width: 4, height: 3),
    ]);
    return (await db.watchOfficial(pit).first).firstWhere(
      (i) => i.imageFile == f,
    );
  }

  Future<FanArt> fan(
    String pit,
    String f, {
    List<String> tagIds = const [],
    String author = 'au',
  }) async {
    await db.addFanArts(
      pit,
      [NewImage(file: f, width: 4, height: 3)],
      author: author,
      tagIds: tagIds,
    );
    return (await db.watchFanArts(pit).first).firstWhere(
      (i) => i.imageFile == f,
    );
  }

  Future<List<String>> tagNamesOf(String fanId) async {
    final ids = await db.watchTagIds(TagTarget.fanArt, fanId).first;
    final all = await db.select(db.tags).get();
    return [
      for (final t in all)
        if (ids.contains(t.id)) t.name,
    ]..sort();
  }

  test('官方跨坑：目標坑新建（預設第一個分組）、來源隱藏、移回恢復', () async {
    final o = await official(a, aOfficial[2].id, 'o.png');
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.official,
      targetPitId: b,
    );
    expect(await db.watchOfficial(a).first, isEmpty);
    final inB = await db.watchOfficial(b).first;
    expect(inB.single.imageFile, 'o.png');
    expect(inB.single.pitId, b);
    expect(inB.single.groupId, bOfficial.first.id);
    expect(inB.single.imageKey, o.imageKey);
    // 隱藏列留在原坑
    final raw = await db.select(db.officialImages).get();
    final hidden = raw.singleWhere((r) => r.hidden);
    expect((hidden.pitId, hidden.groupId), (a, aOfficial[2].id));
    expect((await db.watchPitStats(a).first).imageCount, 0);
    expect((await db.watchPitStats(b).first).imageCount, 1);

    // 移回 A：恢復原本的分組、不新增列
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [inB.single.id],
      to: AlbumCell.official,
      targetPitId: a,
    );
    final back = await db.watchOfficial(a).first;
    expect(back.single.id, o.id);
    expect(back.single.groupId, aOfficial[2].id);
    expect(await db.watchOfficial(b).first, isEmpty);
    expect((await db.select(db.officialImages).get()).length, 2);
  });

  test('官方跨坑：指定目標坑的分組；分組不屬於目標坑會丟 ArgumentError', () async {
    final o = await official(a, aOfficial[0].id, 'o.png');
    await expectLater(
      db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [o.id],
        to: AlbumCell.official,
        groupId: aOfficial[1].id,
        targetPitId: b,
      ),
      throwsArgumentError,
    );
    // transaction 失敗：沒有任何變動
    expect((await db.watchOfficial(a).first).single.id, o.id);
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.official,
      groupId: bOfficial[1].id,
      targetPitId: b,
    );
    expect((await db.watchOfficial(b).first).single.groupId, bOfficial[1].id);
  });

  test('同人圖跨坑：tag 按名稱對應既有、缺的自動新增，作者保留', () async {
    final tA1 = await db.createTag(a, '角色');
    final tA2 = await db.createTag(a, '風景');
    final tB = await db.createTag(b, '角色'); // 目標坑已有同名
    final f = await fan(a, 'f.png', tagIds: [tA1, tA2]);

    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [f.id],
      to: AlbumCell.fan,
      groupId: bFan.first.id,
      targetPitId: b,
    );
    expect(await db.watchFanArts(a).first, isEmpty);
    final inB = (await db.watchFanArts(b).first).single;
    expect((inB.pitId, inB.author, inB.groupId), (b, 'au', bFan.first.id));
    expect(await tagNamesOf(inB.id), ['角色', '風景']);
    // 既有的 tag 重用、不重複建立；缺的新增在目標坑
    final bTags = await db.watchTags(b).first;
    expect(bTags.map((t) => t.name).toSet(), {'角色', '風景'});
    expect(bTags.where((t) => t.name == '角色').single.id, tB);
    // 來源坑的 tag 不變
    expect((await db.watchTags(a).first).length, 2);
    // 用量：A 的 tag 因為來源隱藏而 0 次，B 的各 1 次
    final useA = await db.watchTagUsage(a).first;
    expect(useA.every((u) => u.count == 0), isTrue);
    final useB = await db.watchTagUsage(b).first;
    expect(useB.every((u) => u.count == 1), isTrue);

    // 在 B 改 tag 後移回 A：恢復 A 原本的隱藏列與它原本的 tag
    await db.setTags(TagTarget.fanArt, inB.id, const []);
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [inB.id],
      to: AlbumCell.fan,
      targetPitId: a,
    );
    final back = (await db.watchFanArts(a).first).single;
    expect(back.id, f.id);
    expect(await tagNamesOf(back.id), ['角色', '風景']);
    expect(await db.watchFanArts(b).first, isEmpty);
    expect((await db.select(db.fanArts).get()).length, 2);
  });

  test('同人圖跨坑 → 官方 → 回同人圖：tag 留在隱藏列，不重複對應', () async {
    final tA = await db.createTag(a, 't');
    final f = await fan(a, 'f.png', tagIds: [tA]);
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [f.id],
      to: AlbumCell.official,
      targetPitId: b,
    );
    // 目標是官方：不建立 tag
    expect(await db.watchTags(b).first, isEmpty);
    final o = (await db.watchOfficial(b).first).single;
    expect(o.groupId, bOfficial.first.id);
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.fan,
      targetPitId: a,
    );
    expect(await tagNamesOf((await db.watchFanArts(a).first).single.id), ['t']);
  });

  test('雜物不需要分組；跨坑到雜物、官方→B 的雜物', () async {
    final o = await official(a, aOfficial.first.id, 'o.png');
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.junk,
      targetPitId: b,
    );
    expect(await db.watchOfficial(a).first, isEmpty);
    final j = await db.watchJunk(b).first;
    expect(j.single.pitId, b);
    expect(await db.watchJunk(a).first, isEmpty);
    // 雜物跨坑（同格）：B → A
    await db.moveAlbumImages(
      from: AlbumCell.junk,
      ids: [j.single.id],
      to: AlbumCell.junk,
      targetPitId: a,
    );
    expect(await db.watchJunk(b).first, isEmpty);
    expect((await db.watchJunk(a).first).single.pitId, a);
  });

  test('封面：來源坑指向被移動列的封面清成 null；移進目標坑不設封面', () async {
    final o = await official(a, aOfficial.first.id, 'o.png');
    final other = await official(b, bOfficial.first.id, 'keep.png');
    await db.setCover(b, other.id);
    await db.setCover(a, o.id);
    await db.setOfficialCover(a, o.id);

    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.official,
      targetPitId: b,
    );
    final pa = (await db.watchPit(a).first)!;
    expect(pa.coverImageId, isNull);
    expect(pa.officialCoverId, isNull);
    final pb = (await db.watchPit(b).first)!;
    expect(pb.coverImageId, other.id); // 目標坑的封面不受影響
    expect(pb.officialCoverId, isNull);

    // 同坑跨格仍維持舊行為：坑封面改指向新列
    final o2 = await official(a, aOfficial.first.id, 'o2.png');
    await db.setCover(a, o2.id);
    await db.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o2.id],
      to: AlbumCell.fan,
    );
    final newFan = (await db.watchFanArts(a).first).single;
    expect((await db.watchPit(a).first)!.coverImageId, newFan.id);
  });

  test('隱藏列各處都排除：搜尋、封面候選、統計、tag 用量', () async {
    final t = await db.createTag(a, '特別');
    final f = await fan(a, 'f.png', tagIds: [t]);
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [f.id],
      to: AlbumCell.fan,
      targetPitId: b,
    );
    expect(await db.watchFanArts(a).first, isEmpty);
    expect((await db.watchPitStats(a).first).imageCount, 0);
    expect(await db.imageFileOf(f.id), isNull);
    final candidates = await db.watchCoverCandidates(a).first;
    expect(candidates, isEmpty);
    // 刪除 B 的列：A 的隱藏分身一起軟刪除，不會殘留
    final inB = (await db.watchFanArts(b).first).single;
    await db.deleteFanArts([inB.id]);
    final raw = await db.select(db.fanArts).get();
    expect(raw.length, 2);
    expect(raw.every((r) => r.deletedAt != null), isTrue);
  });

  test('同步：跨坑移動後的新列、隱藏列、新 tag 都同步到另一台', () async {
    final dirA = await Directory.systemTemp.createTemp('xp_a');
    final dirB = await Directory.systemTemp.createTemp('xp_b');
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final remote = MemoryRemote();
    final e1 = SyncEngine(db: db, remote: remote, images: ImageStore(dirA));
    final e2 = SyncEngine(db: other, remote: remote, images: ImageStore(dirB));

    final tA = await db.createTag(a, '角色');
    final f = await fan(a, 'f.png', tagIds: [tA]);
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [f.id],
      to: AlbumCell.fan,
      targetPitId: b,
    );
    await e1.sync();
    await e2.sync();

    expect(await other.watchFanArts(a).first, isEmpty);
    final inB = (await other.watchFanArts(b).first).single;
    expect(inB.pitId, b);
    final names = {for (final t in await other.watchTags(b).first) t.name};
    expect(names, {'角色'});
    final ids = await other.watchTagIds(TagTarget.fanArt, inB.id).first;
    expect(ids.length, 1);
    // 隱藏的原列也過去了：在另一台移回 A 會恢復它
    await other.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [inB.id],
      to: AlbumCell.fan,
      targetPitId: a,
    );
    expect((await other.watchFanArts(a).first).single.id, f.id);
  });
}
