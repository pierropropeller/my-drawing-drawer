/// 我的／登入／同步頁用的 icon（設計稿 inline SVG 圖形，24×24）。
abstract final class MeIcons {
  /// 立即同步（兩個循環箭頭）。Backup
  static const refresh =
      '<path d="M20 12a8 8 0 0 1-14 5.3M4 12a8 8 0 0 1 14-5.3"/><path d="M18 3v4h-4M6 21v-4h4"/>';

  /// 雲＋向下箭頭（首次同步中）。SyncFirst
  static const cloudDownload =
      '<path d="M7 18h10a3 3 0 0 0 .4-6 5 5 0 0 0-9.7-1.5A3.6 3.6 0 0 0 7 18z"/><path d="M12 10v6M9.5 13.5L12 16l2.5-2.5"/>';

  /// 相機（編輯個人資料：更換頭像）。ProfileEdit
  static const camera =
      '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.2"/>';

  /// App 圖示（抽屜）。About
  static const appDrawer =
      '<rect x="3.5" y="9" width="17" height="11" rx="2"/><path d="M6 9V6.5A1.5 1.5 0 0 1 7.5 5h9A1.5 1.5 0 0 1 18 6.5V9M10 13.5h4"/>';
}
