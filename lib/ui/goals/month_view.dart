import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'goal_widgets.dart';
import 'day_page.dart';
import 'goals_page.dart';

/// 月度（Month）：月曆（當天有成圖，日期變成圓形圖片，預設最晚一張）＋月度小目標。
class MonthView extends ConsumerStatefulWidget {
  const MonthView({
    super.key,
    this.onYearChanged,
    this.onDayTap,
    this.wide = false,
    this.side = 20,
  });

  /// iPad 並排版面（稿沒畫，由手機月頁推導）：左月曆、右月度目標，各自捲動。
  final bool wide;

  /// 寬版的左右留白。
  final double side;

  /// 點日曆某一天：上層切到「日」並捲到該日（D-072）；沒給就另開一頁日頁。
  final ValueChanged<DateTime>? onDayTap;

  /// 月份切換後所在年份改變時通知（標題列的年份跟著變）。
  final ValueChanged<int>? onYearChanged;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  void _shift(int d) {
    final m = DateTime(_year, _month + d);
    setState(() {
      _year = m.year;
      _month = m.month;
    });
    widget.onYearChanged?.call(_year);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final covers =
        ref.watch(monthCoversProvider((_year, _month))).value ?? const {};
    final first = DateTime(_year, _month);
    final days = DateTime(_year, _month + 1, 0).day;
    final lead = first.weekday % 7; // 週日開頭
    final today = DateTime.now();
    final l = context.l10n;
    final wk = [
      l.goalsWeekSun,
      l.goalsWeekMon,
      l.goalsWeekTue,
      l.goalsWeekWed,
      l.goalsWeekThu,
      l.goalsWeekFri,
      l.goalsWeekSat,
    ];
    final nav = PeriodNav(
      label: l.goalsMonthTitle(_month),
      prevTooltip: l.goalsPrevMonth,
      nextTooltip: l.goalsNextMonth,
      onPrev: () => _shift(-1),
      onNext: () => _shift(1),
    );
    final weekRow = Row(
      children: [
        for (final w in wk)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(w, style: TextStyle(color: t.text4, fontSize: 11)),
              ),
            ),
          ),
      ],
    );
    final calendar = GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: [
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var d = 1; d <= days; d++)
          _DayCell(
            day: d,
            file: covers[d],
            maxSize: widget.wide ? 52 : 40,
            isToday:
                today.year == _year && today.month == _month && today.day == d,
            onTap: () {
              final day = DateTime(_year, _month, d);
              final cb = widget.onDayTap;
              if (cb != null) {
                cb(day);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => DayPage(day: day)),
                );
              }
            },
          ),
      ],
    );
    if (widget.wide) {
      return LayoutBuilder(
        builder: (context, box) {
          final inner = box.maxWidth - widget.side * 2;
          final leftW = (inner * 0.5).clamp(320.0, 460.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(widget.side, 26, widget.side, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: leftW,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      nav,
                      weekRow,
                      const SizedBox(height: 2),
                      calendar,
                    ],
                  ),
                ),
                SizedBox(width: inner >= 800 ? 32 : 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: GoalList(
                      period: GoalPeriod.month,
                      year: _year,
                      month: _month,
                      topGap: 0,
                      wide: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
      children: [
        nav,
        weekRow,
        const SizedBox(height: 2),
        calendar,
        GoalList(period: GoalPeriod.month, year: _year, month: _month),
      ],
    );
  }
}

/// 月曆一格：40 的圓；有成圖＝圖片圓＋白字陰影；今天＝主色實心圓＋白字（有圖時改為主色外框）。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.file,
    required this.isToday,
    required this.onTap,
    this.maxSize = 40,
  });
  final double maxSize;
  final int day;
  final String? file;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasArt = file != null;
    final bold = hasArt || isToday;
    final Color numColor = hasArt || isToday
        ? Colors.white
        : t.ink.withValues(alpha: .9);
    final circle = ClipOval(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasArt)
            StoredImage(file!, cacheWidth: 200)
          else if (isToday)
            ColoredBox(color: t.accent),
          Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                color: numColor,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                shadows: hasArt
                    ? const [
                        Shadow(
                          blurRadius: 2,
                          offset: Offset(0, 1),
                          color: Colors.black54,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSize, maxHeight: maxSize),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: hasArt && isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: t.accent, spreadRadius: 2)],
                    )
                  : null,
              child: circle,
            ),
          ),
        ),
      ),
    );
  }
}
