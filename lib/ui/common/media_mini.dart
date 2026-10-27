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
    this.sensitiveBadge = true,
    this.bigBadge = false,
  });

  /// 76px 縮圖（推活／日頁時間軸，D-126）：小標用 20px（影片＝圓形＋三角、不顯示時長；GIF 10.5px 字）。
  final bool bigBadge;

  /// 見 [MediaThumb.sensitiveCircle]。
  final double? sensitiveCircle;

  /// 見 [MediaThumb.sensitiveBadge]。
  final bool sensitiveBadge;

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
      sensitiveBadge: sensitiveBadge,
    );
    final Widget? badge = bigBadge
        ? _bigBadge(context)
        : media.isGif
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

  Widget? _bigBadge(BuildContext context) {
    if (media.isGif) {
      return Container(
        key: const ValueKey('miniBadgeGif'),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: mediaBadgeColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          context.l10n.mediaBadgeGif,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.42,
            height: 1.1,
          ),
        ),
      );
    }
    if (media.isVideo) {
      return Container(
        key: const ValueKey('miniBadgeVideo'),
        width: 20,
        height: 20,
        padding: const EdgeInsets.only(left: 2),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: mediaBadgeColor,
          shape: BoxShape.circle,
        ),
        child: const MediaGlyph(MediaIcons.playSmall, width: 8, height: 9),
      );
    }
    return null;
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
