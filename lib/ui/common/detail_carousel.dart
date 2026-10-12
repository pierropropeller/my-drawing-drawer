import 'package:flutter/material.dart';

import '../../data/entity_queries.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../entity/image_gallery_page.dart';
import 'app_icons.dart';
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

  void _open(int i) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ImageGalleryPage(images: widget.images, initialIndex: i),
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
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _open(i),
                        child: StoredImage(
                          images[i].file,
                          fit: BoxFit.contain,
                          cacheWidth: widget.cacheWidth,
                          placeholderColor: letterbox,
                        ),
                      ),
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
