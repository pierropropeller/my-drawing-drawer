import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/top_toast.dart';
import 'album_image.dart';

/// 提示條（States 設計稿）：深色底，[success]＝前面加綠色勾，[offline]＝前面加黃色離線雲。
/// D-114：留在下方、浮在固定底部元件上面（不蓋住按鈕），實作見 `top_toast.dart`；新的取代舊的。
/// 只在「動作已生效、使用者留在這一頁」時用；表單中途的操作、會跳頁的動作不要用。
/// [actionLabel]／[onAction]＝右邊的文字按鈕（例如「復原」）。
void showSnack(
  BuildContext context,
  String text, {
  bool success = false,
  bool offline = false,
  String? actionLabel,
  VoidCallback? onAction,
}) => showTopToast(
  context,
  text,
  success: success,
  offline: offline,
  actionLabel: actionLabel,
  onAction: onAction,
);

/// 刪除一律要確認。
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
  bool toTrash = false,
}) async {
  // 移到最近刪除（D-120）：內文固定說明 30 天內可以還原；按了刪除後出「已移到最近刪除」。
  final body = message ?? (toTrash ? context.l10n.trashDeleteBody : null);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            ctx.l10n.commonDelete,
            style: TextStyle(color: ctx.tokens.danger),
          ),
        ),
      ],
    ),
  );
  if (ok == true && toTrash && context.mounted) {
    showSnack(context, context.l10n.trashMovedSnack);
  }
  return ok == true;
}

/// 單行文字輸入對話框；取消回傳 null。
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            final v = c.text.trim();
            Navigator.pop(ctx, v.isEmpty ? null : v);
          },
          child: Text(ctx.l10n.albumConfirm),
        ),
      ],
    ),
  );
}

/// 下載存到的獨立相簿名稱（D-007）：Android 為 `Pictures/Drawer`。
/// 固定英文，不跟隨 App 顯示名稱的在地化。
const downloadAlbumName = 'Drawer';

/// 儲存到系統相簿（圖片、GIF、影片都存原檔）。回傳成功張數。
Future<int> downloadImages(WidgetRef ref, Iterable<AlbumImage> images) async {
  final store = await ref.read(imageStoreProvider.future);
  if (!await Gal.hasAccess()) {
    if (!await Gal.requestAccess()) return 0;
  }
  var ok = 0;
  for (final im in images) {
    try {
      // 存原檔（不轉檔）。影片用 putVideo；兩者都放進同一個 `Drawer` 相簿（Pictures/Drawer）。
      final path = store.fileOf(im.file).path;
      if (im.media.isVideo) {
        await Gal.putVideo(path, album: downloadAlbumName);
      } else {
        await Gal.putImage(path, album: downloadAlbumName);
      }
      ok++;
    } catch (_) {}
  }
  return ok;
}

/// 一次分享多張圖（雜物多選的「分享」）。
Future<void> shareImages(WidgetRef ref, Iterable<AlbumImage> images) async {
  final store = await ref.read(imageStoreProvider.future);
  await SharePlus.instance.share(
    ShareParams(
      files: [for (final i in images) XFile(store.fileOf(i.file).path)],
    ),
  );
}

Future<void> shareImage(WidgetRef ref, AlbumImage image) async {
  final store = await ref.read(imageStoreProvider.future);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(store.fileOf(image.file).path)]),
  );
}
