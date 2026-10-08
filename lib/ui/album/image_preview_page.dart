import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
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
    if (mounted) showSnack(context, n > 0 ? '已儲存到相簿' : '儲存失敗');
  }

  Future<void> _setCover() async {
    // 「設為封面」＝設為官方圖冊這一格的封面；
    // 主頁坑卡片的封面要在坑內頁長按格子選擇。
    await ref
        .read(databaseProvider)
        .setOfficialCover(widget.pitId, _current.id);
    if (mounted) showSnack(context, '已設為官方圖冊封面');
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
                  const Expanded(
                    child: Text(
                      '更換分組',
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
                    child: const Text('管理'),
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
      if (mounted) showSnack(context, '已更換分組');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context, title: '刪除這張圖？');
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
      title: pitName == null ? '官方圖冊' : '$pitName · 官方圖冊',
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
        PreviewAction(AppIcons.share, '分享', () => shareImage(ref, _current)),
        PreviewAction(AppIcons.download, '下載', _download),
        PreviewAction(AppIcons.setCover, '設為封面', _setCover),
        PreviewAction(AppIcons.edit, '編輯', _edit),
        PreviewAction(
          AppIcons.trash,
          '刪除',
          _delete,
          color: PreviewPalette.danger,
        ),
      ],
    );
  }
}
