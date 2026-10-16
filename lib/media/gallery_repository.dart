import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;

/// 自家圖片選擇器（D-084）讀相簿的抽象。真正的實作在 `photo_manager_gallery.dart`；
/// 測試用假的實作，不需要任何外掛。

/// 讀取相簿的權限狀態。
enum GalleryPermission {
  /// 全部可讀。
  granted,

  /// 只開放部分相片（Android 14+「選取相片和影片」）。
  limited,

  /// 拒絕（或系統限制）。
  denied,
}

/// 相簿（資料夾）的種類，決定 pills 的排序：全部、截圖、相機，其餘按張數多到少。
enum GalleryAlbumKind { all, screenshot, camera, other }

class GalleryAlbum {
  const GalleryAlbum({
    required this.id,
    required this.name,
    required this.count,
    this.kind = GalleryAlbumKind.other,
  });

  final String id;
  final String name;
  final int count;
  final GalleryAlbumKind kind;
}

enum GalleryItemType { image, gif, video }

class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.createdAt,
    this.type = GalleryItemType.image,
    this.durationMs,
  });

  final String id;

  /// 拍攝／建立時間（本地時間），用來按日期分組。
  final DateTime createdAt;
  final GalleryItemType type;

  /// 影片長度（毫秒）。
  final int? durationMs;

  bool get isVideo => type == GalleryItemType.video;
  bool get isGif => type == GalleryItemType.gif;
}

abstract class GalleryRepository {
  const GalleryRepository();

  /// 檢查目前權限，不跳系統對話框。
  Future<GalleryPermission> permission();

  /// 要求權限（第一次會跳系統對話框）。
  Future<GalleryPermission> requestPermission();

  /// 相簿列表（含「全部」，kind＝all；沒有相片的相簿不用回）。順序不拘，由選擇器排序。
  Future<List<GalleryAlbum>> albums({required bool imagesOnly});

  /// 某相簿裡 [start, end) 的項目，新到舊。
  Future<List<GalleryItem>> items(
    String albumId, {
    required int start,
    required int end,
    required bool imagesOnly,
  });

  /// 縮圖的 JPEG 位元組（正方形、邊長 [size] px）；取不到回 null。
  Future<Uint8List?> thumbnail(String itemId, int size);

  /// 匯出原檔（HEIC、影片都原樣）；取不到回 null。
  Future<XFile?> export(String itemId);

  /// 部分權限下重新選擇要開放的相片（Android 14+ 開系統選擇畫面）。
  Future<void> manageLimited();

  /// 開系統的 App 設定頁。
  Future<void> openSettings();
}
