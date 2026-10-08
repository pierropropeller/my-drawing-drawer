import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'day_page.dart';
import 'goal_widgets.dart';
import 'goals_page.dart';

/// 月度（Month）：月曆（當天有成圖，日期變成圓形圖片，預設最晚一張）＋月度小目標。
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, this.onYearChanged});

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
    const wk = ['日', '一', '二', '三', '四', '五', '六'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
      children: [
        PeriodNav(
          label: '$_month 月',
          prevTooltip: '上個月',
          nextTooltip: '下個月',
          onPrev: () => _shift(-1),
          onNext: () => _shift(1),
        ),
        Row(
          children: [
            for (final w in wk)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(color: t.text4, fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        GridView.count(
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
                isToday:
                    today.year == _year &&
                    today.month == _month &&
                    today.day == d,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DayPage(day: DateTime(_year, _month, d)),
                  ),
                ),
              ),
          ],
        ),
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
  });
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
          constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
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
