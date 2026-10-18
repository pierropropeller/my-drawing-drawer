import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../ui/common/video_player_view.dart'
    show MediaPlayback, PlaybackFactory;
import 'video_playback_gate.dart';

/// 用「播放器」擷取到的一格畫面（PNG）。
class PosterFrame {
  const PosterFrame({
    required this.bytes,
    required this.width,
    required this.height,
    this.ext = 'png',
    this.durationMs,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String ext;

  /// 播放器回報的長度（毫秒）；原生探測沒讀到長度時拿來補。
  final int? durationMs;
}

/// 原生探測（MediaMetadataRetriever／MediaCodec）取不到截圖時的備援：用「實際播放這支影片的解碼器」取畫面。
///
/// 獨立成介面，測試換成假的。實作要保證：同時只跑一份、有逾時、永不丟例外（失敗＝null）。
abstract class PosterFrameGenerator {
  /// 現在能不能擷取（畫面上有承載容器、App 在前景）。false 時呼叫端不要把這次算成「試過」。
  bool get available;

  /// `available` 可能變成 true 時通知（例如承載容器剛掛上），讓排程補做先前因為「還不能擷取」而略過的影片。
  Listenable? get availabilityChanges;

  Future<PosterFrame?> generate(
    String path, {
    int? width,
    int? height,
    int maxSide = 720,
  });
}

// ───────────────────────── 承載容器 ─────────────────────────

/// 擷取用播放器畫面的承載位置。[PlayerFramePosterGenerator] 把要畫的內容放進來，
/// [PosterCaptureHost]（放在 App 最上層的 Stack）把它畫出來，再由 [boundaryKey] 取 RepaintBoundary。
class PosterCaptureSlot extends ChangeNotifier {
  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'posterCapture');

  WidgetBuilder? _builder;
  Size _size = Size.zero;
  bool _offscreen = true;
  int _hosts = 0;

  /// 有沒有 [PosterCaptureHost] 掛在樹上。
  bool get attached => _hosts > 0;

  /// [attached] 改變時通知。
  final ValueNotifier<bool> attachedNotifier = ValueNotifier<bool>(false);

  WidgetBuilder? get builder => _builder;
  Size get size => _size;

  /// true＝畫在螢幕外（左邊）；false＝畫在左上角（只用在螢幕外取不到畫面時的備案，尺寸會很小）。
  bool get offscreen => _offscreen;

  void show(WidgetBuilder builder, Size size, {required bool offscreen}) {
    if (_disposed) return;
    _builder = builder;
    _size = size;
    _offscreen = offscreen;
    notifyListeners();
  }

  void clear() {
    if (_builder == null || _disposed) return;
    _builder = null;
    notifyListeners();
  }

  bool _disposed = false;

  void _attach() {
    _hosts++;
    if (!_disposed) attachedNotifier.value = true;
  }

  void _detach() {
    _hosts--;
    if (!_disposed) attachedNotifier.value = _hosts > 0;
  }

  @override
  void dispose() {
    _disposed = true;
    attachedNotifier.dispose();
    super.dispose();
  }
}

/// 把 [slot] 的內容畫出來。必須是 `Stack` 的直接子層，且要**真的繪製**
/// （不能 Opacity 0、不能 Offstage，否則 Texture 不會更新、截到的是空白）。
/// 預設畫在螢幕外；內容以 [IgnorePointer]＋[ExcludeSemantics] 包起來，不吃觸控也不進無障礙。
class PosterCaptureHost extends StatefulWidget {
  const PosterCaptureHost({super.key, required this.slot});
  final PosterCaptureSlot slot;

  @override
  State<PosterCaptureHost> createState() => _PosterCaptureHostState();
}

class _PosterCaptureHostState extends State<PosterCaptureHost> {
  @override
  void initState() {
    super.initState();
    widget.slot._attach();
    widget.slot.addListener(_changed);
  }

  @override
  void didUpdateWidget(PosterCaptureHost old) {
    super.didUpdateWidget(old);
    if (old.slot != widget.slot) {
      old.slot.removeListener(_changed);
      old.slot._detach();
      widget.slot._attach();
      widget.slot.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.slot.removeListener(_changed);
    widget.slot._detach();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final builder = slot.builder;
    if (builder == null) return const SizedBox.shrink();
    final size = slot.size;
    return Positioned(
      left: slot.offscreen ? -(size.width + 64) : 0,
      top: 0,
      width: size.width,
      height: size.height,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            key: slot.boundaryKey,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
}

/// 把 [child] 與 [PosterCaptureHost] 疊在一起（放在 `MaterialApp` 外面一層）。
class PosterCaptureScope extends StatelessWidget {
  const PosterCaptureScope({
    super.key,
    required this.slot,
    required this.child,
  });
  final PosterCaptureSlot slot;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    fit: StackFit.expand,
    children: [
      child,
      PosterCaptureHost(slot: slot),
    ],
  );
}

// ───────────────────────── 產生器 ─────────────────────────

/// 以 `video_player`（Android 上是 ExoPlayer，也就是 App 真正拿來播這支影片的解碼器）取海報（D-080 備援）。
///
/// 為什麼需要：部分 Twitter 轉出的小 mp4 系統縮圖器（MediaMetadataRetriever）取不到畫面，
/// ExoPlayer 卻播得動。做法：
/// 1. 建一個不顯示的播放器、初始化，靜音；
/// 2. 依序 seek 到 min(1 秒, 長度/2)、0、長度/2，每次等畫面出來；
/// 3. 把播放器畫面放進 [PosterCaptureSlot]（螢幕外、有真的繪製、有 RepaintBoundary），
///    `RenderRepaintBoundary.toImage` 截下來；
/// 4. 檢查是不是全黑（取樣像素）：全黑就丟掉換下一個時間點、先輕輕播放一下再截；
/// 5. 編成 PNG（`dart:ui`，不引入額外套件）。
///
/// 同時只處理一支（排隊）、整體逾時 [timeout]（預設 8 秒）、任何錯誤＝null，不碰 UI thread 以外的東西。
class PlayerFramePosterGenerator implements PosterFrameGenerator {
  PlayerFramePosterGenerator({
    required this.slot,
    required this.playbackFactory,
    this.timeout = const Duration(seconds: 8),
    this.settle = const Duration(milliseconds: 250),
    this.isForeground = _defaultForeground,
    VideoPlaybackGate? gate,
  }) : gate = gate ?? videoPlaybackGate;

  final PosterCaptureSlot slot;
  final PlaybackFactory playbackFactory;
  final Duration timeout;

  /// seek 之後等多久再截（讓 ExoPlayer 把畫面送進 Texture）。
  final Duration settle;
  final bool Function() isForeground;

  /// 使用者正在播放影片時不另開播放器（避免搶解碼器造成掉幀）。
  final VideoPlaybackGate gate;

  static bool _defaultForeground() {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed;
  }

  Future<void> _tail = Future<void>.value();

  @override
  bool get available => slot.attached && isForeground() && !gate.active;

  @override
  Listenable? get availabilityChanges =>
      Listenable.merge([slot.attachedNotifier, gate]);

  @override
  Future<PosterFrame?> generate(
    String path, {
    int? width,
    int? height,
    int maxSide = 720,
  }) {
    // 排隊：前一支（含它的逾時清理）結束才輪到這一支。
    final completer = Completer<PosterFrame?>();
    _tail = _tail.then((_) async {
      PosterFrame? r;
      try {
        r = await _run(path, width: width, height: height, maxSide: maxSide);
      } catch (_) {
        r = null;
      }
      completer.complete(r);
    });
    return completer.future;
  }

  Future<PosterFrame?> _run(
    String path, {
    int? width,
    int? height,
    required int maxSide,
  }) async {
    if (!available) return null;
    final job = _Job();
    // 擷取途中使用者開始播放影片：馬上中止、釋放播放器（結果算「沒試過」，閘門放開後會補）。
    final interrupted = Completer<PosterFrame?>();
    void onGate() {
      if (!gate.active) return;
      job.abort();
      if (!interrupted.isCompleted) interrupted.complete(null);
    }

    gate.addListener(onGate);
    try {
      // initialize() 之類的呼叫可能永遠不回來，所以用 Future.timeout 硬切；
      // 逾時後 job 已 abort（播放器釋放），殘留的流程在下一個 check() 就會中止。
      return await Future.any([
        _capture(
          job,
          path,
          width: width,
          height: height,
          maxSide: maxSide,
        ).timeout(
          timeout,
          onTimeout: () {
            job.abort();
            return null;
          },
        ),
        interrupted.future,
      ]);
    } catch (_) {
      return null;
    } finally {
      gate.removeListener(onGate);
      job.finish(slot);
    }
  }

  Future<PosterFrame?> _capture(
    _Job job,
    String path, {
    int? width,
    int? height,
    required int maxSide,
  }) async {
    final p = playbackFactory(File(path));
    job.playback = p;
    await p.initialize();
    job.check();
    if (!p.isInitialized || p.hasError) return null;
    try {
      await p.setVolume(0);
    } catch (_) {}
    final duration = p.duration;
    final aspect = p.aspectRatio > 0 ? p.aspectRatio : 16 / 9;

    // 時間點：先 min(1 秒, 長度/2)（跟原生探測「第 1 秒」規則一致），再 0，再長度/2。
    final half = duration ~/ 2;
    final first = duration <= Duration.zero
        ? Duration.zero
        : (half < const Duration(seconds: 1)
              ? half
              : const Duration(seconds: 1));
    final candidates = <Duration>[];
    for (final d in [first, Duration.zero, half]) {
      if (!candidates.contains(d)) candidates.add(d);
    }

    // 版面尺寸：先用「螢幕外、輸出尺寸」；取不到再改「左上角、很小」（pixelRatio 放大）。
    final nativeLongest = math.max(width ?? 0, height ?? 0);
    final outLongest =
        (nativeLongest > 0 ? math.min(nativeLongest, maxSide) : maxSide)
            .toDouble();
    for (final offscreen in [true, false]) {
      final layoutLongest = offscreen ? outLongest : 32.0;
      final size = aspect >= 1
          ? Size(layoutLongest, layoutLongest / aspect)
          : Size(layoutLongest * aspect, layoutLongest);
      final ratio = outLongest / layoutLongest;
      job.check();
      slot.show((ctx) => p.buildView(ctx), size, offscreen: offscreen);
      await _frames();
      job.check();
      for (final t in candidates) {
        try {
          await p.seekTo(t);
        } catch (_) {
          continue;
        }
        for (var attempt = 0; attempt < 3; attempt++) {
          job.check();
          if (attempt == 2) await _nudge(p, job);
          await Future<void>.delayed(settle);
          await _frames();
          final frame = await _grab(ratio);
          if (frame != null) {
            return PosterFrame(
              bytes: frame.bytes,
              width: frame.width,
              height: frame.height,
              durationMs: duration > Duration.zero
                  ? duration.inMilliseconds
                  : null,
            );
          }
        }
      }
    }
    return null;
  }

  /// 靜音輕輕播一下再停：有些機型 seek 後暫停不會把畫面送進 Texture。
  Future<void> _nudge(MediaPlayback p, _Job job) async {
    try {
      await p.play();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      job.check();
      await p.pause();
      await _frames();
    } catch (e) {
      if (e is _Aborted) rethrow;
    }
  }

  Future<void> _frames() async {
    final b = WidgetsBinding.instance;
    b.scheduleFrame();
    await b.endOfFrame;
  }

  /// 截下 RepaintBoundary；全黑／全透明／取不到＝null。
  Future<PosterFrame?> _grab(double pixelRatio) async {
    final ro = slot.boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    ui.Image? image;
    try {
      image = await ro.toImage(pixelRatio: pixelRatio);
      final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null || isMostlyBlank(raw, image.width, image.height)) {
        return null;
      }
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return PosterFrame(
        bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  /// 取樣 24×24 個點；幾乎都是黑（或全透明）＝空畫面（Texture 還沒更新或解碼器沒出畫面）。
  @visibleForTesting
  static bool isMostlyBlank(ByteData rgba, int width, int height) {
    if (width <= 0 || height <= 0) return true;
    const n = 24;
    var lit = 0;
    var total = 0;
    for (var iy = 0; iy < n; iy++) {
      for (var ix = 0; ix < n; ix++) {
        final x = math.min(width - 1, ((ix + .5) * width / n).floor());
        final y = math.min(height - 1, ((iy + .5) * height / n).floor());
        final o = (y * width + x) * 4;
        if (o + 3 >= rgba.lengthInBytes) continue;
        total++;
        final a = rgba.getUint8(o + 3);
        if (a < 8) continue;
        if (rgba.getUint8(o) > 14 ||
            rgba.getUint8(o + 1) > 14 ||
            rgba.getUint8(o + 2) > 14) {
          lit++;
        }
      }
    }
    return total == 0 || lit / total < 0.02;
  }
}

class _Aborted implements Exception {
  const _Aborted();
}

/// 一次擷取的資源：逾時（[abort]）或結束（[finish]）時一定釋放播放器、清空承載位置。
class _Job {
  MediaPlayback? playback;
  bool _aborted = false;
  bool _done = false;

  void check() {
    if (_aborted) throw const _Aborted();
  }

  void abort() {
    _aborted = true;
    _release();
  }

  void finish(PosterCaptureSlot slot) {
    if (_done) return;
    _done = true;
    slot.clear();
    _release();
  }

  void _release() {
    final p = playback;
    playback = null;
    if (p == null) return;
    try {
      p.dispose();
    } catch (_) {}
  }
}
