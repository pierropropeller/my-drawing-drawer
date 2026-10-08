import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'album_image.dart';
import 'album_view.dart';
import 'group_manage_page.dart';
import 'official_new_page.dart';

/// 官方圖冊：分組 chips，最右固定「管理分組」icon。
class OfficialListPage extends ConsumerStatefulWidget {
  const OfficialListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<OfficialListPage> createState() => _OfficialListPageState();
}

class _OfficialListPageState extends ConsumerState<OfficialListPage> {
  String? _groupId;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add(String? groupId) async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfficialNewPage(
          pitId: widget.pitId,
          initialGroupId: groupId,
          initialImages: picked,
        ),
      ),
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
    final rows =
        ref.watch(officialProvider((widget.pitId, groupId))).value ?? const [];
    final images = [
      for (final r in rows)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.official,
          groupName: names[r.groupId],
          groupId: r.groupId,
          createdAt: r.createdAt,
        ),
    ];
    return AlbumView(
      pitId: widget.pitId,
      cell: AlbumCell.official,
      title: '官方圖冊',
      images: images,
      emptyLabel: '還沒有官方圖',
      emptySvg: AppIcons.pitOfficial,
      total: total,
      emptyColor: t.official,
      onAdd: () => _add(groupId),
      onDelete: (picked) => db.deleteOfficial(picked.map((e) => e.id)),
      filter: ChipRow(
        options: [for (final g in groups) (g.id, g.name)],
        selected: groupId,
        onSelected: (v) => setState(() => _groupId = v),
        trailing: ChipRowManageButton(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupManagePage(pitId: widget.pitId),
            ),
          ),
        ),
      ),
    );
  }
}
