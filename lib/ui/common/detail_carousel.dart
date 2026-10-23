import 'package:flutter/material.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../entity/image_gallery_page.dart';
import 'app_icons.dart';
import 'media_mini.dart';
import 'media_widgets.dart';
import 'sensitive_gate.dart';
import 'svg_icon.dart';

/// 詳情頁圖片框比例的上下限（D-073）：最扁 1.91:1（寬:高），最高 3:4。
const double detailFrameMaxAspect = 1.91;
const double detailFrameMinAspect = 3 / 4;

/// 詳情頁圖片框的寬高比（寬/高）：取所有圖裡最瘦長（寬/高最小）的那張，夾在 3:4～1.91:1。
/// 尺寸未知（0）的圖當 1:1；沒有圖時回傳 [emptyAspect]。單張圖就是它自己的比例。
double detailFrameAspect(List<ImageRef> images, {double emptyAspect = 1}) {
  if (images.isEmpty) return emptyAspect;
  var a = double.infinity;
  for (final im in images) {
    if (im.aspect < a) a = im.aspect;
  }
  return a.clamp(detailFrameMinAspect, detailFrameMaxAspect);
}

/// 詳情頁共用的圖片輪播（D-073）：框高度固定（依最瘦長那張，滑動不跳），每張圖 contain 完整顯示、
/// 留白填 `#EFE8DE`；多張時框右上角「1 / N」膠囊（貼框不貼圖）；點圖開全螢幕看圖。
class DetailCarousel extends StatefulWidget {
  const DetailCarousel({
    super.key,
    required this.images,
    this.controller,
    this.onPageChanged,
    this.borderRadius = 0,
    this.emptyAspect = 1,
    this.emptyColor,
    this.cacheWidth = 1000,
    this.maxHeightFactor = 0.62,
  });

  final List<ImageRef> images;

  /// 外部要控制翻頁（縮圖條點選）時傳入；沒傳就自己管。
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final double borderRadius;

  /// 沒有圖時佔位框的比例與底色。
  final double emptyAspect;
  final Color? emptyColor;
  final int cacheWidth;

  /// 平板上框高度不超過螢幕高度的這個比例。
  final double maxHeightFactor;

  @override
  State<DetailCarousel> createState() => _DetailCarouselState();
}

class _DetailCarouselState extends State<DetailCarousel> {
  PageController? _own;
  PageController get _controller =>
      widget.controller ?? (_own ??= PageController());
  int _index = 0;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _open(int i, {VideoStart? start}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ImageGalleryPage(
        images: widget.images,
        initialIndex: i,
        videoStart: start,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final images = widget.images;
    final multi = images.length > 1;
    final aspect = detailFrameAspect(images, emptyAspect: widget.emptyAspect);
    final letterbox = dark ? t.chipBg : const Color(0xFFEFE8DE);
    final maxH = MediaQuery.sizeOf(context).height * widget.maxHeightFactor;
    return LayoutBuilder(
      builder: (_, c) {
        final h = (c.maxWidth / aspect).clamp(0.0, maxH);
        return SizedBox(
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isEmpty)
                  ColoredBox(
                    color: widget.emptyColor ?? letterbox,
                    child: Center(
                      child: SvgIcon(
                        AppIcons.image,
                        size: 44,
                        strokeWidth: 1.5,
                        color: t.ink.withValues(alpha: .22),
                      ),
                    ),
                  )
                else
                  ColoredBox(
                    color: letterbox,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: images.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        widget.onPageChanged?.call(i);
                      },
                      itemBuilder: (_, i) {
                        final media = MediaSource.fromImageRef(images[i]);
                        // 影片（D-080）：點一下是播放，不開全螢幕；全螢幕鍵才開預覽頁並接續播放。
                        // 換頁（_index 變了）自動暫停。GIF 直接循環播放、不顯示標記。
                        if (media.isVideo) {
                          return MediaViewer(
                            media,
                            active: i == _index,
                            placeholderColor: letterbox,
                            onFullscreen: (pos, playing) => _open(
                              i,
                              start: VideoStart(pos, autoPlay: playing),
                            ),
                          );
                        }
                        return GestureDetector(
                          onTap: () => _open(i),
                          // 詳情頁的主圖照安全模式模糊（52px 圓，D-110）／加小標；全螢幕預覽也一樣。
                          child: SensitiveGate(
                            file: media.file,
                            badgeInset: 12,
                            circleSize: 52,
                            child: MediaViewer(
                              media,
                              active: i == _index,
                              cacheWidth: widget.cacheWidth,
                              placeholderColor: letterbox,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (multi)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IgnorePointer(
                      child: Container(
                        key: const ValueKey('detailPagePill'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2622).withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_index + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 詳情頁的大圖區（D-073／D-092，摸魚與腦洞詳情共用）：[DetailCarousel]，框比例依最瘦長那張。多張時下方縮圖列（目前這張描主色框）。
class DetailImageStage extends StatefulWidget {
  const DetailImageStage({
    super.key,
    required this.images,
    this.borderRadius = 0,
    this.sidePadding = 20,
    this.maxHeightFactor = 0.62,
    this.onIndexChanged,
  });
  final List<ImageRef> images;
  final double borderRadius;

  /// 換到哪一張（P-038：iPad 詳情面板的眼睛鈕要知道現在是哪一張）。
  final ValueChanged<int>? onIndexChanged;

  /// 縮圖列左右留白。
  final double sidePadding;
  final double maxHeightFactor;

  @override
  State<DetailImageStage> createState() => _DetailImageStageState();
}

class _DetailImageStageState extends State<DetailImageStage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final images = widget.images;
    final multi = images.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailCarousel(
          images: images,
          controller: _controller,
          onPageChanged: (i) {
            setState(() => _index = i);
            widget.onIndexChanged?.call(i);
          },
          emptyAspect: 3 / 4,
          borderRadius: widget.borderRadius,
          maxHeightFactor: widget.maxHeightFactor,
        ),
        if (multi)
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(
                widget.sidePadding,
                12,
                widget.sidePadding,
                0,
              ),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Semantics(
                button: true,
                label: context.l10n.draftDetailImageLabel(i + 1),
                child: GestureDetector(
                  onTap: () => _controller.jumpToPage(i),
                  // 圖片先裁成 10px 圓角、選中框畫在圖上面（外緣圓角同為 10），
                  // 內緣圓角才會貼合（框畫在 clip 外面時內角是方的，會很醜）。
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: MiniMediaThumb(
                            MediaSource.fromImageRef(images[i]),
                            cacheWidth: 200,
                            sensitiveCircle: 24,
                          ),
                        ),
                        if (i == _index)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.accent, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
