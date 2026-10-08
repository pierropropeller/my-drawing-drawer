import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'fan_art_edit_page.dart';
import 'preview_shell.dart';

/// 同人圖預覽（FanArtPreview，D-045）：與官方圖冊預覽分開。
/// 作者、出處、全部 tag（可點）、加入日期；底部動作與官方預覽相同。沒有底部導覽列。
class FanArtPreviewPage extends ConsumerStatefulWidget {
  const FanArtPreviewPage({
    super.key,
    required this.pitId,
    required this.images,
    required this.initialIndex,
    this.onTagTap = _noTagTap,
  });

  final String pitId;
  final List<AlbumImage> images;
  final int initialIndex;

  /// 點 tag 時呼叫（參數是 tag id）。預設不動作，由搜尋區塊接上「回到列表並篩選」。
  final void Function(String tagId) onTagTap;

  static void _noTagTap(String tagId) {}

  @override
  ConsumerState<FanArtPreviewPage> createState() => _FanArtPreviewPageState();
}

class _FanArtPreviewPageState extends ConsumerState<FanArtPreviewPage>
    with HidesNavBar<FanArtPreviewPage> {
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
    if (!mounted) return;
    showSnack(
      context,
      n > 0 ? context.l10n.albumSavedToGallery : context.l10n.albumSaveFailed,
    );
  }

  Future<void> _setCover() async {
    await ref.read(databaseProvider).setFanArtCover(widget.pitId, _current.id);
    if (mounted) showSnack(context, context.l10n.albumFanCoverSet);
  }

  Future<void> _edit() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            FanArtEditPage(pitId: widget.pitId, imageId: _current.id),
      ),
    );
    if (deleted == true && mounted) _removeCurrent();
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteFanArts([_current.id]);
    if (mounted) _removeCurrent();
  }

  void _removeCurrent() {
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
    final cur = _current;
    // 編輯後要立刻看到新的作者／出處：以資料庫最新的列為準，找不到再用列表帶進來的值。
    final live = (ref.watch(fanArtsProvider((widget.pitId, null))).value ?? [])
        .where((r) => r.id == cur.id)
        .firstOrNull;
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'fan'))).value ?? const [];
    final groupId = live == null ? cur.groupId : live.groupId;
    final group =
        groups.where((g) => g.id == groupId).firstOrNull?.name ??
        (live == null ? cur.groupName : null) ??
        '';
    final author = live?.author ?? cur.author ?? '';
    final tagIds =
        ref.watch(tagIdsProvider((TagTarget.fanArt, cur.id))).value ??
        const <String>[];
    final tagNames = {
      for (final tag
          in ref.watch(tagsProvider(widget.pitId)).value ?? const <Tag>[])
        tag.id: tag.name,
    };
    final date = cur.createdAt;
    return PreviewShell(
      title: pitName == null
          ? context.l10n.pitsFanArt
          : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsFanArt),
      counter: '${_index + 1} / ${_items.length}',
      controller: _controller,
      files: [for (final i in _items) i.file],
      onPageChanged: (i) => setState(() => _index = i),
      info: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (author.isNotEmpty || group.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PreviewPalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (group.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: PreviewPalette.pillFan,
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
                  ],
                ],
              ),
            if (tagIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in tagIds)
                      if (tagNames[id] != null)
                        GestureDetector(
                          onTap: () => widget.onTagTap(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PreviewPalette.tagBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#${tagNames[id]}',
                              style: const TextStyle(
                                color: PreviewPalette.tagText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            if (date != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  previewDate(date, context.l10n),
                  style: const TextStyle(
                    color: PreviewPalette.muted,
                    fontSize: 11.5,
                  ),
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
