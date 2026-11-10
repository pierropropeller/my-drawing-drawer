import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../data/database.dart';

/// 選圖 sheet 頂部「相簿｜靈感廣場」的廣場那段（D-145）：開 sheet 時的分類與圖（快照）、
/// 縮圖、以及把選到的廣場圖交出去的方式。
class InspoPickerSource {
  InspoPickerSource({
    required this.categories,
    required this.images,
    required this.thumb,
    required this.export,
  });

  final List<InspoCategory> categories;
  final List<MaterialImage> images;

  /// 格子／底部已選列的縮圖。
  final Widget Function(MaterialImage image) thumb;

  /// 把一張廣場圖交成檔案；本機沒有檔案（同步還沒下載完）回傳 null。
  final Future<XFile?> Function(MaterialImage image) export;

  /// 已選列表裡廣場圖的 id 前綴（和相簿的 id 分開）。
  static const idPrefix = 'inspo:';

  /// 靈感廣場自己的「加圖」不列廣場那段（自己加自己沒意義）。
  static bool suppressed = false;

  late final Map<String, MaterialImage> byId = {
    for (final m in images) m.id: m,
  };
}

/// 選圖時從廣場選的圖：暫存檔路徑 → 廣場圖 id（D-145）。
/// 新增參考圖用它把這些圖改成「放進坑」（連結），其他地方照一般圖片複製一份。
final pickedFromInspo = <String, String>{};
