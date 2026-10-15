import '../../data/album_queries.dart' show NewImage;
import '../../data/entity_queries.dart' show ImageRef;
import '../../data/media.dart';

/// 一個要顯示的媒體（圖片／GIF／影片，D-080）的最小描述。
///
/// 各種資料來源（`ImageRef`、`NewImage`、官方圖／同人圖／雜物／素材庫的資料列、`AlbumImage`）
/// 都轉成它，再交給 `media_widgets.dart` 的元件，這樣元件不必認得每一種資料型別。
class MediaSource {
  const MediaSource({
    required this.file,
    this.kind = MediaKind.image,
    this.durationMs,
    this.poster,
    this.width = 0,
    this.height = 0,
  });

  /// 腦洞／草稿／成圖／推活的 `ImageRef`。
  MediaSource.fromImageRef(ImageRef r)
    : file = r.file,
      kind = r.kind,
      durationMs = r.durationMs,
      poster = r.poster,
      width = r.width,
      height = r.height;

  /// 表單裡已匯入的 `NewImage`。
  MediaSource.fromNewImage(NewImage n)
    : file = n.file,
      kind = n.kind,
      durationMs = n.durationMs,
      poster = n.posterFile,
      width = n.width,
      height = n.height;

  /// 官方圖／同人圖／雜物／素材庫的資料列：欄位直接是 `row.kind`／`row.durationMs`／`row.posterFile`。
  /// [kind] 傳 `row.kind`（`MediaKind`）。
  const MediaSource.row({
    required this.file,
    required this.kind,
    this.durationMs,
    String? posterFile,
    this.width = 0,
    this.height = 0,
  }) : poster = posterFile;

  final String file;
  final MediaKind kind;
  final int? durationMs;

  /// 影片第一格截圖的檔名（影片才有）。
  final String? poster;
  final int width;
  final int height;

  bool get isVideo => kind == MediaKind.video;
  bool get isGif => kind == MediaKind.gif;

  /// 需要靜態圖的地方用的檔名：影片＝[poster]（可能是 null），圖片與 GIF＝[file]。
  String? get staticFile => staticFileOf(kind, file, poster);

  double get aspect => (width > 0 && height > 0) ? width / height : 1;
}

/// 影片長度的顯示字串：`0:24`、`1:05`、一小時以上 `1:02:03`。四捨五入到秒。
String formatMediaDuration(int? ms) {
  final total = ((ms ?? 0) / 1000).round().clamp(0, 359999);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
