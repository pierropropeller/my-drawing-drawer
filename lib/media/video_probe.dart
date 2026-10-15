import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 影片探測的結果（D-080）：寬高（已套用旋轉）、長度、第一格截圖（JPEG）。
class VideoMeta {
  const VideoMeta({
    this.width = 0,
    this.height = 0,
    this.durationMs,
    this.poster,
  });

  final int width;
  final int height;
  final int? durationMs;

  /// 第一格截圖的 JPEG 位元組；取不到＝null。
  final Uint8List? poster;

  bool get hasPoster => poster != null && poster!.isNotEmpty;
}

/// 讀影片檔的寬高、長度與第一格截圖。純 Dart 做不到，交給原生（MediaMetadataRetriever）。
///
/// 獨立成介面，測試時換成假的；失敗一律回傳 null（不丟例外），呼叫端照樣能存影片，
/// 只是沒有截圖，之後由 `generateMissingPosters` 補。
abstract class VideoProbe {
  Future<VideoMeta?> probe(String path, {int maxPosterSide = 720});
}

/// 正式實作：`io.molly.drawer/media` channel（見 MainActivity.kt）。
/// 不在 Android 上（測試、桌面）或原生失敗＝null。
class ChannelVideoProbe implements VideoProbe {
  const ChannelVideoProbe();

  static const _channel = MethodChannel('io.molly.drawer/media');

  @override
  Future<VideoMeta?> probe(String path, {int maxPosterSide = 720}) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('probeVideo', {
        'path': path,
        'maxSide': maxPosterSide,
      });
      if (r == null) return null;
      return VideoMeta(
        width: (r['width'] as num?)?.toInt() ?? 0,
        height: (r['height'] as num?)?.toInt() ?? 0,
        durationMs: (r['durationMs'] as num?)?.toInt(),
        poster: r['poster'] as Uint8List?,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final videoProbeProvider = Provider<VideoProbe>(
  (ref) => const ChannelVideoProbe(),
);
