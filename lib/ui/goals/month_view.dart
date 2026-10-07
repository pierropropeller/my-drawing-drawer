import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'day_page.dart';
import 'goal_widgets.dart';
import 'goals_page.dart';

/// 月度：月曆（當天有成圖，日期變成圓形圖片，預設最晚一張）＋月度目標。
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  void _shift(int d) => setState(() {
    final m = DateTime(_year, _month + d);
    _year = m.year;
    _month = m.month;
  });

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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PeriodHeader(
          label: '$_year 年 $_month 月',
          onPrev: () => _shift(-1),
          onNext: () => _shift(1),
        ),
        Row(
          children: [
            for (final w in wk)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(color: t.text3, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
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
        const SizedBox(height: 24),
        GoalList(period: GoalPeriod.month, year: _year, month: _month),
      ],
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: t.accent, width: 2) : null,
          color: file == null ? Colors.transparent : null,
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file != null) StoredImage(file!, cacheWidth: 200),
              Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: file != null
                        ? Colors.white
                        : (isToday ? t.accent : t.ink),
                    fontWeight: file != null || isToday
                        ? FontWeight.w700
                        : FontWeight.w400,
                    shadows: file != null
                        ? const [Shadow(blurRadius: 4, color: Colors.black87)]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
