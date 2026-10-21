/// 檔案大小的顯示（D-101）：二進位換算（1 GB＝1024³ 位元組，與 Google 儲存空間一致），
/// 數值四捨五入到小數一位、整數不帶 `.0`：`8.3 GB`、`15 GB`、`512 KB`、`0 B`。
/// 單位符號（B、KB、MB、GB、TB）是通用符號，不是介面文字。
String formatByteSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes < 0 ? 0.0 : bytes.toDouble();
  var i = 0;
  // 四捨五入後會進位成 1024 的（例如 1023.97 KB）直接升一級。
  while (i < units.length - 1 && (v >= 1024 || _round1(v) >= 1024)) {
    v /= 1024;
    i++;
  }
  // 位元組不帶小數。
  final r = i == 0 ? v.roundToDouble() : _round1(v);
  final text = r == r.truncateToDouble()
      ? r.toInt().toString()
      : r.toStringAsFixed(1);
  return '$text ${units[i]}';
}

double _round1(double v) => (v * 10).round() / 10;
