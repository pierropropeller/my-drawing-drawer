import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// 影片參考檢視需要的播放介面（比 `MediaPlayback` 多了速度、循環）。
///
/// 獨立成介面是為了測試換成假的、也讓 iOS 日後可以換原生實作；
/// 正式實作包 `video_player`（Android 是 ExoPlayer、iOS 是 AVPlayer）。
/// 是個 [Listenable]：播放狀態、位置改變就通知。
abstract class RefVideoPlayback implements Listenable {
  bool get isInitialized;
  bool get isPlaying;
  bool get hasError;
  Duration get position;
  Duration get duration;

  /// 寬/高（已套用旋轉）；未知時 16:9。
  double get aspectRatio;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();

  /// 跳到指定位置。`video_player` 的 seek 不保證精準到格（見 `RefVideoViewer` 的說明）。
  Future<void> seekTo(Duration position);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setLooping(bool looping);

  /// 0～1。
  Future<void> setVolume(double volume);

  /// 影片畫面本體（沒有控制列）。
  Widget buildView(BuildContext context);
  void dispose();
}

class VideoPlayerRefPlayback implements RefVideoPlayback {
  VideoPlayerRefPlayback(File file) : _c = VideoPlayerController.file(file);
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
  Future<void> initialize() => _c.initialize();
  @override
  Future<void> play() => _c.play();
  @override
  Future<void> pause() => _c.pause();
  @override
  Future<void> seekTo(Duration position) => _c.seekTo(position);
  @override
  Future<void> setPlaybackSpeed(double speed) => _c.setPlaybackSpeed(speed);
  @override
  Future<void> setLooping(bool looping) => _c.setLooping(looping);
  @override
  Future<void> setVolume(double volume) => _c.setVolume(volume);

  @override
  Widget buildView(BuildContext context) => VideoPlayer(_c);

  @override
  void addListener(VoidCallback listener) => _c.addListener(listener);
  @override
  void removeListener(VoidCallback listener) => _c.removeListener(listener);
  @override
  void dispose() => _c.dispose();
}

typedef RefPlaybackFactory = RefVideoPlayback Function(File file);

/// 建立播放器的工廠；測試用 `overrideWithValue((f) => FakeRefPlayback())` 換掉。
final refPlaybackFactoryProvider = Provider<RefPlaybackFactory>(
  (ref) =>
      (file) => VideoPlayerRefPlayback(file),
);
