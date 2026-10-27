import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../nav/adaptive_nav.dart';
import '../common/swipe_pager.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'day_page.dart';
import 'day_timeline.dart';
import 'goal_new_page.dart';
import 'goal_widgets.dart';
import 'month_view.dart';
import 'year_view.dart';

/// 時間軸分頁（GoalYear／Month／Day）：襯線「時間軸」＋年份、年／月／日分段控制。
/// 三個視圖用 IndexedStack 保留各自的狀態。
class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  /// 內容區至少這麼寬才用並排版面（左 430 回顧卡＋右目標列表）。
  static const _wideMin = 720.0;

  // 上次停留的年／月／日（設定，啟動即還原）。
  late int _mode = ref.read(settingsProvider).lastGoalsMode;
  final _dayKey = GlobalKey<DayTimelineState>();
  final _monthKey = GlobalKey<MonthViewState>();
  int _year = DateTime.now().year; // 年度視圖的年份
  final _years = [DateTime.now().year, DateTime.now().year]; // 月、日視圖目前顯示的年份

  /// 左右滑的小數頁碼，年／月／日切換的白底跟著它滑（D-118）。
  late final _progress = ValueNotifier<double>(_mode.toDouble());

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 側邊欄的年份清單（iPad）與年度視圖的年份同步。
    _year = ref.read(goalSidebarYearProvider);
  }

  /// 年度視圖換年份：同時告訴側邊欄。
  void _setYear(int y) {
    setState(() => _year = y);
    ref.read(goalSidebarYearProvider.notifier).select(y);
  }

  /// 年度頁點月份格（D-112）：切到「月」（同時記住分頁）並把月頁切到該年該月。
  void _openMonth(int month) {
    setState(() {
      _mode = 1;
      _years[0] = _year;
    });
    ref.read(settingsProvider.notifier).setLastGoalsMode(1);
    // 月頁可能還沒建（左右滑的頁面用到才建）：建好後再跳。
    final y = _year;
    void jump() => _monthKey.currentState?.jumpToMonth(y, month);
    if (_monthKey.currentState != null) {
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => jump());
    }
  }

  @override
  Widget build(BuildContext context) {
    // 側邊欄點年份 → 年度視圖跟著換。
    ref.listen<int>(goalSidebarYearProvider, (_, y) {
      if (y != _year) setState(() => _year = y);
    });
    final t = context.tokens;
    final headerYear = switch (_mode) {
      0 => _year,
      _ => _years[_mode - 1],
    };
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // 內容區（已扣掉側邊導覽）夠寬才用 iPad 並排版面；拉窄時同一棵樹自動退回手機版。
        child: LayoutBuilder(
          builder: (context, box) {
            final wide =
                WindowClass.of(context).isWide && box.maxWidth >= _wideMin;
            final side = wide ? (box.maxWidth >= 900 ? 40.0 : 24.0) : 20.0;
            final yearStep = _mode == 0
                ? [
                    _YearStep(
                      icon: AppIcons.back,
                      tooltip: context.l10n.goalsPrevYear,
                      onTap: () => _setYear(_year - 1),
                    ),
                    _YearStep(
                      icon: AppIcons.chevronRight,
                      tooltip: context.l10n.goalsNextYear,
                      onTap: () => _setYear(_year + 1),
                    ),
                  ]
                : const <Widget>[];
            void setMode(int i) {
              setState(() => _mode = i);
              ref.read(settingsProvider.notifier).setLastGoalsMode(i);
            }

            final segmented = _Segmented(
              labels: [
                context.l10n.goalsModeYear,
                context.l10n.goalsModeMonth,
                context.l10n.goalsModeDay,
              ],
              progress: _progress,
              onChanged: setMode,
            );
            final titleStyle = Theme.of(context).textTheme.headlineMedium
                ?.copyWith(
                  fontSize: wide ? 30 : 24,
                  fontWeight: FontWeight.w700,
                );
            final yearStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: wide ? 22 : 18,
              fontWeight: FontWeight.w400,
              color: t.text3,
            );
            return ContentWidth(
              maxWidth: wide ? double.infinity : 920,
              child: Column(
                children: [
                  Padding(
                    padding: wide
                        ? EdgeInsets.fromLTRB(side, 30, side, 0)
                        : const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(context.l10n.goalsTitle, style: titleStyle),
                            SizedBox(width: wide ? 16 : 10),
                            Text('$headerYear', style: yearStyle),
                            const Spacer(),
                            ...yearStep,
                            // 寬版：年／月／日切換和標題同一列（Goal 稿 260 寬）。
                            if (wide) ...[
                              const SizedBox(width: 12),
                              SizedBox(width: 260, child: segmented),
                            ],
                          ],
                        ),
                        if (!wide) ...[const SizedBox(height: 14), segmented],
                      ],
                    ),
                  ),
                  Expanded(
                    // 左右滑動切換 年／月／日（不循環），內容跟著手指走（D-118）。
                    child: SwipePager<int>(
                      order: const [0, 1, 2],
                      current: _mode,
                      progress: _progress,
                      onChanged: setMode,
                      itemBuilder: (context, mode) => switch (mode) {
                        0 => YearView(
                          year: _year,
                          wide: wide,
                          side: side,
                          onMonthTap: _openMonth,
                        ),
                        1 => MonthView(
                          key: _monthKey,
                          wide: wide,
                          side: side,
                          onYearChanged: (y) => setState(() => _years[0] = y),
                          // 月頁點日曆：切到「日」並捲到該日（D-072）。
                          onDayTap: (d) {
                            setState(() => _mode = 2);
                            ref
                                .read(settingsProvider.notifier)
                                .setLastGoalsMode(2);
                            if (_dayKey.currentState != null) {
                              _dayKey.currentState!.jumpToDay(d);
                            } else {
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _dayKey.currentState?.jumpToDay(d),
                              );
                            }
                          },
                        ),
                        // 日：時間軸在寬版置中限寬（稿沒畫，沿用手機時間軸）。
                        _ => Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide ? 760 : double.infinity,
                            ),
                            child: DayView(
                              timelineKey: _dayKey,
                              onYearChanged: (y) =>
                                  setState(() => _years[1] = y),
                            ),
                          ),
                        ),
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
/// 年／月／日切換。白底跟著左右滑的進度 [progress]（小數頁碼）滑動（D-118）。
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.progress,
    required this.onChanged,
  });
  final List<String> labels;
  final ValueListenable<double> progress;
  final ValueChanged<int> onChanged;

  static const _pad = 4.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(
        color: dark ? t.chipBg : const Color(0xFFF1EADF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final n = labels.length;
          final segW = (box.maxWidth - _gap * (n - 1)) / n;
          return ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) {
              final pos = p.clamp(0.0, n - 1.0);
              final selected = pos.round();
              return Stack(
                children: [
                  Positioned(
                    left: pos * (segW + _gap),
                    top: 0,
                    bottom: 0,
                    width: segW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    spacing: _gap,
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: i == selected,
                            child: GestureDetector(
                              onTap: () => onChanged(i),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
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
                ],
              );
            },
          );
        },
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
    this.topGap,
    this.wide = false,
  });
  final GoalPeriod period;
  final int year;
  final int? month;

  /// iPad 並排版面：標題 17、「新增」是主色實心按鈕（Goal 稿）。
  final bool wide;

  /// 標題上方的間距；預設年度 22（GoalEmpty）、月度 20，年度頁有商稿收入卡時是 20。
  final double? topGap;

  void _new(BuildContext context) =>
      GoalNewPage.open(context, period: period, year: year, month: month);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views =
        ref.watch(goalViewsProvider((period, year, month))).value ?? const [];
    final title = period == GoalPeriod.year
        ? context.l10n.goalsSectionYear
        : context.l10n.goalsSectionMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoalSectionRow(
          title: title,
          titleSize: wide ? 17 : 16,
          padding: EdgeInsets.only(
            top: topGap ?? (period == GoalPeriod.year ? 22 : 20),
            bottom: wide ? 4 : 10,
          ),
          trailing: views.isEmpty
              ? null
              : (wide
                    ? AddButton(onTap: () => _new(context))
                    : AddLink(onTap: () => _new(context))),
        ),
        if (views.isEmpty)
          DashedGoalEmpty(
            text: period == GoalPeriod.year
                ? context.l10n.goalsEmptyYear
                : context.l10n.goalsEmptyMonth,
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
                  child: Row(
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
                        context.l10n.goalsNewGoal,
                        style: const TextStyle(
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

class _GoalTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GoalCard(
      view: view,
      onTap: () => GoalNewPage.open(
        context,
        period: period,
        year: year,
        month: month,
        goalId: view.goal.id,
      ),
    );
  }
}
