// 影片與 GIF 的共用元件（D-080，artboard：MediaBadges）。
//
// ═══ 給「把這些元件套到各列表」的人：怎麼用 ═══
//
// 1. 先把資料轉成 [MediaSource]（任何一種都行）：
//      MediaSource.fromImageRef(ref)            // 腦洞／草稿／成圖／推活的 ImageRef
//      MediaSource.fromNewImage(newImage)       // 表單裡剛匯入的 NewImage
//      MediaSource.row(file: r.imageFile, kind: r.kind,
//                      durationMs: r.durationMs, posterFile: r.posterFile)   // 官方圖／同人圖／雜物／素材庫的資料列
//      albumImage.media                          // AlbumImage（建構時要帶 mediaKind／durationMs／posterFile）
//
// 2. 列表／九宮格／瀑布的格子內容（取代 StoredImage(file, cacheWidth: …)）：
//      MediaThumb(media, cacheWidth: 400, count: images.length)
//    - 圖片：和 StoredImage 一樣。
//    - GIF：自動循環播放（只在畫面上時播，捲出去換回靜態第一格；本來就不發聲）；左下角「GIF」小標。
//    - 影片：顯示 poster 靜態圖，**永不自動播放**；左下角「▶ 0:24」小標。沒有 poster（還沒產生）時是佔位 icon。
//    - [count] > 1：右下角張數標記。
//    左下角（媒體標記）與右下角（張數）是同一個 Stack 裡的兩個 Positioned，離邊都是 [badgeInset]
//    （九宮格 5、瀑布 7、詳情頁 12，照設計稿）。已經自己畫了張數標記的格子傳 `count: 1`，只用媒體標記。
//    不想要自動播放（多選畫面、表單縮圖）傳 `animate: false`；要完全不要標記傳 `showBadge: false`。
//
// 3. 需要「一張靜態圖」的地方（坑封面、年度回顧、月曆格、分享卡縮圖）：
//      StaticMediaImage(media, cacheWidth: 300)        // GIF＝第一格，影片＝poster，無標記
//    或直接用 `StoredImage(media.staticFile!, …)`——StoredImage 對 .gif 預設就只畫第一格。
//    資料層的 `staticFile`（ImageRef／CoverCandidate／TimelineItem 等）已經替影片換成 poster。
//
// 4. 詳情頁／全螢幕預覽的一頁：
//      MediaViewer(media, active: i == currentIndex, zoomable: true)
//    GIF 直接循環播放（不顯示標記）；影片見 [VideoPlayerView]。換頁時把 [active] 設為 false 會自動暫停。
//
// 5. 匯入請一律用 `importPickedMedia(store, xfile)`（lib/media/media_import.dart），
//    不要直接 `store.import`，否則影片沒有寬高／長度／poster。
//
// 這個檔案同時 export 底下的元件，列表那邊只需要 `import '../common/media_widgets.dart'`。

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'app_icons.dart';
import 'dismissible_preview.dart';
import 'media_badges.dart';
import 'media_source.dart';
import 'poster_requester.dart';
import 'sensitive_gate.dart';
import 'svg_icon.dart';
import 'video_player_view.dart';

export 'gif_image.dart' show FirstFrameImage, GifImage, OnScreen;
export 'media_badges.dart';
export 'media_source.dart';
export 'video_player_view.dart';

/// 沒有靜態圖可以顯示時的佔位（影片還沒有 poster、或檔案壞掉）：底色＋圖片 icon。
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: color ?? t.chipBg,
      child: Center(
        child: SvgIcon(
          AppIcons.image,
          size: 22,
          strokeWidth: 1.5,
          color: dark
              ? Colors.white.withValues(alpha: .22)
              : t.ink.withValues(alpha: .22),
        ),
      ),
    );
  }
}

/// 靜態圖：圖片＝圖片本身、GIF＝第一格、影片＝poster（沒有 poster＝[MediaPlaceholder]）。沒有任何標記。
class StaticMediaImage extends StatelessWidget {
  const StaticMediaImage(
    this.media, {
    super.key,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  final MediaSource media;
  final int? cacheWidth;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      // 影片沒有 poster 時請背景補，補好會自己換上（見 [LivePoster]）。
      return LivePoster(
        file: media.file,
        poster: media.poster,
        builder: (context, poster) => poster == null || poster.isEmpty
            ? const VideoPlaceholder()
            : StoredImage(
                poster,
                cacheWidth: cacheWidth,
                fit: fit,
                placeholderColor: placeholderColor,
              ),
      );
    }
    final f = media.staticFile;
    if (f == null) return MediaPlaceholder(color: placeholderColor);
    return StoredImage(
      f,
      cacheWidth: cacheWidth,
      fit: fit,
      placeholderColor: placeholderColor,
      isGif: media.isGif ? true : null,
    );
  }
}

/// 列表格子內容（見檔頭說明）：內容＋左下角媒體標記＋右下角張數標記。
class MediaThumb extends StatelessWidget {
  const MediaThumb(
    this.media, {
    super.key,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.count = 1,
    this.badgeInset = 5,
    this.animate = true,
    this.showBadge = true,
    this.placeholderColor,
    this.protectSensitive = true,
    this.sensitiveCircle,
    this.sensitiveBadge = true,
  });

  final MediaSource media;
  final int? cacheWidth;
  final BoxFit fit;

  /// 模糊時中間圓圈的直徑（詳情頁主圖 52、縮圖列 24）；null＝列表預設，見 [SensitiveGate.circleSize]。
  final double? sensitiveCircle;

  /// false＝安全模式關時不加左上角敏感小標（詳情頁：小標只在列表類畫面出現）；安全模式開時照樣模糊。
  final bool sensitiveBadge;

  /// 敏感內容（D-104）：列表類畫面（預設）依安全模式把已標記的圖模糊，或在左上角加敏感小標，見 [SensitiveGate]。
  /// 詳情頁（D-110 起也模糊，圓圈用 [sensitiveCircle]）；傳 false＝永遠正常顯示。
  final bool protectSensitive;

  /// 這一格代表幾張圖；大於 1 才顯示右下角張數。
  final int count;

  /// 標記離格子邊緣的距離（九宮格 5、瀑布 7）。
  final double badgeInset;

  /// GIF 要不要自動播放（false＝第一格靜態）。
  final bool animate;

  /// 要不要畫左下角的 GIF／影片小標。
  final bool showBadge;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (media.isVideo) {
      content = StaticMediaImage(
        media,
        cacheWidth: cacheWidth,
        fit: fit,
        placeholderColor: placeholderColor,
      );
    } else {
      Widget image(bool moving) => StoredImage(
        media.file,
        cacheWidth: cacheWidth,
        fit: fit,
        placeholderColor: placeholderColor,
        animate: moving && media.isGif,
        isGif: media.isGif ? true : null,
      );
      content = image(animate);
    }
    if (protectSensitive) {
      if (animate && media.isGif) {
        // D-113 ①：已標記的 GIF 在安全模式開時只畫模糊的第一格，不解碼動畫。
        final moving = content;
        content = SensitiveMotionGate(
          file: media.file,
          circleSize: sensitiveCircle,
          showBadge: sensitiveBadge,
          still: (_) => StoredImage(
            media.file,
            cacheWidth: cacheWidth,
            fit: fit,
            placeholderColor: placeholderColor,
            animate: false,
            isGif: true,
          ),
          live: (_) => moving,
        );
      } else {
        content = SensitiveGate(
          file: media.file,
          circleSize: sensitiveCircle,
          showBadge: sensitiveBadge,
          child: content,
        );
      }
    }
    final badge = !showBadge
        ? null
        : media.isGif
        ? const MediaBadgeGif()
        : media.isVideo
        ? MediaBadgeVideo(durationMs: media.durationMs)
        : null;
    if (badge == null && count <= 1) return content;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        content,
        if (badge != null)
          Positioned(
            left: badgeInset,
            bottom: badgeInset,
            child: IgnorePointer(child: badge),
          ),
        if (count > 1)
          Positioned(
            right: badgeInset,
            bottom: badgeInset,
            child: IgnorePointer(child: MediaCountBadge(count)),
          ),
      ],
    );
  }
}

/// 詳情／預覽頁的一頁（D-080）：圖片 contain、GIF 循環播放（不顯示標記）、影片用 [VideoPlayerView]。
class MediaViewer extends StatefulWidget {
  const MediaViewer(
    this.media, {
    super.key,
    this.active = true,
    this.cacheWidth,
    this.placeholderColor,
    this.zoomable = false,
    this.onFullscreen,
    this.start,
    this.badgeInset = 12,
    this.autoPlay = false,
  });

  final MediaSource media;

  /// 這一頁是不是目前顯示的頁；false 時影片自動暫停、GIF 停止，縮放也還原。
  final bool active;
  final int? cacheWidth;
  final Color? placeholderColor;

  /// 圖片與 GIF 可雙指縮放（預覽頁用）；影片不縮放。
  final bool zoomable;
  final VideoFullscreenCallback? onFullscreen;
  final VideoStart? start;
  final double badgeInset;

  /// 影片：輪到這一頁就直接播放（預覽頁用）。
  final bool autoPlay;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

/// 放大超過這個倍數就算「放大中」（預覽頁此時不觸發拖曳退出）。
const _zoomedThreshold = 1.02;

class _MediaViewerState extends State<MediaViewer> {
  TransformationController? _tc;
  PreviewController? _preview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview = PreviewScope.maybeOf(context);
  }

  void _onTransform() {
    _preview?.setZoomed(
      this,
      _tc!.value.getMaxScaleOnAxis() > _zoomedThreshold,
    );
  }

  TransformationController get _controller =>
      _tc ??= TransformationController()..addListener(_onTransform);

  @override
  void didUpdateWidget(MediaViewer old) {
    super.didUpdateWidget(old);
    // 換到別頁後，這頁的縮放還原（也避免看不見的頁面讓預覽一直處於「放大中」）。
    if (old.active && !widget.active && _tc != null) {
      _tc!.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _preview?.setZoomed(this, false);
    _tc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    if (media.isVideo) {
      return VideoPlayerView(
        file: media.file,
        poster: media.poster,
        durationMs: media.durationMs,
        active: widget.active,
        onFullscreen: widget.onFullscreen,
        start: widget.start,
        badgeInset: widget.badgeInset,
        autoPlay: widget.autoPlay,
      );
    }
    final image = StoredImage(
      media.file,
      fit: BoxFit.contain,
      cacheWidth: widget.cacheWidth,
      placeholderColor: widget.placeholderColor,
      animate: media.isGif && widget.active,
      isGif: media.isGif ? true : null,
    );
    if (!widget.zoomable) return image;
    return InteractiveViewer(
      transformationController: _controller,
      maxScale: 4,
      child: SizedBox.expand(child: image),
    );
  }
}

/// [MediaViewer] 加上敏感內容閘門（D-110／D-113 ①）：詳情頁輪播、預覽頁、全螢幕看圖用。
///
/// - 圖片：已標記且安全模式開 → 模糊＋圓圈（同 [SensitiveGate]）。
/// - GIF、影片：安全模式開時只畫模糊的第一格（GIF＝第一格、影片＝poster），**不建立播放器、
///   不播動畫**，沒有影片控制列；關閉安全模式（或 iPad 面板撳開這一張）後才換成 [MediaViewer]
///   正常播放。
/// - 安全模式關：不加左上角小標（[showBadge] false）。
class SensitiveMediaViewer extends StatelessWidget {
  const SensitiveMediaViewer(
    this.media, {
    super.key,
    this.active = true,
    this.cacheWidth,
    this.placeholderColor,
    this.zoomable = false,
    this.onFullscreen,
    this.start,
    this.badgeInset = 12,
    this.circleSize = 52,
    this.showBadge = false,
    this.onBlurredTap,
  });

  /// 模糊中（沒有播放器）時點一下的動作，例如詳情頁輪播的影片頁開全螢幕。
  final VoidCallback? onBlurredTap;

  final MediaSource media;
  final bool active;
  final int? cacheWidth;
  final Color? placeholderColor;
  final bool zoomable;
  final VideoFullscreenCallback? onFullscreen;
  final VideoStart? start;
  final double badgeInset;
  final double circleSize;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    Widget viewer(BuildContext _) => MediaViewer(
      media,
      active: active,
      cacheWidth: cacheWidth,
      placeholderColor: placeholderColor,
      zoomable: zoomable,
      onFullscreen: onFullscreen,
      start: start,
      badgeInset: badgeInset,
    );
    if (!media.isVideo && !media.isGif) {
      return SensitiveGate(
        file: media.file,
        circleSize: circleSize,
        showBadge: showBadge,
        child: viewer(context),
      );
    }
    return SensitiveMotionGate(
      file: media.file,
      circleSize: circleSize,
      showBadge: showBadge,
      still: (_) {
        final still = SizedBox.expand(
          child: StaticMediaImage(
            media,
            cacheWidth: cacheWidth,
            fit: BoxFit.contain,
            placeholderColor: placeholderColor,
          ),
        );
        final tap = onBlurredTap;
        return tap == null
            ? still
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tap,
                child: still,
              );
      },
      live: viewer,
    );
  }
}
