import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'image_masonry.dart';

/// 選擇封面：只列出該格（或整個坑）內的圖，點一下即設為封面，沒有選中狀態。
class CoverPickPage extends ConsumerWidget {
  const CoverPickPage({super.key, required this.pitId, this.kind});
  final String pitId;

  /// 限定來自哪一格；null 表示官方圖與同人圖都列出。
  final AlbumKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final official = kind == AlbumKind.fanArt
        ? const []
        : (ref.watch(officialProvider((pitId, null))).value ?? const []);
    final fan = kind == AlbumKind.official
        ? const []
        : (ref.watch(fanArtsProvider((pitId, null))).value ?? const []);
    final images = [
      for (final r in official)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.official,
        ),
      for (final r in fan)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.fanArt,
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('選擇封面')),
      body: images.isEmpty
          ? Center(
              child: Text('沒有可選的圖', style: TextStyle(color: t.text3)),
            )
          : ImageMasonry(
              images: images,
              onTap: (im, _) async {
                await ref.read(databaseProvider).setCover(pitId, im.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                showSnack(context, '已設為封面');
              },
            ),
    );
  }
}
