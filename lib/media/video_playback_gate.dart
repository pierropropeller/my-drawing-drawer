import 'package:flutter/foundation.dart';

/// 「正在使用者面前播放影片」的全域閘門。
///
/// 影片播放器（ExoPlayer）持有硬體解碼器；背景補截圖（[PlayerFramePosterGenerator]、
/// `PosterFixer` 的原生探測）同時開額外的解碼器會讓播放掉幀（尤其螢幕錄影常是高幀率）。
/// 播放元件在擁有播放器期間 [acquire]，釋放時 [release]；背景工作看 [active]，
/// 為 true 就不開始、進行中的也中止，閘門放開（[addListener] 通知）後再補。
class VideoPlaybackGate extends ChangeNotifier {
  int _holders = 0;

  /// 有播放器被使用者開著（播放中或暫停但尚未釋放）。
  bool get active => _holders > 0;

  void acquire() {
    _holders++;
    if (_holders == 1) notifyListeners();
  }

  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) notifyListeners();
  }

  @visibleForTesting
  void reset() {
    final was = active;
    _holders = 0;
    if (was) notifyListeners();
  }
}

/// App 共用的那一個。
final VideoPlaybackGate videoPlaybackGate = VideoPlaybackGate();
