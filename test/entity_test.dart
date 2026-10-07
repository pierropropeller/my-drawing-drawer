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

  const img = NewImage(file: 'a.png', width: 100, height: 50);

  Future<String> idea(String title) => db.saveIdea(
    pitId: pitId,
    title: title,
    body: '',
    images: const [],
    tagIds: const [],
    draftIds: const [],
    pieceIds: const [],
  );

  Future<String> draft({String? title, List<String> ideaIds = const []}) =>
      db.saveDraft(
        pitId: pitId,
        title: title,
        images: const [img],
        tagIds: const [],
        ideaIds: ideaIds,
      );

  Future<String> piece(
    String title, {
    List<String> ideaIds = const [],
    List<String> draftIds = const [],
  }) => db.savePiece(
    pitId: pitId,
    title: title,
    body: '',
    images: const [img],
    tagIds: const [],
    links: const [SocialLink('推特', 'https://x.com/a')],
    targetLikes: 100,
    finishedAt: DateTime(2026, 5, 1),
    ideaIds: ideaIds,
    draftIds: draftIds,
  );

  test('腦洞狀態由關係推導：未孵 → 孵化中 → 已孵', () async {
    final i = await idea('腦洞');
    var v = (await db.watchIdeaView(i).first)!;
    expect(v.status, IdeaStatus.open);
    final d = await draft(ideaIds: [i]);
    v = (await db.watchIdeaView(i).first)!;
    expect(v.status, IdeaStatus.hatching);
    expect(v.draftIds, [d]);
    await piece('成圖', ideaIds: [i]);
    v = (await db.watchIdeaView(i).first)!;
    expect(v.status, IdeaStatus.hatched);
  });

  test('坑卡片的「未孵腦洞數」只算沒有連接的腦洞', () async {
    final a = await idea('a');
    await idea('b');
    await draft(ideaIds: [a]);
    final s = await db.watchPitStats(pitId).first;
    expect(s.ideas, 2);
    expect(s.openIdeas, 1);
  });

  test('草稿：純圖判定與圖片數量', () async {
    final plain = await draft();
    final text = await draft(title: '有標題');
    final views = await db.watchDraftViews(pitId).first;
    expect(views.firstWhere((v) => v.draft.id == plain).imageOnly, isTrue);
    expect(views.firstWhere((v) => v.draft.id == text).imageOnly, isFalse);
    expect(views.first.images.single.aspect, 2);
  });

  test('成圖：連結、互動量、連接與刪除', () async {
    final i = await idea('腦洞');
    final d = await draft();
    final p = await piece('成圖', ideaIds: [i], draftIds: [d]);
    var v = (await db.watchPieceView(p).first)!;
    expect(v.links.single.url, 'https://x.com/a');
    expect(v.ideaIds, [i]);
    expect(v.draftIds, [d]);
    expect(v.piece.targetLikes, 100);
    await db.setActualLikes(p, 123);
    v = (await db.watchPieceView(p).first)!;
    expect(v.piece.actualLikes, 123);
    await db.deletePieces([p]);
    expect(await db.watchPieceView(p).first, isNull);
    // 刪除成圖後，腦洞回到未孵
    expect((await db.watchIdeaView(i).first)!.status, IdeaStatus.open);
  });

  test('編輯：圖片與 tag 整組替換', () async {
    final tag = await db.createTag(pitId, '角色1');
    final i = await db.saveIdea(
      pitId: pitId,
      title: 't',
      body: '',
      images: const [
        img,
        NewImage(file: 'b.png'),
      ],
      tagIds: [tag],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.saveIdea(
      id: i,
      pitId: pitId,
      title: 't2',
      body: 'x',
      images: const [NewImage(file: 'b.png')],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    final v = (await db.watchIdeaView(i).first)!;
    expect(v.idea.title, 't2');
    expect(v.images.map((e) => e.file), ['b.png']);
    expect(v.tags, isEmpty);
  });

  test('tag 篩選與使用次數涵蓋腦洞／成圖', () async {
    final tag = await db.createTag(pitId, '夏日');
    await db.saveIdea(
      pitId: pitId,
      title: 'a',
      body: '',
      images: const [],
      tagIds: [tag],
      draftIds: const [],
      pieceIds: const [],
    );
    await idea('b');
    expect((await db.watchIdeaViews(pitId, tagId: tag).first).length, 1);
    expect((await db.watchTagUsage(pitId).first).single.count, 1);
  });
}
