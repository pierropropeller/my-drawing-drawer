import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'dismissible_preview.dart';
import 'media_widgets.dart';
import 'top_toast.dart' show BottomInsetAnchor;

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
            // 提示條浮在底欄（資訊區＋操作列）上方，不蓋住操作列（D-114）。
            child: BottomInsetAnchor(
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

/// 雙擊放大的倍數、雙指最多放大到幾倍（D-121）。
const kPreviewDoubleTapScale = 2.0;
const kPreviewMaxScale = 4.0;

/// 預覽頁的一頁媒體（D-116 對齊、D-121 縮放）。
///
/// 「可用區」＝頂欄下面到底欄（資訊區）上面那一段；圖片一律滿寬、不裁切：
/// - 影片：維持原樣，放在可用區內（不縮放）；
/// - 圖片高度 ≤ 可用區：垂直置中（上下留白相等）；
/// - 圖片高度 ＞ 可用區：靠頂（從頂欄下面開始），往下捲看餘下部分。
/// 兩種圖都能雙指縮放（最多 4 倍）、雙擊放大 2 倍（以點的位置為中心）／再雙擊還原；
/// 放大時可放大到整個螢幕（疊在橫幅底下），只被螢幕裁切。
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
        padding: EdgeInsets.fromLTRB(0, insets.top, 0, insets.bottom),
        child: inner,
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final known = media.width > 0 && media.height > 0;
        final area = c.maxHeight - insets.top - insets.bottom;
        final h = known ? c.maxWidth * media.height / media.width : 0.0;
        if (known && h > area + 0.5) {
          return _TallPage(
            media: media,
            active: active,
            top: insets.top,
            bottom: insets.bottom,
            child: inner,
          );
        }
        return PreviewZoom(
          active: active,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, insets.top, 0, insets.bottom),
            child: inner,
          ),
        );
      },
    );
  }
}

/// 雙擊：沒放大＝以點的位置為中心放大 [kPreviewDoubleTapScale] 倍；放大中＝還原。
Matrix4 _doubleTapTarget(Matrix4 current, Offset? at, Size viewport) {
  if (current.getMaxScaleOnAxis() > _zoomedThreshold) return Matrix4.identity();
  final p = at ?? viewport.center(Offset.zero);
  // 先把現在的位移換回內容座標，再以那一點為中心放大。
  final inv = Matrix4.inverted(current);
  final scene = MatrixUtils.transformPoint(inv, p);
  const k = kPreviewDoubleTapScale;
  return Matrix4.identity()
    ..translateByDouble(p.dx - scene.dx * k, p.dy - scene.dy * k, 0, 1)
    ..scaleByDouble(k, k, 1, 1);
}

/// 縮放動畫（雙擊用）。
mixin _AnimatedZoom<T extends StatefulWidget> on State<T>, TickerProvider {
  TransformationController get tc;
  AnimationController? _anim;
  Offset? _tapAt;

  void animateTo(Matrix4 target) {
    _anim?.dispose();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      tc.value = target;
      return;
    }
    final tween = Matrix4Tween(begin: tc.value.clone(), end: target);
    final a = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _anim = a;
    final curved = CurvedAnimation(parent: a, curve: Curves.easeOut);
    a.addListener(() => tc.value = tween.evaluate(curved));
    a.forward();
  }

  Widget doubleTap(Size viewport, Widget child) => GestureDetector(
    onDoubleTapDown: (d) => _tapAt = d.localPosition,
    onDoubleTap: () => animateTo(_doubleTapTarget(tc.value, _tapAt, viewport)),
    child: child,
  );

  void disposeZoom() => _anim?.dispose();
}

/// 圖片放得下：整個螢幕大的 InteractiveViewer，圖在可用區內置中。雙指最多 4 倍、雙擊 2 倍，
/// 回報縮放狀態給預覽手勢（放大時不退出、不換頁）。表單內預覽也用它。
class PreviewZoom extends StatefulWidget {
  const PreviewZoom({super.key, this.active = true, required this.child});
  final bool active;
  final Widget child;

  @override
  State<PreviewZoom> createState() => PreviewZoomState();
}

class PreviewZoomState extends State<PreviewZoom>
    with TickerProviderStateMixin, _AnimatedZoom {
  final _tc = TransformationController();
  PreviewController? _preview;

  @override
  TransformationController get tc => _tc;

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
  void didUpdateWidget(PreviewZoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _tc.value = Matrix4.identity();
  }

  @override
  void dispose() {
    disposeZoom();
    _preview?.setZoomed(this, false);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => doubleTap(
      c.biggest,
      InteractiveViewer(
        transformationController: _tc,
        maxScale: kPreviewMaxScale,
        child: SizedBox.expand(child: widget.child),
      ),
    ),
  );
}

/// 圖片比可用區高：寬度＝螢幕寬度、從頂欄下面開始；InteractiveViewer 同時負責垂直捲動
/// （縮放倍率 1 時）和縮放。內容上下各墊頂欄／底欄的高度，捲到底時圖的底邊停在資訊區上面。
class _TallPage extends StatefulWidget {
  const _TallPage({
    required this.media,
    required this.active,
    required this.top,
    required this.bottom,
    required this.child,
  });
  final MediaSource media;
  final bool active;
  final double top;
  final double bottom;
  final Widget child;

  @override
  State<_TallPage> createState() => _TallPageState();
}

class _TallPageState extends State<_TallPage>
    with TickerProviderStateMixin, _AnimatedZoom {
  final _tc = TransformationController();
  PreviewController? _preview;
  double _contentH = 0;
  double _viewportH = 0;

  @override
  TransformationController get tc => _tc;

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
    disposeZoom();
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
        final imageH = w * widget.media.height / widget.media.width;
        final contentH = widget.top + imageH + widget.bottom;
        if (contentH != _contentH || c.maxHeight != _viewportH) {
          _contentH = contentH;
          _viewportH = c.maxHeight;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _report();
          });
        }
        return doubleTap(
          c.biggest,
          InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            alignment: Alignment.topLeft,
            maxScale: kPreviewMaxScale,
            child: SizedBox(
              width: w,
              height: contentH,
              child: Padding(
                padding: EdgeInsets.only(
                  top: widget.top,
                  bottom: widget.bottom,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
