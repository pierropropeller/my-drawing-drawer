import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 與 Android 原生（MainActivity）溝通的 channel 包裝（D-053）。
///
/// 原生端已把分享進來的圖片複製到 App 的 cache 資料夾，這裡只拿到檔案路徑。
/// 獨立成類別是為了測試時可以換成假的。
class ShareChannel {
  const ShareChannel();

  static const _channel = MethodChannel('io.molly.drawer/share');

  /// 冷啟動時帶來的分享（沒有或不在 Android 上＝空）。
  Future<List<String>> getInitialShare() async {
    try {
      final r = await _channel.invokeMethod<List<Object?>>('getInitialShare');
      return [for (final p in r ?? const []) p as String];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// App 已在執行時又有新的分享進來。傳 null 取消監聽。
  void setOnShare(void Function(List<String> paths)? onShare) {
    if (onShare == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final paths = [for (final p in call.arguments as List) p as String];
        if (paths.isNotEmpty) onShare(paths);
      }
      return null;
    });
  }

  /// 把整個 App 移到背景，回到分享來源的 App。
  Future<void> moveTaskToBack() async {
    try {
      await _channel.invokeMethod<void>('moveTaskToBack');
    } on MissingPluginException {
      // 非 Android：沒有事要做。
    } on PlatformException catch (e) {
      debugPrint('moveTaskToBack failed: $e');
    }
  }
}

final shareChannelProvider = Provider<ShareChannel>(
  (ref) => const ShareChannel(),
);
