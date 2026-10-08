import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'group_manage_page.dart';
import 'preview_shell.dart';

/// 官方圖冊的圖片預覽（ImagePreview）：深色全屏、圖片滿版；分享、下載、設為封面、編輯、刪除。
/// 同人圖有自己的預覽頁，見 `FanArtPreviewPage`。沒有底部導覽列。
class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.pitId,
    required this.images,
    required this.initialIndex,
  });

  final String pitId;
  final List<AlbumImage> images;
  final int initialIndex;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage>
    with HidesNavBar<ImagePreviewPage> {
  late final _items = [...widget.images];
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  AlbumImage get _current => _items[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final n = await downloadImages(ref, [_current]);
    if (mounted)
      showSnack(
        context,
        n > 0 ? context.l10n.albumSavedToGallery : context.l10n.albumSaveFailed,
      );
  }

  Future<void> _setCover() async {
    // 「設為封面」＝設為官方圖冊這一格的封面；
    // 主頁坑卡片的封面要在坑內頁長按格子選擇。
    await ref
        .read(databaseProvider)
        .setOfficialCover(widget.pitId, _current.id);
    if (mounted) showSnack(context, context.l10n.albumCoverSetOfficial);
  }

  /// 編輯＝更換分組（官方圖只有分組一個欄位）。
  Future<void> _edit() async {
    final db = ref.read(databaseProvider);
    final im = _current;
    final groups = await db.watchGroups(widget.pitId).first;
    if (!mounted) return;
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
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GroupManagePage(pitId: widget.pitId),
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
    if (picked != null) {
      await db.setOfficialGroup(im.id, picked);
      if (mounted) showSnack(context, context.l10n.albumGroupChanged);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteOfficial([_current.id]);
    if (!mounted) return;
    setState(() => _items.removeAt(_index));
    if (_items.isEmpty) {
      Navigator.of(context).pop();
    } else if (_index >= _items.length) {
      _index = _items.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: PreviewPalette.bg);
    }
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final group = _current.groupName ?? '';
    final date = _current.createdAt;
    return PreviewShell(
      title: pitName == null
          ? context.l10n.pitsOfficial
          : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsOfficial),
      counter: '${_index + 1} / ${_items.length}',
      controller: _controller,
      files: [for (final i in _items) i.file],
      onPageChanged: (i) => setState(() => _index = i),
      info: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: Row(
          children: [
            if (group.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: PreviewPalette.pill,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  group,
                  style: const TextStyle(
                    color: PreviewPalette.bg,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        PreviewAction(AppIcons.setCover, context.l10n.albumSetCover, _setCover),
        PreviewAction(AppIcons.edit, context.l10n.commonEdit, _edit),
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
