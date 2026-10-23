import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'media_icons.dart';
import 'media_widgets.dart';

/// 小縮圖（約 40～80px：腦洞卡、草稿小圖版、關聯縮圖、表單縮圖）用的媒體格子（D-080）。
///
/// 設計稿只畫了九宮格以上尺寸的標記（20px 高、影片帶長度），放進 54px 的格子會蓋掉半張圖；
/// 這裡縮小成 15px 高：GIF＝「GIF」字樣、影片＝只有三角形（不帶長度）。位置仍是左下角，
/// 張數（[count]）仍在右下角。自行判斷，回報時註明。
class MiniMediaThumb extends StatelessWidget {
  const MiniMediaThumb(
    this.media, {
    super.key,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.count = 1,
    this.inset = 3,
    this.animate = true,
    this.placeholderColor,
    this.protectSensitive = true,
    this.sensitiveCircle,
  });

  /// 見 [MediaThumb.sensitiveCircle]。
  final double? sensitiveCircle;

  /// 見 [MediaThumb.protectSensitive]（詳情頁縮圖列同列表，依安全模式處理）。
  final bool protectSensitive;

  final MediaSource media;
  final int? cacheWidth;
  final BoxFit fit;
  final int count;
  final double inset;
  final bool animate;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final content = MediaThumb(
      media,
      cacheWidth: cacheWidth,
      fit: fit,
      animate: animate,
      showBadge: false,
      placeholderColor: placeholderColor,
      protectSensitive: protectSensitive,
      sensitiveCircle: sensitiveCircle,
    );
    final Widget? badge = media.isGif
        ? _pill(
            Text(
              context.l10n.mediaBadgeGif,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                height: 1.1,
              ),
            ),
            const ValueKey('miniBadgeGif'),
          )
        : media.isVideo
        ? _pill(
            const MediaGlyph(
              MediaIcons.playSmall,
              width: MediaIcons.playSmallWidth,
              height: MediaIcons.playSmallHeight,
            ),
            const ValueKey('miniBadgeVideo'),
          )
        : null;
    if (badge == null && count <= 1) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        content,
        if (badge != null)
          Positioned(
            left: inset,
            bottom: inset,
            child: IgnorePointer(child: badge),
          ),
        if (count > 1)
          Positioned(
            right: inset,
            bottom: inset,
            child: IgnorePointer(child: MediaCountBadge(count)),
          ),
      ],
    );
  }

  Widget _pill(Widget child, Key key) => Container(
    key: key,
    height: 15,
    constraints: const BoxConstraints(minWidth: 15),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: mediaBadgeColor,
      borderRadius: BorderRadius.circular(7.5),
    ),
    child: child,
  );
}
