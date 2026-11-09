import 'package:drift/drift.dart'
    show BooleanExpressionOperators, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/inspo_queries.dart';
import 'package:huakeng/data/junk_queries.dart' show AlbumCell;
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/trash_queries.dart';

/// 參考圖／靈感廣場（D-140～D-145）：自訂分類、說明、放進坑（連結）、移出、坑圖移到廣場、
/// 刪除與還原連動。
void main() {
  late AppDatabase db;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  NewImage im(String f) => NewImage(file: f, width: 30, height: 40);
  final pose = materialCategoryIdOf(MaterialCategory.pose);

  Future<String> firstGroup(String pitId) async =>
      (await db.watchGroups(pitId).first).first.id;

  Future<List<OfficialImage>> liveOfficial(String pitId) => (db.select(
    db.officialImages,
  )..where((o) => o.pitId.equals(pitId) & o.deletedAt.isNull())).get();

  test('新坑的參考圖預設分組是新的 11 個', () async {
    final pit = await db.createPit(name: '坑A');
    final names = [for (final g in await db.watchGroups(pit).first) g.name];
    expect(names, AppDatabase.defaultGroups);
    expect(names, contains('海報宣傳'));
    expect(names, isNot(contains('素材')));
  });

  test('預設 7 個廣場分類；可新增、改名、排序；刪除時圖移到第一個、至少留一個', () async {
    final cats = await db.loadInspoCategories();
    expect([
      for (final c in cats) c.name,
    ], AppDatabase.defaultMaterialCategoryNames);
    expect(cats.first.id, materialCategoryIdOf(MaterialCategory.clothing));

    final id = await db.addInspoCategory('手部');
    await db.renameInspoCategory(id, '手');
    var all = await db.loadInspoCategories();
    expect(all.last.name, '手');

    final ids = await db.addMaterials(id, [im('a.png')]);
    expect((await db.watchMaterials(category: id).first).single.id, ids.single);

    await db.reorderInspoCategories([id, ...cats.map((c) => c.id)]);
    all = await db.loadInspoCategories();
    expect(all.first.id, id);

    expect(await db.deleteInspoCategory(id), isTrue);
    all = await db.loadInspoCategories();
    expect(all.any((c) => c.id == id), isFalse);
    // 圖改歸剩下的第一個分類。
    final moved = (await db.watchMaterials().first).single;
    expect(moved.categoryKey, all.first.id);

    for (final c in all.skip(1)) {
      expect(await db.deleteInspoCategory(c.id), isTrue);
    }
    expect(await db.deleteInspoCategory(all.first.id), isFalse);
  });

  test('自訂分類的圖：舊欄位寫 clothing（舊版 App 也讀得到）', () async {
    final id = await db.addInspoCategory('手');
    await db.addMaterials(id, [im('a.png')]);
    final row = (await db.select(db.materialImages).get()).single;
    expect(row.categoryId, id);
    expect(row.category, MaterialCategory.clothing);
    expect((await db.watchMaterialCounts().first).of(id), 1);
  });

  test('放進坑：建立連結參考圖（同一個檔案）、跳過已在坑裡的、說明共用、記得放進了哪些坑', () async {
    final a = await db.createPit(name: '坑A');
    final b = await db.createPit(name: '坑B');
    final [m1, m2] = await db.addMaterials(pose, [im('m1.png'), im('m2.png')]);
    await db.setMaterialNote(m1, '  手臂要壓短  ');

    final added = await db.placeMaterials([m1, m2], a, await firstGroup(a));
    expect(added, hasLength(2));
    // 再放一次：全部跳過。
    expect(await db.placeMaterials([m1], a, await firstGroup(a)), isEmpty);
    await db.placeMaterials([m1], b, await firstGroup(b));

    final rows = await liveOfficial(a);
    expect(rows, hasLength(2));
    final placed = rows.firstWhere((r) => r.materialId == m1);
    expect(placed.imageFile, 'm1.png');
    expect(placed.imageKey, placed.id);

    // 說明：讀的是廣場那張；在參考圖改＝改廣場那張。
    expect(await db.watchOfficialNote(placed.id).first, '手臂要壓短');
    expect((await db.watchOfficialNotes(a).first)[placed.id], '手臂要壓短');
    await db.setOfficialNote(placed.id, '改過');
    final mat = (await db.watchMaterials().first).firstWhere((m) => m.id == m1);
    expect(mat.note, '改過');

    final pits = await db.watchPlacedPits().first;
    expect([for (final p in pits[m1]!) p.name], ['坑A', '坑B']);
    expect([for (final p in pits[m2]!) p.name], ['坑A']);
  });

  test('移出：只解除連結，廣場那張還在，不進最近刪除', () async {
    final a = await db.createPit(name: '坑A');
    final [m1] = await db.addMaterials(pose, [im('m1.png')]);
    final [o] = await db.placeMaterials([m1], a, await firstGroup(a));
    await db.unplaceOfficial([o]);
    expect(await liveOfficial(a), isEmpty);
    expect(await db.watchMaterials().first, hasLength(1));
    final trash = await db.watchTrash().first;
    expect(trash.items, isEmpty);
    expect(await db.watchPlacedPits().first, isEmpty);
  });

  test('刪除廣場圖：放進坑的一起拿掉；還原時一起回來；最近刪除只列廣場那張', () async {
    final a = await db.createPit(name: '坑A');
    final [m1] = await db.addMaterials(pose, [im('m1.png')]);
    await db.placeMaterials([m1], a, await firstGroup(a));
    await db.deleteMaterials([m1]);
    expect(await liveOfficial(a), isEmpty);
    final trash = await db.watchTrash().first;
    expect(trash.items, hasLength(1));
    expect(trash.items.single.kind, TrashKind.material);

    await db.restoreItems(trash.items);
    expect(await liveOfficial(a), hasLength(1));
    expect(await db.watchMaterials().first, hasLength(1));
  });

  test('坑圖移到廣場：廣場多一張（說明帶過去），坑裡那張拿走且不進最近刪除', () async {
    final a = await db.createPit(name: '坑A');
    await db.addOfficial(a, await firstGroup(a), [im('o.png')], note: '看背面');
    final o = (await liveOfficial(a)).single;
    await db.addFanArts(a, [im('f.png')], author: 'X', note: '線條');
    final f = (await db.select(db.fanArts).get()).single;

    await db.moveToInspo(AlbumCell.official, [o.id], pose);
    await db.moveToInspo(AlbumCell.fan, [f.id], pose);

    expect(await liveOfficial(a), isEmpty);
    final mats = await db.watchMaterials().first;
    expect(
      {for (final m in mats) m.imageFile: m.note},
      {'o.png': '看背面', 'f.png': '線條'},
    );
    expect((await db.watchTrash().first).items, isEmpty);
  });

  test('從廣場放進來的參考圖再移到廣場：只解除連結，不重複建立', () async {
    final a = await db.createPit(name: '坑A');
    final [m1] = await db.addMaterials(pose, [im('m1.png')]);
    final [o] = await db.placeMaterials([m1], a, await firstGroup(a));
    await db.moveToInspo(AlbumCell.official, [o], pose);
    expect(await db.watchMaterials().first, hasLength(1));
    expect(await liveOfficial(a), isEmpty);
  });
}
