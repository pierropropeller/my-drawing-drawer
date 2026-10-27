import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';
import '../common/device_class.dart';
import '../common/nav_bar_hidden.dart';
import '../common/window_class.dart';
import '../reference/reference_viewer.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'fan_art_edit_page.dart';
import '../search/tagged_list.dart';
import 'preview_shell.dart';

/// 同人圖預覽（FanArtPreview，D-045）：與官方圖冊預覽分開。
/// 作者、出處、全部 tag（可點）、加入日期；底部動作與官方預覽相同。沒有底部導覽列。
class FanArtPreviewPage extends ConsumerStatefulWidget {
  const FanArtPreviewPage({
    super.key,
    required this.pitId,
    required this.images,
    required this.initialIndex,
    this.onTagTap,
  });

  final String pitId;
  final List<AlbumImage> images;
  final int initialIndex;

  /// 點 tag 時呼叫（參數是 tag id）。預設進該坑的搜尋結果頁並帶上這個 tag（D-107）。
  final void Function(String tagId)? onTagTap;

  @override
  ConsumerState<FanArtPreviewPage> createState() => _FanArtPreviewPageState();
}

class _FanArtPreviewPageState extends ConsumerState<FanArtPreviewPage>
    with HidesNavBar<FanArtPreviewPage> {
  /// 點 tag：預設進該坑的搜尋結果頁並帶上這個 tag（D-107）。
  void _tagTap(String id) => widget.onTagTap != null
      ? widget.onTagTap!(id)
      : openTagSearch(context, widget.pitId, id);

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
    final deleted = await openFanArtEdit(
      context,
      pitId: widget.pitId,
      imageId: _current.id,
    );
    if (deleted == true && mounted) _removeCurrent();
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
      toTrash: true,
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

  /// 開參考圖檢視（平板／分屏才有入口，手機版面不變）；回來時把檢視器裡刪掉的圖也拿掉。
  Future<void> _openReference(String title) async {
    final removed = await openReferenceViewer(
      context,
      images: [
        for (final i in _items)
          RefImage.fromAlbum(i, pitId: widget.pitId, title: title),
      ],
      index: _index,
    );
    if (!mounted || removed.isEmpty) return;
    setState(() => _items.removeWhere((i) => removed.contains(i.id)));
    if (_items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _index = _index.clamp(0, _items.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(_index);
    });
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
    final title = pitName == null
        ? context.l10n.pitsFanArt
        : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsFanArt);
    // iPad：預覽頁就是參考圖檢視（RespRef400／RefFull…），不用手機版的深色預覽。
    if (isTabletDevice(context)) {
      return AlbumReferenceScreen(
        images: _items,
        index: _index,
        pitId: widget.pitId,
        title: title,
      );
    }
    return PreviewShell(
      title: title,
      headerTrailing: WindowClass.of(context).isCompact
          ? null
          : RefEntryChip(onTap: () => _openReference(title)),
      counter: '${_index + 1} / ${_items.length}',
      controller: _controller,
      media: [for (final i in _items) i.media],
      currentIndex: _index,
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
                          onTap: () => _tagTap(id),
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
