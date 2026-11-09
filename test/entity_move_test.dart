import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_move_queries.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/junk_queries.dart';

/// 腦洞／摸魚／成圖跨坑移動（CR 2026-11-09）＋圖片跨坑的 tag 選項。
void main() {
  late AppDatabase db;
  late String a;
  late String b;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    a = await db.createPit(name: 'A');
    b = await db.createPit(name: 'B');
  });
  tearDown(() => db.close());

  Future<List<String>> tagNames(TagTarget target, String id) async {
    final ids = await db.watchTagIds(target, id).first;
    final all = await db.select(db.tags).get();
    return [
      for (final t in all)
        if (ids.contains(t.id)) '${t.pitId == a ? 'A' : 'B'}:${t.name}',
    ]..sort();
  }

  Future<(String, String, String)> linkedTrio({
    List<String> tags = const [],
  }) async {
    final draft = await db.saveDraft(
      pitId: a,
      title: null,
      body: '沒有標題的摸魚',
      images: const [NewImage(file: 'd.png', width: 4, height: 3)],
      tagIds: tags,
      ideaIds: const [],
    );
    final piece = await db.savePiece(
      pitId: a,
      title: '成圖',
      body: '',
      images: const [],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 11, 1),
      ideaIds: const [],
      draftIds: [draft],
    );
    final idea = await db.saveIdea(
      pitId: a,
      title: '腦洞',
      body: '',
      images: const [],
      tagIds: tags,
      draftIds: [draft],
      pieceIds: [piece],
    );
    return (idea, draft, piece);
  }

  test('列出會斷開的關聯：種類、標題／內文、第一張圖', () async {
    final (idea, draft, piece) = await linkedTrio();
    final fromIdea = await db.crossPitLinksOf(OwnerType.idea, [idea]);
    expect(
      [for (final x in fromIdea) x.type],
      [OwnerType.draft, OwnerType.piece],
    );
    final d = fromIdea.first;
    expect(d.id, draft);
    expect(d.title, isNull);
    expect(d.body, '沒有標題的摸魚');
    expect(d.firstImage?.file, 'd.png');
    final fromPiece = await db.crossPitLinksOf(OwnerType.piece, [piece]);
    expect({for (final x in fromPiece) x.id}, {idea, draft});
  });

  test('移動腦洞：改坑、斷開所有關聯，另一端留在原坑', () async {
    final (idea, draft, piece) = await linkedTrio();
    await db.moveEntitiesToPit(
      OwnerType.idea,
      [idea],
      b,
      createMissingTags: true,
    );
    final i = await (db.select(
      db.ideas,
    )..where((x) => x.id.equals(idea))).getSingle();
    expect(i.pitId, b);
    expect(await db.select(db.ideaDrafts).get(), isEmpty);
    expect(await db.select(db.ideaPieces).get(), isEmpty);
    // 摸魚↔成圖不受影響。
    expect((await db.select(db.draftPieces).get()).single.draftId, draft);
    final d = await (db.select(
      db.drafts,
    )..where((x) => x.id.equals(draft))).getSingle();
    expect(d.pitId, a);
    expect(await db.crossPitLinksOf(OwnerType.piece, [piece]), hasLength(1));
  });

  test('移動摸魚：斷開腦洞與成圖兩邊', () async {
    final (_, draft, _) = await linkedTrio();
    await db.moveEntitiesToPit(
      OwnerType.draft,
      [draft],
      b,
      createMissingTags: true,
    );
    expect(await db.select(db.ideaDrafts).get(), isEmpty);
    expect(await db.select(db.draftPieces).get(), isEmpty);
    expect(await db.select(db.ideaPieces).get(), hasLength(1));
  });

  test('tag：按名稱對應；缺的看選擇新增或不保留', () async {
    final t1 = await db.createTag(a, '角色');
    final t2 = await db.createTag(a, '企劃');
    await db.createTag(b, '角色');
    final (idea, draft, _) = await linkedTrio(tags: [t1, t2]);

    expect(await db.missingTagNamesForMove(TagTarget.idea, [idea], b), ['企劃']);

    await db.moveEntitiesToPit(
      OwnerType.idea,
      [idea],
      b,
      createMissingTags: false,
    );
    expect(await tagNames(TagTarget.idea, idea), ['B:角色']);

    await db.moveEntitiesToPit(
      OwnerType.draft,
      [draft],
      b,
      createMissingTags: true,
    );
    expect(await tagNames(TagTarget.draft, draft), ['B:企劃', 'B:角色']);
  });

  test('原坑的格子封面若是被移走的圖，清掉', () async {
    final (_, draft, _) = await linkedTrio();
    final img = await (db.select(
      db.entityImages,
    )..where((i) => i.ownerId.equals(draft))).getSingle();
    await db.setCellCover(a, 'draft', img.id);
    expect(
      (await (db.select(
        db.pits,
      )..where((x) => x.id.equals(a))).getSingle()).draftCoverFile,
      img.imageFile,
    );
    await db.moveEntitiesToPit(
      OwnerType.draft,
      [draft],
      b,
      createMissingTags: true,
    );
    final p = await (db.select(
      db.pits,
    )..where((x) => x.id.equals(a))).getSingle();
    expect(p.draftCoverFile, isNull);
  });

  test('已在目標坑的項目不動', () async {
    final (idea, _, _) = await linkedTrio();
    await db.moveEntitiesToPit(
      OwnerType.idea,
      [idea],
      a,
      createMissingTags: true,
    );
    expect(await db.select(db.ideaDrafts).get(), hasLength(1));
  });

  test('圖片跨坑：createMissingTags=false 不帶目標坑沒有的 tag', () async {
    final t1 = await db.createTag(a, '角色');
    final t2 = await db.createTag(a, '風景');
    await db.createTag(b, '角色');
    await db.addFanArts(
      a,
      const [NewImage(file: 'f.png', width: 4, height: 3)],
      author: 'au',
      tagIds: [t1, t2],
    );
    final f = (await db.watchFanArts(a).first).single;
    expect(await db.missingTagNamesForMove(TagTarget.fanArt, [f.id], b), [
      '風景',
    ]);
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [f.id],
      to: AlbumCell.fan,
      targetPitId: b,
      createMissingTags: false,
    );
    final inB = (await db.watchFanArts(b).first).single;
    expect(await tagNames(TagTarget.fanArt, inB.id), ['B:角色']);
    final bTags = await (db.select(
      db.tags,
    )..where((t) => t.pitId.equals(b))).get();
    expect([for (final t in bTags) t.name], ['角色']);
  });
}
