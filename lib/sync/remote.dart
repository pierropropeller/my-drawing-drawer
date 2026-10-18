import 'dart:typed_data';

import '../l10n/l10n.dart';

class RemoteFile {
  const RemoteFile({required this.name, required this.modified, this.id});
  final String name;
  final String modified; // 遠端的修改時間（字串，只用來比對是否變動）
  final String? id;
}

class SyncAuthException implements Exception {
  SyncAuthException([String? message])
    : message = message ?? l10nStatic.syncAuthExpired;
  final String message;
  @override
  String toString() => message;
}

/// 網絡層失敗（逾時、斷線、伺服器暫時錯誤）且重試用盡：向上報錯，由同步流程顯示並稍後重排。
class SyncNetworkException implements Exception {
  SyncNetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 單次同步太久沒有任何進展而被看門狗中止。
class SyncStalledException implements Exception {
  SyncStalledException() : message = l10nStatic.syncuiStalled;
  final String message;
  @override
  String toString() => message;
}

/// 傳輸中的位元組進度：[done] 已傳位元組，[total] 總位元組（未知為 null）。
typedef TransferProgress = void Function(int done, int? total);

/// 遠端儲存（Google Drive 專用資料夾）。扁平命名空間：
/// `meta__{kind}__{id}.json`、`images__{檔名}`。
abstract class SyncRemote {
  Future<List<RemoteFile>> list();

  /// 下載；[onProgress] 在收到資料時回報（可能不回報，例如檔案很小）。
  Future<Uint8List?> download(String name, {TransferProgress? onProgress});

  /// 上傳（新增或覆蓋），回傳遠端的修改時間字串。[onProgress] 回報已送出的位元組。
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  });
}

/// 遠端能提供「由雲端自己產生的縮圖」時實作（D-099 的舊資料備援）。
/// 新增成獨立介面（而不是塞進 [SyncRemote]），舊的／測試用的遠端不必改。
abstract interface class ThumbnailFallbackRemote {
  /// 取得 [name]（遠端原圖檔名，例如 `images__xxx.jpg`）由雲端產生的縮圖（長邊約 480）；
  /// 雲端沒有縮圖、連結過期、請求失敗都回傳 null（不丟例外，授權過期除外）。
  Future<Uint8List?> fallbackThumbnail(String name);
}

/// 記憶體遠端：測試與（日後）本機資料夾備份共用。
///
/// 測試可設 [progressSteps] > 0 模擬分段傳輸：每次傳輸分成這麼多段回報進度，
/// 段與段之間等 [stepDelay]；[onTransfer] 在每次傳輸開始時呼叫（可用來暫停／觀察）。
class MemoryRemote implements SyncRemote, ThumbnailFallbackRemote {
  MemoryRemote({
    this.progressSteps = 0,
    this.stepDelay = Duration.zero,
    this.onTransfer,
  });

  final int progressSteps;
  final Duration stepDelay;
  final Future<void> Function(String name, bool isUpload)? onTransfer;

  final Map<String, Uint8List> files = {};

  /// 測試用：模擬雲端自己產生的縮圖（遠端原圖檔名 → 位元組）。
  final Map<String, Uint8List> fallbackThumbs = {};

  /// 測試用：呼叫 [fallbackThumbnail] 的次數。
  int fallbackCalls = 0;
  final Map<String, int> _version = {};
  int _clock = 0;

  Future<void> _simulate(
    String name,
    bool isUpload,
    int length,
    TransferProgress? onProgress,
  ) async {
    await onTransfer?.call(name, isUpload);
    if (progressSteps <= 0 || onProgress == null) return;
    for (var i = 1; i <= progressSteps; i++) {
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      onProgress(length * i ~/ progressSteps, length);
    }
  }

  @override
  Future<Uint8List?> fallbackThumbnail(String name) async {
    fallbackCalls++;
    return fallbackThumbs[name];
  }

  @override
  Future<List<RemoteFile>> list() async => [
    for (final n in files.keys)
      RemoteFile(name: n, modified: '${_version[n]}', id: n),
  ];

  @override
  Future<Uint8List?> download(
    String name, {
    TransferProgress? onProgress,
  }) async {
    final bytes = files[name];
    if (bytes == null) return null;
    await _simulate(name, false, bytes.length, onProgress);
    return bytes;
  }

  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) async {
    await _simulate(name, true, bytes.length, onProgress);
    files[name] = bytes;
    _version[name] = ++_clock;
    return '${_version[name]}';
  }
}
