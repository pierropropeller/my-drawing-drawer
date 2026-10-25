import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'dismissible_preview.dart';
import 'media_widgets.dart';

/// 預覽頁（官方圖冊／同人圖／雜物／詳情輪播的全螢幕）共用版面：
///
/// - 圖片區鋪滿**整個螢幕**（含狀態列、頂欄、底欄後面），放大時只被螢幕邊界裁切；
/// - 頂欄（返回、標題、頁碼）和底欄（資訊區＋操作列）疊在圖片上，底色是 [bannerColor]
///   （預覽頁底色 80% 不透明）；點一下圖片時淡出／淡入（[PreviewChrome]）；
/// - 圖片區拿到頂欄、底欄的高度（[PreviewInsets]），寬圖（寬 ≥ 高）原樣置中在兩欄之間，
///   不會因為收起 UI 而跳動。
class PreviewLayout extends StatefulWidget {
  const PreviewLayout({
    super.key,
    required this.bannerColor,
    required this.header,
    required this.media,
    required this.bottom,
  });

  /// 兩個橫幅的底色（含透明度）。
  final Color bannerColor;

  /// 頂欄內容（不含狀態列的空間，這裡會自己墊）。
  final Widget header;

  /// 圖片區（通常是 [PreviewMediaArea]）。
  final Widget media;

  /// 底欄內容（資訊區＋操作列，這裡會自己墊下方安全區）。
  final Widget bottom;

  /// 預覽頁底色的 80%。
  static Color bannerOf(Color background) =>
      background.withValues(alpha: background.a * 0.8);

  @override
  State<PreviewLayout> createState() => _PreviewLayoutState();
}

class _PreviewLayoutState extends State<PreviewLayout> {
  final _insets = ValueNotifier<EdgeInsets>(EdgeInsets.zero);
  bool _measured = false;
  double _top = 0;
  double _bottom = 0;

  @override
  void dispose() {
    _insets.dispose();
    super.dispose();
  }

  void _update({double? top, double? bottom}) {
    _top = top ?? _top;
    _bottom = bottom ?? _bottom;
    final next = EdgeInsets.only(top: _top, bottom: _bottom);
    if (next != _insets.value) _insets.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (!_measured) {
      // 第一格還沒量到橫幅高度時先用估計值（之後量到就換成實際的），避免圖片先鋪滿再跳開。
      _measured = true;
      _top = pad.top + 52;
      _bottom = pad.bottom + 140;
      _insets.value = EdgeInsets.only(top: _top, bottom: _bottom);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: PreviewInsets(notifier: _insets, child: widget.media),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _MeasureSize(
            onSize: (s) => _update(top: s.height),
            child: PreviewChrome(
              child: ColoredBox(
                color: widget.bannerColor,
                child: Padding(
                  padding: EdgeInsets.only(top: pad.top),
                  child: widget.header,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _MeasureSize(
            onSize: (s) => _update(bottom: s.height),
            child: PreviewChrome(
              child: ColoredBox(
                color: widget.bannerColor,
                child: Padding(
                  padding: EdgeInsets.only(bottom: pad.bottom),
                  child: widget.bottom,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 圖片區要避開的頂欄／底欄高度（由 [PreviewLayout] 提供）。
class PreviewInsets extends InheritedNotifier<ValueNotifier<EdgeInsets>> {
  const PreviewInsets({
    super.key,
    required ValueNotifier<EdgeInsets> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static EdgeInsets of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PreviewInsets>()
          ?.notifier
          ?.value ??
      EdgeInsets.zero;
}

/// 量出子元件的大小，變動時在這一格畫完之後回報。
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasureSize r) =>
      r.onSize = onSize;
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onSize);
  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    _last = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(size);
    });
  }
}

/// 放大超過這個倍數就算「放大中」（此時不觸發拖曳退出）。
const _zoomedThreshold = 1.02;

/// 預覽頁的一頁媒體。
///
/// - 影片：維持原樣，放在兩個橫幅之間（不縮放）；
/// - 寬圖（寬 ≥ 高）／尺寸不明：原樣 contain 置中在兩個橫幅之間；雙指放大時
///   可放大到整個螢幕（疊在橫幅底下），只被螢幕裁切；
/// - 長圖（高 > 寬）：寬度＝螢幕寬度、貼齊最上面，往下垂直捲動（像條漫）；雙指也能放大。
///   圖整張放得下時就貼齊最上面，不能捲。
class PreviewMediaPage extends StatelessWidget {
  const PreviewMediaPage(
    this.media, {
    super.key,
    this.active = true,
    this.start,
    this.onFullscreen,
  });

  final MediaSource media;
  final bool active;
  final VideoStart? start;
  final VideoFullscreenCallback? onFullscreen;

  /// 這個媒體是不是長圖（高 > 寬，影片除外）。
  static bool isTall(MediaSource m) =>
      !m.isVideo && m.width > 0 && m.height > m.width;

  @override
  Widget build(BuildContext context) {
    final insets = PreviewInsets.of(context);
    final inner = MediaViewer(
      media,
      active: active,
      start: start,
      onFullscreen: onFullscreen,
    );
    if (media.isVideo) {
      return Padding(
        padding: EdgeInsets.fromLTRB(0, insets.top + 8, 0, insets.bottom + 8),
        child: inner,
      );
    }
    if (isTall(media)) {
      return _TallPage(media: media, active: active, child: inner);
    }
    return _ZoomPage(
      active: active,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, insets.top + 8, 0, insets.bottom + 8),
        child: inner,
      ),
    );
  }
}

/// 寬圖：整個螢幕大的 InteractiveViewer，圖在裡面置中。
class _ZoomPage extends StatefulWidget {
  const _ZoomPage({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _tc = TransformationController();
  PreviewController? _preview;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_onTransform);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview = PreviewScope.maybeOf(context);
  }

  void _onTransform() => _preview?.setZoomed(
    this,
    _tc.value.getMaxScaleOnAxis() > _zoomedThreshold,
  );

  @override
  void didUpdateWidget(_ZoomPage old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _tc.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _preview?.setZoomed(this, false);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    transformationController: _tc,
    maxScale: 5,
    child: SizedBox.expand(child: widget.child),
  );
}

/// 長圖：寬度＝螢幕寬度、貼齊最上面；InteractiveViewer 同時負責垂直捲動（縮放倍率 1 時）和雙指縮放。
class _TallPage extends StatefulWidget {
  const _TallPage({
    required this.media,
    required this.active,
    required this.child,
  });
  final MediaSource media;
  final bool active;
  final Widget child;

  @override
  State<_TallPage> createState() => _TallPageState();
}

class _TallPageState extends State<_TallPage> {
  final _tc = TransformationController();
  PreviewController? _preview;
  double _contentH = 0;
  double _viewportH = 0;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_report);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview = PreviewScope.maybeOf(context);
  }

  void _report() {
    final p = _preview;
    if (p == null) return;
    p.setZoomed(this, _tc.value.getMaxScaleOnAxis() > _zoomedThreshold);
    p.setVerticalScroll(
      this,
      scrollable: widget.active && _contentH > _viewportH + 0.5,
      atTop: _tc.value.getTranslation().y >= -0.5,
    );
  }

  @override
  void didUpdateWidget(_TallPage old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) {
      _tc.value = Matrix4.identity();
      _report();
    }
  }

  @override
  void dispose() {
    _preview?.setZoomed(this, false);
    _preview?.setVerticalScroll(this, scrollable: false, atTop: true);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final contentH = w * widget.media.height / widget.media.width;
        if (contentH != _contentH || c.maxHeight != _viewportH) {
          _contentH = contentH;
          _viewportH = c.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _report();
          });
        }
        return InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          alignment: Alignment.topLeft,
          maxScale: 5,
          child: SizedBox(width: w, height: contentH, child: widget.child),
        );
      },
    );
  }
}
