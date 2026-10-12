/// 素材庫用的 icon（SVG 圖形取自 MaterialList／MaterialGrid／Profile 設計稿）。
/// 返回、加號、關閉、勾、分享、下載、移動、刪除、圖片佔位沿用共用的 AppIcons／AlbumIcons（圖形完全相同）。
abstract final class MaterialLibIcons {
  /// 版面切換：瀑布（線寬 1.8）。
  static const layoutWaterfall =
      '<rect x="4" y="4" width="7" height="9" rx="1.5"/>'
      '<rect x="4" y="15" width="7" height="5" rx="1.5"/>'
      '<rect x="13" y="4" width="7" height="5" rx="1.5"/>'
      '<rect x="13" y="11" width="7" height="9" rx="1.5"/>';

  /// 版面切換：九宮格（線寬 1.8）。
  static const layoutGrid =
      '<rect x="4" y="4" width="7" height="7" rx="1.5"/>'
      '<rect x="13" y="4" width="7" height="7" rx="1.5"/>'
      '<rect x="4" y="13" width="7" height="7" rx="1.5"/>'
      '<rect x="13" y="13" width="7" height="7" rx="1.5"/>';

  /// 「我的」的素材庫卡（相簿，線寬 1.7）。
  static const library =
      '<rect x="3" y="7" width="14" height="13" rx="2.5"/>'
      '<path d="M7 4h11.5A2.5 2.5 0 0 1 21 6.5V16"/>'
      '<circle cx="8" cy="11.5" r="1.5"/>'
      '<path d="M3.5 17.5l4-3.5 3 2.5 2.5-2 3.5 3"/>';
}
