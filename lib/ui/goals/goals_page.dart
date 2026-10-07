import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'day_page.dart';
import 'goal_new_page.dart';
import 'goal_widgets.dart';
import 'month_view.dart';
import 'year_view.dart';

/// 目標分頁：年度／月度／時間軸。
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('目標'),
          bottom: TabBar(
            labelColor: t.accent,
            unselectedLabelColor: t.text3,
            indicatorColor: t.accent,
            tabs: const [
              Tab(text: '年度'),
              Tab(text: '月度'),
              Tab(text: '時間軸'),
            ],
          ),
        ),
        body: const TabBarView(children: [YearView(), MonthView(), DayView()]),
      ),
    );
  }
}

/// 目標列表（年度、月度共用）：卡片＋「新增目標」。
class GoalList extends ConsumerWidget {
  const GoalList({
    super.key,
    required this.period,
    required this.year,
    this.month,
  });
  final GoalPeriod period;
  final int year;
  final int? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final views =
        ref.watch(goalViewsProvider((period, year, month))).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                period == GoalPeriod.year ? '年度目標' : '月度目標',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      GoalNewPage(period: period, year: year, month: month),
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增目標'),
            ),
          ],
        ),
        if (views.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('還沒有目標', style: TextStyle(color: t.text3)),
            ),
          )
        else
          for (final v in views)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalTile(
                view: v,
                period: period,
                year: year,
                month: month,
              ),
            ),
      ],
    );
  }
}

class _GoalTile extends ConsumerWidget {
  const _GoalTile({
    required this.view,
    required this.period,
    required this.year,
    this.month,
  });
  final GoalView view;
  final GoalPeriod period;
  final int year;
  final int? month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = view.pit == null
        ? null
        : ref.watch(coverFileProvider(view.pit!.id)).value;
    return GoalCard(
      view: view,
      coverFile: cover,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GoalNewPage(
            period: period,
            year: year,
            month: month,
            goalId: view.goal.id,
          ),
        ),
      ),
    );
  }
}

/// 避免 pit 型別在其他檔案找不到時的匯入警告。
typedef GoalPit = Pit;
