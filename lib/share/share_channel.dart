import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 與原生溝通的分享 channel 包裝（D-053）。Android 由 MainActivity 實作；
/// iOS 由 AppDelegate 實作（Share Extension 經剪貼簿交接，見 docs/IOS_SHARE_EXTENSION.md）。
///
/// 原生端已把分享進來的圖片複製到 App 的 cache 資料夾，這裡只拿到檔案路徑。
/// 獨立成類別是為了測試時可以換成假的。
class ShareChannel {
  const ShareChannel();

  static const _channel = MethodChannel('io.molly.drawer/share');

  /// 冷啟動時帶來的分享（沒有，或平台沒有實作＝空）。
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
}

final shareChannelProvider = Provider<ShareChannel>(
  (ref) => const ShareChannel(),
);
