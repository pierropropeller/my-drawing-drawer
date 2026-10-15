/// 推活區塊用到、`AppIcons` 沒有的 icon（路徑抄自設計稿 OshiTimeline／OshiGrid／OshiNew／OshiDetail／Pit，24×24）。
abstract final class OshiIcons {
  /// 推活（Pit 第六格、空白頁）：星星。
  static const star =
      '<path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>';

  /// 佈局切換：時間軸（OshiTimeline 標題列）。
  static const layoutTimeline =
      '<path d="M7 4v16"/><circle cx="7" cy="8" r="1.8" fill="currentColor" stroke="none"/>'
      '<circle cx="7" cy="16" r="1.8" fill="currentColor" stroke="none"/><path d="M11 8h9M11 16h9"/>';

  /// 佈局切換：九宮格（OshiGrid 標題列，3×3，線寬 1.7；同草稿的九宮格 icon）。
  static const layoutGrid =
      '<rect x="3.5" y="3.5" width="5" height="5" rx="1"/><rect x="9.5" y="3.5" width="5" height="5" rx="1"/>'
      '<rect x="15.5" y="3.5" width="5" height="5" rx="1"/><rect x="3.5" y="9.5" width="5" height="5" rx="1"/>'
      '<rect x="9.5" y="9.5" width="5" height="5" rx="1"/><rect x="15.5" y="9.5" width="5" height="5" rx="1"/>'
      '<rect x="3.5" y="15.5" width="5" height="5" rx="1"/><rect x="9.5" y="15.5" width="5" height="5" rx="1"/>'
      '<rect x="15.5" y="15.5" width="5" height="5" rx="1"/>';

  /// 日期欄右側的日曆（OshiNew）。
  static const calendar =
      '<rect x="3.5" y="5" width="17" height="16" rx="2.5"/><path d="M3.5 9.5h17M8 3.5v3M16 3.5v3"/>';

  /// 詳情頁分組 chip 的資料夾（OshiDetail）。
  static const folder =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>';
}
