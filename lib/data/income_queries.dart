import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart';
import 'payment.dart';

/// 商稿收入頁的一張商稿（D-047）。
class IncomeEntry {
  const IncomeEntry({
    required this.piece,
    required this.cover,
    required this.payment,
  });

  final Piece piece;

  /// 成圖第一張圖；沒有圖為 null。
  final ImageRef? cover;
  final PaymentState payment;

  String get currency => piece.currency;
  double? get amount => piece.amount;
  double get received => piece.receivedAmount;
}

/// 某幣種的年度合計卡片。
class IncomeCurrency {
  const IncomeCurrency({
    required this.currency,
    required this.total,
    required this.received,
    required this.count,
    required this.outstanding,
    required this.unpaidCount,
  });

  final String currency;

  /// 金額合計。
  final double total;

  /// 已收合計（多收的也算進去）。
  final double received;

  /// 張數。
  final int count;

  /// 尚欠＝未收／部分收款的商稿（金額 − 已收）合計。
  final double outstanding;

  /// 未收齊的張數（未收＋部分收款）。
  final int unpaidCount;

  bool get hasOutstanding => unpaidCount > 0;
}

/// 某月的商稿清單；[totals] 是各幣種的金額小計（灰字）。
class IncomeMonth {
  const IncomeMonth({
    required this.month,
    required this.entries,
    required this.totals,
  });

  final int month;
  final List<IncomeEntry> entries;
  final Map<String, double> totals;
}

class IncomeYear {
  const IncomeYear({
    required this.year,
    required this.currencies,
    required this.months,
  });

  final int year;

  /// 幣種卡片，合計金額大的在前；不做匯率換算。
  final List<IncomeCurrency> currencies;

  /// 有商稿的月份，12 月到 1 月（新的在前）。
  final List<IncomeMonth> months;

  bool get isEmpty => months.isEmpty;
}

extension IncomeQueries on AppDatabase {
  /// 年度商稿收入。月份以成圖的「完成日期」[Piece.finishedAt] 歸屬
  /// （設計稿沒有指定；交稿日期 dueAt 是預定日，可能晚於完成）。
  /// 沒填金額的商稿只出現在月份清單，不計入卡片與小計。
  Stream<IncomeYear> watchIncome(int year) {
    return watchAssembled(this, {pieces, entityImages}, () async {
      final rows =
          await (select(pieces)
                ..where(
                  (p) =>
                      p.deletedAt.isNull() &
                      p.isCommission.equals(true) &
                      p.finishedAt.isBiggerOrEqualValue(DateTime(year)) &
                      p.finishedAt.isSmallerThanValue(DateTime(year + 1)),
                )
                ..orderBy([(p) => OrderingTerm.desc(p.finishedAt)]))
              .get();

      final entries = <IncomeEntry>[];
      for (final p in rows) {
        final im =
            await (select(entityImages)
                  ..where(
                    (e) =>
                        e.ownerType.equalsValue(OwnerType.piece) &
                        e.ownerId.equals(p.id) &
                        e.deletedAt.isNull(),
                  )
                  ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)])
                  ..limit(1))
                .getSingleOrNull();
        entries.add(
          IncomeEntry(
            piece: p,
            cover: im == null
                ? null
                : ImageRef(im.imageFile, im.width, im.height),
            payment: paymentStateOf(
              amount: p.amount,
              received: p.receivedAmount,
            ),
          ),
        );
      }

      final byCurrency = <String, List<IncomeEntry>>{};
      for (final e in entries.where((e) => e.amount != null)) {
        byCurrency.putIfAbsent(e.currency, () => []).add(e);
      }
      final currencies =
          [
            for (final c in byCurrency.entries)
              IncomeCurrency(
                currency: c.key,
                total: c.value.fold(0.0, (a, e) => a + e.amount!),
                received: c.value.fold(0.0, (a, e) => a + e.received),
                count: c.value.length,
                outstanding: c.value.fold(
                  0.0,
                  (a, e) =>
                      a + outstandingOf(amount: e.amount, received: e.received),
                ),
                unpaidCount: c.value.where((e) => !e.payment.isPaid).length,
              ),
          ]..sort((a, b) {
            final d = b.total.compareTo(a.total);
            return d != 0 ? d : a.currency.compareTo(b.currency);
          });

      final byMonth = <int, List<IncomeEntry>>{};
      for (final e in entries) {
        byMonth.putIfAbsent(e.piece.finishedAt.month, () => []).add(e);
      }
      final months = [
        for (final m in (byMonth.keys.toList()..sort((a, b) => b.compareTo(a))))
          IncomeMonth(
            month: m,
            entries: byMonth[m]!,
            totals: _sumByCurrency(byMonth[m]!),
          ),
      ];
      return IncomeYear(year: year, currencies: currencies, months: months);
    });
  }

  /// 各幣種金額合計，幣種按該月合計大的在前。
  Map<String, double> _sumByCurrency(List<IncomeEntry> list) {
    final sums = <String, double>{};
    for (final e in list) {
      if (e.amount == null) continue;
      sums[e.currency] = (sums[e.currency] ?? 0) + e.amount!;
    }
    final keys = sums.keys.toList()
      ..sort((a, b) {
        final d = sums[b]!.compareTo(sums[a]!);
        return d != 0 ? d : a.compareTo(b);
      });
    return {for (final k in keys) k: sums[k]!};
  }
}
