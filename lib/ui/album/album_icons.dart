/// 圖冊／雜物區塊用到、`AppIcons` 沒有的 icon（路徑抄自設計稿，24×24）。
abstract final class AlbumIcons {
  /// 移動：資料夾＋向右箭頭（OfficialSelect、JunkSelect 的底部「移動」）。
  static const moveFolder =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>'
      '<path d="M10 13h6M13.5 10.5L16 13l-2.5 2.5"/>';

  /// 雜物（PitJunk 入口）。
  static const junk =
      '<rect x="3.5" y="9" width="17" height="11" rx="2"/>'
      '<path d="M6 9V6.5A1.5 1.5 0 0 1 7.5 5h9A1.5 1.5 0 0 1 18 6.5V9M10 13.5h4"/>';

  /// tag（OfficialSelect、FanArtTagSheet 底部「tag」，線寬 1.7）。
  static const tag =
      '<path d="M4 12V5a1 1 0 0 1 1-1h7l8 8-8 8z"/>'
      '<circle cx="8.5" cy="8.5" r="1.5"/>';

  /// 批次 tag sheet「部分有」狀態的橫線。
  static const dash = '<path d="M7 12h10"/>';
}
