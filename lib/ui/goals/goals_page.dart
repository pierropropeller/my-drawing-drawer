import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import 'day_page.dart';
import 'goal_new_page.dart';
import 'goal_widgets.dart';
import 'month_view.dart';
import 'year_view.dart';

/// 目標分頁（GoalYear／Month／Day）：襯線「目標」＋年份、年／月／日分段控制。
/// 三個視圖用 IndexedStack 保留各自的狀態。
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  int _mode = 0;
  int _year = DateTime.now().year; // 年度視圖的年份
  final _years = [DateTime.now().year, DateTime.now().year]; // 月、日視圖目前顯示的年份

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final headerYear = switch (_mode) {
      0 => _year,
      _ => _years[_mode - 1],
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '目標',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$headerYear',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: t.text3,
                        ),
                      ),
                      const Spacer(),
                      if (_mode == 0) ...[
                        _YearStep(
                          icon: AppIcons.back,
                          tooltip: '上一年',
                          onTap: () => setState(() => _year--),
                        ),
                        _YearStep(
                          icon: AppIcons.chevronRight,
                          tooltip: '下一年',
                          onTap: () => setState(() => _year++),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Segmented(
                    labels: const ['年', '月', '日'],
                    selected: _mode,
                    onChanged: (i) => setState(() => _mode = i),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: [
                  YearView(year: _year),
                  MonthView(
                    onYearChanged: (y) => setState(() => _years[0] = y),
                  ),
                  DayView(onYearChanged: (y) => setState(() => _years[1] = y)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearStep extends StatelessWidget {
  const _YearStep({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SvgIcon(
          icon,
          size: 20,
          strokeWidth: 2,
          color: context.tokens.text3,
        ),
      ),
    ),
  );
}

/// 年／月／日分段控制：#F1EADF 圓角 12 底、白色選中膠囊（圓角 9、淡陰影）。
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? t.chipBg : const Color(0xFFF1EADF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 6,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? t.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: i == selected
                          ? const [
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i == selected ? t.ink : t.text3,
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

/// 目標列表（年度、月度共用）：標題＋「新增」連結＋卡片；空白時是虛線框＋「新增目標」按鈕。
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

  void _new(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GoalNewPage(period: period, year: year, month: month),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views =
        ref.watch(goalViewsProvider((period, year, month))).value ?? const [];
    final title = period == GoalPeriod.year ? '年度目標' : '月度小目標';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoalSectionRow(
          title: title,
          padding: EdgeInsets.only(
            top: period == GoalPeriod.year ? 22 : 20,
            bottom: 10,
          ),
          trailing: views.isEmpty ? null : AddLink(onTap: () => _new(context)),
        ),
        if (views.isEmpty)
          DashedGoalEmpty(
            text: period == GoalPeriod.year ? '還沒有年度目標' : '還沒有月度目標',
            onAdd: () => _new(context),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

/// 空白目標框（GoalEmpty）：虛線 16 圓角、襯線標題、主色「＋ 新增目標」按鈕。
class DashedGoalEmpty extends StatelessWidget {
  const DashedGoalEmpty({super.key, required this.text, required this.onAdd});
  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
      child: DashedBox(
        color: t.dashed,
        radius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
          child: Column(
            children: [
              Text(
                text,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      SvgIcon(
                        AppIcons.plus,
                        size: 18,
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                      Text(
                        '新增目標',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
