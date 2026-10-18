/// 影片／GIF 相關 icon（D-080），路徑抄自 MediaBadges artboard。
///
/// 24×24 的用 `SvgIcon`；兩個小三角形的 viewBox 不是 24，用 `media_widgets.dart` 裡的 `MediaPlayGlyph`。
abstract final class MediaIcons {
  /// 暫停（實心，兩根直條；用 `fill: 'currentColor'`、`strokeWidth: 0`）。
  static const pause =
      '<rect x="6" y="5" width="4" height="14" rx="1"/>'
      '<rect x="14" y="5" width="4" height="14" rx="1"/>';

  /// 播放（實心三角形；設計稿的控制列只畫了暫停，播放鍵沿用同一組尺寸與位置）。
  static const play = '<path d="M7 4.5l12 7.5-12 7.5z"/>';

  /// 喇叭＋聲波（有聲）。
  static const volume =
      '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" stroke-linejoin="round"/>'
      '<path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a7.5 7.5 0 0 1 0 11" stroke-linecap="round"/>';

  /// 靜音：同一個喇叭，聲波換成一個叉（設計稿沒畫靜音狀態，自行判斷）。
  static const volumeOff =
      '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" stroke-linejoin="round"/>'
      '<path d="M16.5 9.5l5 5M21.5 9.5l-5 5" stroke-linecap="round"/>';

  /// 全螢幕（四角向外）。
  static const fullscreen =
      '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 結束全螢幕（四角向內；設計稿沒畫，自行判斷）。
  static const exitFullscreen =
      '<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 循環播放（兩條首尾相接的箭頭；線條風格與其他控制列 icon 一致，設計稿沒畫，自行判斷）。
  static const loop =
      '<path d="M17 2l4 4-4 4M3 11V10a4 4 0 0 1 4-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 0 1-4 4H3" stroke-linecap="round" stroke-linejoin="round"/>';

  /// 列表左下角標記裡的小三角形，viewBox 9×10。
  static const playSmall = '<path d="M1 1l7 4-7 4z" fill="currentColor"/>';
  static const playSmallWidth = 9.0;
  static const playSmallHeight = 10.0;

  /// 詳情頁中央大播放鍵裡的三角形，viewBox 22×24。
  static const playBig = '<path d="M3 2l17 10L3 22z" fill="currentColor"/>';
  static const playBigWidth = 22.0;
  static const playBigHeight = 24.0;
}
