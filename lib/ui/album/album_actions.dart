import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'album_image.dart';
import 'group_manage_page.dart';

/// 提示條（States 設計稿）：深色底，[success]＝前面加綠色勾，[offline]＝前面加黃色離線雲。
void showSnack(
  BuildContext context,
  String text, {
  bool success = false,
  bool offline = false,
}) {
  final icon = success
      ? const SvgIcon(
          AppIcons.check,
          size: 18,
          strokeWidth: 2.2,
          color: Color(0xFF8FD19E),
        )
      : offline
      ? const SvgIcon(
          AppIcons.cloudOff,
          size: 18,
          strokeWidth: 1.9,
          color: Color(0xFFE6C98F),
        )
      : null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: icon == null
            ? Text(text)
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Expanded(child: Text(text)),
                ],
              ),
      ),
    );
}

/// 刪除一律要確認。
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String? message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
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

/// 官方圖「編輯」＝更換分組（官方圖只有分組一個欄位）：彈出分組清單，選了就更新。
/// 預覽頁與平板的預覽面板共用。回傳是否真的換了分組。
Future<bool> changeOfficialGroup(
  BuildContext context,
  WidgetRef ref, {
  required String pitId,
  required String imageId,
}) async {
  final db = ref.read(databaseProvider);
  final groups = await db.watchGroups(pitId).first;
  if (!context.mounted) return false;
  final picked = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ctx.l10n.albumChangeGroup,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GroupManagePage(pitId: pitId),
                      ),
                    );
                  },
                  child: Text(ctx.l10n.commonManage),
                ),
              ],
            ),
          ),
          for (final g in groups)
            ListTile(
              title: Text(g.name),
              onTap: () => Navigator.pop(ctx, g.id),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return false;
  await db.setOfficialGroup(imageId, picked);
  return true;
}
