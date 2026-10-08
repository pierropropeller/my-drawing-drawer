import '../../app_name.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'album_image.dart';

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
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('刪除', style: TextStyle(color: ctx.tokens.danger)),
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
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final v = c.text.trim();
            Navigator.pop(ctx, v.isEmpty ? null : v);
          },
          child: const Text('確定'),
        ),
      ],
    ),
  );
}

/// 儲存到系統相簿。回傳成功張數。
Future<int> downloadImages(WidgetRef ref, Iterable<AlbumImage> images) async {
  final store = await ref.read(imageStoreProvider.future);
  if (!await Gal.hasAccess()) {
    if (!await Gal.requestAccess()) return 0;
  }
  var ok = 0;
  for (final im in images) {
    try {
      await Gal.putImage(store.fileOf(im.file).path, album: appName);
      ok++;
    } catch (_) {}
  }
  return ok;
}

Future<void> shareImage(WidgetRef ref, AlbumImage image) async {
  final store = await ref.read(imageStoreProvider.future);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(store.fileOf(image.file).path)]),
  );
}
