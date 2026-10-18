import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/search_queries.dart';
import 'package:huakeng/data/timeline_queries.dart';

/// D-098：封存坑的腦洞／摸魚／成圖不進目標的日頁（時間軸）與月頁（月曆）；
/// 坑內搜尋照常找得到；轉回現坑／淺坑後重新出現；進度本來就不計入（D-088）。
void main() {
  late AppDatabase db;
  late String live;
  late String old;
  final day = DateTime(2026, 9, 12, 10);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    live = await db.createPit(name: '現坑');
    old = await db.createPit(name: '舊坑');
    for (final pit in [live, old]) {
      final tag = pit == live ? '現' : '舊';
      await db
          .into(db.ideas)
          .insert(
            IdeasCompanion.insert(
              pitId: pit,
              title: '$tag腦洞',
              date: Value(day),
            ),
          );
      await db
          .into(db.drafts)
          .insert(
            DraftsCompanion.insert(
              pitId: pit,
              title: Value('$tag摸魚'),
              date: Value(day),
            ),
          );
      await db
          .into(db.pieces)
          .insert(
            PiecesCompanion.insert(
              pitId: pit,
              title: '$tag成圖',
              finishedAt: Value(day),
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<List<String>> timelineTitles() async {
    final page = await db.loadTimelinePage();
    return [for (final i in page.items) i.title];
  }

  test('封存坑的項目不進時間軸（分頁、跳日期、月份計數、單日）；現坑照常', () async {
    expect((await timelineTitles()).length, 6);
    await db.setPitStatus(old, PitStatus.archived);

    final titles = await timelineTitles();
    expect(titles.toSet(), {'現腦洞', '現摸魚', '現成圖'});
    expect((await db.loadTimelineUntil(day)).items.length, 3);
    expect(await db.nearestTimelineDay(day), DateTime(2026, 9, 12));
    expect((await db.timelineMonthCounts([day]))[DateTime(2026, 9)], 3);
    final single = await db.watchTimeline(DateTime(2026, 9, 12)).first;
    expect(single.length, 3);
  });

  test('只剩封存坑有內容：時間軸是空的、nearestTimelineDay 是 null', () async {
    await db.setPitStatus(live, PitStatus.archived);
    await db.setPitStatus(old, PitStatus.archived);
    final page = await db.loadTimelinePage();
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
    expect(await db.nearestTimelineDay(day), isNull);
    expect((await db.timelineMonthCounts([day]))[DateTime(2026, 9)], 0);
  });

  test('月曆日期圖不用封存坑的成圖', () async {
    // 兩個坑的成圖各一張圖；舊坑的較晚，封存前會被選為當天圖。
    Future<void> img(String pitId, String file) async {
      final p = await (db.select(
        db.pieces,
      )..where((x) => x.pitId.equals(pitId))).getSingle();
      await db
          .into(db.entityImages)
          .insert(
            EntityImagesCompanion.insert(
              ownerType: OwnerType.piece,
              ownerId: p.id,
              imageFile: file,
              width: const Value(10),
              height: const Value(10),
            ),
          );
    }

    await img(live, 'live.png');
    await img(old, 'old.png');
    await (db.update(db.pieces)..where((p) => p.pitId.equals(old))).write(
      PiecesCompanion(finishedAt: Value(DateTime(2026, 9, 12, 20))),
    );
    expect((await db.watchMonthCovers(2026, 9).first)[12], 'old.png');
    await db.setPitStatus(old, PitStatus.archived);
    expect((await db.watchMonthCovers(2026, 9).first)[12], 'live.png');
    await db.setPitStatus(old, PitStatus.active);
    expect((await db.watchMonthCovers(2026, 9).first)[12], 'old.png');
  });

  test('轉回現坑／淺坑後項目重新出現（資料沒被刪）', () async {
    await db.setPitStatus(old, PitStatus.archived);
    expect((await timelineTitles()).length, 3);
    await db.setPitStatus(old, PitStatus.active);
    expect((await timelineTitles()).length, 6);
    await db.setPitStatus(old, PitStatus.archived);
    expect((await timelineTitles()).length, 3);
    await db.setPitStatus(old, PitStatus.shallow);
    expect((await timelineTitles()).length, 6);
  });

  test('坑內搜尋照常搜得到封存坑的內容（只限該坑）', () async {
    await db.setPitStatus(old, PitStatus.archived);
    final r = await db.watchPitSearch(old, text: '舊').first;
    expect(r.ideas.total, 1);
    expect(r.drafts.total, 1);
    expect(r.pieces.total, 1);
    final other = await db.watchPitSearch(old, text: '現').first;
    expect(other.ideas.total + other.drafts.total + other.pieces.total, 0);
  });

  test('目標進度本來就不計入封存坑（D-088）', () async {
    final id = await db.saveGoal(
      kind: GoalKind.idea,
      period: GoalPeriod.year,
      year: 2026,
      count: 5,
      tagIds: const [],
    );
    expect((await db.goalById(id)), isNotNull);
    int progress(List<GoalView> v) => v.single.progress;
    expect(progress(await db.watchGoalViews(GoalPeriod.year, 2026).first), 2);
    await db.setPitStatus(old, PitStatus.archived);
    expect(progress(await db.watchGoalViews(GoalPeriod.year, 2026).first), 1);
  });
}
