import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n.dart';
import '../../media/video_playback_gate.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import 'media_badges.dart';
import 'media_icons.dart';
import 'media_source.dart';
import 'nav_bar_hidden.dart';
import 'poster_requester.dart';
import 'svg_icon.dart';

// ───────────────────────── 播放器抽象 ─────────────────────────

/// 影片播放的最小介面。正式實作包 `video_player`（[VideoPlayerPlayback]），
/// 測試換成假的（不必載入外掛）。是個 [Listenable]：狀態（播放中、位置、音量…）改變就通知。
abstract class MediaPlayback implements Listenable {
  bool get isInitialized;
  bool get isPlaying;
  bool get hasError;
  Duration get position;
  Duration get duration;

  /// 寬/高（已套用旋轉）；未知時 16:9。
  double get aspectRatio;

  /// 0～1。
  double get volume;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setVolume(double volume);

  /// 循環播放（到尾自動從頭）。
  bool get isLooping;
  Future<void> setLooping(bool looping);

  /// 影片畫面本體（沒有控制列）。
  Widget buildView(BuildContext context);
  void dispose();
}

/// `video_player` 的實作（Android 上是 ExoPlayer）。
class VideoPlayerPlayback implements MediaPlayback {
  VideoPlayerPlayback(File file) : _c = VideoPlayerController.file(file);
  final VideoPlayerController _c;

  @override
  bool get isInitialized => _c.value.isInitialized;
  @override
  bool get isPlaying => _c.value.isPlaying;
  @override
  bool get hasError => _c.value.hasError;
  @override
  Duration get position => _c.value.position;
  @override
  Duration get duration => _c.value.duration;
  @override
  double get aspectRatio {
    final a = _c.value.aspectRatio;
    return a > 0 ? a : 16 / 9;
  }

  @override
  double get volume => _c.value.volume;
  @override
  bool get isLooping => _c.value.isLooping;

  @override
  Future<void> initialize() => _c.initialize();
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);
  @override
  Future<void> setVolume(double volume) => _c.setVolume(volume);
  @override
  Future<void> setLooping(bool looping) => _c.setLooping(looping);

  @override
  Widget buildView(BuildContext context) => VideoPlayer(_c);

  @override
  void addListener(VoidCallback listener) => _c.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _c.removeListener(listener);
  @override
  void dispose() => _c.dispose();
}

typedef PlaybackFactory = MediaPlayback Function(File file);

/// 建立播放器的工廠；測試用 `overrideWithValue((f) => FakePlayback())` 換掉。
final playbackFactoryProvider = Provider<PlaybackFactory>(
  (ref) =>
      (file) => VideoPlayerPlayback(file),
);

// ───────────────────────── 控制列自動隱藏 ─────────────────────────

/// 控制列的顯示邏輯（D-080）：播放中 2 秒沒操作就隱藏，點畫面再叫出來；
/// 暫停、拖進度條時一律留著（[setHold]）。純邏輯，沒有 widget 依賴，方便測試。
class ControlsAutoHide extends ChangeNotifier {
  ControlsAutoHide({this.delay = const Duration(seconds: 2)});

  final Duration delay;
  bool _visible = true;
  bool _hold = false;
  Timer? _timer;

  bool get visible => _visible;
  bool get holding => _hold;

  /// 顯示並重新倒數（任何對控制列的操作都該呼叫）。
  void show() {
    _set(true);
    _restart();
  }

  /// 使用者點畫面：顯示中就收起來（被 hold 時收不起來），隱藏中就叫出來。
  void toggle() {
    if (_visible) {
      if (_hold) return;
      hide();
    } else {
      show();
    }
  }

  void hide() {
    _timer?.cancel();
    _set(false);
  }

  /// 暫停中、拖曳中：控制列固定顯示、不倒數；放開（false）後重新倒數。
  void setHold(bool hold) {
    if (_hold == hold) return;
    _hold = hold;
    if (hold) {
      _timer?.cancel();
      _set(true);
    } else {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    if (_hold) return;
    _timer = Timer(delay, () => _set(false));
  }

  void _set(bool v) {
    if (_visible == v) return;
    _visible = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ───────────────────────── 進度條 ─────────────────────────

/// 進度條（設計稿：4px 軌道、白色進度、12px 圓形把手；觸控範圍加高到 28px）。
/// 點一下跳到該處，水平拖曳連續改變；放開才呼叫 [onChangeEnd]。
class VideoScrubber extends StatelessWidget {
  const VideoScrubber({
    super.key,
    required this.fraction,
    this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  /// 0～1。
  final double fraction;
  final VoidCallback? onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      label: context.l10n.mediaSeekBar,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          double at(double dx) => w <= 0 ? 0 : (dx / w).clamp(0.0, 1.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              onChangeStart?.call();
              onChanged(at(d.localPosition.dx));
            },
            onTapUp: (d) => onChangeEnd(at(d.localPosition.dx)),
            onTapCancel: () => onChangeEnd(f),
            onHorizontalDragStart: (d) {
              onChangeStart?.call();
              onChanged(at(d.localPosition.dx));
            },
            onHorizontalDragUpdate: (d) => onChanged(at(d.localPosition.dx)),
            onHorizontalDragEnd: (_) => onChangeEnd(f),
            child: SizedBox(
              height: 28,
              child: Center(
                child: SizedBox(
                  height: 12,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: f,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: f * w - 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── 播放畫面＋控制列 ─────────────────────────

/// 播放中的畫面：影片置中 contain、點一下顯示／收起控制列、底部控制列
/// （暫停／播放、進度條、「0:08 / 0:24」、靜音、全螢幕）。
class VideoSurface extends ConsumerStatefulWidget {
  const VideoSurface({
    super.key,
    required this.playback,
    required this.onFullscreen,
    this.fullscreen = false,
    this.hideDelay = const Duration(seconds: 2),
    this.background,
  });

  final MediaPlayback playback;

  /// 按全螢幕（或結束全螢幕）鍵。
  final VoidCallback onFullscreen;
  final bool fullscreen;
  final Duration hideDelay;
  final Color? background;

  @override
  ConsumerState<VideoSurface> createState() => _VideoSurfaceState();
}

/// 位置文字／進度條的最短更新間隔（約 10 Hz）；位置跳動超過 [_posJump] 時不等。
const _posInterval = Duration(milliseconds: 100);
const _posJump = Duration(milliseconds: 250);

/// 效能：播放器每次通知（位置、狀態）**不** `setState` 整個畫面。影片畫面（Texture）
/// 放在 RepaintBoundary 裡、build 只在初始化時跑一次；控制列各部分用 [ValueNotifier]
/// 只重建自己（播放鍵、靜音、時間＋進度條），位置更新再節流。
class _VideoSurfaceState extends ConsumerState<VideoSurface> {
  late final ControlsAutoHide _hide = ControlsAutoHide(delay: widget.hideDelay);
  final _drag = ValueNotifier<double?>(null); // 拖曳中的進度比例
  late final _playing = ValueNotifier<bool>(_p.isPlaying);
  late final _volume = ValueNotifier<double>(_p.volume);
  late final _pos = ValueNotifier<Duration>(_p.position);
  final _clock = Stopwatch()..start();
  Duration _lastPosPush = Duration.zero;

  MediaPlayback get _p => widget.playback;

  @override
  void initState() {
    super.initState();
    _hide.show();
    _hide.setHold(!_p.isPlaying);
    _p.addListener(_onPlayback);
    // 套用裝置上記住的循環設定（內嵌與全螢幕共用同一個播放器，這裡讓兩邊都生效）。
    final loop = ref.read(settingsProvider).videoLoop;
    if (_p.isLooping != loop) unawaited(_p.setLooping(loop));
  }

  @override
  void didUpdateWidget(VideoSurface old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.removeListener(_onPlayback);
      widget.playback.addListener(_onPlayback);
      _onPlayback();
    }
  }

  @override
  void dispose() {
    _p.removeListener(_onPlayback);
    _hide.dispose();
    _drag.dispose();
    _playing.dispose();
    _volume.dispose();
    _pos.dispose();
    super.dispose();
  }

  void _onPlayback() {
    _hide.setHold(!_p.isPlaying || _drag.value != null);
    _playing.value = _p.isPlaying;
    _volume.value = _p.volume;
    final now = _clock.elapsed;
    final p = _p.position;
    final jumped = (p - _pos.value).abs() >= _posJump;
    if (jumped || now - _lastPosPush >= _posInterval) {
      _lastPosPush = now;
      _pos.value = p;
    }
  }

  Future<void> _togglePlay() async {
    _hide.show();
    if (_p.isPlaying) {
      await _p.pause();
    } else {
      // 播完了：從頭來。
      if (_p.duration > Duration.zero &&
          _p.position >= _p.duration - const Duration(milliseconds: 200)) {
        await _p.seekTo(Duration.zero);
      }
      await _p.play();
    }
  }

  Future<void> _toggleMute() async {
    _hide.show();
    await _p.setVolume(_p.volume > 0 ? 0 : 1);
  }

  Future<void> _toggleLoop() async {
    _hide.show();
    final next = !ref.read(settingsProvider).videoLoop;
    ref.read(settingsProvider.notifier).setVideoLoop(next);
    await _p.setLooping(next);
  }

  Duration _shown(Duration total) {
    final d = _drag.value;
    return d != null
        ? Duration(milliseconds: (total.inMilliseconds * d).round())
        : _pos.value;
  }

  static double _fractionOf(Duration shown, Duration total) =>
      total.inMilliseconds <= 0
      ? 0.0
      : (shown.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final total = _p.duration;
    final loop = ref.watch(settingsProvider.select((s) => s.videoLoop));
    final bottomInset = widget.fullscreen
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    return ColoredBox(
      color: widget.background ?? Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _hide.toggle,
            child: Center(
              child: AspectRatio(
                aspectRatio: _p.aspectRatio,
                // 影片自成一層：控制列、進度條重繪不會連帶重繪影片，也沒有 saveLayer 的祖先。
                child: RepaintBoundary(child: _p.buildView(context)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ListenableBuilder(
              listenable: _hide,
              builder: (context, child) => IgnorePointer(
                ignoring: !_hide.visible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _hide.visible ? 1 : 0,
                  child: child,
                ),
              ),
              child: Container(
                key: const ValueKey('videoControlBar'),
                padding: EdgeInsets.fromLTRB(12, 26, 12, 10 + bottomInset),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x001E1A17), Color(0x8C1E1A17)],
                  ),
                ),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge([_pos, _drag]),
                        builder: (context, _) => VideoScrubber(
                          key: const ValueKey('videoScrubber'),
                          fraction: _fractionOf(_shown(total), total),
                          onChangeStart: () {
                            _drag.value = _fractionOf(_pos.value, total);
                            _hide.setHold(true);
                          },
                          onChanged: (f) {
                            _hide.show();
                            _drag.value = f;
                          },
                          onChangeEnd: (f) async {
                            final target = Duration(
                              milliseconds: (total.inMilliseconds * f).round(),
                            );
                            _drag.value = null;
                            _pos.value = target;
                            _hide.setHold(!_p.isPlaying);
                            _hide.show();
                            await _p.seekTo(target);
                          },
                        ),
                      ),
                      Row(
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: _playing,
                            builder: (context, playing, _) => _BarButton(
                              key: const ValueKey('videoPlayPause'),
                              label: playing ? l10n.mediaPause : l10n.mediaPlay,
                              onTap: _togglePlay,
                              child: SvgIcon(
                                playing ? MediaIcons.pause : MediaIcons.play,
                                size: 20,
                                fill: 'currentColor',
                                strokeWidth: 0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ListenableBuilder(
                                listenable: Listenable.merge([_pos, _drag]),
                                builder: (context, _) => Text(
                                  '${formatMediaDuration(_shown(total).inMilliseconds)} / '
                                  '${formatMediaDuration(total.inMilliseconds)}',
                                  key: const ValueKey('videoTime'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _BarButton(
                            key: const ValueKey('videoLoop'),
                            label: l10n.videoloopLoop,
                            tooltip: loop
                                ? l10n.videoloopLoopOn
                                : l10n.videoloopLoopOff,
                            selected: loop,
                            onTap: _toggleLoop,
                            child: SvgIcon(
                              MediaIcons.loop,
                              size: 20,
                              color: loop ? t.accent : Colors.white,
                            ),
                          ),
                          ValueListenableBuilder<double>(
                            valueListenable: _volume,
                            builder: (context, vol, _) => _BarButton(
                              key: const ValueKey('videoMute'),
                              label: vol > 0 ? l10n.mediaMute : l10n.mediaUnmute,
                              onTap: _toggleMute,
                              child: SvgIcon(
                                vol > 0
                                    ? MediaIcons.volume
                                    : MediaIcons.volumeOff,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          _BarButton(
                            key: const ValueKey('videoFullscreen'),
                            label: widget.fullscreen
                                ? l10n.mediaExitFullscreen
                                : l10n.mediaFullscreen,
                            onTap: () {
                              _hide.show();
                              widget.onFullscreen();
                            },
                            child: SvgIcon(
                              widget.fullscreen
                                  ? MediaIcons.exitFullscreen
                                  : MediaIcons.fullscreen,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 控制列的圖示鈕：圖 20px，觸控範圍 32×32（設計稿圖與圖間距 12px，剛好由內距補成觸控範圍）。
class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.tooltip,
    this.selected,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;

  /// 長按提示（開關鈕用，說明目前狀態）。
  final String? tooltip;

  /// 非 null＝開關鈕，語意上帶「已開啟／未開啟」。
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    Widget w = SizedBox(width: 32, height: 32, child: Center(child: child));
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return Semantics(
      button: true,
      label: label,
      toggled: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: w,
      ),
    );
  }
}

// ───────────────────────── 詳情／預覽用的整合元件 ─────────────────────────

/// 影片播放的起點（從別的畫面接手時用，例如詳情頁按全螢幕開預覽頁）。
class VideoStart {
  const VideoStart(this.position, {this.autoPlay = true});
  final Duration position;
  final bool autoPlay;
}

typedef VideoFullscreenCallback = void Function(
  Duration position,
  bool playing,
);

/// 影片的詳情／預覽播放元件（D-080）。填滿父層給的空間（影片 contain）。
///
/// - **未播放**：[poster] 靜態圖（沒有就空底色）＋中央 60px 半透明圓形播放鍵＋左下角「▶ 0:24」；
///   點任何地方開始播放（**有聲音**）。
/// - **播放後**：[VideoSurface]（控制列 2 秒沒操作自動隱藏，點畫面叫出來）。
/// - [active] 為 false（滑到別頁、被蓋住）自動暫停；App 進背景也暫停。
/// - 全螢幕鍵：給了 [onFullscreen] 就交給呼叫端（詳情頁開預覽頁）；沒給就用內建的
///   橫向沉浸式全螢幕（共用同一個播放器，不中斷）。
///
/// 影片檔還沒下載完（同步中）時，點播放沒有反應（[StoredImage] 的下載角標由 poster 那層負責）。
class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.file,
    this.poster,
    this.durationMs,
    this.active = true,
    this.onFullscreen,
    this.start,
    this.badgeInset = 12,
    this.hideDelay = const Duration(seconds: 2),
  });

  final String file;
  final String? poster;
  final int? durationMs;
  final bool active;
  final VideoFullscreenCallback? onFullscreen;
  final VideoStart? start;
  final double badgeInset;
  final Duration hideDelay;

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView>
    with WidgetsBindingObserver {
  MediaPlayback? _playback;
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;

  bool get _started => _playback != null && _playback!.isInitialized;

  // 擁有播放器期間佔著全域閘門：背景補截圖不得另開播放器／解碼器（見 VideoPlaybackGate）。
  bool _gateHeld = false;
  void _holdGate(bool hold) {
    if (hold == _gateHeld) return;
    _gateHeld = hold;
    hold ? videoPlaybackGate.acquire() : videoPlaybackGate.release();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.start;
    if (s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start(from: s.position, autoPlay: s.autoPlay);
      });
    }
  }

  @override
  void didUpdateWidget(VideoPlayerView old) {
    super.didUpdateWidget(old);
    // 滑到別頁／被蓋住：直接釋放播放器（回到截圖），同時只留一個 ExoPlayer 在用。
    if (old.active && !widget.active) _deactivate();
    if (old.file != widget.file) {
      _release();
      setState(() {
        _failed = false;
        _loading = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  void _release() {
    final p = _playback;
    _playback = null;
    _holdGate(false);
    if (p != null) {
      p.pause();
      p.dispose();
    }
  }

  /// 釋放播放器並回到截圖畫面。
  void _deactivate() {
    if (_playback == null) return;
    _release();
    if (mounted) setState(() {});
  }

  void _pause() {
    final p = _playback;
    if (p != null && p.isPlaying) p.pause();
  }

  Future<void> _start({Duration? from, bool autoPlay = true}) async {
    if (_loading) return;
    final store = await ref.read(imageStoreProvider.future);
    if (_disposed) return;
    if (!store.exists(widget.file)) return; // 還沒下載完。
    setState(() {
      _loading = true;
      _failed = false;
    });
    final p = ref.read(playbackFactoryProvider)(store.fileOf(widget.file));
    _holdGate(true);
    try {
      await p.initialize();
      if (_disposed) {
        p.dispose();
        _holdGate(false);
        return;
      }
      if (from != null && from > Duration.zero) await p.seekTo(from);
      await p.setVolume(1);
      if (autoPlay && widget.active) await p.play();
    } catch (_) {
      p.dispose();
      _holdGate(false);
      if (!_disposed) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    if (_disposed) {
      p.dispose();
      _holdGate(false);
      return;
    }
    setState(() {
      _playback = p;
      _loading = false;
    });
  }

  Future<void> _fullscreen() async {
    final p = _playback;
    if (p == null) return;
    final cb = widget.onFullscreen;
    if (cb != null) {
      final playing = p.isPlaying;
      await p.pause();
      final pos = p.position;
      // 交給預覽頁接手播放：這邊的播放器先釋放，避免兩個 ExoPlayer 同時活著。
      _deactivate();
      cb(pos, playing);
      return;
    }
    await openVideoFullscreen(context, p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _playback;
    if (p != null && _started) {
      return VideoSurface(
        playback: p,
        hideDelay: widget.hideDelay,
        onFullscreen: _fullscreen,
      );
    }
    final t = Theme.of(context);
    return GestureDetector(
      key: const ValueKey('videoPoster'),
      behavior: HitTestBehavior.opaque,
      onTap: _start,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LivePoster(
            file: widget.file,
            poster: widget.poster,
            builder: (context, poster) => poster == null || poster.isEmpty
                // 沒有截圖：深色底（大 ▶ 疊在上面），不要讓播放鍵浮在米色頁面上。
                ? ColoredBox(color: VideoPlaceholder.colorOf(context))
                : StoredImage(poster, fit: BoxFit.contain, cacheWidth: 1000),
          ),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            )
          else if (_failed)
            Center(
              child: Text(
                context.l10n.mediaVideoError,
                style: t.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            )
          else
            const Center(child: MediaPlayButton()),
          if (!_failed)
            Positioned(
              left: widget.badgeInset,
              bottom: widget.badgeInset,
              child: IgnorePointer(
                child: MediaBadgeVideo(durationMs: widget.durationMs),
              ),
            ),
        ],
      ),
    );
  }
}

/// 內建全螢幕：橫向影片轉橫向、隱藏系統列，沿用同一個播放器（不中斷）。離開時還原。
Future<void> openVideoFullscreen(
  BuildContext context,
  MediaPlayback playback,
) async {
  final navigator = Navigator.of(context);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  if (playback.aspectRatio > 1) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  try {
    await navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (ctx, _, _) => HideNavBar(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: VideoSurface(
              playback: playback,
              fullscreen: true,
              background: Colors.black,
              onFullscreen: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ),
      ),
    );
  } finally {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
