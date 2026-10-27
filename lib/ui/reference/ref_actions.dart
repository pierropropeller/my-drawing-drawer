import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../album/fan_art_edit_page.dart';
import '../album/official_new_page.dart';
import 'ref_icons.dart';
import 'ref_image.dart';
import 'ref_info.dart';

/// 資料面板動作的實作：全部沿用官方圖冊／同人圖預覽頁已有的動作（下載、分享、設為封面、
/// 編輯、刪除），不另做一套。
///
/// [onRemoved]：圖片被刪除（或在編輯頁被刪）後呼叫，檢視器據此把它從列表拿掉。
List<RefInfoAction> buildRefActions({
  required BuildContext context,
  required WidgetRef ref,
  required RefImage image,
  required VoidCallback onRemoved,
}) {
  final a = image.album;
  final pitId = image.pitId;
  if (a == null || pitId == null) return const [];
  final l10n = context.l10n;
  final db = ref.read(databaseProvider);
  final fan = a.kind == AlbumKind.fanArt;
  final junk = a.kind == AlbumKind.junk;

  Future<void> setCover() async {
    if (fan) {
      await db.setFanArtCover(pitId, a.id);
    } else {
      await db.setOfficialCover(pitId, a.id);
    }
    if (context.mounted) {
      showSnack(
        context,
        fan ? l10n.albumFanCoverSet : l10n.albumCoverSetOfficial,
      );
    }
  }

  Future<void> download() async {
    final n = await downloadImages(ref, [a]);
    if (!context.mounted) return;
    showSnack(context, n > 0 ? l10n.albumSavedToGallery : l10n.albumSaveFailed);
  }

  Future<void> edit() async {
    if (fan) {
      final deleted = await openFanArtEdit(
        context,
        pitId: pitId,
        imageId: a.id,
      );
      if (deleted == true) onRemoved();
    } else {
      final deleted = await openOfficialEdit(
        context,
        pitId: pitId,
        imageId: a.id,
      );
      if (deleted == true) onRemoved();
    }
  }

  Future<void> delete() async {
    final ok = await confirmDelete(
      context,
      title: l10n.albumDeleteImageTitle,
      toTrash: true,
    );
    if (!ok) return;
    if (fan) {
      await db.deleteFanArts([a.id]);
    } else if (junk) {
      await db.deleteJunk([a.id]);
    } else {
      await db.deleteOfficial([a.id]);
    }
    onRemoved();
  }

  return [
    if (!junk)
      RefInfoAction(
        icon: RefIcons.setCover,
        label: l10n.albumSetCover,
        onTap: setCover,
      ),
    RefInfoAction(
      icon: RefIcons.download,
      label: l10n.commonDownload,
      onTap: download,
    ),
    // FanArt 稿的面板沒有「分享」，官方圖冊有。
    if (!fan)
      RefInfoAction(
        icon: RefIcons.share,
        label: l10n.commonShare,
        onTap: () => shareImage(ref, a),
      ),
    if (!junk)
      RefInfoAction(icon: RefIcons.edit, label: l10n.commonEdit, onTap: edit),
    RefInfoAction(
      icon: RefIcons.trash,
      label: l10n.commonDelete,
      onTap: delete,
      danger: true,
    ),
  ];
}
