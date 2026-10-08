import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/junk_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_icons.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import 'junk_preview_page.dart';

/// 雜物（JunkList／JunkSelect，D-034）：3 欄正方形純圖格、右下新增鈕；有底部導覽列。
/// 長按多選（分享／下載／移動／刪除）時導覽列隱藏。坑內頁的「雜物」入口 push 這一頁。
class JunkListPage extends ConsumerWidget {
  const JunkListPage({super.key, required this.pitId});
  final String pitId;

  /// 新增：開相簿選圖，直接加入雜物（雜物沒有分組、作者、tag，不需要表單）。
  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty) return;
    final store = await ref.read(imageStoreProvider.future);
    final imported = <NewImage>[for (final f in picked) await store.import(f)];
    await ref.read(databaseProvider).addJunk(pitId, imported);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.watch(databaseProvider);
    final rows = ref.watch(junkProvider(pitId)).value ?? const [];
    final images = [
      for (final r in rows)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.junk,
          createdAt: r.createdAt,
        ),
    ];
    return AlbumView(
      pitId: pitId,
      cell: AlbumCell.junk,
      squares: true,
      shareInSelect: true,
      title: '雜物',
      images: images,
      emptyLabel: '還沒有雜物',
      emptySvg: AlbumIcons.junk,
      emptyColor: CategoryColor(t.chipBg, t.text3),
      onAdd: () => _add(context, ref),
      onDelete: (picked) => db.deleteJunk(picked.map((e) => e.id)),
      previewBuilder: (items, i) =>
          JunkPreviewPage(pitId: pitId, images: items, initialIndex: i),
    );
  }
}
