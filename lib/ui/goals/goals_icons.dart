/// 目標區塊專用 icon（直接抄 artboard 的 inline SVG 圖形，24×24）。
abstract final class GoalsIcons {
  /// 商稿收入卡（GoalYear 的「商稿收入」）。
  static const wallet =
      '<rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M7 15h3"/>';

  /// 紅色提示條的驚嘆圓（IncomeYear 未收齊）。
  static const alert =
      '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5M12 16h.01"/>';

  /// 腦洞（DayAddSheet）。
  static const sheetIdea =
      '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2H9c0-.8-.3-1.3-1-2A6 6 0 0 1 12 3z"/>';

  /// 草稿（DayAddSheet）。
  static const sheetDraft =
      '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z"/><path d="M13.5 7.5l3 3"/>';

  /// 成圖（DayAddSheet）。
  static const sheetPiece =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.8"/><path d="M3.5 16.5l4.5-4 4 3 3-2.5 5.5 4.5"/>';
}
