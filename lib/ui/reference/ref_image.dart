import '../../data/media.dart';
import '../album/album_image.dart';
import '../common/media_source.dart';

/// 參考圖檢視要顯示的一張圖（所有來源共用的最小描述）。
///
/// 官方圖／同人圖（[AlbumImage]）用 [RefImage.fromAlbum] 轉；草稿、腦洞、成圖的圖片
/// 直接建構即可（沒有 [album] 就沒有資料面板的動作，只顯示分類／tag／加入日期）。
class RefImage {
  const RefImage({
    required this.id,
    required this.file,
    this.width = 0,
    this.height = 0,
    this.kind = MediaKind.image,
    this.durationMs,
    this.posterFile,
    this.title,
    this.category,
    this.tags,
    this.addedAt,
    this.album,
    this.pitId,
  });

  /// 官方圖／同人圖。[pitId] 是所屬坑（設為封面、截取影片格都要用）；
  /// [title] 是頂欄標題，例如「坑A · 官方圖冊」；
  /// [tags] 留空（null）＝由檢視器依資料庫自己查（官方圖與同人圖都有 tag）。
  factory RefImage.fromAlbum(
    AlbumImage im, {
    required String pitId,
    String? title,
    List<String>? tags,
  }) => RefImage(
    id: im.id,
    file: im.file,
    width: im.width,
    height: im.height,
    kind: im.media.kind,
    durationMs: im.durationMs,
    posterFile: im.posterFile,
    title: title,
    category: im.groupName,
    tags: tags,
    addedAt: im.createdAt,
    album: im,
    pitId: pitId,
  );

  final String id;

  /// 圖片檔名（相對於圖片資料夾）。檢視狀態以它為鍵。
  final String file;
  final int width;
  final int height;
  final MediaKind kind;
  final int? durationMs;
  final String? posterFile;

  /// 頂欄標題（通常是「坑名 · 分區名」）。
  final String? title;

  /// 資料面板的「分類」（官方圖冊的分組、同人圖的出處）。
  final String? category;

  /// 資料面板的 tag 名稱（不含 #）；null＝依資料庫查。
  final List<String>? tags;
  final DateTime? addedAt;

  /// 來自官方圖冊／同人圖／雜物時才有：資料面板的動作靠它。
  final AlbumImage? album;
  final String? pitId;

  bool get isVideo => kind == MediaKind.video;
  bool get isGif => kind == MediaKind.gif;

  /// 縮圖用的靜態檔名（影片＝poster，可能是 null）。
  String? get staticFile => staticFileOf(kind, file, posterFile);

  MediaSource get media => MediaSource(
    file: file,
    kind: kind,
    durationMs: durationMs,
    poster: posterFile,
    width: width,
    height: height,
  );
}
