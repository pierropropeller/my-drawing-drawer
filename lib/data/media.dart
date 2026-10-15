import 'tables.dart' show MediaKind;

export 'tables.dart' show MediaKind;

/// 媒體種類的判斷與輔助（D-080，HANDOFF 3.13）。純 Dart，不依賴任何外掛。

/// 影片副檔名（小寫，不含點）。
const videoExtensions = {'mp4', 'mov', 'm4v', 'webm', '3gp', '3gpp', 'mkv'};

extension MediaKindX on MediaKind {
  bool get isImage => this == MediaKind.image;
  bool get isGif => this == MediaKind.gif;
  bool get isVideo => this == MediaKind.video;

  /// 需要自己的靜態圖（poster）才能顯示成縮圖／封面：只有影片。
  /// GIF 用檔案本身（第一格），圖片就是圖片。
  bool get needsPoster => this == MediaKind.video;

  /// 由儲存的名稱還原；null、空字串或不認得的值（較新版 App 的新種類）一律當 [MediaKind.image]。
  static MediaKind parse(String? name) {
    for (final k in MediaKind.values) {
      if (k.name == name) return k;
    }
    return MediaKind.image;
  }
}

/// 只看副檔名（含或不含路徑都可以）。不認得的副檔名＝圖片。
MediaKind mediaKindFromExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return MediaKind.image;
  final ext = fileName.substring(dot + 1).toLowerCase();
  if (ext == 'gif') return MediaKind.gif;
  if (videoExtensions.contains(ext)) return MediaKind.video;
  return MediaKind.image;
}

/// 只看檔案開頭的位元組（magic bytes）；認不出來回傳 null。
/// - GIF：`GIF87a`／`GIF89a`
/// - 影片：ISO 基礎媒體檔（mp4／mov／m4v／3gp，第 4～8 位元組是 `ftyp`，
///   但 HEIC／HEIF／AVIF 這類圖片也是 `ftyp`，靠 brand 排除）、舊式 QuickTime（`moov`／`mdat`／`wide`／`free`）、
///   Matroska／WebM（EBML 標頭 `1A 45 DF A3`）
/// - 圖片：JPEG、PNG、WebP、BMP、HEIC 等
MediaKind? mediaKindFromBytes(List<int> head) {
  bool at(int offset, String s) {
    if (head.length < offset + s.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (head[offset + i] != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (at(0, 'GIF87a') || at(0, 'GIF89a')) return MediaKind.gif;
  if (head.length >= 4 &&
      head[0] == 0x1A &&
      head[1] == 0x45 &&
      head[2] == 0xDF &&
      head[3] == 0xA3) {
    return MediaKind.video; // Matroska／WebM
  }
  if (at(4, 'ftyp')) {
    const imageBrands = {
      'heic',
      'heix',
      'heim',
      'heis',
      'hevc',
      'hevx',
      'hevm',
      'hevs',
      'mif1',
      'msf1',
      'avif',
      'avis',
    };
    if (head.length >= 12) {
      final brand = String.fromCharCodes(head.sublist(8, 12)).toLowerCase();
      if (imageBrands.contains(brand)) return MediaKind.image;
    }
    return MediaKind.video;
  }
  if (at(4, 'moov') || at(4, 'mdat') || at(4, 'wide') || at(4, 'free')) {
    return MediaKind.video; // 舊式 QuickTime .mov
  }
  if (head.length >= 3 &&
      head[0] == 0xFF &&
      head[1] == 0xD8 &&
      head[2] == 0xFF) {
    return MediaKind.image; // JPEG
  }
  if (at(1, 'PNG')) return MediaKind.image;
  if (at(0, 'RIFF') && at(8, 'WEBP')) return MediaKind.image;
  if (at(0, 'BM')) return MediaKind.image;
  return null;
}

/// 綜合判斷：先看內容（magic bytes），認不出來再看副檔名。
/// 例如改了副檔名的 GIF 仍會被認成 GIF，截斷到只剩幾個位元組的檔案則靠副檔名。
MediaKind detectMediaKind(String fileName, List<int> head) =>
    mediaKindFromBytes(head) ?? mediaKindFromExtension(fileName);

/// 給需要「靜態圖」的地方（坑封面、年度回顧、月曆格、分享卡縮圖）：
/// 圖片與 GIF 用檔案本身（GIF 由 Flutter 解碼出第一格），影片用 [posterFile]；
/// 影片還沒有截圖時回傳 null（呼叫端改選別張或顯示 icon）。
String? staticFileOf(MediaKind kind, String file, String? posterFile) {
  if (kind != MediaKind.video) return file;
  if (posterFile == null || posterFile.isEmpty) return null;
  return posterFile;
}
