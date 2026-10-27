import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// 影片有聲播放時的音訊焦點：播放時「暫時」借用，暫停／播完／關掉就還回去，
/// 讓其他 App（音樂、Podcast）自動恢復播放。
///
/// `video_player` 自己要的是永久焦點（別的 App 被停掉後不會自己恢復），所以播放器一律用
/// `mixWithOthers: true` 讓它不碰焦點，改由這裡統一處理：
/// - Android：`AUDIOFOCUS_GAIN_TRANSIENT`，放掉時其他 App 收到焦點恢復；
/// - iOS／iPadOS：AVAudioSession `playback`，停用時帶 `notifyOthersOnDeactivation`。
class VideoAudioFocus {
  VideoAudioFocus._();
  static final instance = VideoAudioFocus._();

  bool _configured = false;
  bool _active = false;

  /// 測試或不支援的平台不做事。
  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<AudioSession> _session() async {
    final s = await AudioSession.instance;
    if (!_configured) {
      _configured = true;
      await s.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.moviePlayback,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.movie,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        ),
      );
    }
    return s;
  }

  /// 開始有聲播放：借用焦點（其他 App 暫停）。
  void acquire() {
    if (!_supported || _active) return;
    _active = true;
    unawaited(_set(true));
  }

  /// 暫停、播完或關掉播放器：還回焦點（其他 App 恢復）。
  void release() {
    if (!_supported || !_active) return;
    _active = false;
    unawaited(_set(false));
  }

  Future<void> _set(bool active) async {
    try {
      final s = await _session();
      await s.setActive(active);
    } catch (e) {
      debugPrint('audio focus: $e');
    }
  }
}
