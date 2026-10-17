/// 加圖來源選單（MediaMenu）與拖放提示的 icon，圖形抄自 MediaMenu／MediaDrop／NewOfficial artboard（24×24）。
abstract final class MediaSourceIcons {
  /// 從「照片」選取。
  static const photos =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.8"/><path d="M3.5 16.5l4.5-4 4 3 3-2.5 5.5 4.5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 從「檔案」選取（資料夾）。
  static const files =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke-linejoin="round"/>';

  /// 從素材庫選取。
  static const materials =
      '<rect x="3" y="7" width="14" height="13" rx="2.5"/><path d="M7 4h11.5A2.5 2.5 0 0 1 21 6.5V16" stroke-linecap="round"/>';

  /// 拍照。
  static const camera =
      '<path d="M4 8h3l2-3h6l2 3h3v11H4z" stroke-linejoin="round"/><circle cx="12" cy="13" r="3.5"/>';

  /// 貼上（剪貼簿）。
  static const paste =
      '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4V3h6v1" stroke-linecap="round"/>';

  /// 拖放提示：向下的箭頭落到底線。
  static const dropArrow =
      '<path d="M12 4v11M7.5 10.5L12 15l4.5-4.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M5 19h14" stroke-linecap="round"/>';
}
