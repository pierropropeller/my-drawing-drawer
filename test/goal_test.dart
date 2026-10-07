import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';

void main() {
  late AppDatabase db;
  late String pitId;
  late String otherPit;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: 'A');
    otherPit = await db.createPit(name: 'B');
  });
  tearDown(() => db.close());

  Future<String> piece(
    String pit,
    DateTime at, {
    int likes = 0,
    List<String> tagIds = const [],
  }) async {
    final id = await db.savePiece(
      pitId: pit,
      title: 'p',
      body: '',
      images: const [NewImage(file: 'x.png')],
      tagIds: tagIds,
      links: const [],
      targetLikes: 0,
      finishedAt: at,
      ideaIds: const [],
      draftIds: const [],
    );
    await db.setActualLikes(id, likes);
    return id;
  }

  test('自動名稱', () {
    Goal g(GoalKind k, {int? likes, String? name}) => Goal(
      id: '1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      deviceId: '',
      period: GoalPeriod.year,
      year: 2026,
      kind: k,
      count: 12,
      requireLikes: likes,
      name: name,
    );
    expect(goalAutoName(g(GoalKind.idea)), '生產 12 個腦洞');
    expect(goalAutoName(g(GoalKind.draft)), '畫 12 份草稿');
    expect(goalAutoName(g(GoalKind.piece)), '完成 12 張成圖');
    expect(goalAutoName(g(GoalKind.piece, likes: 500)), '互動量過 500 的成圖 12 張');
    expect(goalAutoName(g(GoalKind.piece, name: '夏日企劃')), '夏日企劃');
  });

  test('年度目標進度：期間、坑、互動量', () async {
    await piece(pitId, DateTime(2026, 3, 1), likes: 600);
    await piece(pitId, DateTime(2026, 8, 9), likes: 100);
    await piece(otherPit, DateTime(2026, 8, 9), likes: 900);
    await piece(pitId, DateTime(2025, 12, 31), likes: 900); // 去年不算
    await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 10,
    );
    await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 5,
      pitId: pitId,
    );
    await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 5,
      requireLikes: 500,
    );
    final views = await db.watchGoalViews(GoalPeriod.year, 2026).first;
    expect(views.map((v) => v.progress), [3, 2, 2]);
    expect(views[1].pit!.name, 'A');
  });

  test('月度目標與 tag（需同時符合）', () async {
    final a = await db.createTag(pitId, '角色1');
    final b = await db.createTag(pitId, '角色2');
    await piece(pitId, DateTime(2026, 5, 3), tagIds: [a, b]);
    await piece(pitId, DateTime(2026, 5, 4), tagIds: [a]);
    await piece(pitId, DateTime(2026, 6, 1), tagIds: [a, b]); // 別的月
    await db.saveGoal(
      period: GoalPeriod.month,
      year: 2026,
      month: 5,
      kind: GoalKind.piece,
      count: 3,
      pitId: pitId,
      tagIds: [a, b],
    );
    final v = (await db.watchGoalViews(GoalPeriod.month, 2026, month: 5).first)
        .single;
    expect(v.progress, 1);
    expect(v.tags.length, 2);
    expect(
      await db.watchGoalViews(GoalPeriod.month, 2026, month: 6).first,
      isEmpty,
    );
  });

  test('未選坑時不存 tag；刪除目標', () async {
    final a = await db.createTag(pitId, '角色1');
    final id = await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.idea,
      count: 3,
      tagIds: [a],
    );
    expect(await db.goalTagIds(id), isEmpty);
    await db.deleteGoal(id);
    expect(await db.watchGoalViews(GoalPeriod.year, 2026).first, isEmpty);
  });

  test('月曆封面取當天最晚一張；時間軸新到舊', () async {
    await piece(pitId, DateTime(2026, 5, 3, 9));
    await db.saveIdea(
      pitId: pitId,
      title: 'i',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
      createdAt: DateTime(2026, 5, 3, 12),
    );
    final covers = await db.watchMonthCovers(2026, 5).first;
    expect(covers.keys, [3]);
    final tl = await db.watchTimeline(DateTime(2026, 5, 3)).first;
    expect(tl.map((e) => e.kind), [GoalKind.idea, GoalKind.piece]);
    expect(await db.watchTimeline(DateTime(2026, 5, 4)).first, isEmpty);
  });

  test('年度回顧：每月圖與排版設定預設值', () async {
    await piece(pitId, DateTime(2026, 2, 1));
    expect((await db.pieceImagesByMonth(2026))[2], ['x.png']);
    await db.setReviewMonth(2026, 2, 'y.png');
    expect((await db.watchReviewMonths(2026).first)[2], 'y.png');
    final s = await db.watchReviewSettings(2026).first;
    expect(
      (s.columns, s.ratio, s.monthFormat, s.monthOnImage),
      (4, '1:1', 'Jan', true),
    );
  });
}
