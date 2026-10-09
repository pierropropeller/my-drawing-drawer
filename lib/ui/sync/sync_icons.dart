/// 同步進度用到的 icon（SVG 圖形取自設計稿 MainSyncing／SyncSheet）。
class SyncIcons {
  const SyncIcons._();

  /// 未下載角標中央的下載箭頭（MainSyncing，14px、線寬 2.4）。
  static const badgeDownload = '<path d="M12 5v11M7.5 11.5L12 16l4.5-4.5"/>';

  /// sheet 列的「上傳」標籤 icon（SyncSheet，線寬 2.2）。
  static const upload = '<path d="M12 19V8M7.5 12.5L12 8l4.5 4.5M6 5h12"/>';

  /// sheet 列的「下載」標籤 icon（SyncSheet，線寬 2.2）。
  static const download = '<path d="M12 5v11M7.5 11.5L12 16l4.5-4.5M6 19h12"/>';
}
