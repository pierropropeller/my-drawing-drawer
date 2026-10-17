import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../data/database.dart';
import '../../data/image_store.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart' show showSnack;
import '../common/window_class.dart';
import 'material_pick_sheet.dart';
import 'media_menu_anchor.dart';
import 'media_source_menu.dart';
import 'media_source_services.dart';

/// 讀 provider 的函式（`ref.read` 的形狀）；`Ref` 與 `WidgetRef` 都能傳 `ref.read`。
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// 表單「加圖」的唯一入口（iPad：MediaMenu）。
///
/// - 視窗 ＜600（手機）：直接開自家選擇器（D-084），和以前完全一樣。
/// - 視窗 ≥600：在加圖格旁彈出來源選單（照片／檔案／素材庫／拍照／貼上），選了再走對應流程。
///
/// 回傳選到的檔案（可直接交給 `importPickedMedia`）；取消或失敗回傳空清單。
/// 所有呼叫 `ref.read(imagePickerProvider)(context)` 的地方經由 [imagePickerProvider] 自動走這裡；
/// 新程式碼想直接呼叫也可以用這個。
Future<List<XFile>> pickImagesFor(BuildContext context, WidgetRef ref) =>
    pickImagesWith(context, ref.read);

/// [pickImagesFor] 的本體，接受 `ref.read`，讓 provider 裡（只有 `Ref`）也能用。
Future<List<XFile>> pickImagesWith(
  BuildContext context,
  ProviderReader read,
) async {
  final direct = read(photoPickerProvider);
  if (WindowClass.of(context).isCompact) return direct(context);

  final services = read(mediaSourceServicesProvider);
  final anchor = MediaMenuAnchor.take();
  final camera = await services.camera.isAvailable();
  final clipboard = await _safeProbe(services.clipboard);
  if (!context.mounted) return const [];
  final source = await showMediaSourceMenu(
    context,
    options: AddSourceOptions(camera: camera, clipboard: clipboard),
    anchor: anchor,
  );
  if (source == null || !context.mounted) return const [];
  return runAddSource(context, source, read);
}

Future<ClipboardProbe> _safeProbe(ClipboardImageService s) async {
  try {
    return await s.probe();
  } catch (_) {
    return ClipboardProbe.none;
  }
}

/// 執行選單選到的來源。
Future<List<XFile>> runAddSource(
  BuildContext context,
  AddSource source,
  ProviderReader read,
) async {
  final services = read(mediaSourceServicesProvider);
  final l = context.l10n;
  void toast(String text) {
    if (context.mounted && ScaffoldMessenger.maybeOf(context) != null) {
      showSnack(context, text);
    }
  }

  switch (source) {
    case AddSource.photos:
      return read(photoPickerProvider)(context);
    case AddSource.files:
      try {
        return await services.files.pick();
      } catch (_) {
        toast(l.ipadmediaFilesFailed);
        return const [];
      }
    case AddSource.materials:
      final rows = await showMaterialPickSheet(context);
      if (rows == null || rows.isEmpty || !context.mounted) return const [];
      try {
        final store = await read(imageStoreProvider.future);
        final dir = await services.tempDir();
        final files = await copyMaterialsToTemp(store, rows, dir);
        if (files.isEmpty) toast(l.ipadmediaMaterialsFailed);
        return files;
      } catch (_) {
        toast(l.ipadmediaMaterialsFailed);
        return const [];
      }
    case AddSource.camera:
      try {
        final shot = await services.camera.capture();
        return shot == null ? const [] : [shot];
      } catch (_) {
        // 權限被拒、沒有相機等。
        toast(l.ipadmediaCameraFailed);
        return const [];
      }
    case AddSource.paste:
      try {
        final dir = await services.tempDir();
        final pasted = await services.clipboard.read(dir);
        if (pasted == null) {
          toast(l.ipadmediaPasteEmpty);
          return const [];
        }
        return [pasted];
      } catch (_) {
        toast(l.ipadmediaPasteEmpty);
        return const [];
      }
  }
}

/// 把素材庫的檔案複製到暫存資料夾，回傳和選照片一樣的 `XFile`（匯入時會再存進 App 儲存空間）。
/// 保留點選次序與副檔名（GIF／影片才認得）；本機還沒有檔案（同步未下載完）的略過。
Future<List<XFile>> copyMaterialsToTemp(
  ImageStore store,
  List<MaterialImage> rows,
  Directory dir,
) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final out = <XFile>[];
  for (var i = 0; i < rows.length; i++) {
    final src = store.fileOf(rows[i].imageFile);
    if (!src.existsSync()) continue;
    final ext = p.extension(rows[i].imageFile);
    final dest = File(p.join(dir.path, 'material_${stamp}_$i$ext'));
    await src.copy(dest.path);
    out.add(XFile(dest.path));
  }
  return out;
}
