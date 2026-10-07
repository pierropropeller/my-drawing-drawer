import 'dart:io';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'album_queries.dart';

/// 圖片存在 App 內部資料夾；資料庫只記錄檔名（相對路徑），之後同步到 Drive 也用同一個名字。
class ImageStore {
  ImageStore(this.dir);
  final Directory dir;

  File fileOf(String name) => File(p.join(dir.path, name));

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
    return NewImage(file: name, width: w, height: h);
  }
}
