import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/timeline_queries.dart';

/// 連續日頁時間軸（D-072）：分頁、游標、跳日期、月份計數、刷新訊號。
void main() {
  late AppDatabase db;
  late String pit;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pit = await db.createPit(name: '坑');
  });
  tearDown(() => db.close());

  Future<void> idea(String id, DateTime date, {String title = 'i'}) => db
      .into(db.ideas)
      .insert(
        IdeasCompanion.insert(
          id: Value(id),
          pitId: pit,
          title: title,
          date: Value(date),
        ),
      );
  Future<void> draft(String id, DateTime date) => db
      .into(db.drafts)
      .insert(
        DraftsCompanion.insert(
          id: Value(id),
          pitId: pit,
          title: const Value('d'),
          date: Value(date),
        ),
      );
  Future<void> piece(String id, DateTime at) => db
      .into(db.pieces)
      .insert(
        PiecesCompanion.insert(
          id: Value(id),
          pitId: pit,
          title: 'p',
          finishedAt: Value(at),
        ),
      );

  /// 把整條時間軸一頁一頁讀完。
  Future<List<TimelineItem>> readAll(int limit) async {
    final out = <TimelineItem>[];
    TimelineCursor? cur;
    var guard = 0;
    while (true) {
      final page = await db.loadTimelinePage(after: cur, limit: limit);
      out.addAll(page.items);
      if (!page.hasMore) break;
      cur = page.next;
      expect(++guard, lessThan(200));
    }
    return out;
  }

  test('空資料：空頁、hasMore=false、沒有 next', () async {
    final page = await db.loadTimelinePage();
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
    expect(page.next, isNull);
    expect(await db.nearestTimelineDay(DateTime(2026, 5, 1)), isNull);
  });

  test('腦洞／摸魚／成圖合併，依 date／finishedAt 新到舊；每項帶圖片與 tag', () async {
    final tag = await db.createTag(pit, '角色');
    await db.saveIdea(
      pitId: pit,
      title: '腦洞',
      body: '內文',
      images: const [NewImage(file: 'i.png')],
      tagIds: [tag],
      draftIds: const [],
      pieceIds: const [],
      date: DateTime(2026, 9, 19, 15),
    );
    await db.saveDraft(
      pitId: pit,
      title: '摸魚',
      images: const [],
      tagIds: const [],
      ideaIds: const [],
      date: DateTime(2026, 9, 19, 20),
    );
    await db.savePiece(
      pitId: pit,
      title: '成圖',
      body: '',
      images: const [NewImage(file: 'p.png')],
      tagIds: const [],
      links: const [],
      targetLikes: 100,
      finishedAt: DateTime(2026, 9, 17, 23),
      ideaIds: const [],
      draftIds: const [],
    );
    final page = await db.loadTimelinePage();
    expect(page.items.map((e) => (e.kind, e.title)), [
      (GoalKind.draft, '摸魚'),
      (GoalKind.idea, '腦洞'),
      (GoalKind.piece, '成圖'),
    ]);
    expect(page.items[1].files, ['i.png']);
    expect(page.items[1].tagNames, ['角色']);
    expect(page.items[1].text, '內文');
    expect(page.items[2].targetLikes, 100);
    expect(page.hasMore, isFalse);
  });

  test('ideas／drafts 用 date 排序，不是 createdAt；成圖用 finishedAt', () async {
    // createdAt 順序與 date 順序相反
    await db
        .into(db.ideas)
        .insert(
          IdeasCompanion.insert(
            id: const Value('a'),
            pitId: pit,
            title: 'a',
            date: Value(DateTime(2026, 1, 1)),
            createdAt: Value(DateTime(2026, 12, 1)),
          ),
        );
    await db
        .into(db.drafts)
        .insert(
          DraftsCompanion.insert(
            id: const Value('b'),
            pitId: pit,
            date: Value(DateTime(2026, 6, 1)),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    await db
        .into(db.pieces)
        .insert(
          PiecesCompanion.insert(
            id: const Value('c'),
            pitId: pit,
            title: 'c',
            finishedAt: Value(DateTime(2026, 3, 1)),
            createdAt: Value(DateTime(2026, 12, 31)),
          ),
        );
    final items = (await db.loadTimelinePage()).items;
    expect(items.map((e) => e.id), ['b', 'c', 'a']);
    expect(items.map((e) => e.time), [
      DateTime(2026, 6, 1),
      DateTime(2026, 3, 1),
      DateTime(2026, 1, 1),
    ]);
  });

  test('分頁：邊界（剛好一頁、多一筆）、不重複不跳過、next 游標連續', () async {
    for (var i = 0; i < 7; i++) {
      await idea('i$i', DateTime(2026, 5, 1 + i, 10));
    }
    var page = await db.loadTimelinePage(limit: 7);
    expect(page.items.length, 7);
    expect(page.hasMore, isFalse); // 剛好一頁：沒有下一頁
    page = await db.loadTimelinePage(limit: 6);
    expect(page.items.length, 6);
    expect(page.hasMore, isTrue);
    final rest = await db.loadTimelinePage(after: page.next, limit: 6);
    expect(rest.items.map((e) => e.id), ['i0']);
    expect(rest.hasMore, isFalse);

    for (final limit in [1, 2, 3, 5]) {
      final all = await readAll(limit);
      expect(all.map((e) => e.id), [for (var i = 6; i >= 0; i--) 'i$i']);
    }
  });

  test('同一時間的多筆（跨種類）依 id 由大到小，跨頁不重複不漏', () async {
    final t = DateTime(2026, 5, 5, 12);
    await idea('b-idea', t);
    await draft('c-draft', t);
    await piece('a-piece', t);
    await idea('d-idea', t);
    await idea('e-older', DateTime(2026, 5, 5, 11));
    await idea('z-newer', DateTime(2026, 5, 5, 13));

    final expected = [
      'z-newer',
      'd-idea',
      'c-draft',
      'b-idea',
      'a-piece',
      'e-older',
    ];
    for (final limit in [1, 2, 3, 4, 6, 7]) {
      final all = await readAll(limit);
      expect(all.map((e) => e.id), expected, reason: 'limit $limit');
    }
  });

  test('已刪除的不出現；不影響 hasMore 與游標', () async {
    await idea('i1', DateTime(2026, 5, 3));
    await idea('i2', DateTime(2026, 5, 2));
    await draft('d1', DateTime(2026, 5, 1));
    await piece('p1', DateTime(2026, 4, 30));
    await db.deleteIdeas(['i2']);
    await db.deleteDrafts(['d1']);
    final page = await db.loadTimelinePage(limit: 1);
    expect(page.items.single.id, 'i1');
    expect(page.hasMore, isTrue);
    final next = await db.loadTimelinePage(after: page.next, limit: 5);
    expect(next.items.map((e) => e.id), ['p1']);
    expect(next.hasMore, isFalse);
    await db.deletePieces(['p1']);
    expect((await db.loadTimelinePage(after: page.next)).items, isEmpty);
    expect(await db.nearestTimelineDay(DateTime(2026, 4, 30)), isNull);
  });

  test('沒有內容的日子不出現（只有有內容的日子，連續兩天之間的空白被跳過）', () async {
    await idea('a', DateTime(2026, 5, 20, 9));
    await idea('b', DateTime(2026, 3, 2, 9));
    final items = (await db.loadTimelinePage()).items;
    expect(items.map((e) => e.time.day), [20, 2]);
  });

  test('nearestTimelineDay：當天有內容回當天；沒有就回之前最近的；之前沒有回 null', () async {
    await idea('a', DateTime(2026, 5, 20, 23, 59));
    await draft('b', DateTime(2026, 5, 10, 0, 0));
    await piece('c', DateTime(2026, 4, 1, 8));
    expect(
      await db.nearestTimelineDay(DateTime(2026, 5, 20)),
      DateTime(2026, 5, 20),
    );
    // 傳入含時間的 DateTime 也以那天為準（那天 23:59 的內容算在當天）
    expect(
      await db.nearestTimelineDay(DateTime(2026, 5, 20, 1)),
      DateTime(2026, 5, 20),
    );
    expect(
      await db.nearestTimelineDay(DateTime(2026, 5, 19)),
      DateTime(2026, 5, 10),
    );
    expect(
      await db.nearestTimelineDay(DateTime(2026, 5, 10)),
      DateTime(2026, 5, 10),
    );
    expect(
      await db.nearestTimelineDay(DateTime(2026, 5, 9)),
      DateTime(2026, 4, 1),
    );
    expect(await db.nearestTimelineDay(DateTime(2026, 3, 31)), isNull);
    // 比最新的還晚：回最新的一天
    expect(
      await db.nearestTimelineDay(DateTime(2027, 1, 1)),
      DateTime(2026, 5, 20),
    );
  });

  test('loadTimelineUntil：載到包含目標日（或其前最近有內容的日）的全部內容', () async {
    // 每天 2 筆，共 20 天（5/20 ~ 5/1）＝40 筆
    for (var d = 1; d <= 20; d++) {
      await idea('i-$d', DateTime(2026, 5, d, 9));
      await draft('d-$d', DateTime(2026, 5, d, 18));
    }
    // 目標 5/10：5/20..5/10 共 11 天 22 筆，之後還有更舊的
    var page = await db.loadTimelineUntil(DateTime(2026, 5, 10), limit: 5);
    expect(page.items.length, 22);
    expect(page.items.last.time.day, 10);
    expect(page.items.every((e) => e.time.day >= 10), isTrue);
    expect(page.hasMore, isTrue);
    // 接著用 next 載入下一頁：從 5/9 開始，沒有重複
    final more = await db.loadTimelinePage(after: page.next, limit: 3);
    expect(more.items.first.time.day, 9);
    expect(
      more.items
          .map((e) => e.id)
          .toSet()
          .intersection(page.items.map((e) => e.id).toSet()),
      isEmpty,
    );

    // 目標是最舊的一天：載完，hasMore=false
    page = await db.loadTimelineUntil(DateTime(2026, 5, 1), limit: 5);
    expect(page.items.length, 40);
    expect(page.hasMore, isFalse);

    // 內容不足 limit：等同第一頁（至少 limit 筆）
    page = await db.loadTimelineUntil(DateTime(2026, 5, 20), limit: 30);
    expect(page.items.length, 30);
    expect(page.hasMore, isTrue);

    // 目標日沒有內容 → 以其前最近有內容的日子為準
    await db.deleteIdeas([for (var d = 10; d <= 12; d++) 'i-$d']);
    await db.deleteDrafts([for (var d = 10; d <= 12; d++) 'd-$d']);
    page = await db.loadTimelineUntil(DateTime(2026, 5, 12), limit: 5);
    expect(page.items.last.time.day, 9);
    expect(page.items.where((e) => e.time.day == 9).length, 2);

    // 目標之前完全沒有內容 → 等同第一頁
    page = await db.loadTimelineUntil(DateTime(2026, 1, 1), limit: 4);
    expect(page.items.length, 4);
    expect(page.hasMore, isTrue);
  });

  test('loadTimelineUntil：同一天的同時間 tie 不被截斷', () async {
    final t = DateTime(2026, 6, 1, 10);
    for (var i = 0; i < 6; i++) {
      await idea('same-$i', t);
    }
    await idea('older', DateTime(2026, 5, 31, 10));
    final page = await db.loadTimelineUntil(DateTime(2026, 6, 1), limit: 2);
    expect(page.items.length, 6);
    expect(page.hasMore, isTrue);
    expect(
      (await db.loadTimelinePage(after: page.next)).items.single.id,
      'older',
    );
  });

  test('timelineMonthCounts：整個月的總數（與已載入幾筆無關），不含已刪除，鍵是當月 1 日', () async {
    for (var d = 1; d <= 10; d++) {
      await idea('s$d', DateTime(2026, 9, d, 12));
    }
    await draft('d1', DateTime(2026, 9, 30, 23, 59));
    await piece('p1', DateTime(2026, 9, 1, 0, 0));
    await piece('p0', DateTime(2026, 8, 31, 23, 59));
    await idea('o1', DateTime(2026, 10, 1, 0, 0));
    await db.deleteIdeas(['s1']);
    final page = await db.loadTimelinePage(limit: 3); // 只載入 3 筆
    expect(page.items.length, 3);
    final counts = await db.timelineMonthCounts([
      DateTime(2026, 9, 15), // 取年月，日無關
      DateTime(2026, 9, 2), // 重複月份只算一次
      DateTime(2026, 8),
      DateTime(2026, 10, 31),
      DateTime(2026, 7),
    ]);
    expect(counts, {
      DateTime(2026, 9): 11, // 9 腦洞 + 1 摸魚 + 1 成圖
      DateTime(2026, 8): 1,
      DateTime(2026, 10): 1,
      DateTime(2026, 7): 0,
    });
  });

  test('watchTimelineRevision：內容有變動才遞增，先發 0', () async {
    final seen = <int>[];
    final sub = db.watchTimelineRevision().listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, [0]);
    await idea('x', DateTime(2026, 5, 1));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.deleteIdeas(['x']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await piece('y', DateTime(2026, 5, 2));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen.length, greaterThanOrEqualTo(4));
    expect(seen, orderedEquals(List.generate(seen.length, (i) => i)));
  });

  test('舊的單日查詢 watchTimeline 行為不變（仍可用）', () async {
    await idea('a', DateTime(2026, 5, 3, 9));
    await draft('b', DateTime(2026, 5, 3, 20));
    await idea('c', DateTime(2026, 5, 4, 0, 0));
    final day = await db.watchTimeline(DateTime(2026, 5, 3)).first;
    expect(day.map((e) => e.id), ['b', 'a']);
    expect(await db.watchTimeline(DateTime(2026, 5, 2)).first, isEmpty);
  });
}
