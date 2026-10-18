import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:photo_manager/photo_manager.dart';

import 'gallery_repository.dart';

/// 用 `photo_manager` 讀手機相簿（MediaStore）的 [GalleryRepository]（D-084）。
///
/// 縮圖走系統 thumbnail API；原檔用 [AssetEntity.originFile]（HEIC、影片都原樣，
/// Android 10+ 外掛會先複製一份到自己的 cache 再回傳路徑）。
class PhotoManagerGallery extends GalleryRepository {
  PhotoManagerGallery();

  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  /// 新到舊（以建立時間）。
  ///
  /// **每次讀相簿都要重新建**，不能存成 `static final`：`FilterOptionGroup` 的建立／修改時間條件
  /// 預設是 `max = 建立當下的 DateTime.now()`，套件不會自己更新。存成靜態會把上限凍結在第一次
  /// 打開選擇器的時刻，之後才拍／才存進手機的相片全被濾掉，要殺掉 App 重開才看得到。
  /// 上限多給一天，避開手機時鐘與 MediaStore 時間的小誤差。
  static FilterOptionGroup buildFilter({DateTime Function()? now}) {
    final upper = (now ?? DateTime.now)().add(const Duration(days: 1));
    return FilterOptionGroup(
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
      createTimeCond: DateTimeCond(min: DateTimeCond.zero, max: upper),
      updateTimeCond: DateTimeCond(min: DateTimeCond.zero, max: upper),
    );
  }

  final Map<String, AssetPathEntity> _paths = {};
  final Map<String, AssetEntity> _entities = {};

  static GalleryPermission _map(PermissionState s) => switch (s) {
    PermissionState.authorized => GalleryPermission.granted,
    PermissionState.limited => GalleryPermission.limited,
    _ => GalleryPermission.denied,
  };

  @override
  Future<GalleryPermission> permission() async => _map(
    await PhotoManager.getPermissionState(requestOption: _permissionOption),
  );

  @override
  Future<GalleryPermission> requestPermission() async => _map(
    await PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    ),
  );

  static GalleryAlbumKind _kindOf(AssetPathEntity p) {
    if (p.isAll) return GalleryAlbumKind.all;
    final n = p.name.toLowerCase();
    if (n.contains('screenshot') || n.contains('截圖') || n.contains('截屏')) {
      return GalleryAlbumKind.screenshot;
    }
    if (n == 'camera' || n.contains('相機') || n == 'dcim') {
      return GalleryAlbumKind.camera;
    }
    return GalleryAlbumKind.other;
  }

  @override
  Future<List<GalleryAlbum>> albums({required bool imagesOnly}) async {
    final paths = await PhotoManager.getAssetPathList(
      hasAll: true,
      type: imagesOnly ? RequestType.image : RequestType.common,
      filterOption: buildFilter(),
    );
    _paths.clear();
    final out = <GalleryAlbum>[];
    for (final p in paths) {
      final count = await p.assetCountAsync;
      if (count <= 0) continue;
      _paths[p.id] = p;
      out.add(
        GalleryAlbum(id: p.id, name: p.name, count: count, kind: _kindOf(p)),
      );
    }
    return out;
  }

  @override
  Future<List<GalleryItem>> items(
    String albumId, {
    required int start,
    required int end,
    required bool imagesOnly,
  }) async {
    final path = _paths[albumId];
    if (path == null) return const [];
    final list = await path.getAssetListRange(start: start, end: end);
    final out = <GalleryItem>[];
    for (final e in list) {
      if (e.type != AssetType.image && e.type != AssetType.video) continue;
      if (imagesOnly && e.type != AssetType.image) continue;
      _entities[e.id] = e;
      final gif =
          e.type == AssetType.image &&
          ((e.mimeType ?? '').toLowerCase() == 'image/gif' ||
              (e.title ?? '').toLowerCase().endsWith('.gif'));
      out.add(
        GalleryItem(
          id: e.id,
          createdAt: e.createDateTime,
          type: e.type == AssetType.video
              ? GalleryItemType.video
              : gif
              ? GalleryItemType.gif
              : GalleryItemType.image,
          durationMs: e.type == AssetType.video ? e.duration * 1000 : null,
        ),
      );
    }
    return out;
  }

  @override
  Future<Uint8List?> thumbnail(String itemId, int size) async {
    final e = _entities[itemId];
    if (e == null) return null;
    return e.thumbnailDataWithSize(ThumbnailSize.square(size), quality: 80);
  }

  @override
  Future<XFile?> export(String itemId) async {
    final e = _entities[itemId];
    if (e == null) return null;
    final f = await e.originFile ?? await e.file;
    return f == null ? null : XFile(f.path);
  }

  @override
  Future<void> manageLimited() => PhotoManager.presentLimited();

  @override
  Future<void> openSettings() => PhotoManager.openSetting();
}
