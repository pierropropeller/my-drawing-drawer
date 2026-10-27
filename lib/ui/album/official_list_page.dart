import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../media_source/drop_zone.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import 'album_panels.dart';
import 'album_view.dart';
import 'group_manage_page.dart';
import 'image_preview_page.dart';
import 'official_new_page.dart';
import '../pits/pit_section_tabs.dart';

/// 官方圖冊：分組 chips，最右固定「管理分組」icon。
class OfficialListPage extends ConsumerStatefulWidget {
  const OfficialListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<OfficialListPage> createState() => _OfficialListPageState();
}

class _OfficialListPageState extends ConsumerState<OfficialListPage> {
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
    await _openNew(groupId, picked);
  }

  /// 進入新增頁（圖已選好）。從其他 App 拖放進來（MediaDrop）也走這裡：
  /// 新增頁就是「放開後選擇分組」那一步（分組 chips＋加入按鈕）。
  Future<void> _openNew(String? groupId, List<XFile> picked) async {
    await openOfficialNew(
      context,
      pitId: widget.pitId,
      initialGroupId: groupId,
      initialImages: picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final db = ref.watch(databaseProvider);
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'official'))).value ?? const [];
    // 篩選中的分組被刪除時退回「全部」。
    final groupId = groups.any((g) => g.id == _groupId) ? _groupId : null;
    final names = {for (final g in groups) g.id: g.name};
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.official;
    List<AlbumImage> imagesOf(WidgetRef ref, String? gid) => [
      for (final r
          in ref
                  .watch(officialFilteredProvider((widget.pitId, gid, null)))
                  .value ??
              const [])
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.official,
          groupName: names[r.groupId],
          groupId: r.groupId,
          createdAt: r.createdAt,
          mediaKind: r.kind,
          durationMs: r.durationMs,
          posterFile: r.posterFile,
        ),
    ];
    final images = imagesOf(ref, groupId);
    // 列表區左右滑動切換分組 chip（全部 → 各分組，不循環），內容跟著手指走（D-118）。
    final order = <String?>[null, for (final g in groups) g.id];

    final view = AlbumView(
      pitId: widget.pitId,
      cell: AlbumCell.official,
      title: context.l10n.pitsOfficial,
      images: images,
      sectionTabs: PitSectionTabBar(
        pitId: widget.pitId,
        selected: PitSection.official,
      ),
      emptyLabel: context.l10n.albumOfficialEmpty,
      emptySvg: AppIcons.pitOfficial,
      total: total,
      emptyColor: t.official,
      pages: AlbumSwipePages(
        order: order,
        current: groupId,
        progress: _progress,
        onChanged: (v) => setState(() => _groupId = v),
        imagesOf: imagesOf,
      ),
      onAdd: () => _add(groupId),
      onDelete: (picked) => db.deleteOfficial(picked.map((e) => e.id)),
      previewBuilder: (items, i) =>
          ImagePreviewPage(pitId: widget.pitId, images: items, initialIndex: i),
      panelBuilder: (context, image, openReference, dismiss) =>
          OfficialPreviewPanel(
            key: ValueKey(image.id),
            pitId: widget.pitId,
            image: image,
            onReference: openReference,
            onDismiss: dismiss,
          ),
      filter: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChipRow(
            options: [for (final g in groups) (g.id, g.name)],
            selected: groupId,
            progress: _progress,
            onSelected: (v) => setState(() => _groupId = v),
            trailing: ChipRowManageButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GroupManagePage(pitId: widget.pitId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // 從「照片」「檔案」拖放圖片／影片進來（MediaDrop）；只有這個列表頁和新增官方圖頁收。
    return DropZone(
      title: context.l10n.ipadmediaDropTitle(context.l10n.pitsOfficial),
      subtitleFor: context.l10n.ipadmediaDropChooseGroup,
      onFiles: (files) => _openNew(groupId, files),
      child: view,
    );
  }
}
