import '../l10n/l10n.dart';

/// 同步完成時間的相對寫法（D-109 ②）：1 分鐘內「剛剛」、1 小時內「N 分鐘前」，
/// 之後同一天「今天 22:15」、其他日子「10/22 22:15」。
///
/// [now] 比 [at] 早（時鐘被調整）也算「剛剛」。
String syncRelativeTime(DateTime at, DateTime now) {
  final l = l10nStatic;
  final diff = now.difference(at);
  if (diff < const Duration(minutes: 1)) return l.syncuiDoneJustNow;
  if (diff < const Duration(hours: 1)) {
    return l.syncuiTimeMinutesAgo(diff.inMinutes);
  }
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(at.hour)}:${two(at.minute)}';
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return sameDay ? l.meTimeToday(hm) : l.meTimeDate(at.month, at.day, hm);
}

/// 距離 [syncRelativeTime] 的文字下一次會改變還要多久；之後不會再變（滿 1 小時）回傳 null。
Duration? syncRelativeTimeNextChange(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff >= const Duration(hours: 1)) return null;
  if (diff.isNegative) return const Duration(minutes: 1);
  final into = diff.inMicroseconds % Duration.microsecondsPerMinute;
  return Duration(microseconds: Duration.microsecondsPerMinute - into);
}
