import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/album_icons.dart';
import '../album/album_image.dart';
import '../album/move_sheet.dart';
import '../album/preview_shell.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';

/// 雜物的圖片預覽。設計稿沒畫，沿用 ImagePreview 的深色全屏版型；
/// 雜物不能當封面、沒有可編輯欄位，所以底部是 分享／下載／移動／刪除。沒有底部導覽列。
class JunkPreviewPage extends ConsumerStatefulWidget {
  const JunkPreviewPage({
    super.key,
    required this.pitId,
    required this.images,
    required this.initialIndex,
  });
  final String pitId;
  final List<AlbumImage> images;
  final int initialIndex;

  @override
  ConsumerState<JunkPreviewPage> createState() => _JunkPreviewPageState();
}

class _JunkPreviewPageState extends ConsumerState<JunkPreviewPage>
    with HidesNavBar<JunkPreviewPage> {
  late final _items = [...widget.images];
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  AlbumImage get _current => _items[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _removeCurrent() {
    setState(() => _items.removeAt(_index));
    if (_items.isEmpty) {
      Navigator.of(context).pop();
    } else if (_index >= _items.length) {
      _index = _items.length - 1;
    }
  }

  Future<void> _download() async {
    final n = await downloadImages(ref, [_current]);
    if (mounted) {
      showSnack(
        context,
        n > 0 ? context.l10n.albumSavedToGallery : context.l10n.albumSaveFailed,
      );
    }
  }

  Future<void> _move() async {
    final target = await showMoveSheet(
      context,
      pitId: widget.pitId,
      from: AlbumCell.junk,
      count: 1,
    );
    if (target == null || !mounted) return;
    await ref
        .read(databaseProvider)
        .moveAlbumImages(
          from: AlbumCell.junk,
          ids: [_current.id],
          to: target.cell,
          groupId: target.groupId,
        );
    if (!mounted) return;
    showSnack(
      context,
      context.l10n.albumMovedCount(
        1,
        albumCellLabel(context.l10n, target.cell),
      ),
      success: true,
    );
    _removeCurrent();
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteJunk([_current.id]);
    if (mounted) _removeCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: PreviewPalette.bg);
    }
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final date = _current.createdAt;
    return PreviewShell(
      title: pitName == null
          ? context.l10n.junkTitle
          : context.l10n.albumTitleWithPit(pitName, context.l10n.junkTitle),
      counter: '${_index + 1} / ${_items.length}',
      controller: _controller,
      files: [for (final i in _items) i.file],
      onPageChanged: (i) => setState(() => _index = i),
      info: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: Row(
          children: [
            const Spacer(),
            if (date != null)
              Text(
                previewDate(date),
                style: const TextStyle(
                  color: PreviewPalette.muted,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
      ),
      actions: [
        PreviewAction(
          AppIcons.share,
          context.l10n.commonShare,
          () => shareImage(ref, _current),
        ),
        PreviewAction(
          AppIcons.download,
          context.l10n.commonDownload,
          _download,
        ),
        PreviewAction(AlbumIcons.moveFolder, context.l10n.commonMove, _move),
        PreviewAction(
          AppIcons.trash,
          context.l10n.commonDelete,
          _delete,
          color: PreviewPalette.danger,
        ),
      ],
    );
  }
}
