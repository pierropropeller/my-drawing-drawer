/// 商稿金額的顯示：符號＋空格＋千分位（「¥ 12,800」「HK$ 3,600」），不做匯率換算。
const _symbols = {
  'CNY': '¥',
  'HKD': 'HK\$',
  'TWD': 'NT\$',
  'USD': 'US\$',
  'JPY': 'JP¥',
  'EUR': '€',
  'GBP': '£',
  'KRW': '₩',
  'SGD': 'S\$',
};

const _names = {
  'CNY': '人民幣',
  'HKD': '港幣',
  'TWD': '新台幣',
  'USD': '美元',
  'JPY': '日圓',
  'EUR': '歐元',
  'GBP': '英鎊',
  'KRW': '韓元',
  'SGD': '新加坡幣',
};

/// 幣種符號；沒有對應符號的直接用代碼。
String currencySymbol(String code) => _symbols[code] ?? code;

/// 幣種中文名（IncomeYear 卡片上方小字）；沒有對應時用代碼。
String currencyName(String code) => _names[code] ?? code;

/// 千分位數字；有小數才顯示（最多兩位）。
String groupedNumber(double v) {
  final negative = v < 0;
  final abs = v.abs();
  var s = abs == abs.roundToDouble()
      ? abs.toStringAsFixed(0)
      : abs.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  final dot = s.indexOf('.');
  final intPart = dot < 0 ? s : s.substring(0, dot);
  final frac = dot < 0 ? '' : s.substring(dot);
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  s = '$buf$frac';
  return negative ? '-$s' : s;
}

String formatMoney(String currency, double amount) =>
    '${currencySymbol(currency)} ${groupedNumber(amount)}';
