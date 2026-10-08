import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../data/income_queries.dart';
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

/// 年度（GoalYear／GoalEmpty）：年度回顧 4×3 預覽（已選 N / 12、排版）＋年度目標列表。
class YearView extends ConsumerStatefulWidget {
  const YearView({super.key, required this.year});
  final int year;

  @override
  ConsumerState<YearView> createState() => _YearViewState();
}

class _YearViewState extends ConsumerState<YearView> {
  Map<int, List<String>> _byMonth = {};

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  @override
  void didUpdateWidget(YearView old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) {
      _byMonth = {};
      _loadMonths();
    }
  }

  Future<void> _loadMonths() async {
    final year = widget.year;
    final m = await ref.read(databaseProvider).pieceImagesByMonth(year);
    if (mounted && year == widget.year) setState(() => _byMonth = m);
  }

  Future<void> _editLayout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewEditPage(year: widget.year),
      ),
    );
    _loadMonths();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chosen =
        ref.watch(reviewMonthsProvider(widget.year)).value ?? const {};
    final files = <int, String?>{
      for (var m = 1; m <= 12; m++)
        m: chosen.containsKey(m) ? chosen[m] : _byMonth[m]?.first,
    };
    final income = ref.watch(incomeProvider(widget.year)).value;
    final selected = files.values.where((f) => f != null).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        GoalSectionRow(
          title: '年度回顧',
          padding: const EdgeInsets.only(bottom: 10),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                '已選 $selected / 12',
                style: TextStyle(fontSize: 12, color: t.text3),
              ),
              GestureDetector(
                onTap: _editLayout,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '排版',
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
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var m = 1; m <= 12; m++)
              _MonthCell(
                month: m,
                file: files[m],
                allEmpty: selected == 0,
                onTap: _editLayout,
              ),
          ],
        ),
        if (income != null && !income.isEmpty)
          _IncomeCard(income: income, year: widget.year),
        GoalList(
          period: GoalPeriod.year,
          year: widget.year,
          topGap: income != null && !income.isEmpty ? 20 : null,
        ),
      ],
    );
  }
}

/// 商稿收入卡（D-047）：各幣種金額合計（不換算）＋張數，點進 IncomeYear。
/// 沒有任何商稿時不顯示（GoalEmpty 沒有畫）。
class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.income, required this.year});
  final IncomeYear income;
  final int year;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = income.months.fold<int>(0, (n, m) => n + m.entries.length);
    final sums = [
      for (final c in income.currencies) formatMoney(c.currency, c.total),
    ].join('\u3000');
    return Padding(
      padding: const EdgeInsets.only(top: 20),
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
                    const Text(
                      '商稿收入',
                      style: TextStyle(
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
                '$count 張',
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
  });
  final int month;
  final String? file;
  final bool allEmpty;
  final VoidCallback onTap;

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
            StoredImage(file!, cacheWidth: 300),
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
                  '$month月',
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
              '$month月',
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
                '$month月',
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
    return GestureDetector(onTap: onTap, child: inner);
  }
}
