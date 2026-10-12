import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../data/timeline_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/timeline.dart';

/// 日頁的連續時間軸（D-072）：新到舊分頁載入，捲到底載下一頁；
/// 月份標題（月份＋該月項數）與日期欄照 artboard `Day` 內嵌在清單裡（不吸頂）。
///
/// 跳到某天（[DayTimelineState.jumpToDay]）：用 CustomScrollView 的 center 當錨點，
/// 錨點那天放在 offset 0（視窗頂端），比它新的項目放在往上長的 sliver。
/// 這樣不必知道每列高度就能精準捲到該天，往上也捲得回去；資料刷新時以錨點項目重新定位，
/// 視窗相對於錨點的位置不變，所以捲動位置不會跑掉。
class DayTimeline extends ConsumerStatefulWidget {
  const DayTimeline({
    super.key,
    required this.entryOf,
    this.initialDay,
    this.onYearChanged,
    this.pageSize = 30,
  });

  /// 把一筆項目組成共用時間軸的一筆。
  final TimelineEntry Function(BuildContext context, TimelineItem item) entryOf;

  /// 一開始要捲到的日子；null＝從今天開始。
  final DateTime? initialDay;

  /// 跳到某天後，該天所在年份通知上層（標題列的年份）。
  final ValueChanged<int>? onYearChanged;

  final int pageSize;

  @override
  ConsumerState<DayTimeline> createState() => DayTimelineState();
}

sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.year, this.month, this.count);
  final int year, month, count;
}

class _EntryRow extends _Row {
  _EntryRow(this.entry, {required this.showDate, required this.line});
  final TimelineEntry entry;
  final bool showDate;
  final bool line;
}

class DayTimelineState extends ConsumerState<DayTimeline> {
  final _scroll = ScrollController();
  final _centerKey = GlobalKey();

  List<TimelineItem> _items = const [];
  bool _hasMore = false;
  bool _loaded = false;
  bool _loadingMore = false;
  Map<DateTime, int> _counts = const {};

  /// 錨點項目（錨點那天最新的一筆）；null＝從最新的開始。
  String? _anchorKey;
  DateTime? _anchorTime;

  /// 載入世代：新的載入開始就讓舊的結果作廢。
  int _gen = 0;
  int? _lastRevision;

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  void initState() {
    super.initState();
    jumpToDay(widget.initialDay ?? DateTime.now());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static String _keyOf(TimelineItem it) => '${it.kind.name}-${it.id}';

  Future<Map<DateTime, int>> _countsOf(List<TimelineItem> items) =>
      _db.timelineMonthCounts({
        for (final i in items) DateTime(i.time.year, i.time.month),
      });

  /// 捲到 [day]；那天沒有內容就捲到它之前最近有內容的一天；之前都沒有內容＝從頂端開始。
  Future<void> jumpToDay(DateTime day) async {
    final gen = ++_gen;
    final target = await _db.nearestTimelineDay(day);
    final page = await _db.loadTimelineUntil(day, limit: widget.pageSize);
    final counts = await _countsOf(page.items);
    if (!mounted || gen != _gen) return;
    TimelineItem? anchor;
    if (target != null) {
      for (final i in page.items) {
        if (i.time.year == target.year &&
            i.time.month == target.month &&
            i.time.day == target.day) {
          anchor = i;
          break;
        }
      }
    }
    setState(() {
      _items = page.items;
      _hasMore = page.hasMore;
      _counts = counts;
      _loaded = true;
      _loadingMore = false;
      _anchorKey = anchor == null ? null : _keyOf(anchor);
      _anchorTime = anchor?.time;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    widget.onYearChanged?.call((target ?? day).year);
  }

  /// 資料有變動：重載目前已載入的範圍，保持捲動位置。
  Future<void> _reload() async {
    if (!_loaded) return;
    final gen = ++_gen;
    final page = await _db.loadTimelinePage(
      limit: math.max(_items.length, widget.pageSize),
    );
    final counts = await _countsOf(page.items);
    if (!mounted || gen != _gen) return;
    setState(() {
      // 還在最頂端（沒有錨點）但已經捲離頂端時，把原本的第一筆當錨點，新項目才不會把畫面往下推。
      if (_anchorKey == null &&
          _items.isNotEmpty &&
          _scroll.hasClients &&
          _scroll.offset > 1) {
        _anchorKey = _keyOf(_items.first);
        _anchorTime = _items.first.time;
      }
      _items = page.items;
      _hasMore = page.hasMore;
      _counts = counts;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    _loadingMore = true;
    final gen = _gen;
    final page = await _db.loadTimelinePage(
      after: TimelineCursor.of(_items.last),
      limit: widget.pageSize,
    );
    if (!mounted || gen != _gen) return;
    final all = [..._items, ...page.items];
    final counts = await _countsOf(all);
    if (!mounted || gen != _gen) return;
    setState(() {
      _items = all;
      _hasMore = page.hasMore;
      _counts = counts;
      _loadingMore = false;
    });
  }

  List<_Row> _rows(BuildContext context) {
    final entries = [for (final i in _items) widget.entryOf(context, i)];
    bool sameMonth(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month;
    final rows = <_Row>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final prev = i > 0 ? entries[i - 1] : null;
      final next = i + 1 < entries.length ? entries[i + 1] : null;
      final newMonth = prev == null || !sameMonth(prev.date, e.date);
      if (newMonth) {
        final n =
            _counts[DateTime(e.date.year, e.date.month)] ??
            entries.where((x) => sameMonth(x.date, e.date)).length;
        rows.add(_HeaderRow(e.date.year, e.date.month, n));
      }
      rows.add(
        _EntryRow(
          e,
          showDate:
              prev == null || newMonth || !sameTimelineDay(prev.date, e.date),
          // 月份最後一筆不畫線。
          line: next != null && sameMonth(next.date, e.date),
        ),
      );
    }
    return rows;
  }

  /// 錨點在 rows 的位置（錨點是該月第一筆時連月份標題一起算進去）。
  int _splitOf(List<_Row> rows) {
    if (_anchorKey == null) return 0;
    var idx = rows.indexWhere(
      (r) => r is _EntryRow && r.entry.id == _anchorKey,
    );
    if (idx < 0 && _anchorTime != null) {
      // 錨點項目被刪或改了日期：用時間找最近的一筆。
      idx = rows.indexWhere(
        (r) => r is _EntryRow && !r.entry.date.isAfter(_anchorTime!),
      );
    }
    if (idx < 0) return 0;
    if (idx > 0 && rows[idx - 1] is _HeaderRow) idx--;
    return idx;
  }

  Widget _tile(BuildContext context, _Row r) => switch (r) {
    _HeaderRow() => TimelineSectionHeader(
      title: context.l10n.oshiMonthHeader(r.year, r.month),
      count: context.l10n.oshiCountItems(r.count),
    ),
    _EntryRow() => TimelineRowTile(
      key: ValueKey('timeline-${r.entry.id}'),
      entry: r.entry,
      showDate: r.showDate,
      line: r.line,
    ),
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<int>>(timelineRevisionProvider, (_, next) {
      final v = next.value;
      if (v == null) return;
      final changed = _lastRevision != null && _lastRevision != v;
      _lastRevision = v;
      if (changed) _reload();
    });

    if (!_loaded) return const SizedBox.expand();
    if (_items.isEmpty) {
      return Center(
        child: Text(
          context.l10n.dayflowEmpty,
          style: TextStyle(color: context.tokens.text3),
        ),
      );
    }
    final rows = _rows(context);
    final split = _splitOf(rows);
    const side = EdgeInsets.symmetric(horizontal: 20);
    return CustomScrollView(
      controller: _scroll,
      center: _centerKey,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        // 比錨點新的列：index 0 貼著錨點、往上長。
        SliverPadding(
          padding: side,
          sliver: SliverList.builder(
            itemCount: split,
            itemBuilder: (c, i) => _tile(c, rows[split - 1 - i]),
          ),
        ),
        SliverPadding(
          key: _centerKey,
          padding: side,
          sliver: SliverList.builder(
            itemCount: rows.length - split,
            itemBuilder: (c, i) {
              if (rows.length - split - i <= 5 && _hasMore) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _loadMore();
                });
              }
              return _tile(c, rows[split + i]);
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}
