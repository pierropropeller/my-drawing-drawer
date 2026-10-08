import '../../data/database.dart';
import '../../data/goal_queries.dart';
import '../../l10n/l10n.dart';

/// 依種類／數量／互動量門檻自動命名（ARB 整句）。
String goalAutoNameText(
  AppLocalizations l,
  GoalKind kind,
  int count,
  int? requireLikes,
) => switch (kind) {
  GoalKind.idea => l.goalsAutoNameIdea(count),
  GoalKind.draft => l.goalsAutoNameDraft(count),
  GoalKind.piece =>
    requireLikes != null
        ? l.goalsAutoNamePieceLikes(requireLikes, count)
        : l.goalsAutoNamePiece(count),
};

/// 目標顯示名稱：有自訂名稱用自訂，否則自動命名。
String goalDisplayName(AppLocalizations l, Goal g) =>
    goalCustomName(g) ?? goalAutoNameText(l, g.kind, g.count, g.requireLikes);
