import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';

import '../../data/media.dart';

/// 只留年月日。
DateTime oshiDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 解析 EXIF 的拍攝時間字串（`2026:10:05 14:03:22`，也容許 `-`、`/` 分隔與尾端的空字元）。
/// 格式不對、年份不合理（例如全 0 的未設定值）回傳 null。
DateTime? parseExifDateTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
    r'^\s*(\d{4})[:\-/](\d{2})[:\-/](\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?',
  ).firstMatch(raw);
  if (m == null) return null;
  final y = int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (y < 1900 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(
    y,
    mo,
    d,
    int.tryParse(m[4] ?? '') ?? 0,
    int.tryParse(m[5] ?? '') ?? 0,
    int.tryParse(m[6] ?? '') ?? 0,
  );
}

/// 讀圖片的 EXIF `DateTimeOriginal`；沒有或讀不出來回傳 null。
Future<DateTime?> exifDateTimeOriginal(Uint8List bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    return parseExifDateTime(tags['EXIF DateTimeOriginal']?.printable);
  } catch (_) {
    return null;
  }
}

/// 推活預設日期的決定順序（HANDOFF 3.11）：EXIF 拍攝時間 → 檔案修改時間 → 今天。只取年月日。
DateTime pickOshiDate({DateTime? exif, DateTime? modified, DateTime? now}) =>
    oshiDateOnly(exif ?? modified ?? now ?? DateTime.now());

/// 依第一張圖的檔案猜日期；讀不到任何資訊就用 [now]（預設今天）。
Future<DateTime> guessOshiDate(String path, {DateTime? now}) async {
  DateTime? exifAt;
  DateTime? modified;
  try {
    final f = File(path);
    // 影片（D-080）不讀進記憶體找 EXIF，直接用檔案修改時間。
    if (mediaKindFromExtension(path) != MediaKind.video) {
      exifAt = await exifDateTimeOriginal(await f.readAsBytes());
    }
    if (exifAt == null) modified = await f.lastModified();
  } catch (_) {
    // 檔案讀不到：用今天。
  }
  return pickOshiDate(exif: exifAt, modified: modified, now: now);
}
