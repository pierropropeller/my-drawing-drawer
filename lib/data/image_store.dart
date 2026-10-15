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
    final kind = detectMediaKind(srcName, await _readHead(source));
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
    if (kind == MediaKind.video) {
      final sink = fileOf(name).openWrite();
      try {
        await sink.addStream(source.openRead());
      } finally {
        await sink.close();
      }
    } else {
      final bytes = await source.readAsBytes();
      await fileOf(name).writeAsBytes(bytes, flush: true);
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
