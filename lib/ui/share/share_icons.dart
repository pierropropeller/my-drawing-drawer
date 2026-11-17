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

  /// 推活（星形，線寬 1.8）。
  static const star =
      '<path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>';

  /// 「開新坑」chip 的加號（線寬 2）。
  static const plus = '<path d="M12 5v14M5 12h14"/>';

  /// 分享推文（TweetShare*）：縮圖的移除 ✕（線寬 3）。
  static const close = '<path d="M6 6l12 12M18 6L6 18"/>';

  /// 讀取推文中的轉圈（3/4 圓弧，線寬 2.2）。
  static const spinner = '<path d="M12 3a9 9 0 1 1-9 9"/>';

  /// 讀不到推文（驚嘆號圓圈，線寬 1.8）。
  static const warn =
      '<circle cx="12" cy="12" r="9"/>'
      '<path d="M12 7.5v5.5M12 16.5v.01"/>';
}
