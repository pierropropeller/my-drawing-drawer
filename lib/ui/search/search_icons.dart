/// 坑內搜尋用到、`AppIcons` 沒有的 icon（路徑抄自設計稿，24×24）。
abstract final class SearchIcons {
  /// 搜尋（放大鏡）：FanArtList／IdeaList／Finished 右上、PitSearch 輸入框、Main 右上的搜尋鍵。
  static const search =
      '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/>';

  /// 未加 tag（tag 加斜線）：PitSearch 的「未加 tag」卡片（線寬 1.7）。
  static const untagged =
      '<path d="M4 12V5a1 1 0 0 1 1-1h7l8 8-8 8z"/>'
      '<circle cx="8.5" cy="8.5" r="1.5"/><path d="M3 21L21 3"/>';
}
