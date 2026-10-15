import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 這個 widget 目前有沒有在畫面上（D-080）。
///
/// 「在畫面上」＝它的矩形和螢幕、以及每一層祖先 `Scrollable` 的可視範圍都有重疊
/// （所以捲出列表、PageView 滑到隔壁頁的都算不在）。捲動、版面變化、視窗尺寸改變時重新檢查。
/// 第一個 frame 之前一律是 false，檢查完才變 true，所以剛建好的格子會晚一個 frame 才開始播。
///
/// 只用來決定 GIF 要不要播；不影響版面（[builder] 的結果原樣顯示）。
class OnScreen extends StatefulWidget {
  const OnScreen({super.key, required this.builder});

  final Widget Function(BuildContext context, bool visible) builder;

  @override
  State<OnScreen> createState() => _OnScreenState();
}

class _OnScreenState extends State<OnScreen> with WidgetsBindingObserver {
  final List<ScrollPosition> _positions = [];
  bool _visible = false;
  bool _checkQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detach();
    ScrollableState? s = Scrollable.maybeOf(context);
    while (s != null) {
      final pos = s.position;
      pos.addListener(_queueCheck);
      _positions.add(pos);
      s = Scrollable.maybeOf(s.context);
    }
    _queueCheck();
  }

  void _detach() {
    for (final p in _positions) {
      p.removeListener(_queueCheck);
    }
    _positions.clear();
  }

  @override
  void didUpdateWidget(OnScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _queueCheck();
  }

  @override
  void didChangeMetrics() => _queueCheck();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detach();
    super.dispose();
  }

  /// 捲動中每個 frame 都會進來；排到 frame 結束後（版面已定）再量一次。
  void _queueCheck() {
    if (_checkQueued || !mounted) return;
    _checkQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (!mounted) return;
      final v = _measure();
      if (v != _visible) setState(() => _visible = v);
    });
    // 沒有 frame 排程時（例如靜止的畫面）也要能量到。
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  bool _measure() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    final rect = MatrixUtils.transformRect(
      ro.getTransformTo(null),
      Offset.zero & ro.size,
    );
    if (rect.isEmpty) return false;
    final view = View.maybeOf(context);
    if (view != null) {
      final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
      if (!rect.overlaps(screen)) return false;
    }
    ScrollableState? s = Scrollable.maybeOf(context);
    while (s != null) {
      final box = s.context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final vp = MatrixUtils.transformRect(
          box.getTransformTo(null),
          Offset.zero & box.size,
        );
        if (!rect.overlaps(vp)) return false;
      }
      s = Scrollable.maybeOf(s.context);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible);
}

/// GIF 的靜態第一格：解出第一個 frame 就停止監聽（不再解碼後面的 frame），用 [RawImage] 畫出。
///
/// 需要「靜態圖」的地方（坑封面、年度回顧、月曆格、表單縮圖、捲出畫面的 GIF）用這個。
/// 和動畫版共用同一個 [ImageProvider] 的 cache key，切換時不會重讀檔案。
class FirstFrameImage extends StatefulWidget {
  const FirstFrameImage({
    super.key,
    required this.provider,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final ImageProvider provider;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<FirstFrameImage> createState() => _FirstFrameImageState();
}

class _FirstFrameImageState extends State<FirstFrameImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;
  Object? _error;
  StackTrace? _stack;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(FirstFrameImage old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) _resolve();
  }

  void _resolve() {
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_stream?.key == stream.key && (_info != null || _error != null)) {
      return;
    }
    _stopListening();
    _info?.dispose();
    _info = null;
    _error = null;
    _stream = stream;
    _listener = ImageStreamListener(
      (info, sync) {
        // 第一格到手就收下（複製一份，原本的由 completer 管），然後不再聽後面的 frame。
        final first = _info == null;
        if (first) {
          _info = info.clone();
          _stopListening();
          if (mounted) setState(() {});
        }
      },
      onError: (e, s) {
        _error = e;
        _stack = s;
        _stopListening();
        if (mounted) setState(() {});
      },
    );
    stream.addListener(_listener!);
  }

  void _stopListening() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    _info?.dispose();
    _info = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info != null) {
      return RawImage(image: info.image, scale: info.scale, fit: widget.fit);
    }
    if (_error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _error!, _stack);
    }
    return const SizedBox.expand();
  }
}

/// 會動的 GIF（D-080）：**只在畫面上時播放**，捲出去（或 [play] 為 false、所在的頁面被蓋住）
/// 就換回靜態第一格，Image 不再監聽、不再解碼後續 frame。
///
/// 播放中的子樹帶 `ValueKey('gifAnimating')`，靜止的帶 `ValueKey('gifStill')`（測試用）。
class GifImage extends StatelessWidget {
  const GifImage({
    super.key,
    required this.file,
    this.cacheWidth,
    this.fit = BoxFit.cover,
    this.play = true,
    this.errorBuilder,
  });

  final File file;
  final int? cacheWidth;
  final BoxFit fit;

  /// 呼叫端另外的條件（例如詳情頁只有目前這一頁才播）。
  final bool play;
  final ImageErrorWidgetBuilder? errorBuilder;

  ImageProvider get _provider =>
      ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(file));

  @override
  Widget build(BuildContext context) {
    return OnScreen(
      builder: (context, visible) {
        final animate = visible && play && TickerMode.valuesOf(context).enabled;
        if (animate) {
          return KeyedSubtree(
            key: const ValueKey('gifAnimating'),
            child: Image(
              image: _provider,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: errorBuilder,
            ),
          );
        }
        return KeyedSubtree(
          key: const ValueKey('gifStill'),
          child: FirstFrameImage(
            provider: _provider,
            fit: fit,
            errorBuilder: errorBuilder,
          ),
        );
      },
    );
  }
}
