import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import 'album_view.dart';
import 'fan_art_new_page.dart';
import 'group_manage_page.dart';

/// 好看同人圖：出處 chips 篩選。
class FanArtListPage extends ConsumerStatefulWidget {
  const FanArtListPage({super.key, required this.pitId});
  final String pitId;

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
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.fanArts;
    final rows =
        ref.watch(fanArtsProvider((widget.pitId, groupId))).value ?? const [];
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
          createdAt: r.createdAt,
        ),
    ];
    return AlbumView(
      pitId: widget.pitId,
      title: '好看同人圖',
      images: images,
      emptyLabel: '還沒有同人圖',
      emptySvg: AppIcons.pitFanArt,
      total: total,
      emptyColor: context.tokens.fanArt,
      onAdd: () => _add(groupId),
      onDelete: (picked) => db.deleteFanArts(picked.map((e) => e.id)),
      filter: ChipRow(
        options: [for (final g in groups) (g.id, g.name)],
        selected: groupId,
        onSelected: (v) => setState(() => _groupId = v),
        trailing: ChipRowManageButton(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupManagePage(pitId: widget.pitId, kind: 'fan'),
            ),
          ),
        ),
      ),
    );
  }
}
