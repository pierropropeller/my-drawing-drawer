/// 素材庫用的 icon（SVG 圖形取自 MaterialList／MaterialGrid／Profile 設計稿）。
/// 返回、加號、關閉、勾、分享、下載、移動、刪除、圖片佔位沿用共用的 AppIcons／AlbumIcons（圖形完全相同）。
abstract final class MaterialLibIcons {
  /// 版面切換：瀑布（線寬 1.8）。
  static const layoutWaterfall =
      '<rect x="4" y="4" width="7" height="9" rx="1.5"/>'
      '<rect x="4" y="15" width="7" height="5" rx="1.5"/>'
      '<rect x="13" y="4" width="7" height="5" rx="1.5"/>'
      '<rect x="13" y="11" width="7" height="9" rx="1.5"/>';

  /// 版面切換：九宮格（3×3，同草稿的九宮格 icon，D-078）。
  static const layoutGrid =
      '<rect x="3.5" y="3.5" width="5" height="5" rx="1"/><rect x="9.5" y="3.5" width="5" height="5" rx="1"/>'
      '<rect x="15.5" y="3.5" width="5" height="5" rx="1"/><rect x="3.5" y="9.5" width="5" height="5" rx="1"/>'
      '<rect x="9.5" y="9.5" width="5" height="5" rx="1"/><rect x="15.5" y="9.5" width="5" height="5" rx="1"/>'
      '<rect x="3.5" y="15.5" width="5" height="5" rx="1"/><rect x="9.5" y="15.5" width="5" height="5" rx="1"/>'
      '<rect x="15.5" y="15.5" width="5" height="5" rx="1"/>';

  /// 「我的」的素材庫卡（相簿，線寬 1.7）。
  static const library =
      '<rect x="3" y="7" width="14" height="13" rx="2.5"/>'
      '<path d="M7 4h11.5A2.5 2.5 0 0 1 21 6.5V16"/>'
      '<circle cx="8" cy="11.5" r="1.5"/>'
      '<path d="M3.5 17.5l4-3.5 3 2.5 2.5-2 3.5 3"/>';

  /// 燈泡：來自靈感廣場（RefList 縮圖角標、RefPreview 小標，線寬 2）。
  static const bulb =
      '<path d="M9 18h6M10 21h4" stroke-linecap="round"/>'
      '<path d="M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2H9c0-.8-.3-1.3-1-2A6 6 0 0 1 12 3z" stroke-linejoin="round"/>';

  /// 素材庫（抽屜；我的頁入口、坑裡參考圖的角標，D-148）。
  static const drawer =
      '<rect x="4" y="4" width="16" height="16" rx="2.5"/>'
      '<path d="M4 12h16M10 8h4M10 16h4" stroke-linecap="round"/>';

  /// 說明（三條橫線；預覽的「說明」小標，線寬 2）。
  static const note =
      '<path d="M5 6h14M5 12h14M5 18h9" stroke-linecap="round"/>';

  /// 放進坑（資料夾＋加號；InspoPreview、InspoSelect，線寬 1.7）。
  static const placeInPit =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke-linejoin="round"/>'
      '<path d="M12 10v6M9 13h6" stroke-linecap="round"/>';

  /// 移出（資料夾＋減號；RefPreview 從廣場放進來的圖，線寬 1.7）。
  static const unplace =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" stroke-linejoin="round"/>'
      '<path d="M9.5 13h5" stroke-linecap="round"/>';
}
