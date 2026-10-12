import 'dart:async';

import 'package:drift/drift.dart';

import 'database.dart';
import 'goal_queries.dart';

/// 連續時間軸（D-072）的分頁游標：最後一筆的時間＋id。
/// 排序是「時間新到舊，同一時間以 id 由大到小」，所以 (date, id) 是穩定且唯一的位置。
class TimelineCursor {
  const TimelineCursor(this.date, this.id);

  factory TimelineCursor.of(TimelineItem item) =>
      TimelineCursor(item.time, item.id);

  final DateTime date;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is TimelineCursor && other.date == date && other.id == id;

  @override
  int get hashCode => Object.hash(date, id);

  @override
  String toString() => 'TimelineCursor($date, $id)';
}

/// 一頁時間軸（時間新到舊）。
class TimelinePage {
  const TimelinePage(this.items, {required this.hasMore});

  final List<TimelineItem> items;

  /// 這頁之後還有更舊的內容。
  final bool hasMore;

  /// 載入下一頁用的游標；空頁為 null。
  TimelineCursor? get next =>
      items.isEmpty ? null : TimelineCursor.of(items.last);

  static const empty = TimelinePage([], hasMore: false);
}

/// 一筆尚未組成 [TimelineItem] 的原始列。
typedef _Raw = ({DateTime time, String id, Object row});

int _byTimeDesc(_Raw a, _Raw b) {
  final c = b.time.compareTo(a.time);
  return c != 0 ? c : b.id.compareTo(a.id);
}

/// 目標 · 日頁的連續時間軸（D-072）：腦洞／草稿（`date`）與成圖（`finishedAt`）合併，
/// 依時間新到舊分頁載入。沒有內容的日子不會出現；已刪除的不算。
extension TimelineQueries on AppDatabase {
  /// 載入一頁。[after] 為 null＝從最新開始；否則接在該游標之後（不含游標那一筆）。
  /// 頁與頁之間不重複、不跳過（同一時間的多筆以 id 排定先後）。
  Future<TimelinePage> loadTimelinePage({
    TimelineCursor? after,
    int limit = 30,
  }) async {
    assert(limit > 0);
    final raws = await _timelineRaws(after: after, limit: limit + 1);
    final hasMore = raws.length > limit;
    return TimelinePage(
      await _buildTimelineItems(hasMore ? raws.sublist(0, limit) : raws),
      hasMore: hasMore,
    );
  }

  /// 跳到某天用：從最新開始，載入到**包含**「`day` 當天或之前最近有內容的那一天」的所有內容。
  /// 至少載入 [limit] 筆（內容不足時等同第一頁）。`hasMore` 為這之後還有更舊的內容。
  /// 該天以前完全沒內容 → 等同 `loadTimelinePage(limit: limit)`（沒有地方可捲）。
  /// UI 搭配 [nearestTimelineDay] 取得要捲到的那一天。
  Future<TimelinePage> loadTimelineUntil(DateTime day, {int limit = 30}) async {
    final target = await nearestTimelineDay(day);
    if (target == null) return loadTimelinePage(limit: limit);
    final raws = await _timelineRaws(since: target);
    if (raws.length < limit) return loadTimelinePage(limit: limit);
    return TimelinePage(
      await _buildTimelineItems(raws),
      hasMore: await _latestBefore(target) != null,
    );
  }

  /// `day` 當天或之前，最近一個有內容的日子（當天 00:00）；之前完全沒有內容回傳 null。
  /// 月頁點到沒內容的日子時，日頁捲到這一天。
  Future<DateTime?> nearestTimelineDay(DateTime day) async {
    final latest = await _latestBefore(
      DateTime(day.year, day.month, day.day + 1),
    );
    return latest == null
        ? null
        : DateTime(latest.year, latest.month, latest.day);
  }

  /// 各月份的內容總數（腦洞＋草稿＋成圖的筆數，已刪除的不算），不論該月載入了多少。
  /// [months] 的每個元素取其年月；回傳的 key 是 `DateTime(年, 月)`，沒有內容的月份值為 0。
  /// 日頁的月份標題「2026 年 9 月 · N 項」用：先從已載入的 items 取出出現過的月份再查。
  Future<Map<DateTime, int>> timelineMonthCounts(
    Iterable<DateTime> months,
  ) async {
    final out = <DateTime, int>{};
    for (final m in months) {
      final start = DateTime(m.year, m.month);
      final end = DateTime(m.year, m.month + 1);
      if (out.containsKey(start)) continue;
      var n = 0;
      n += await _count(
        ideas,
        (ideas.deletedAt.isNull() &
            ideas.date.isBiggerOrEqualValue(start) &
            ideas.date.isSmallerThanValue(end)),
      );
      n += await _count(
        drafts,
        (drafts.deletedAt.isNull() &
            drafts.date.isBiggerOrEqualValue(start) &
            drafts.date.isSmallerThanValue(end)),
      );
      n += await _count(
        pieces,
        (pieces.deletedAt.isNull() &
            pieces.finishedAt.isBiggerOrEqualValue(start) &
            pieces.finishedAt.isSmallerThanValue(end)),
      );
      out[start] = n;
    }
    return out;
  }

  /// 時間軸內容有任何變動時發出（初始先發 0，之後遞增）。涵蓋腦洞／草稿／成圖本身、
  /// 圖片與 tag 的變動。UI 用它判斷「已載入的頁要重新抓」，本身不帶資料。
  Stream<int> watchTimelineRevision() {
    var n = 0;
    StreamSubscription<Set<TableUpdate>>? sub;
    late final StreamController<int> out;
    out = StreamController<int>(
      onListen: () {
        out.add(n);
        sub = tableUpdates(
          TableUpdateQuery.onAllTables({
            ideas,
            drafts,
            pieces,
            entityImages,
            tags,
            tagLinks,
          }),
        ).listen((_) => out.add(++n));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  // ---- 內部 ----

  Future<int> _count(
    TableInfo<Table, dynamic> table,
    Expression<bool> where,
  ) async {
    final c = countAll();
    final row =
        await (selectOnly(table)
              ..addColumns([c])
              ..where(where))
            .getSingle();
    return row.read(c)!;
  }

  /// 比 [t] 早（嚴格小於）的最晚一筆時間；沒有回傳 null。
  Future<DateTime?> _latestBefore(DateTime t) async {
    final found = <DateTime>[];
    final i =
        await (select(ideas)
              ..where(
                (x) => x.deletedAt.isNull() & x.date.isSmallerThanValue(t),
              )
              ..orderBy([(x) => OrderingTerm.desc(x.date)])
              ..limit(1))
            .getSingleOrNull();
    if (i != null) found.add(i.date);
    final d =
        await (select(drafts)
              ..where(
                (x) => x.deletedAt.isNull() & x.date.isSmallerThanValue(t),
              )
              ..orderBy([(x) => OrderingTerm.desc(x.date)])
              ..limit(1))
            .getSingleOrNull();
    if (d != null) found.add(d.date);
    final p =
        await (select(pieces)
              ..where(
                (x) =>
                    x.deletedAt.isNull() & x.finishedAt.isSmallerThanValue(t),
              )
              ..orderBy([(x) => OrderingTerm.desc(x.finishedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (p != null) found.add(p.finishedAt);
    if (found.isEmpty) return null;
    return found.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// 依 (時間 desc, id desc) 取最多 [limit] 筆原始列（每張表各取 [limit] 再合併，所以不會漏）。
  /// [after]＝排在游標之後；[since]＝時間 >= since（不設 [limit] 時全取）。
  Future<List<_Raw>> _timelineRaws({
    TimelineCursor? after,
    DateTime? since,
    int? limit,
  }) async {
    Expression<bool> pos(
      GeneratedColumn<DateTime> date,
      GeneratedColumn<String> id,
    ) {
      Expression<bool> e = const Constant(true);
      if (after != null) {
        e =
            e &
            (date.isSmallerThanValue(after.date) |
                (date.equals(after.date) & id.isSmallerThanValue(after.id)));
      }
      if (since != null) e = e & date.isBiggerOrEqualValue(since);
      return e;
    }

    final i =
        await (select(ideas)
              ..where((x) => x.deletedAt.isNull() & pos(x.date, x.id))
              ..orderBy([
                (x) => OrderingTerm.desc(x.date),
                (x) => OrderingTerm.desc(x.id),
              ])
              ..limit(limit ?? -1))
            .get();
    final d =
        await (select(drafts)
              ..where((x) => x.deletedAt.isNull() & pos(x.date, x.id))
              ..orderBy([
                (x) => OrderingTerm.desc(x.date),
                (x) => OrderingTerm.desc(x.id),
              ])
              ..limit(limit ?? -1))
            .get();
    final p =
        await (select(pieces)
              ..where((x) => x.deletedAt.isNull() & pos(x.finishedAt, x.id))
              ..orderBy([
                (x) => OrderingTerm.desc(x.finishedAt),
                (x) => OrderingTerm.desc(x.id),
              ])
              ..limit(limit ?? -1))
            .get();
    final all = <_Raw>[
      for (final r in i) (time: r.date, id: r.id, row: r),
      for (final r in d) (time: r.date, id: r.id, row: r),
      for (final r in p) (time: r.finishedAt, id: r.id, row: r),
    ]..sort(_byTimeDesc);
    return limit == null || all.length <= limit ? all : all.sublist(0, limit);
  }

  Future<List<TimelineItem>> _buildTimelineItems(List<_Raw> raws) async {
    final ideasList = <Idea>[];
    final draftsList = <Draft>[];
    final piecesList = <Piece>[];
    for (final r in raws) {
      switch (r.row) {
        case final Idea x:
          ideasList.add(x);
        case final Draft x:
          draftsList.add(x);
        case final Piece x:
          piecesList.add(x);
      }
    }
    final built = {
      for (final it in await timelineItemsOf(
        ideasList: ideasList,
        draftsList: draftsList,
        piecesList: piecesList,
      ))
        it.id: it,
    };
    return [for (final r in raws) built[r.id]!];
  }
}
