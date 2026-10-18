import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;

import '../../l10n/l10n.dart';
import '../../media/gallery_repository.dart';
import '../common/drag_select.dart';
import '../common/media_badges.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart' show weekdayLabel;
import 'picker_controller.dart';
import 'picker_icons.dart';
import 'thumb_loader.dart';

/// 選擇器固定的深色（不隨主題）。
const Color kPickerBg = Color(0xFF121110);
const Color kPickerInk = Color(0xFFF2ECE4);
const Color kPickerSub = Color(0xFF8C8378);

const double _kHeaderHeight = 40;
const double _kGap = 2;
const double _kTailPadding = 24;

/// 日期標題文字：「今天 · 10月16日 週四」「昨天 · …」、今年「10月12日 週日」、跨年「2025年3月8日 週六」。
String pickerDayLabel(AppLocalizations l, DateTime day, DateTime now) {
  final weekday = weekdayLabel(l, day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final plain = l.pickerDate(day.month, day.day, weekday);
  if (day == today) return l.pickerDayToday(plain);
  if (day == yesterday) return l.pickerDayYesterday(plain);
  if (day.year != now.year) {
    return l.pickerDateWithYear(day.year, day.month, day.day, weekday);
  }
  return plain;
}

class _Row {
  const _Row.header(this.day) : start = 0, count = 0;
  const _Row.cells(this.day, this.start, this.count);
  final int day;

  /// 這一列第一格在當天項目裡的位置。
  final int start;
  final int count;
  bool get isHeader => count == 0;
}

/// 日期分組的 4 欄格子，日期標題捲動時置頂（D-084）。
///
/// 為了幾萬張也順：不是每天一個 sliver，而是把「標題列＋每 4 張一列」攤平成一份固定列高
/// 的清單（[SliverVariedExtentList]），置頂標題用疊在上面的一條標題模擬（位置由捲動量查表算出，
/// 下一天的標題頂上來時把它推走）。列高是算好的，所以快速捲動條也能直接算出位置。
class PickerGrid extends StatefulWidget {
  const PickerGrid({
    super.key,
    required this.controller,
    required this.loader,
    required this.scroll,
    required this.accent,
  });

  final PickerController controller;
  final ThumbLoader loader;
  final ScrollController scroll;
  final Color accent;

  @override
  State<PickerGrid> createState() => _PickerGridState();
}

class _PickerGridState extends State<PickerGrid> {
  int _version = -1;
  double _width = -1;
  List<_Row> _rows = const [];
  List<double> _offsets = const [0]; // 第 i 列的上緣；最後一個＝內容總高
  List<double> _headerOffsets = const [];
  double _cell = 0;

  /// 欄數：窄（＜560，手機與 iPad 分屏，MediaPicker400）4 欄；寬（MediaPicker 的置中 sheet）6 欄。
  int _cols = 4;

  PickerController get c => widget.controller;

  void _layout(double width) {
    if (_version == c.layoutVersion && _width == width) return;
    _version = c.layoutVersion;
    _width = width;
    _cols = width >= 560 ? 6 : 4;
    _cell = (width - (_cols - 1) * _kGap) / _cols;
    final rows = <_Row>[];
    for (var d = 0; d < c.days.length; d++) {
      rows.add(_Row.header(d));
      final n = c.days[d].items.length;
      for (var s = 0; s < n; s += _cols) {
        rows.add(_Row.cells(d, s, math.min(_cols, n - s)));
      }
    }
    final offsets = <double>[0];
    final headers = <double>[];
    var y = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r.isHeader) {
        headers.add(y);
        y += _kHeaderHeight;
      } else {
        final lastInDay = i + 1 >= rows.length || rows[i + 1].isHeader;
        y += _cell + (lastInDay ? 0 : _kGap);
      }
      offsets.add(y);
    }
    _rows = rows;
    _offsets = offsets;
    _headerOffsets = headers;
  }

  double _extentOf(int i) => _offsets[i + 1] - _offsets[i];

  /// 捲動量 [o] 落在哪一天（標題上緣 ≤ o 的最後一個）。
  int _dayAt(double o) {
    var lo = 0, hi = _headerOffsets.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_headerOffsets[mid] <= o) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  double _scrollOffset() {
    final s = widget.scroll;
    return s.positions.isNotEmpty && s.position.hasPixels
        ? s.position.pixels
        : 0;
  }

  /// 供快速捲動條：某個捲動量對應的月份標題。
  DateTime? _dayDateAt(double o) {
    if (c.days.isEmpty) return null;
    return c.days[_dayAt(o)].day;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.days.isEmpty) {
          return c.loading
              ? const SizedBox.shrink()
              : _ScrollableMessage(
                  scroll: widget.scroll,
                  child: Text(
                    context.l10n.pickerEmpty,
                    style: const TextStyle(color: kPickerSub, fontSize: 14),
                  ),
                );
        }
        return LayoutBuilder(
          builder: (context, box) {
            _layout(box.maxWidth);
            return DragSelectArea(
              enabled: !c.single,
              itemCount: c.items.length,
              isSelected: c.isIndexSelected,
              onChanged: c.applyDrag,
              // 裁在格子區域內：被下一天標題推走的日期列要消失在相簿 pills 後面，
              // 不能畫到 pills 上面。
              child: ClipRect(
                child: Stack(
                  children: [
                    CustomScrollView(
                      controller: widget.scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverVariedExtentList.builder(
                          itemCount: _rows.length,
                          itemExtentBuilder: (i, _) => _extentOf(i),
                          itemBuilder: _buildRow,
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: _kTailPadding),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: _StickyOverlay(
                        scroll: widget.scroll,
                        offset: _scrollOffset,
                        dayAt: _dayAt,
                        headerOffsets: _headerOffsets,
                        controller: c,
                        accent: widget.accent,
                      ),
                    ),
                    _FastScroller(
                      scroll: widget.scroll,
                      accent: widget.accent,
                      dateAt: _dayDateAt,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, int i) {
    final r = _rows[i];
    final day = c.days[r.day];
    if (r.isHeader) {
      return PickerDayHeader(
        key: ValueKey('picker-header-${day.day.toIso8601String()}'),
        day: day,
        controller: c,
        accent: widget.accent,
      );
    }
    final lastInDay = i + 1 >= _rows.length || _rows[i + 1].isHeader;
    return Padding(
      padding: EdgeInsets.only(bottom: lastInDay ? 0 : _kGap),
      child: Row(
        children: [
          for (var k = 0; k < _cols; k++) ...[
            if (k > 0) const SizedBox(width: _kGap),
            Expanded(
              child: k < r.count
                  ? _Cell(
                      item: day.items[r.start + k],
                      index: day.firstIndex + r.start + k,
                      controller: c,
                      loader: widget.loader,
                      accent: widget.accent,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// 沒有內容時（相簿是空的）仍要能被 sheet 拖動，所以放在可捲動的容器裡。
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage({required this.scroll, required this.child});
  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: box.maxHeight,
        child: Center(child: child),
      ),
    ),
  );
}

/// 日期標題列：左「今天 · 10月16日 週四　7 張」，右「選取整天」圓圈。
class PickerDayHeader extends StatelessWidget {
  const PickerDayHeader({
    super.key,
    required this.day,
    required this.controller,
    required this.accent,
    this.stuck = false,
  });

  final PickerDay day;
  final PickerController controller;
  final Color accent;

  /// 置頂中（蓋在內容上）：下緣加陰影。
  final bool stuck;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final full = controller.isDayFull(day);
    return Container(
      height: _kHeaderHeight,
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 8),
      decoration: BoxDecoration(
        color: kPickerBg,
        boxShadow: stuck
            ? const [
                BoxShadow(
                  color: Color(0xB3000000),
                  offset: Offset(0, 8),
                  blurRadius: 10,
                  spreadRadius: -8,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: pickerDayLabel(l, day.day, controller.now()),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: kPickerInk,
                    ),
                  ),
                  TextSpan(
                    text: '  ${l.pickerDayCount(day.items.length)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kPickerSub,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!controller.single)
            Semantics(
              button: true,
              label: l.pickerSelectDay,
              child: GestureDetector(
                key: ValueKey('picker-day-select-${day.day.toIso8601String()}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.toggleDay(day),
                child: SizedBox(
                  width: 44,
                  height: 24,
                  child: Center(
                    child: full
                        ? Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const SvgIcon(
                              PickerIcons.check,
                              size: 13,
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF5A524B),
                                width: 2,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 置頂中的日期標題（疊在清單上方）。下一天的標題頂上來時被推走。
class _StickyOverlay extends StatelessWidget {
  const _StickyOverlay({
    required this.scroll,
    required this.offset,
    required this.dayAt,
    required this.headerOffsets,
    required this.controller,
    required this.accent,
  });

  final Color accent;
  final ScrollController scroll;
  final double Function() offset;
  final int Function(double) dayAt;
  final List<double> headerOffsets;
  final PickerController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([scroll, controller]),
      builder: (context, _) {
        if (headerOffsets.isEmpty || controller.days.isEmpty) {
          return const SizedBox.shrink();
        }
        final o = math.max(0.0, offset());
        final d = math.min(dayAt(o), controller.days.length - 1);
        var y = 0.0;
        if (d + 1 < headerOffsets.length) {
          y = math.min(0.0, headerOffsets[d + 1] - o - _kHeaderHeight);
        }
        final stuck = o > headerOffsets[d] + 0.5;
        return SizedBox(
          height: _kHeaderHeight,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: _kHeaderHeight,
            maxHeight: _kHeaderHeight,
            child: Transform.translate(
              offset: Offset(0, y),
              child: PickerDayHeader(
                key: const ValueKey('picker-sticky-header'),
                day: controller.days[d],
                controller: controller,
                accent: accent,
                stuck: stuck && y == 0,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 一格：縮圖、右上角編號圓圈、選中時 3px 主色內框、影片／GIF 標記。
class _Cell extends StatelessWidget {
  const _Cell({
    required this.item,
    required this.index,
    required this.controller,
    required this.loader,
    required this.accent,
  });

  final GalleryItem item;
  final int index;
  final PickerController controller;
  final ThumbLoader loader;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final number = controller.numberOf(item.id);
    final selected = number != null;
    return DragSelectItem(
      index: index,
      child: GestureDetector(
        key: ValueKey('picker-cell-${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.toggle(item.id),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            foregroundDecoration: selected
                ? BoxDecoration(border: Border.all(color: accent, width: 3))
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PickerThumb(id: item.id, loader: loader),
                if (item.isVideo)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: MediaBadgeVideo(durationMs: item.durationMs),
                  )
                else if (item.isGif)
                  const Positioned(left: 4, bottom: 4, child: MediaBadgeGif()),
                Positioned(
                  // 左上角：避開日期標題右邊的「整天選取」圓圈（D-084）。
                  left: 5,
                  top: 5,
                  child: Container(
                    key: ValueKey('picker-circle-${item.id}'),
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? accent : const Color(0x40000000),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 右邊的快速捲動條。平常隱藏；列表一開始捲動（手指滑動、fling、拖捲動條）就淡入，
/// 並在旁邊顯示「2026 年 6 月」泡泡；停止捲動約 1 秒後一起淡出。拖動把手時變主色、
/// 每次拖動更新都立刻 `jumpTo`，列表跟著手指即時捲動。
class _FastScroller extends StatefulWidget {
  const _FastScroller({
    required this.scroll,
    required this.accent,
    required this.dateAt,
  });

  final ScrollController scroll;
  final Color accent;
  final DateTime? Function(double offset) dateAt;

  @override
  State<_FastScroller> createState() => _FastScrollerState();
}

class _FastScrollerState extends State<_FastScroller> {
  static const Duration _hideDelay = Duration(seconds: 1);

  double? _dragFraction;
  bool _active = false; // 最近 1 秒內列表有在捲動
  double _lastPixels = 0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_FastScroller old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_onScroll);
      widget.scroll.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  ScrollPosition? get _pos =>
      widget.scroll.positions.isNotEmpty ? widget.scroll.position : null;

  double _fractionOf(ScrollPosition p) {
    final max = p.maxScrollExtent;
    return max <= 0 ? 0 : (p.pixels / max).clamp(0.0, 1.0);
  }

  // 只有捲動量真的變了才算「在捲動」（拉動 sheet 本身不會改 pixels）。
  void _onScroll() {
    final p = _pos;
    if (p == null || !p.hasPixels) return;
    if (p.pixels == _lastPixels) return;
    _lastPixels = p.pixels;
    _poke();
  }

  void _poke() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && _dragFraction == null) setState(() => _active = false);
    });
    if (!_active) {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _active = true);
        });
      } else {
        setState(() => _active = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          final track = box.maxHeight;
          return ListenableBuilder(
            listenable: widget.scroll,
            builder: (context, _) {
              final p = _pos;
              if (p == null || !p.hasPixels || !p.hasContentDimensions) {
                // 第一個 frame 還沒量好捲動範圍：下一個 frame 再畫。
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
                return const SizedBox.shrink();
              }
              if (p.maxScrollExtent <= 0) return const SizedBox.shrink();
              final dragging = _dragFraction != null;
              final visible = dragging || _active;
              final h = dragging ? 52.0 : 44.0;
              final frac = _dragFraction ?? _fractionOf(p);
              final top = frac * math.max(0, track - h);
              DateTime? date;
              if (visible) date = widget.dateAt(frac * p.maxScrollExtent);
              final l = context.l10n;
              return Stack(
                children: [
                  // 拖曳的觸控範圍（右緣 28px 寬）。隱藏時不接觸控，免得擋住一般捲動。
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 28,
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: GestureDetector(
                        key: const ValueKey('picker-fast-scroll'),
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragStart: (d) =>
                            _update(d.localPosition.dy, track),
                        onVerticalDragUpdate: (d) =>
                            _update(d.localPosition.dy, track),
                        onVerticalDragEnd: (_) => _finish(),
                        onVerticalDragCancel: _finish,
                      ),
                    ),
                  ),
                  Positioned(
                    right: dragging ? 16 : 2,
                    top: top,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: const ValueKey('picker-scroll-bar'),
                        opacity: visible ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (visible && date != null) ...[
                              Container(
                                key: const ValueKey('picker-scrub-bubble'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: kPickerInk,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x80000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  l.oshiMonthHeader(date.year, date.month),
                                  style: const TextStyle(
                                    color: kPickerBg,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              key: const ValueKey('picker-scroll-thumb'),
                              width: dragging ? 8 : 6,
                              height: h,
                              decoration: BoxDecoration(
                                color: dragging
                                    ? widget.accent
                                    : const Color(0x66F2ECE4),
                                borderRadius: BorderRadius.circular(
                                  dragging ? 4 : 3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // 拖動中：每次更新都直接 jumpTo（列高是算好的固定值，位置 = 比例 x 最大捲動量）。
  void _update(double y, double track) {
    const h = 52.0;
    final f = ((y - h / 2) / math.max(1, track - h)).clamp(0.0, 1.0);
    setState(() => _dragFraction = f);
    final p = _pos;
    if (p != null && p.hasContentDimensions) {
      p.jumpTo(f * p.maxScrollExtent);
      _lastPixels = p.pixels;
    }
    _poke();
  }

  void _finish() {
    if (_dragFraction == null) return;
    setState(() {
      _dragFraction = null;
      _active = true; // 放手後再停留約 1 秒才淡出
    });
    _poke();
  }
}
