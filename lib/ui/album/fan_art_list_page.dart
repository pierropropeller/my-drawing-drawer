import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import 'album_view.dart';
import 'fan_art_new_page.dart';
import 'fan_art_preview_page.dart';
import 'group_manage_page.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';

/// 好看同人圖：出處 chips 篩選；卡片開啟同人圖預覽（D-045）。
class FanArtListPage extends ConsumerStatefulWidget {
  const FanArtListPage({
    super.key,
    required this.pitId,
    this.tagId,
    this.onTagTap,
  });
  final String pitId;

  /// 只列出有這個 tag 的同人圖（D-043）；有值時頂部多一條「#tag ×」篩選列。
  final String? tagId;

  /// 在預覽頁點 tag 時的處理；省略＝預設導覽（回到本格列表並篩選）。
  final ValueChanged<String>? onTagTap;

  @override
  ConsumerState<FanArtListPage> createState() => _FanArtListPageState();
}

class _FanArtListPageState extends ConsumerState<FanArtListPage> {
  String? _groupId;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add(String? groupId) async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FanArtNewPage(
          pitId: widget.pitId,
          initialImages: picked,
          initialGroupId: groupId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'fan'))).value ?? const [];
    final groupId = groups.any((g) => g.id == _groupId) ? _groupId : null;
    final names = {for (final g in groups) g.id: g.name};
    final filtered = widget.tagId != null;
    // 標題列一律顯示全部張數；篩選時「N 張」在篩選列（FanArtFiltered）。
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.fanArts;
    final rows =
        ref
            .watch(
              fanArtsFilteredProvider((widget.pitId, groupId, widget.tagId)),
            )
            .value ??
        const [];
    final images = [
      for (final r in rows)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.fanArt,
          author: r.author,
          groupName: names[r.groupId],
          groupId: r.groupId,
          createdAt: r.createdAt,
        ),
    ];
    return AlbumView(
      pitId: widget.pitId,
      cell: AlbumCell.fan,
      title: context.l10n.pitsFanArt,
      images: images,
      emptyLabel: context.l10n.albumFanEmpty,
      emptySvg: AppIcons.pitFanArt,
      total: total,
      emptyColor: context.tokens.fanArt,
      onAdd: () => _add(groupId),
      onDelete: (picked) => db.deleteFanArts(picked.map((e) => e.id)),
      previewBuilder: (items, i) => FanArtPreviewPage(
        pitId: widget.pitId,
        images: items,
        initialIndex: i,
        // 預覽頁點 tag：關掉預覽，回到該格列表套用篩選（已在篩選裡就取代）。
        onTagTap:
            widget.onTagTap ??
            (id) => onListTagTap(
              context,
              pitId: widget.pitId,
              kind: TaggedKind.fan,
              tagId: id,
              listFiltered: filtered,
              fromDetail: true,
            ),
      ),
      searchAction: SearchIconButton(pitId: widget.pitId),
      filter: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (filtered)
            TagFilterBar(
              pitId: widget.pitId,
              kind: TaggedKind.fan,
              tagId: widget.tagId!,
              countText: context.l10n.commonCountImages(images.length),
            ),
          ChipRow(
            options: [for (final g in groups) (g.id, g.name)],
            selected: groupId,
            onSelected: (v) => setState(() => _groupId = v),
            trailing: ChipRowManageButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      GroupManagePage(pitId: widget.pitId, kind: 'fan'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
