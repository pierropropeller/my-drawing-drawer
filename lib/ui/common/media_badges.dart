import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'media_icons.dart';
import 'svg_icon.dart';
import 'media_source.dart';

/// 標記的半透明深色底（MediaBadges artboard：`rgba(43,38,34,.62)`，固定色，不隨主題）。
const Color mediaBadgeColor = Color(0x9E2B2622);

/// 設計稿的小圖形（非 24×24 viewBox 的實心三角形）：[svg] 是 `<path .../>`，`currentColor` 取 [color]。
class MediaGlyph extends StatelessWidget {
  const MediaGlyph(
    this.svg, {
    super.key,
    required this.width,
    required this.height,
    this.color = Colors.white,
  });

  final String svg;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" '
    'viewBox="0 0 $width $height">$svg</svg>',
    width: width,
    height: height,
    theme: SvgTheme(currentColor: color),
  );
}

/// 左下角「GIF」小標：高 20、左右內距 7、圓角 10、字 11px 粗 800、字距 .04em。
class MediaBadgeGif extends StatelessWidget {
  const MediaBadgeGif({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('badgeGif'),
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: mediaBadgeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      context.l10n.mediaBadgeGif,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.44,
        height: 1.1,
      ),
    ),
  );
}

/// 左下角「▶ 0:24」小標：小三角形＋長度（11.5px 粗 700，間距 4）。
class MediaBadgeVideo extends StatelessWidget {
  const MediaBadgeVideo({super.key, this.durationMs});

  /// 影片長度（毫秒）；探測不到（null）時只顯示三角形。
  final int? durationMs;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('badgeVideo'),
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: mediaBadgeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MediaGlyph(
          MediaIcons.playSmall,
          width: MediaIcons.playSmallWidth,
          height: MediaIcons.playSmallHeight,
        ),
        if (durationMs != null) ...[
          const SizedBox(width: 4),
          Text(
            formatMediaDuration(durationMs),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ],
    ),
  );
}

/// 右下角張數標記（多張的圖）：最小寬 20、高 20、內距 6、字 11.5px 粗 700。
class MediaCountBadge extends StatelessWidget {
  const MediaCountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('badgeCount'),
    constraints: const BoxConstraints(minWidth: 20),
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: mediaBadgeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
  );
}

/// 詳情頁影片未播放時中央的圓形播放鍵：60px、`rgba(43,38,34,.55)`、白色三角形 22×24。
class MediaPlayButton extends StatelessWidget {
  const MediaPlayButton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.mediaPlay,
    child: Container(
      key: const ValueKey('videoPlayButton'),
      width: 60,
      height: 60,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0x8C2B2622),
        shape: BoxShape.circle,
      ),
      child: const MediaGlyph(
        MediaIcons.playBig,
        width: MediaIcons.playBigWidth,
        height: MediaIcons.playBigHeight,
      ),
    ),
  );
}

/// 影片還沒有 poster（正在補、或補不出來）時的佔位：深色底＋小 ▶，一看就知道是影片
/// （不用米色的圖片佔位，避免被當成壞掉的圖）。顏色取自主題 token，不寫死。
class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({super.key});

  /// 深色底：亮色主題用 `ink`（深棕）、深色主題用比 `surface` 更深一點的色。
  static Color colorOf(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Color.lerp(t.surface, Colors.black, .45)! : t.ink;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('videoPlaceholder'),
    color: colorOf(context),
    child: Center(
      child: SvgIcon(
        MediaIcons.play,
        size: 26,
        fill: 'currentColor',
        strokeWidth: 0,
        color: Colors.white.withValues(alpha: .6),
      ),
    ),
  );
}
