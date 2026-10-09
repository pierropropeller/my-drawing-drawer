// 同步時逐張圖片的傳輸模型（D-052）。純資料，不含任何介面文字。

enum TransferDirection { upload, download }

/// waiting＝排隊中；active＝正在傳；done＝已完成（下載失敗也算處理過，下次同步再試）。
enum TransferState { waiting, active, done }

/// 一張圖片的一次傳輸。
class SyncTransfer {
  const SyncTransfer({
    required this.file,
    required this.direction,
    this.state = TransferState.waiting,
    this.progress,
  });

  /// 圖片檔名（與資料庫、`ImageStore` 相同）；用 `imageLocationProvider(file)` 查所在位置。
  final String file;
  final TransferDirection direction;
  final TransferState state;

  /// 0~1。排隊中、或進行中但不知道總大小時為 null；完成＝1。
  final double? progress;

  bool get isWaiting => state == TransferState.waiting;
  bool get isActive => state == TransferState.active;
  bool get isDone => state == TransferState.done;
  bool get isUpload => direction == TransferDirection.upload;
  bool get isDownload => direction == TransferDirection.download;

  SyncTransfer copyWith({TransferState? state, double? progress}) =>
      SyncTransfer(
        file: file,
        direction: direction,
        state: state ?? this.state,
        progress: progress,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncTransfer &&
      other.file == file &&
      other.direction == direction &&
      other.state == state &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(file, direction, state, progress);

  @override
  String toString() => '$direction $file $state $progress';
}

/// 某張圖在格子上的下載狀態（D-052 的角標）。
class ImageDownloadStatus {
  const ImageDownloadStatus({this.isMissing = false, this.progress});

  /// 本機還沒有這張圖（要蓋淡色＋角標）。
  final bool isMissing;

  /// 下載進度 0~1；null＝排隊中或不知道（角標轉圈）。只有 [isMissing] 時有意義。
  final double? progress;

  static const present = ImageDownloadStatus();

  @override
  bool operator ==(Object other) =>
      other is ImageDownloadStatus &&
      other.isMissing == isMissing &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(isMissing, progress);
}
