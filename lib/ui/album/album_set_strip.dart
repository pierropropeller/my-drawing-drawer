import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_set_queries.dart';
import '../../data/database.dart';
import '../../data/junk_queries.dart' show AlbumCell;
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/media_widgets.dart';
import 'album_image.dart';
import 'preview_shell.dart';

/// 一組圖（D-136）的第 [extra] 張「額外」圖，包成 [AlbumImage]（id／分組／作者照抄那一筆），
/// 給分享、下載這些只認 [AlbumImage] 的動作用。
AlbumImage albumSetPage(AlbumImage entry, EntityImage extra) => AlbumImage(
  id: entry.id,
  file: extra.imageFile,
  width: extra.width,
  height: extra.height,
  kind: entry.kind,
  author: entry.author,
  groupName: entry.groupName,
  groupId: entry.groupId,
  createdAt: entry.createdAt,
  mediaKind: extra.kind,
  durationMs: extra.durationMs,
  posterFile: extra.posterFile,
  imageKey: entry.imageKey,
);

/// 這一組的每一張（第 1 張＝那一筆本身）。
List<AlbumImage> albumSetPages(WidgetRef ref, AlbumImage entry) => [
  entry,
  for (final e
      in ref.watch(albumExtrasProvider(entry.imageKey)).value ??
          const <EntityImage>[])
    albumSetPage(entry, e),
];

/// 多選的下載／分享：每一組展開成全部的圖。
Future<List<AlbumImage>> expandAlbumSets(
  WidgetRef ref,
  Iterable<AlbumImage> entries,
) async {
  final db = ref.read(databaseProvider);
  return [
    for (final a in entries) ...[
      a,
      for (final e in await db.albumExtrasOf(a.imageKey)) albumSetPage(a, e),
    ],
  ];
}

/// 編輯完回到預覽頁：重讀這一筆的第 1 張（編輯頁可能換了次序或換掉第 1 張）。
Future<AlbumImage> reloadAlbumSetFirst(
  WidgetRef ref,
  AlbumCell cell,
  AlbumImage a,
) async {
  final images = await ref.read(databaseProvider).albumSetImages(cell, a.id);
  if (images.isEmpty) return a;
  final n = images.first;
  return AlbumImage(
    id: a.id,
    file: n.file,
    width: n.width,
    height: n.height,
    kind: a.kind,
    author: a.author,
    groupName: a.groupName,
    groupId: a.groupId,
    createdAt: a.createdAt,
    mediaKind: n.kind,
    durationMs: n.durationMs,
    posterFile: n.posterFile,
    imageKey: a.imageKey,
  );
}

/// 預覽頁每一筆目前看第幾張（D-136）；換到別筆再回來時保留。
mixin AlbumSetPreview<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _sub = <String, int>{};

  int subIndexOf(AlbumImage entry, int count) =>
      (_sub[entry.id] ?? 0).clamp(0, count - 1 < 0 ? 0 : count - 1);

  void selectSub(AlbumImage entry, int i) => setState(() => _sub[entry.id] = i);

  /// 編輯完：這一筆換成重讀的 [fresh]，回到第 1 張。
  void replaceEntry(List<AlbumImage> items, int index, AlbumImage fresh) =>
      setState(() {
        items[index] = fresh;
        _sub.remove(fresh.id);
      });

  /// 預覽頁每一頁（每一筆）要顯示的媒體：目前這筆和左右兩筆看選中的那一張，其他先用第 1 張。
  List<MediaSource> pageMedia(List<AlbumImage> items, int index) => [
    for (var i = 0; i < items.length; i++)
      if ((i - index).abs() <= 1) _pageOf(items[i]).media else items[i].media,
  ];

  AlbumImage _pageOf(AlbumImage entry) {
    final pages = albumSetPages(ref, entry);
    return pages[subIndexOf(entry, pages.length)];
  }

  /// 目前這筆、目前這張（分享、下載用）。
  AlbumImage currentPage(AlbumImage entry) => _pageOf(entry);
}

/// 預覽頁的縮圖條（D-136，ImagePreviewMulti）：左邊固定「n / N」，右邊 40×40 縮圖橫向捲動；
/// 選中的白框、其他 55% 不透明。切換時選中的那格自動捲進畫面。
class AlbumSetStrip extends StatefulWidget {
  const AlbumSetStrip({
    super.key,
    required this.pages,
    required this.selected,
    required this.onSelected,
  });

  final List<AlbumImage> pages;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<AlbumSetStrip> createState() => _AlbumSetStripState();
}

class _AlbumSetStripState extends State<AlbumSetStrip> {
  static const _size = 40.0;
  static const _gap = 6.0;
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(AlbumSetStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(jump: true));
  }

  void _reveal({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final left = widget.selected * (_size + _gap);
    final right = left + _size;
    double? to;
    if (left < pos.pixels) {
      to = left;
    } else if (right > pos.pixels + pos.viewportDimension) {
      to = right - pos.viewportDimension;
    }
    if (to == null) return;
    to = to.clamp(0, pos.maxScrollExtent);
    if (jump) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(
        to,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pages.length;
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            '${widget.selected + 1} / $n',
            style: const TextStyle(
              color: PreviewPalette.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: _size + 4,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 2, 24, 2),
              itemCount: n,
              separatorBuilder: (_, _) => const SizedBox(width: _gap),
              itemBuilder: (context, i) {
                final on = i == widget.selected;
                return Semantics(
                  button: true,
                  selected: on,
                  label: context.l10n.albumSetThumb(i + 1),
                  child: GestureDetector(
                    onTap: () => widget.onSelected(i),
                    child: Opacity(
                      opacity: on ? 1 : 0.55,
                      child: Container(
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: on
                                ? PreviewPalette.text
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: MediaThumb(
                            widget.pages[i].media,
                            cacheWidth: 120,
                            showBadge: false,
                            animate: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
