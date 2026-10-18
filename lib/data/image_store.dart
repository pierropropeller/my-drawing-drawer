import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'album_queries.dart';
import 'media.dart';

/// 圖片存在 App 內部資料夾；資料庫只記錄檔名（相對路徑），之後同步到 Drive 也用同一個名字。
class ImageStore {
  ImageStore(this.dir);
  final Directory dir;

  final _changes = StreamController<String>.broadcast();

  /// 有檔案寫進來（匯入或同步下載完成）時送出檔名。
  Stream<String> get changes => _changes.stream;

  File fileOf(String name) => File(p.join(dir.path, name));

  /// 本機是否已有這個檔案（同步還沒下載完的圖是 false）。
  bool exists(String name) => fileOf(name).existsSync();

  /// 這個檔案是否存在，檔案下載完成時會再送一次 true。
  /// 供 UI 對「還沒下載完」的封面蓋一層淡色＋下載 icon（D-028）。
  Stream<bool> watchExists(String name) {
    late final StreamController<bool> out;
    StreamSubscription<String>? sub;
    out = StreamController<bool>(
      onListen: () {
        var last = exists(name);
        out.add(last);
        sub = changes.listen((n) {
          if (n != name) return;
          final now = exists(name);
          if (now != last) {
            last = now;
            out.add(now);
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  // ---- 縮圖（D-099）----
  //
  // 本機縮圖放在 `<images>/thumbs/`：
  // - `<主檔名>.jpg`      ＝正式縮圖（長邊 480、JPEG 80；本機產生或從 Drive 的 thumbs 下載）
  // - `<主檔名>.tmp.jpg`  ＝暫用縮圖（Drive `thumbnailLink` 備援；正式縮圖到了就被取代）
  // - `<主檔名>.skip`     ＝這張圖產生不了縮圖（壞檔、不支援的格式）；補縮圖時不再重試
  // 主檔名＝圖片檔名去掉副檔名（uuid）。影片原檔不做縮圖，它的 poster 是一張獨立的 jpg，有自己的縮圖。

  /// 縮圖長邊（像素）。
  static const thumbMaxEdge = 480;

  Directory get thumbDir => Directory(p.join(dir.path, 'thumbs'));

  static String thumbStem(String name) => p.basenameWithoutExtension(name);

  File thumbFileOf(String name) =>
      File(p.join(thumbDir.path, '${thumbStem(name)}.jpg'));
  File tempThumbFileOf(String name) =>
      File(p.join(thumbDir.path, '${thumbStem(name)}.tmp.jpg'));
  File _skipFileOf(String name) =>
      File(p.join(thumbDir.path, '${thumbStem(name)}.skip'));

  final _thumbChanges = StreamController<String>.broadcast();

  /// 有縮圖寫進來（含取代暫用縮圖）時送出圖片檔名。
  Stream<String> get thumbChanges => _thumbChanges.stream;

  // 縮圖目錄的記憶體索引（主檔名集合），讓列表格子可以同步查「有沒有縮圖」而不必每格 stat。
  // 還沒載入（[loadThumbIndex] 沒呼叫過，例如測試）時退回直接查檔案。
  Set<String>? _realThumbs;
  Set<String>? _tempThumbs;
  Set<String>? _skipped;

  /// 掃描縮圖目錄建立索引（App 啟動時做一次）。
  Future<void> loadThumbIndex() async {
    final real = <String>{}, temp = <String>{}, skip = <String>{};
    final d = thumbDir;
    if (await d.exists()) {
      await for (final e in d.list()) {
        final n = p.basename(e.path);
        if (n.endsWith('.tmp.jpg')) {
          temp.add(n.substring(0, n.length - '.tmp.jpg'.length));
        } else if (n.endsWith('.jpg')) {
          real.add(n.substring(0, n.length - '.jpg'.length));
        } else if (n.endsWith('.skip')) {
          skip.add(n.substring(0, n.length - '.skip'.length));
        }
      }
    }
    _realThumbs = real;
    _tempThumbs = temp;
    _skipped = skip;
  }

  /// 有正式縮圖。
  bool hasRealThumb(String name) =>
      _realThumbs?.contains(thumbStem(name)) ?? thumbFileOf(name).existsSync();

  bool hasTempThumb(String name) =>
      _tempThumbs?.contains(thumbStem(name)) ??
      tempThumbFileOf(name).existsSync();

  /// 有任何可用的縮圖（正式或暫用）。
  bool hasThumb(String name) => hasRealThumb(name) || hasTempThumb(name);

  /// 目前該用哪個縮圖檔（正式優先，其次暫用）；沒有為 null。
  File? thumbFileFor(String name) {
    if (hasRealThumb(name)) return thumbFileOf(name);
    if (hasTempThumb(name)) return tempThumbFileOf(name);
    return null;
  }

  /// 這張圖被標記為「產生不了縮圖」。
  bool thumbFailed(String name) =>
      _skipped?.contains(thumbStem(name)) ?? _skipFileOf(name).existsSync();

  /// 寫入正式縮圖（本機產生或同步下載），並取代暫用縮圖。
  Future<void> saveThumb(String name, Uint8List bytes) async {
    await thumbDir.create(recursive: true);
    await thumbFileOf(name).writeAsBytes(bytes, flush: true);
    _realThumbs?.add(thumbStem(name));
    final tmp = tempThumbFileOf(name);
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync();
      } catch (_) {}
    }
    _tempThumbs?.remove(thumbStem(name));
    _thumbChanges.add(name);
  }

  /// 寫入暫用縮圖（Drive thumbnailLink 備援）。已經有正式縮圖就不寫。
  Future<void> saveTempThumb(String name, Uint8List bytes) async {
    if (hasRealThumb(name)) return;
    await thumbDir.create(recursive: true);
    await tempThumbFileOf(name).writeAsBytes(bytes, flush: true);
    _tempThumbs?.add(thumbStem(name));
    _thumbChanges.add(name);
  }

  /// 標記這張圖產生不了縮圖。
  Future<void> markThumbFailed(String name) async {
    await thumbDir.create(recursive: true);
    await _skipFileOf(name).writeAsBytes(const [], flush: true);
    _skipped?.add(thumbStem(name));
  }

  /// 這張圖的縮圖有變動時送出遞增的版本號（先送一次目前值）；UI 收到後重新取 [thumbFileFor]。
  Stream<int> watchThumb(String name) {
    late final StreamController<int> out;
    StreamSubscription<String>? sub;
    out = StreamController<int>(
      onListen: () {
        var v = 0;
        out.add(v);
        sub = thumbChanges.listen((n) {
          if (n == name) out.add(++v);
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  /// 寫入一個檔案（同步下載用），完成後通知 [changes]。
  Future<void> save(String name, Uint8List bytes) async {
    await dir.create(recursive: true);
    await fileOf(name).writeAsBytes(bytes, flush: true);
    _changes.add(name);
  }

  /// 把選到的檔案複製進 App 資料夾，判斷種類（圖片／GIF／影片，D-080）並讀出寬高。
  ///
  /// - 原檔照搬，不轉檔、不重新編碼；副檔名保留（認不出或太長時：圖片 `.jpg`、GIF `.gif`、影片 `.mp4`）。
  /// - 種類先看內容（magic bytes）再看副檔名（見 [detectMediaKind]）。
  /// - 圖片與 GIF 會嘗試讀出寬高（GIF 取第一格）；影片的寬高、長度、截圖這裡**不探測**
  ///   （純 Dart 做不到），回傳 `width/height = 0`、`durationMs = null`、`posterFile = null`，
  ///   由 UI 探測後用 [importMedia] 的參數，或 `AppDatabase.setMediaMeta` 補上。
  /// - 影片以串流複製，不整個讀進記憶體。
  Future<NewImage> import(XFile source) => importMedia(source);

  /// [import] 的完整版：UI 已經探測過影片的寬高、長度、第一格截圖時一併交進來。
  ///
  /// - [width]／[height]／[durationMs] 有給就以給的為準（沒給的照 [import] 的做法）。
  /// - [posterBytes]：影片第一格截圖的位元組，存成獨立的檔案（副檔名 [posterExt]，預設 `jpg`），
  ///   檔名放進 [NewImage.posterFile]；只對影片有意義，圖片與 GIF 會忽略。
  Future<NewImage> importMedia(
    XFile source, {
    int? width,
    int? height,
    int? durationMs,
    Uint8List? posterBytes,
    String posterExt = 'jpg',
  }) async {
    await dir.create(recursive: true);
    final srcName = source.path.isNotEmpty ? source.path : source.name;
    // 副檔名說是影片的才先讀開頭、再串流複製（不整個讀進記憶體）；
    // 其餘（圖片、GIF、沒有副檔名）整個讀進來，種類由內容判斷——步驟越少越好，
    // 也讓表單測試裡有限的非同步等待夠用。
    Uint8List? bytes;
    late final MediaKind kind;
    if (mediaKindFromExtension(srcName) == MediaKind.video) {
      kind = detectMediaKind(srcName, await _readHead(source));
    } else {
      bytes = await source.readAsBytes();
      kind = detectMediaKind(
        srcName,
        bytes.length > 32 ? bytes.sublist(0, 32) : bytes,
      );
    }
    var ext = p.extension(srcName).toLowerCase();
    if (ext.isEmpty || ext.length > 6) {
      ext = switch (kind) {
        MediaKind.image => '.jpg',
        MediaKind.gif => '.gif',
        MediaKind.video => '.mp4',
      };
    }
    final name = '${const Uuid().v4()}$ext';
    var w = 0, h = 0;
    if (bytes == null) {
      final sink = fileOf(name).openWrite();
      try {
        await sink.addStream(source.openRead());
      } finally {
        await sink.close();
      }
    } else {
      await fileOf(name).writeAsBytes(bytes, flush: true);
      if (kind != MediaKind.video) {
        try {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final desc = await ui.ImageDescriptor.encoded(buffer);
          w = desc.width;
          h = desc.height;
          desc.dispose();
          buffer.dispose();
        } catch (_) {
          // 讀不到尺寸就當作未知，瀑布流改用方形。
        }
      }
    }
    String? poster;
    if (kind == MediaKind.video &&
        posterBytes != null &&
        posterBytes.isNotEmpty) {
      poster = await savePoster(posterBytes, ext: posterExt);
    }
    _changes.add(name);
    return NewImage(
      file: name,
      width: width ?? w,
      height: height ?? h,
      kind: kind,
      durationMs: kind == MediaKind.video ? durationMs : null,
      posterFile: poster,
    );
  }

  /// 把影片截圖存成獨立檔案（跟圖片同一個資料夾、同步方式也相同），回傳檔名。
  Future<String> savePoster(Uint8List bytes, {String ext = 'jpg'}) async {
    await dir.create(recursive: true);
    final clean = ext.replaceAll('.', '').toLowerCase();
    final name = '${const Uuid().v4()}.${clean.isEmpty ? 'jpg' : clean}';
    await fileOf(name).writeAsBytes(bytes, flush: true);
    _changes.add(name);
    return name;
  }

  /// 讀檔案開頭供判斷種類用；讀不到就回傳空（改靠副檔名）。
  Future<List<int>> _readHead(XFile source) async {
    try {
      final out = <int>[];
      await for (final chunk in source.openRead(0, 32)) {
        out.addAll(chunk);
        if (out.length >= 32) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
