import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 坑／主頁用到、共用 AppIcons 沒有的 icon（SVG 圖形取自設計稿）。
class PitsIcons {
  const PitsIcons._();

  /// 坑內頁最底的「雜物」入口 icon（PitJunk）。
  static const junk =
      '<rect x="3.5" y="9" width="17" height="11" rx="2"/>'
      '<path d="M6 9V6.5A1.5 1.5 0 0 1 7.5 5h9A1.5 1.5 0 0 1 18 6.5V9M10 13.5h4"/>';

  /// 推活（星星；坑內頁第六格，Pit）。
  static const oshi =
      '<path d="M12 3.5l2.6 5.3 5.8.8-4.2 4.1 1 5.8L12 16.8l-5.2 2.7 1-5.8-4.2-4.1 5.8-.8z"/>';
}

/// 推活格顏色（D-058）：淺色 `#ECE6F3`／`#6E5A92`，深色 `#312B3A`／`#B8A6D9`。
/// 暫時定義在這裡；統籌合併時可改用 tokens 的 `oshi`。
abstract final class PitsOshiColors {
  static CategoryColor of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const light = CategoryColor(Color(0xFFECE6F3), Color(0xFF6E5A92));
  static const dark = CategoryColor(Color(0xFF312B3A), Color(0xFFB8A6D9));
}
