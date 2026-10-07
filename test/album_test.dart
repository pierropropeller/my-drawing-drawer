import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';

void main() {
  late AppDatabase db;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '測試坑');
  });
  tearDown(() => db.close());

  const img = NewImage(file: 'a.png', width: 100, height: 200);

  test('官方圖：新增、依分組篩選、刪除', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, groups[0].id, [img, img]);
    await db.addOfficial(pitId, groups[1].id, [img]);
    expect((await db.watchOfficial(pitId).first).length, 3);
    final g0 = await db.watchOfficial(pitId, groupId: groups[0].id).first;
    expect(g0.length, 2);
    expect(g0.first.width, 100);
    await db.deleteOfficial([g0.first.id]);
    expect((await db.watchOfficial(pitId).first).length, 2);
  });

  test('刪除分組：組內圖移到其他分組，最後一個分組不能刪', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, groups[0].id, [img]);
    expect(await db.deleteGroup(groups[0].id), isTrue);
    final rest = await db.watchGroups(pitId).first;
    expect(rest.length, groups.length - 1);
    final moved = await db.watchOfficial(pitId, groupId: rest.first.id).first;
    expect(moved.length, 1);
    for (final g in rest.skip(1)) {
      await db.deleteGroup(g.id);
    }
    expect(await db.deleteGroup(rest.first.id), isFalse);
  });

  test('分組排序與新增', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.reorderGroups(groups.reversed.map((g) => g.id).toList());
    final reordered = await db.watchGroups(pitId).first;
    expect(reordered.first.id, groups.last.id);
    await db.addGroup(pitId, '新分組');
    expect((await db.watchGroups(pitId).first).last.name, '新分組');
  });

  test('同人圖：分組篩選、tag 關聯、使用次數', () async {
    final tagId = await db.createTag(pitId, '角色1');
    expect(await db.createTag(pitId, '角色1'), tagId); // 同名不重複
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    expect(fan.map((g) => g.name), AppDatabase.defaultFanGroups);
    await db.addFanArts(
      pitId,
      [img],
      author: '@a',
      groupId: fan[0].id,
      tagIds: [tagId],
    );
    await db.addFanArts(pitId, [img], author: '@b', groupId: fan[2].id);
    expect((await db.watchFanArts(pitId, groupId: fan[0].id).first).length, 1);
    final usage = await db.watchTagUsage(pitId).first;
    expect(usage.single.count, 1);
    await db.deleteTag(tagId);
    expect(await db.watchTags(pitId).first, isEmpty);
  });

  test('tag 按坑獨立', () async {
    final other = await db.createPit(name: '另一個坑');
    await db.createTag(pitId, '夏日');
    expect(await db.watchTags(other).first, isEmpty);
  });

  test('封面：設定後可取得檔名，圖被刪除時一併清除', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, groups[0].id, [img]);
    final id = (await db.watchOfficial(pitId).first).single.id;
    await db.setCover(pitId, id);
    expect(await db.imageFileOf(id), 'a.png');
    await db.deleteOfficial([id]);
    final pit = await db.watchPit(pitId).first;
    expect(pit!.coverImageId, isNull);
  });

  test('統計：圖片數量', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, groups[0].id, [img, img]);
    await db.addFanArts(pitId, [img], author: '');
    final s = await db.watchPitStats(pitId).first;
    expect(s.official, 2);
    expect(s.fanArts, 1);
    expect(s.imageCount, 3);
  });

  test('預設分組：官方圖冊沒有「自定義」，有「圖透」「官方周邊」；同人圖有各出處', () async {
    final official = await db.watchGroups(pitId).first;
    expect(official.map((g) => g.name), [
      '設定圖',
      '海報宣傳',
      '素材',
      '自用截圖',
      '圖透',
      '官方周邊',
    ]);
    expect(official.any((g) => g.name == '自定義'), isFalse);
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    expect(fan.map((g) => g.name), ['推特', '小紅書', 'lofter', '朋友發的', '網上搜的']);
  });

  test('刪除同人圖分組：組內圖移到同種類的其他分組，不會跑進官方分組', () async {
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    await db.addFanArts(pitId, [img], author: '', groupId: fan[0].id);
    expect(await db.deleteGroup(fan[0].id), isTrue);
    final art = (await db.watchFanArts(pitId).first).single;
    expect(art.groupId, fan[1].id);
    final official = await db.watchGroups(pitId).first;
    expect(official.length, 6);
  });

  test('同人圖分組可以自己新增，不影響官方分組', () async {
    await db.addGroup(pitId, '自己的分組', kind: 'fan');
    expect((await db.watchGroups(pitId, kind: 'fan').first).last.name, '自己的分組');
    expect((await db.watchGroups(pitId).first).length, 6);
  });

  test('「設為封面」設的是這一格的封面，不是主頁坑的封面', () async {
    final groups = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, groups[0].id, [
      img,
      const NewImage(file: 'b.png'),
    ]);
    final all = await db.watchOfficial(pitId).first;
    final target = all.firstWhere((o) => o.imageFile == 'a.png');
    await db.setOfficialCover(pitId, target.id);
    var covers = await db.watchCellCovers(pitId).first;
    expect(covers.official, 'a.png');
    var pit = (await db.watchPit(pitId).first)!;
    expect(pit.coverImageId, isNull); // 主頁封面沒被動到
    expect(pit.officialCoverId, target.id);
    // 沒指定時用最新一張；刪掉封面圖後退回最新
    await db.deleteOfficial([target.id]);
    covers = await db.watchCellCovers(pitId).first;
    expect(covers.official, 'b.png');
    pit = (await db.watchPit(pitId).first)!;
    expect(pit.officialCoverId, isNull);
  });

  test('坑封面可從任一格選圖；腦洞／草稿／成圖編輯後封面不會失效', () async {
    final id = await db.saveIdea(
      pitId: pitId,
      title: 't',
      body: '',
      images: const [
        NewImage(file: 'x.png'),
        NewImage(file: 'y.png'),
      ],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    final cands = await db.watchCoverCandidates(pitId, kind: 'idea').first;
    expect(cands.map((c) => c.file), ['x.png', 'y.png']);
    expect(await db.watchCoverCandidates(pitId, kind: 'piece').first, isEmpty);
    await db.setCover(pitId, cands.last.id);
    expect(await db.imageFileOf(cands.last.id), 'y.png');
    // 編輯腦洞（圖片清單不變）後，封面用的圖片 id 仍然有效
    await db.saveIdea(
      id: id,
      pitId: pitId,
      title: 't2',
      body: '',
      images: const [
        NewImage(file: 'x.png'),
        NewImage(file: 'y.png'),
        NewImage(file: 'z.png'),
      ],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    expect(await db.imageFileOf(cands.last.id), 'y.png');
    expect((await db.watchCoverCandidates(pitId).first).length, 3);
  });

  test('主頁的坑依「最後更新」排序：坑內有新內容就排到最前', () async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final a = await db.createPit(name: 'A');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final b = await db.createPit(name: 'B');
    // 新增順序 pitId(最舊) < a < b，但 a 內加了圖，a 應排第一
    var order = (await db.watchPits(archived: false).first)
        .map((p) => p.id)
        .toList();
    expect(order.first, b);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await db.addOfficial(a, (await db.watchGroups(a).first).first.id, [img]);
    order = (await db.watchPits(archived: false).first)
        .map((p) => p.id)
        .toList();
    expect(order.first, a);
    // 之後編輯 B 本身，B 又回到最前
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await db.updatePit(b, name: 'B2', archived: false);
    order = (await db.watchPits(archived: false).first)
        .map((p) => p.id)
        .toList();
    expect(order.first, b);
    expect(order.length, 3);
  });
}
