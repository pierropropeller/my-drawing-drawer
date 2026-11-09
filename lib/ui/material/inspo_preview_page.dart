import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/material_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../album/preview_shell.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'inspo_edit_page.dart';
import 'inspo_pit_sheet.dart';
import 'material_icons.dart';

AlbumImage inspoAlbumImage(MaterialImage r) => AlbumImage(
  id: r.id,
  file: r.imageFile,
  width: r.width,
  height: r.height,
  kind: AlbumKind.junk,
  createdAt: r.createdAt,
  mediaKind: r.kind,
  durationMs: r.durationMs,
  posterFile: r.posterFile,
);

/// 靈感廣場的預覽（InspoPreview，D-141／D-142）：深色全屏、圖片滿版，資訊（分類、說明、
/// 已放進的坑、加入日期）疊在圖上。動作：放進坑、分享、下載、編輯、刪除。沒有底部導覽列。
class InspoPreviewPage extends ConsumerStatefulWidget {
  const InspoPreviewPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<MaterialImage> images;
  final int initialIndex;

  @override
  ConsumerState<InspoPreviewPage> createState() => _InspoPreviewPageState();
}

class _InspoPreviewPageState extends ConsumerState<InspoPreviewPage>
    with HidesNavBar<InspoPreviewPage> {
  late final _items = [...widget.images];
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 目前這張（編輯後的分類／說明從資料庫即時讀）。
  MaterialImage _live(Map<String, MaterialImage> byId) =>
      byId[_items[_index].id] ?? _items[_index];

  Future<void> _download(MaterialImage r) async {
    final n = await downloadImages(ref, [inspoAlbumImage(r)]);
    if (mounted) {
      showSnack(
        context,
        n > 0 ? context.l10n.albumSavedToGallery : context.l10n.albumSaveFailed,
      );
    }
  }

  Future<void> _delete(MaterialImage r, bool placed) async {
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImageTitle,
      message: placed ? context.l10n.inspoDeletePlacedNote : null,
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteMaterials([r.id]);
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
    final l = context.l10n;
    final byId = <String, MaterialImage>{
      for (final m in ref.watch(materialsProvider(null)).value ?? const [])
        m.id: m,
    };
    final r = _live(byId);
    final cat = (ref.watch(inspoCategoriesProvider).value ?? const [])
        .where((c) => c.id == r.categoryKey)
        .firstOrNull
        ?.name;
    final pits = ref.watch(placedPitsProvider).value?[r.id] ?? const [];
    final note = r.note ?? '';
    return PreviewShell(
      title: l.materialTitle,
      counter: '${_index + 1} / ${_items.length}',
      controller: _controller,
      media: [for (final i in _items) inspoAlbumImage(i).media],
      currentIndex: _index,
      onPageChanged: (i) => setState(() => _index = i),
      info: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cat != null) PreviewPill(cat, color: PreviewPalette.pillInspo),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PreviewNote(note, icon: MaterialLibIcons.note),
              ),
            if (pits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        l.inspoPlacedIn,
                        style: const TextStyle(
                          color: PreviewPalette.soft,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    for (final p in pits)
                      Container(
                        key: ValueKey('inspoPlaced-${p.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PreviewPalette.tagBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SvgIcon(
                              AppIcons.folder,
                              size: 12,
                              color: PreviewPalette.tagText,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              p.name,
                              style: const TextStyle(
                                color: PreviewPalette.tagText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: cat == null && note.isEmpty && pits.isEmpty ? 0 : 10,
              ),
              child: Text(
                previewDate(r.createdAt, l),
                style: const TextStyle(
                  color: PreviewPalette.soft,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        PreviewAction(
          MaterialLibIcons.placeInPit,
          l.inspoPlaceInPit,
          () => placeInPit(context, ref, [r.id]),
        ),
        PreviewAction(
          AppIcons.share,
          l.commonShare,
          () => shareImage(ref, inspoAlbumImage(r)),
        ),
        PreviewAction(AppIcons.download, l.commonDownload, () => _download(r)),
        PreviewAction(
          AppIcons.edit,
          l.commonEdit,
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => InspoEditPage(image: r)),
          ),
        ),
        PreviewAction(
          AppIcons.trash,
          l.commonDelete,
          () => _delete(r, pits.isNotEmpty),
          color: PreviewPalette.danger,
        ),
      ],
    );
  }
}
