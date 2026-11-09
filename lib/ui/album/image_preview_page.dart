import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../data/junk_queries.dart' show AlbumCell;
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';
import '../common/device_class.dart';
import '../common/nav_bar_hidden.dart';
import '../common/window_class.dart';
import '../reference/reference_viewer.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'album_set_strip.dart';
import 'official_new_page.dart';
import '../search/tagged_list.dart';
import 'preview_shell.dart';

/// 官方圖冊的圖片預覽（ImagePreview）：深色全屏、圖片滿版；分享、下載、設為封面、編輯、刪除。
/// 同人圖有自己的預覽頁，見 `FanArtPreviewPage`。沒有底部導覽列。
class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
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
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage>
    with HidesNavBar<ImagePreviewPage>, AlbumSetPreview<ImagePreviewPage> {
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
    final n = await downloadImages(ref, [currentPage(_current)]);
    if (mounted) {
      showSnack(
        context,
        n > 0 ? context.l10n.albumSavedToGallery : context.l10n.albumSaveFailed,
      );
    }
  }

  Future<void> _setCover() async {
    // 「設為封面」＝設為官方圖冊這一格的封面；
    // 主頁坑卡片的封面要在坑內頁長按格子選擇。
    await ref
        .read(databaseProvider)
        .setOfficialCover(widget.pitId, _current.id);
    if (mounted) showSnack(context, context.l10n.albumCoverSetOfficial);
  }

  /// 編輯＝開編輯頁（OfficialNew 版型：分組、tag）；編輯時按圖上的「×」刪掉這張圖。
  Future<void> _edit() async {
    final id = _current.id;
    final deleted = await openOfficialEdit(
      context,
      pitId: widget.pitId,
      imageId: id,
    );
    if (!mounted) return;
    if (deleted == true) {
      _removeCurrent();
      return;
    }
    final i = _index;
    final fresh = await reloadAlbumSetFirst(ref, AlbumCell.official, _items[i]);
    if (mounted && i < _items.length && _items[i].id == fresh.id) {
      replaceEntry(_items, i, fresh);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteOfficial([_current.id]);
    if (!mounted) return;
    _removeCurrent();
  }

  /// 目前這張已刪除：從預覽拿掉；沒圖了就關閉。
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

  /// 多圖的資訊區（D-136，ImagePreviewMulti）：tag → 縮圖條 → 左日期、右下分組。
  Widget _setInfo(
    List<AlbumImage> pages,
    String group,
    DateTime? date,
    List<String> tagIds,
    Map<String, String> tagNames,
  ) {
    final sub = subIndexOf(_current, pages.length);
    final hasTags = tagIds.any(tagNames.containsKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTags)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in tagIds)
                    if (tagNames[id] != null)
                      PreviewTagChip(tagNames[id]!, onTap: () => _tagTap(id)),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: 24, top: hasTags ? 10 : 6),
            child: AlbumSetStrip(
              pages: pages,
              selected: sub,
              onSelected: (i) => selectSub(_current, i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: date == null
                      ? const SizedBox.shrink()
                      : Text(
                          previewDate(date, context.l10n),
                          style: const TextStyle(
                            color: PreviewPalette.muted,
                            fontSize: 11.5,
                          ),
                        ),
                ),
                if (group.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: PreviewPalette.bg);
    }
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final group = _current.groupName ?? '';
    final date = _current.createdAt;
    final tagIds =
        ref.watch(tagIdsProvider((TagTarget.official, _current.id))).value ??
        const <String>[];
    final tagNames = {
      for (final tag
          in ref.watch(tagsProvider(widget.pitId)).value ?? const <Tag>[])
        tag.id: tag.name,
    };
    final hasTags = tagIds.any(tagNames.containsKey);
    // 多圖（D-136）：這一筆的全部圖。
    final pages = albumSetPages(ref, _current);
    final title = pitName == null
        ? context.l10n.pitsOfficial
        : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsOfficial);
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
      media: pageMedia(_items, _index),
      currentIndex: _index,
      onPageChanged: (i) => setState(() => _index = i),
      info: pages.length > 1
          ? _setInfo(pages, group, date, tagIds, tagNames)
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (group.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
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
                  // tag chips（D-089，同 FanArtPreview）：點了回官方圖冊並以該 tag 篩選。
                  if (hasTags)
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
                      padding: EdgeInsets.only(
                        top: group.isEmpty && !hasTags ? 0 : 10,
                      ),
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
          () => shareImage(ref, currentPage(_current)),
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
