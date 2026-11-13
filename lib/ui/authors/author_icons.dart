/// 作者系統用的 icon（SVG 圖形取自 Author* 設計稿）。
/// 返回、加號、關閉、勾、刪除、搜尋、右箭頭沿用共用的 AppIcons（圖形完全相同）。
abstract final class AuthorIcons {
  /// 「我的」作者卡、沒頭像時的佔位（人＋筆，線寬 1.7）。
  static const author =
      '<circle cx="10" cy="8" r="3.6"/>'
      '<path d="M3.5 19.5c0-3.6 3-5.4 6.5-5.4 1.2 0 2.3.2 3.2.6" stroke-linecap="round"/>'
      '<path d="M14.5 20.5l.6-2.4 4.6-4.6a1.3 1.3 0 0 1 1.8 1.8l-4.6 4.6z" stroke-linejoin="round"/>';

  /// 版面切換：列表（線寬 1.8）。
  static const layoutList =
      '<circle cx="6" cy="7" r="2"/><circle cx="6" cy="17" r="2"/>'
      '<path d="M10.5 6h3M10.5 8.5h2M10.5 16h3M10.5 18.5h2" stroke-linecap="round"/>'
      '<rect x="16" y="5" width="4" height="4" rx="1"/><rect x="16" y="15" width="4" height="4" rx="1"/>';

  /// 版面切換：格子（線寬 1.7）。
  static const layoutGrid =
      '<circle cx="6" cy="6.5" r="2.3"/><circle cx="18" cy="6.5" r="2.3"/>'
      '<circle cx="6" cy="16" r="2.3"/><circle cx="18" cy="16" r="2.3"/>'
      '<path d="M4 20.5h4M16 20.5h4M4 11h4M16 11h4" stroke-linecap="round"/>';

  /// 主坑小標（資料夾，線寬 1.9）。
  static const pit =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke-linejoin="round"/>';

  /// 編輯排序（↑↓，線寬 1.9）。
  static const sort =
      '<path d="M7 4v16M3.5 7.5L7 4l3.5 3.5M17 20V4M13.5 16.5L17 20l3.5-3.5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 拖曳把手（線寬 2）。
  static const handle = '<path d="M5 9h14M5 15h14" stroke-linecap="round"/>';

  /// 編輯（筆，線寬 1.8）。
  static const edit =
      '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z" stroke-linejoin="round"/>';

  /// 相機（換頭像角標，線寬 2）。
  static const camera =
      '<path d="M4 8.5A1.5 1.5 0 0 1 5.5 7h2l1.5-2h6l1.5 2h2A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z" stroke-linejoin="round"/>'
      '<circle cx="12" cy="12.5" r="3.2"/>';

  /// 圖片佔位（封面、縮圖，線寬 1.5）。
  static const image =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.8"/>'
      '<path d="M3.5 16.5l4.5-4 4 3 3-2.5 5.5 4.5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 更新（兩個箭頭的圓，線寬 1.9）。
  static const refresh =
      '<path d="M19.5 8.5A8 8 0 0 0 5 7.5M4.5 15.5A8 8 0 0 0 19 16.5" stroke-linecap="round"/>'
      '<path d="M19.8 3.8v4.9h-4.9M4.2 20.2v-4.9h4.9" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 改用這個同步（左右箭頭，線寬 1.9）。
  static const swap =
      '<path d="M7 4L4 7l3 3M4 7h13M17 20l3-3-3-3M20 17H7" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 舊→新（更新確認，線寬 2）。
  static const arrowRight =
      '<path d="M5 12h13M13 6l6 6-6 6" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 搜尋（選擇作者 sheet，線寬 1.9）。
  static const search =
      '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4" stroke-linecap="round"/>';

  /// 連結成功的勾（線寬 2）。
  static const linked =
      '<path d="M5 12.5l4.5 4.5L19 7.5" stroke-linecap="round" stroke-linejoin="round"/>';
}
