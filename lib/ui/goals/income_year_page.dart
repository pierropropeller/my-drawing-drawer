import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/income_queries.dart';
import '../../data/payment.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../entity/entity_widgets.dart';
import '../entity/piece_detail_page.dart';
import 'goals_icons.dart';
import 'money_format.dart';

/// 商稿收入・年度（IncomeYear）：每幣種一張合計卡、未收齊紅色提示、按月份列出每張商稿。
/// 不做匯率換算。artboard 沒有畫導覽列，所以隱藏。
class IncomeYearPage extends ConsumerStatefulWidget {
  const IncomeYearPage({super.key, required this.year});
  final int year;

  @override
  ConsumerState<IncomeYearPage> createState() => _IncomeYearPageState();
}

class _IncomeYearPageState extends ConsumerState<IncomeYearPage>
    with HidesNavBar {
  @override
  Widget build(BuildContext context) {
    final income = ref.watch(incomeProvider(widget.year)).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SubPageHeader(title: '${widget.year} 商稿收入', titleSize: 20, gap: 6),
            Expanded(
              child: income == null
                  ? const SizedBox.shrink()
                  : ContentWidth(child: _Body(income: income)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.income});
  final IncomeYear income;

  @override
  Widget build(BuildContext context) {
    final owing = [
      for (final c in income.currencies)
        if (c.hasOutstanding) c,
    ];
    final unpaidCount = owing.fold<int>(0, (n, c) => n + c.unpaidCount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        LayoutBuilder(
          builder: (context, c) {
            // 一排兩張；只有一種幣種時整排一張。
            final w = income.currencies.length == 1
                ? c.maxWidth
                : (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final cur in income.currencies)
                  SizedBox(width: w, child: _CurrencyCard(cur)),
              ],
            );
          },
        ),
        if (owing.isNotEmpty)
          _OwingBanner(
            text: '未收齊 $unpaidCount 張',
            amount:
                '尚欠 ${[for (final c in owing) formatMoney(c.currency, c.outstanding)].join('　')}',
          ),
        for (final m in income.months) ...[
          // 月份小計與卡片內容同一條線：卡片 padding 14 ＋ 邊框 1 ＝ 15（D-049）。
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 18, 15, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${m.month}月',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  [
                    for (final e in m.totals.entries)
                      formatMoney(e.key, e.value),
                  ].join('　'),
                  style: TextStyle(fontSize: 12.5, color: context.tokens.text3),
                ),
              ],
            ),
          ),
          _MonthCard(entries: m.entries),
        ],
      ],
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard(this.cur);
  final IncomeCurrency cur;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currencyName(cur.currency),
            style: TextStyle(fontSize: 12, color: t.text3),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoney(cur.currency, cur.total),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '已收 ${formatMoney(cur.currency, cur.received)} · ${cur.count} 張',
            style: TextStyle(fontSize: 12, color: t.text3),
          ),
        ],
      ),
    );
  }
}

/// 紅色提示條：左「未收齊 n 張」、右「尚欠 ¥ x」。
class _OwingBanner extends StatelessWidget {
  const _OwingBanner({required this.text, required this.amount});
  final String text;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFFF08A76) : t.danger;
    final style = TextStyle(
      color: fg,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? t.danger.withValues(alpha: .18) : const Color(0xFFF9E1DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 8,
        children: [
          SvgIcon(GoalsIcons.alert, size: 17, strokeWidth: 2, color: fg),
          Expanded(child: Text(text, style: style)),
          Text(amount, style: style),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.entries});
  final List<IncomeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(children: [for (final e in entries) _EntryRow(entry: e)]),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final IncomeEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = entry.piece;
    final client = p.client.trim().replaceFirst(RegExp(r'^@+'), '');
    final amount = entry.amount;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PieceDetailPage(pieceId: p.id, pitId: p.pitId),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: dark ? t.border : const Color(0xFFF1EADF),
            ),
          ),
        ),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: entry.cover == null
                    ? ColoredBox(
                        color: t.chipBg,
                        child: Center(
                          child: SvgIcon(
                            AppIcons.image,
                            size: 16,
                            strokeWidth: 1.5,
                            color: t.dashed,
                          ),
                        ),
                      )
                    : StoredImage(entry.cover!.file, cacheWidth: 150),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title.isEmpty ? '（無標題）' : p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (client.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '@$client',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.text3),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amount != null)
                  Text(
                    formatMoney(entry.currency, amount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _StatusPill(entry: entry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 收款狀態（自動推算）：已收 ¥ 300（部分）／未收／已收齊。
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.entry});
  final IncomeEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (String label, Color fg, Color bg) = switch (entry.payment.status) {
      PaymentStatus.partial => (
        '已收 ${formatMoney(entry.currency, entry.payment.received)}',
        t.draft.fg,
        t.draft.bg,
      ),
      PaymentStatus.unpaid => (
        '未收',
        dark ? const Color(0xFFF08A76) : t.danger,
        dark ? t.danger.withValues(alpha: .18) : const Color(0xFFF9E1DC),
      ),
      PaymentStatus.paid => (
        '已收齊',
        dark ? const Color(0xFFADBD8C) : const Color(0xFF5C7A44),
        dark ? const Color(0xFF2D3324) : const Color(0xFFE6EBDC),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
