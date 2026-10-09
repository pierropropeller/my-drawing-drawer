/// 分享進來的「加入到」sheet 用的 icon（SVG 圖形取自 ShareImport 設計稿）。
abstract final class ShareIcons {
  /// 位置格：官方圖冊／好看同人圖／雜物（資料夾，線寬 1.8）。
  static const folder =
      '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>';

  /// 腦洞（燈泡，線寬 1.7）。
  static const bulb =
      '<path d="M9 18h6M10 21h4"/>'
      '<path d="M12 3a6 6 0 0 1 4 10.5c-.7.7-1 1.2-1 2H9c0-.8-.3-1.3-1-2A6 6 0 0 1 12 3z"/>';

  /// 草稿（鉛筆，線寬 1.7）。
  static const pen =
      '<path d="M4 20l1-4L15.5 5.5a2.1 2.1 0 0 1 3 3L8 19z"/>'
      '<path d="M13.5 7.5l3 3"/>';

  /// 成圖（圖片，線寬 1.7）。
  static const img =
      '<rect x="3" y="4" width="18" height="16" rx="2.5"/>'
      '<circle cx="8.5" cy="9.5" r="1.8"/>'
      '<path d="M3.5 16.5l4.5-4 4 3 3-2.5 5.5 4.5"/>';

  /// 「開新坑」chip 的加號（線寬 2）。
  static const plus = '<path d="M12 5v14M5 12h14"/>';
}
