import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show FileImage, ImageProvider, ResizeImage;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'album_queries.dart';
import 'heif_size.dart';
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

  // ---- 縮圖與占位圖（D-099）----
  //
  // 兩種東西，分開存、不會混淆：
  // - 列表縮圖：`<images>/thumbs/<主檔名>.jpg`（長邊 480、JPEG 80），**只在本機由原圖產生**，
  //   純粹為了列表捲動順暢；永不上傳、永不下載。
  // - 占位圖（blurry placeholder）：`<images>/placeholders/<主檔名>.jpg`（長邊 32、JPEG 55，約 1KB），
  //   同步到 Drive 的 `thumbs__…`，只在原圖還沒下載完時模糊顯示；原圖到了就刪。
  // - `thumbs/<主檔名>.skip`：這張圖產生不了縮圖（壞檔、不支援的格式），不再重試。
  // 舊版下載到 `thumbs/` 的 480 縮圖照舊當列表縮圖用；原圖不在本機時也可當占位圖（模糊顯示）。
  // 主檔名＝圖片檔名去掉副檔名（uuid）。影片原檔不做縮圖，它的 poster 是一張獨立的 jpg，有自己的縮圖。

  /// 列表縮圖長邊（像素）。
  static const thumbMaxEdge = 480;

  /// 占位圖長邊與 JPEG 品質（同步到 Drive 的那一份）。
  static const placeholderMaxEdge = 32;
  static const placeholderQuality = 55;

  /// UI 畫占位圖時的解碼寬度（固定值，方便清圖片快取）。
  static const placeholderCacheWidth = 96;

  Directory get thumbDir => Directory(p.join(dir.path, 'thumbs'));
  Directory get placeholderDir => Directory(p.join(dir.path, 'placeholders'));

  static String thumbStem(String name) => p.basenameWithoutExtension(name);

  File thumbFileOf(String name) =>
      File(p.join(thumbDir.path, '${thumbStem(name)}.jpg'));
  File placeholderFileOf(String name) =>
      File(p.join(placeholderDir.path, '${thumbStem(name)}.jpg'));
  File _skipFileOf(String name) =>
      File(p.join(thumbDir.path, '${thumbStem(name)}.skip'));

  final _thumbChanges = StreamController<String>.broadcast();

  /// 有縮圖或占位圖寫進來／被刪掉時送出圖片檔名。
  Stream<String> get thumbChanges => _thumbChanges.stream;

  // 目錄的記憶體索引（主檔名集合），讓列表格子可以同步查「有沒有縮圖」而不必每格 stat。
  // 還沒載入（[loadThumbIndex] 沒呼叫過，例如測試）時退回直接查檔案。
  Set<String>? _realThumbs;
  Set<String>? _placeholders;
  Set<String>? _skipped;

  /// 掃描縮圖與占位圖目錄建立索引（App 啟動時做一次）。
  Future<void> loadThumbIndex() async {
    final real = <String>{}, holders = <String>{}, skip = <String>{};
    final d = thumbDir;
    if (await d.exists()) {
      await for (final e in d.list()) {
        final n = p.basename(e.path);
        if (n.endsWith('.tmp.jpg')) {
          // 舊版的暫用縮圖（480）：已由占位圖取代，清掉。
          try {
            await File(e.path).delete();
          } catch (_) {}
        } else if (n.endsWith('.jpg')) {
          real.add(n.substring(0, n.length - '.jpg'.length));
        } else if (n.endsWith('.skip')) {
          skip.add(n.substring(0, n.length - '.skip'.length));
        }
      }
    }
    final pd = placeholderDir;
    if (await pd.exists()) {
      await for (final e in pd.list()) {
        final n = p.basename(e.path);
        if (n.endsWith('.jpg')) holders.add(n.substring(0, n.length - 4));
      }
    }
    _realThumbs = real;
    _placeholders = holders;
    _skipped = skip;
  }

  /// 有本機列表縮圖（480；不含下載來的占位圖）。
  bool hasRealThumb(String name) =>
      _realThumbs?.contains(thumbStem(name)) ?? thumbFileOf(name).existsSync();

  /// 有下載來（或本機補產生）的占位圖。
  bool hasPlaceholder(String name) =>
      _placeholders?.contains(thumbStem(name)) ??
      placeholderFileOf(name).existsSync();

  /// 有任何可用來模糊顯示的圖（占位圖，或舊版留下的 480 縮圖）。
  bool hasThumb(String name) => hasPlaceholder(name) || hasRealThumb(name);

  /// 本機列表縮圖檔（480）；沒有為 null。占位圖不算。
  File? thumbFileFor(String name) =>
      hasRealThumb(name) ? thumbFileOf(name) : null;

  /// 原圖還沒到時模糊顯示用的檔：占位圖優先，其次舊版留下的 480 縮圖；沒有為 null。
  File? placeholderFileFor(String name) {
    if (hasPlaceholder(name)) return placeholderFileOf(name);
    if (hasRealThumb(name)) return thumbFileOf(name);
    return null;
  }

  /// 這張圖被標記為「產生不了縮圖」。
  bool thumbFailed(String name) =>
      _skipped?.contains(thumbStem(name)) ?? _skipFileOf(name).existsSync();

  /// 寫入本機列表縮圖（480，本機由原圖產生）。
  Future<void> saveThumb(String name, Uint8List bytes) async {
    await thumbDir.create(recursive: true);
    await thumbFileOf(name).writeAsBytes(bytes, flush: true);
    _realThumbs?.add(thumbStem(name));
    _evict(thumbFileOf(name));
    _thumbChanges.add(name);
  }

  /// 寫入占位圖（同步下載、thumbnailLink 備援，或本機補產生）。
  Future<void> savePlaceholder(String name, Uint8List bytes) async {
    await placeholderDir.create(recursive: true);
    await placeholderFileOf(name).writeAsBytes(bytes, flush: true);
    _placeholders?.add(thumbStem(name));
    _evict(placeholderFileOf(name));
    _thumbChanges.add(name);
  }

  void _dropPlaceholder(String name) {
    final f = placeholderFileOf(name);
    if (_placeholders?.remove(thumbStem(name)) ?? f.existsSync()) {
      try {
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      _evict(f);
      _thumbChanges.add(name);
    }
  }

  /// 清掉這個檔案的圖片快取（含 UI 用的固定解碼寬度版本）；測試環境沒有 binding 時略過。
  void _evict(File f) {
    for (final provider in <ImageProvider>[
      FileImage(f),
      ResizeImage(FileImage(f), width: placeholderCacheWidth),
    ]) {
      unawaited(provider.evict().then((_) {}, onError: (Object _) {}));
    }
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
    _evict(fileOf(name));
    _dropPlaceholder(name); // 原圖到了，占位圖用不到了
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
          // 解碼器讀不到尺寸：HEIC 直接從檔案結構讀（備援），其餘當作未知，瀑布流改用方形。
        }
        if (w <= 0 || h <= 0) {
          final heif = heifDimensions(bytes);
          if (heif != null) {
            w = heif.width;
            h = heif.height;
          }
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
