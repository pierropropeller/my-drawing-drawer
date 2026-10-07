import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/empty_state.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'image_masonry.dart';

/// 選擇坑的封面（主頁坑卡片上的圖）：長按坑內頁的某一格進入，只列出該格內的圖，
/// 點一下即設為封面，沒有選中狀態。
class CoverPickPage extends ConsumerWidget {
  const CoverPickPage({super.key, required this.pitId, this.kind});
  final String pitId;

  /// `official`／`fan`／`draft`／`idea`／`piece`；null＝整個坑的圖都列出（編輯坑的「更換封面」）。
  final String? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list =
        ref.watch(coverCandidatesProvider((pitId, kind))).value ?? const [];
    final images = [
      for (final c in list)
        AlbumImage(
          id: c.id,
          file: c.file,
          width: c.width,
          height: c.height,
          kind: AlbumKind.official,
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('選擇封面')),
      body: images.isEmpty
          ? EmptyState(
              icon: Icons.image_outlined,
              text: '沒有可選的圖',
              color: t.official,
            )
          : ImageMasonry(
              images: images,
              onTap: (im, _) async {
                await ref.read(databaseProvider).setCover(pitId, im.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                showSnack(context, '已設為坑的封面');
              },
            ),
    );
  }
}
