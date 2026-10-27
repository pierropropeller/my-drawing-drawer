import '../../data/database.dart' show GoalKind;
import '../../l10n/app_localizations.dart';
import 'entity_widgets.dart' show fmtMd;

/// 腦洞／摸魚／成圖沒有標題時，在需要「名稱」的地方（關聯 chip、選擇關聯的 sheet、最近刪除的文字格、
/// 搜尋結果等）的顯示文字（D-129）：標題 → 內文前 12 字 → 日期＋類型（例如「9/10 成圖」）。
String entityDisplayName(
  AppLocalizations l, {
  String? title,
  String? body,
  required DateTime date,
  required GoalKind kind,
}) {
  final t = title?.trim() ?? '';
  if (t.isNotEmpty) return t;
  final b = (body ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (b.isNotEmpty) return String.fromCharCodes(b.runes.take(12));
  final label = switch (kind) {
    GoalKind.idea => l.goalsKindIdea,
    GoalKind.draft => l.goalsKindDraft,
    GoalKind.piece => l.goalsKindPiece,
  };
  return l.entityUntitledName(fmtMd(date), label);
}
