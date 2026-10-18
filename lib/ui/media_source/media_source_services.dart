import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';

/// 加圖來源選單（MediaMenu）用到的「平台能力」都收在這一頁的介面後面，
/// UI 與流程只認介面；測試換成假的（`mediaSourceServicesProvider.overrideWithValue(...)`），
/// 不需要任何外掛或原生環境。

/// 「檔案」App／iCloud Drive 可選的副檔名：只收 App 看得懂的圖片、GIF、影片。
/// PSD、TIFF、SVG 等無法預覽，不收（匯入後會是壞圖）。
const fileSourceExtensions = <String>[
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'mp4',
  'mov',
  'm4v',
  'webm',
  '3gp',
  '3gpp',
  'mkv',
];

/// 從「檔案」選取（iCloud Drive、本機檔案）。
abstract class FileSourceService {
  /// 多選；使用者取消回傳空清單。選到的檔案必須已在本機可讀（iCloud 檔案由系統先下載）。
  Future<List<XFile>> pick();
}

/// 相機。
abstract class CameraSourceService {
  /// 這台裝置有沒有可用的相機（沒有就不顯示「拍照」）。
  Future<bool> isAvailable();

  /// 拍一張；使用者取消回傳 null。權限被拒等錯誤直接丟出。
  Future<XFile?> capture();
}

/// 剪貼簿裡有沒有圖。
enum ClipboardProbe {
  /// 確定沒有圖：不顯示「貼上」。
  none,

  /// 確定有圖：顯示「貼上」＋「剪貼簿有 1 張圖」。
  image,

  /// 無法在不打擾使用者的情況下確定（iOS 16+ 讀剪貼簿內容會跳出「允許貼上」）：
  /// 照常顯示「貼上」，等使用者點了才讀。
  unknown,
}

/// 貼上剪貼簿裡的圖片。
abstract class ClipboardImageService {
  /// 選單打開時呼叫；不可以觸發系統的貼上提示。
  Future<ClipboardProbe> probe();

  /// 使用者點了「貼上」才讀。存成 [dir] 底下的暫存檔回傳；剪貼簿沒有圖片回傳 null。
  Future<XFile?> read(Directory dir);
}

/// 選配：探測時已經讀到剪貼簿圖片的服務（給窄視窗 sheet 的 44px 縮圖用）。
abstract interface class ClipboardPreviewSource {
  Uint8List? get previewBytes;
}

/// 平台能力的集合。
class MediaSourceServices {
  const MediaSourceServices({
    this.files = const PlatformFileSource(),
    this.camera = const ImagePickerCameraSource(),
    this.clipboard = const PasteboardClipboardSource(),
    this.tempDir = _defaultTempDir,
  });

  final FileSourceService files;
  final CameraSourceService camera;
  final ClipboardImageService clipboard;

  /// 放「貼上」「素材庫」複製出來的暫存檔；匯入後由 `ImageStore` 另存，暫存檔交給系統清。
  final Future<Directory> Function() tempDir;

  static Future<Directory> _defaultTempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'media_source'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}

final mediaSourceServicesProvider = Provider<MediaSourceServices>(
  (ref) => const MediaSourceServices(),
);

/// `file_picker`：iOS 走 UIDocumentPicker（含 iCloud Drive），Android 走 SAF。
class PlatformFileSource implements FileSourceService {
  const PlatformFileSource();

  @override
  Future<List<XFile>> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: fileSourceExtensions,
    );
    return [
      for (final f in result)
        if (f.path != null) XFile(f.path!, name: f.name),
    ];
  }
}

/// `image_picker`：只用相機（相簿走自家選擇器）。
class ImagePickerCameraSource implements CameraSourceService {
  const ImagePickerCameraSource();

  @override
  Future<bool> isAvailable() async {
    try {
      return ImagePicker().supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<XFile?> capture() => ImagePicker().pickImage(
    source: ImageSource.camera,
    requestFullMetadata: false,
  );
}

/// `pasteboard`：沒有「只問有沒有圖」的 API，只能讀內容。
/// - iOS：讀內容會跳「允許貼上」，所以選單打開時不探測（[ClipboardProbe.unknown]），點了才讀。
/// - 其他平台：探測時就讀（沒有提示），位元組留著，使用者點「貼上」時直接用。
class PasteboardClipboardSource
    implements ClipboardImageService, ClipboardPreviewSource {
  const PasteboardClipboardSource();

  static Uint8List? _cached;

  @override
  Uint8List? get previewBytes => _cached;

  @override
  Future<ClipboardProbe> probe() async {
    _cached = null;
    if (Platform.isIOS) return ClipboardProbe.unknown;
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return ClipboardProbe.none;
      _cached = bytes;
      return ClipboardProbe.image;
    } catch (_) {
      return ClipboardProbe.none;
    }
  }

  @override
  Future<XFile?> read(Directory dir) async {
    final bytes = _cached ?? await Pasteboard.image;
    _cached = null;
    if (bytes == null || bytes.isEmpty) return null;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      p.join(dir.path, 'paste_$stamp.${sniffImageExtension(bytes)}'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path);
  }
}

/// 看檔頭決定副檔名（GIF 要認得，匯入才會當成 GIF；其餘預設 png）。
String sniffImageExtension(List<int> head) {
  bool at(int i, List<int> m) {
    if (head.length < i + m.length) return false;
    for (var k = 0; k < m.length; k++) {
      if (head[i + k] != m[k]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, const [0x47, 0x49, 0x46, 0x38])) return 'gif';
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
      at(8, const [0x57, 0x45, 0x42, 0x50])) {
    return 'webp';
  }
  return 'png';
}
