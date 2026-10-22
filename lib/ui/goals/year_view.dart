import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/income_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import 'goal_widgets.dart';
import 'goals_icons.dart';
import 'goals_page.dart';
import 'income_year_page.dart';
import 'money_format.dart';
import 'review_edit_page.dart';
import 'review_pick_sheet.dart';
import '../common/sensitive_gate.dart';

/// 年度（GoalYear／GoalEmpty）：年度回顧 4×3 預覽（已選 N / 12、排版）＋年度目標列表。
class YearView extends ConsumerStatefulWidget {
  const YearView({
    super.key,
    required this.year,
    this.wide = false,
    this.side = 20,
  });
  final int year;

  /// iPad 並排版面（Goal 稿）：左「年度回顧」卡＋右「年度目標」列表，各自捲動。
  final bool wide;

  /// 寬版的左右留白。
  final double side;

  @override
  ConsumerState<YearView> createState() => _YearViewState();
}

class _YearViewState extends ConsumerState<YearView> {
  Future<void> _editLayout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewEditPage(year: widget.year),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chosen =
        ref.watch(reviewMonthsProvider(widget.year)).value ?? const {};
    // reviewMonthsProvider 已解析（手動挑的／預設互動量最高的）；沒有候選＝沒有 key。
    final files = <int, String?>{for (var m = 1; m <= 12; m++) m: chosen[m]};
    final summaries =
        ref.watch(reviewMonthSummariesProvider(widget.year)).value ?? const {};
    final income = ref.watch(incomeProvider(widget.year)).value;
    final selected = files.values.where((f) => f != null).length;
    final monthGrid = GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: widget.wide ? 10 : 8,
      crossAxisSpacing: widget.wide ? 10 : 8,
      children: [
        for (var m = 1; m <= 12; m++)
          _MonthCell(
            month: m,
            file: files[m],
            allEmpty: selected == 0,
            onTap: _editLayout,
            // 多於一張成圖才能長按換圖（D-056）；只有一張或沒有＝長按沒反應
            // （仍要註冊空的長按，否則長按放開會被當成點擊而打開排版）。
            onLongPress: summaries[m]?.canPick == true
                ? () => showReviewPickSheet(
                    context,
                    year: widget.year,
                    month: m,
                    current: files[m],
                  )
                : () {},
          ),
      ],
    );
    final hasIncome = income != null && !income.isEmpty;
    if (widget.wide) {
      return LayoutBuilder(
        builder: (context, box) {
          final inner = box.maxWidth - widget.side * 2;
          final gap = inner >= 800 ? 32.0 : 24.0;
          // 稿：左欄 430；窄一點時依內容區取一半，下限 300。
          final leftW = (inner * 0.5).clamp(300.0, 430.0);
          return Padding(
            padding: EdgeInsets.fromLTRB(widget.side, 26, widget.side, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: leftW,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GoalSectionRow(
                          title: context.l10n.goalsYearReview,
                          titleSize: 17,
                          padding: const EdgeInsets.only(bottom: 12),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 14,
                            children: [
                              Text(
                                context.l10n.goalsReviewSelected(selected),
                                style: TextStyle(fontSize: 13, color: t.text3),
                              ),
                              _LayoutButton(onTap: _editLayout),
                            ],
                          ),
                        ),
                        monthGrid,
                        if (hasIncome)
                          _IncomeCard(
                            income: income,
                            year: widget.year,
                            top: 22,
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: GoalList(
                      period: GoalPeriod.year,
                      year: widget.year,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        GoalSectionRow(
          title: context.l10n.goalsYearReview,
          padding: const EdgeInsets.only(bottom: 10),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                context.l10n.goalsReviewSelected(selected),
                style: TextStyle(fontSize: 12, color: t.text3),
              ),
              GestureDetector(
                onTap: _editLayout,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  context.l10n.goalsLayout,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        monthGrid,
        if (hasIncome) _IncomeCard(income: income, year: widget.year),
        GoalList(
          period: GoalPeriod.year,
          year: widget.year,
          topGap: hasIncome ? 20 : null,
        ),
      ],
    );
  }
}

/// 「排版」按鈕（寬版 Goal 稿）：36 高、白底、1px 邊、主色字；觸控範圍補到 44 高。
class _LayoutButton extends StatelessWidget {
  const _LayoutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.l10n.goalsLayout,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 商稿收入卡（D-047）：各幣種金額合計（不換算）＋張數，點進 IncomeYear。
/// 沒有任何商稿時不顯示（GoalEmpty 沒有畫）。
class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.income, required this.year, this.top = 20});
  final IncomeYear income;
  final int year;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = income.months.fold<int>(0, (n, m) => n + m.entries.length);
    final sums = [
      for (final c in income.currencies) formatMoney(c.currency, c.total),
    ].join('\u3000');
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => IncomeYearPage(year: year)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.borderCard),
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF2D3324)
                      : const Color(0xFFE6EBDC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: SvgIcon(
                    GoalsIcons.wallet,
                    size: 21,
                    strokeWidth: 1.8,
                    color: dark
                        ? const Color(0xFFADBD8C)
                        : const Color(0xFF627248),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.goalsIncome,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(sums, style: TextStyle(fontSize: 13, color: t.text2)),
                  ],
                ),
              ),
              Text(
                context.l10n.commonCountImages(count),
                style: TextStyle(fontSize: 12.5, color: t.text4),
              ),
              SvgIcon(
                AppIcons.chevronRight,
                size: 18,
                strokeWidth: 2,
                color: t.text4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 年度回顧預覽的一格：有圖＝圖＋左下白色月份標籤；沒圖＝虛線格（有圖示）；
/// 整年都沒有時（GoalEmpty）＝純虛線格＋中文月份（D-025：「1月」）。
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.month,
    required this.file,
    required this.allEmpty,
    required this.onTap,
    this.onLongPress,
  });
  final int month;
  final String? file;
  final bool allEmpty;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dashed = dark ? t.dashed : const Color(0xFFE0D5C6);
    final Widget inner;
    if (file != null) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            SensitiveGate(
              file: file!,
              child: StoredImage(file!, cacheWidth: 300),
            ),
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.l10n.goalsMonthNum(month),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B2622),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (allEmpty) {
      inner = DashedBox(
        color: dark ? t.dashed : const Color(0xFFDCCFBE),
        radius: 12,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6.5, 0, 0, 6.5),
            child: Text(
              context.l10n.goalsMonthNum(month),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFB3A797),
              ),
            ),
          ),
        ),
      );
    } else {
      inner = DashedBox(
        color: dashed,
        radius: 12,
        fill: dark ? t.chipBg : const Color(0xFFF2ECE3),
        child: Stack(
          children: [
            Center(
              child: SvgIcon(
                AppIcons.image,
                size: 20,
                strokeWidth: 1.6,
                color: dark ? t.dashed : const Color(0xFFD9CFC1),
              ),
            ),
            Positioned(
              left: 11.5,
              bottom: 6.5,
              child: Text(
                context.l10n.goalsMonthNum(month),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: t.text4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: inner,
    );
  }
}
