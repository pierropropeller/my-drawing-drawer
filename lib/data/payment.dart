/// 商稿收款狀態（D-050）：由金額與已收金額推算，不儲存。
enum PaymentStatus { unpaid, partial, paid }

class PaymentState {
  const PaymentState(this.status, this.received);
  final PaymentStatus status;

  /// 已收金額（partial 時顯示「已收 ¥ 300」）。
  final double received;

  bool get isPaid => status == PaymentStatus.paid;
  bool get isUnpaid => status == PaymentStatus.unpaid;
  bool get isPartial => status == PaymentStatus.partial;

  @override
  bool operator ==(Object other) =>
      other is PaymentState &&
      other.status == status &&
      other.received == received;

  @override
  int get hashCode => Object.hash(status, received);

  @override
  String toString() => 'PaymentState($status, $received)';
}

/// 已收 = 0 → 未收；0 < 已收 < 金額 → 部分（顯示已收金額）；已收 ≥ 金額 → 已收齊（多收也算）。
/// 金額沒填（null 或 ≤ 0）時：沒收到錢＝未收，收到任何金額＝已收齊。
PaymentState paymentStateOf({double? amount, required double received}) {
  if (received <= 0) return PaymentState(PaymentStatus.unpaid, received);
  if (amount == null || amount <= 0 || received >= amount) {
    return PaymentState(PaymentStatus.paid, received);
  }
  return PaymentState(PaymentStatus.partial, received);
}

/// 尚欠金額（金額 − 已收，不會小於 0；沒填金額為 0）。
double outstandingOf({double? amount, required double received}) {
  if (amount == null || amount <= 0) return 0;
  final d = amount - received;
  return d > 0 ? d : 0;
}

/// 「已收齊」按鈕是否為實色：已收 ≥ 金額（金額要大於 0）。
bool isFullyReceived({double? amount, required double received}) =>
    amount != null && amount > 0 && received >= amount;
