import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'album_queries.dart';

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

  /// 把選到的圖複製進 App 資料夾，並讀出寬高。
  Future<NewImage> import(XFile source) async {
    await dir.create(recursive: true);
    var ext = p.extension(source.path).toLowerCase();
    if (ext.isEmpty || ext.length > 5) ext = '.jpg';
    final name = '${const Uuid().v4()}$ext';
    final bytes = await source.readAsBytes();
    await fileOf(name).writeAsBytes(bytes, flush: true);
    var w = 0, h = 0;
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
    _changes.add(name);
    return NewImage(file: name, width: w, height: h);
  }
}
