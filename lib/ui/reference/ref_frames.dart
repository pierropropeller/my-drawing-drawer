import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一批抽出的影片畫面（JPEG）與影片的幀率。
class ExtractedFrames {
  const ExtractedFrames({required this.frames, this.fps});

  /// 與要求的位置一一對應；某一格抽不到＝null。
  final List<Uint8List?> frames;

  /// 影片幀率（metadata 讀得到才有）；null＝未知，呼叫端用 30。
  final double? fps;
}

/// 從影片抽指定時間點的畫面（時間軸縮圖、「截取此格」）。純 Dart 做不到，交給原生。
///
/// 獨立成介面，測試換成假的；不支援或失敗一律回傳 null（不丟例外），
/// 呼叫端退回用 poster／色塊。
abstract class FrameExtractor {
  /// [positionsMs]：毫秒。[exact] true＝要最接近該時間的畫面（較慢，截取用），
  /// false＝最近的關鍵格即可（縮圖用）。
  Future<ExtractedFrames?> extract(
    String path,
    List<int> positionsMs, {
    int maxSide = 240,
    int quality = 70,
    bool exact = false,
  });
}

/// 正式實作：`io.molly.drawer/media` channel 的 `extractFrames`（Android 見 MainActivity.kt）。
/// iOS 日後在同一個 channel 補 Swift 實作（AVAssetImageGenerator）即可；
/// 沒有實作的平台（測試、桌面）是 null。
class ChannelFrameExtractor implements FrameExtractor {
  const ChannelFrameExtractor();

  static const _channel = MethodChannel('io.molly.drawer/media');

  @override
  Future<ExtractedFrames?> extract(
    String path,
    List<int> positionsMs, {
    int maxSide = 240,
    int quality = 70,
    bool exact = false,
  }) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(
        'extractFrames',
        {
          'path': path,
          'positionsMs': positionsMs,
          'maxSide': maxSide,
          'quality': quality,
          'exact': exact,
        },
      );
      if (r == null) return null;
      final raw = (r['frames'] as List?) ?? const [];
      return ExtractedFrames(
        frames: [for (final f in raw) f is Uint8List ? f : null],
        fps: (r['fps'] as num?)?.toDouble(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final frameExtractorProvider = Provider<FrameExtractor>(
  (ref) => const ChannelFrameExtractor(),
);
