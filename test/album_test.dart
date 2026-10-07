import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';

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

  test('同人圖：出處篩選、tag 關聯、使用次數', () async {
    final tagId = await db.createTag(pitId, '角色1');
    expect(await db.createTag(pitId, '角色1'), tagId); // 同名不重複
    await db.addFanArts(
      pitId,
      [img],
      author: '@a',
      source: '推特',
      tagIds: [tagId],
    );
    await db.addFanArts(pitId, [img], author: '@b', source: 'lofter');
    expect((await db.watchFanArts(pitId, source: '推特').first).length, 1);
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
    await db.addFanArts(pitId, [img], author: '', source: '');
    final s = await db.watchPitStats(pitId).first;
    expect(s.official, 2);
    expect(s.fanArts, 1);
    expect(s.imageCount, 3);
  });
}
