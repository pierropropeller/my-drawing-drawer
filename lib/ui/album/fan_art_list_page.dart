import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import 'album_panels.dart';
import 'album_view.dart';
import 'fan_art_new_page.dart';
import 'fan_art_preview_page.dart';
import 'group_manage_page.dart';
import '../search/tagged_list.dart';
import '../pits/pit_section_tabs.dart';

/// 好看同人圖：出處 chips 篩選；卡片開啟同人圖預覽（D-045）。
class FanArtListPage extends ConsumerStatefulWidget {
  const FanArtListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<FanArtListPage> createState() => _FanArtListPageState();
}

class _FanArtListPageState extends ConsumerState<FanArtListPage> {
  String? _groupId;

  /// 左右滑的小數頁碼，篩選 pills 的深色底跟著它滑（D-118）。
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add(String? groupId) async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    await openFanArtNew(
      context,
      pitId: widget.pitId,
      initialImages: picked,
      initialGroupId: groupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'fan'))).value ?? const [];
    // 「無出處」pill：有出處的和沒出處的同人圖同時存在才出現，放在最後（同推活的「無分組」）。
    final all =
        ref.watch(fanArtsProvider((widget.pitId, null))).value ?? const [];
    final showNoSource =
        all.any((r) => r.groupId == null) && all.any((r) => r.groupId != null);
    final groupId =
        groups.any((g) => g.id == _groupId) ||
            (showNoSource && _groupId == fanArtNoSourceFilter)
        ? _groupId
        : null;
    final names = {for (final g in groups) g.id: g.name};
    // 標題列一律顯示全部張數。
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.fanArts;
    List<AlbumImage> imagesOf(WidgetRef ref, String? gid) => [
      for (final r
          in ref
                  .watch(fanArtsFilteredProvider((widget.pitId, gid, null)))
                  .value ??
              const [])
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
          mediaKind: r.kind,
          durationMs: r.durationMs,
          posterFile: r.posterFile,
        ),
    ];
    final images = imagesOf(ref, groupId);
    // 列表區左右滑動切換出處 chip（全部 → 各出處 →（無出處），不循環），內容跟著手指走（D-118）。
    final order = <String?>[
      null,
      for (final g in groups) g.id,
      if (showNoSource) fanArtNoSourceFilter,
    ];

    return AlbumView(
      pitId: widget.pitId,
      cell: AlbumCell.fan,
      title: context.l10n.pitsFanArt,
      images: images,
      sectionTabs: PitSectionTabBar(
        pitId: widget.pitId,
        selected: PitSection.fanArt,
      ),
      emptyLabel: context.l10n.albumFanEmpty,
      emptySvg: AppIcons.pitFanArt,
      total: total,
      emptyColor: context.tokens.fanArt,
      pages: AlbumSwipePages(
        order: order,
        current: groupId,
        progress: _progress,
        onChanged: (v) => setState(() => _groupId = v),
        imagesOf: imagesOf,
      ),
      onAdd: () => _add(groupId),
      onDelete: (picked) => db.deleteFanArts(picked.map((e) => e.id)),
      previewBuilder: (items, i) => FanArtPreviewPage(
        pitId: widget.pitId,
        images: items,
        initialIndex: i,
      ),
      panelBuilder: (context, image, openReference, dismiss) =>
          FanArtPreviewPanel(
            key: ValueKey(image.id),
            pitId: widget.pitId,
            image: image,
            onReference: openReference,
            onDismiss: dismiss,
          ),
      searchAction: SearchIconButton(pitId: widget.pitId),
      filter: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChipRow(
            options: [
              for (final g in groups) (g.id, g.name),
              if (showNoSource)
                (fanArtNoSourceFilter, context.l10n.albumPillNoSource),
            ],
            selected: groupId,
            progress: _progress,
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
