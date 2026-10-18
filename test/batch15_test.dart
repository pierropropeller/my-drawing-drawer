import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/search_queries.dart';

/// 批次 15 資料層：D-089 官方圖 tag（篩選、編輯、批量、搜尋、常用 tag 計數）。
void main() {
  late AppDatabase db;
  late String pitId;
  late String groupId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '坑A');
    groupId = (await db.watchGroups(pitId).first).first.id;
  });
  tearDown(() => db.close());

  Future<List<String>> addTwo(List<String> tagIds) async {
    await db.addOfficial(pitId, groupId, [
      NewImage(file: 'a.png'),
    ], tagIds: tagIds);
    await db.addOfficial(pitId, groupId, [NewImage(file: 'b.png')]);
    final rows = await db.watchOfficial(pitId).first;
    return [for (final r in rows) r.id];
  }

  test('watchOfficial 依 tag 篩選，可和分組並用', () async {
    final t = await db.createTag(pitId, '角色1');
    await addTwo([t]);
    expect((await db.watchOfficial(pitId).first).length, 2);
    final hit = await db.watchOfficial(pitId, tagId: t).first;
    expect(hit.map((e) => e.imageFile), ['a.png']);
    await db.addGroup(pitId, '別組');
    final other = (await db.watchGroups(pitId).first).last.id;
    expect(
      await db.watchOfficial(pitId, groupId: other, tagId: t).first,
      isEmpty,
    );
    expect(
      (await db.watchOfficial(pitId, groupId: groupId, tagId: t).first).length,
      1,
    );
  });

  test('updateOfficial 同時換分組與 tag，並更新 updatedAt', () async {
    final t1 = await db.createTag(pitId, '角色1');
    final t2 = await db.createTag(pitId, '角色2');
    await addTwo([t1]);
    final first = (await db.watchOfficial(pitId, tagId: t1).first).single;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await db.addGroup(pitId, '別組');
    final other = (await db.watchGroups(pitId).first).last.id;
    await db.updateOfficial(first.id, groupId: other, tagIds: [t2]);
    expect(await db.watchOfficial(pitId, tagId: t1).first, isEmpty);
    final row = (await db.watchOfficial(pitId, tagId: t2).first).single;
    expect(row.groupId, other);
    expect(row.updatedAt.isAfter(first.updatedAt), isTrue);
    expect(await db.watchTagIds(TagTarget.official, first.id).first, [t2]);
  });

  test('批量加減 tag 對官方圖有效', () async {
    final t = await db.createTag(pitId, '角色1');
    final ids = await addTwo([]);
    await db.applyBatchTags(AlbumCell.official, ids, addTagIds: [t]);
    expect((await db.watchOfficial(pitId, tagId: t).first).length, 2);
    await db.applyBatchTags(
      AlbumCell.official,
      [ids.first],
      removeTagIds: [t],
    );
    expect((await db.watchOfficial(pitId, tagId: t).first).length, 1);
  });

  test('常用 tag 計數含官方圖，刪除的官方圖不算', () async {
    final t = await db.createTag(pitId, '角色1');
    final ids = await addTwo([t]);
    var usage = await db.watchTagUsage(pitId).first;
    expect(usage.firstWhere((u) => u.tag.id == t).count, 1);
    await db.deleteOfficial(ids);
    usage = await db.watchTagUsage(pitId).first;
    expect(usage.firstWhere((u) => u.tag.id == t).count, 0);
  });

  test('坑內搜尋：官方圖冊一段，排在成圖之後、同人圖之前', () async {
    final t = await db.createTag(pitId, '角色1');
    await addTwo([t]);
    await db.addFanArts(pitId, [
      NewImage(file: 'f.png'),
    ], author: 'x', tagIds: [t]);
    final res = await db.watchPitSearch(pitId, tagId: t).first;
    expect(res.official.total, 1);
    expect(res.official.items.single.imageFile, 'a.png');
    expect(res.total, 2);
    expect(res.visibleSections, [
      PitSearchSection.official,
      PitSearchSection.fanArts,
    ]);
    final byText = await db.watchPitSearch(pitId, text: '角色1').first;
    expect(byText.official.total, 1);
    final none = await db.watchPitSearch(pitId, text: '不存在').first;
    expect(none.official.total, 0);
  });
}
