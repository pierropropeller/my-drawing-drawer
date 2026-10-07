import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'album_image.dart';
import 'album_view.dart';
import 'fan_art_new_page.dart';
import 'fan_art_sources.dart';

/// 好看同人圖：出處 chips 篩選。
class FanArtListPage extends ConsumerStatefulWidget {
  const FanArtListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<FanArtListPage> createState() => _FanArtListPageState();
}

class _FanArtListPageState extends ConsumerState<FanArtListPage> {
  String? _source;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final rows =
        ref.watch(fanArtsProvider((widget.pitId, _source))).value ?? const [];
    final images = [
      for (final r in rows)
        AlbumImage(
          id: r.id,
          file: r.imageFile,
          width: r.width,
          height: r.height,
          kind: AlbumKind.fanArt,
        ),
    ];
    return AlbumView(
      pitId: widget.pitId,
      title: '好看同人圖',
      images: images,
      emptyLabel: '還沒有同人圖',
      emptyIcon: Icons.favorite_border,
      emptyColor: context.tokens.fanArt,
      onAdd: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FanArtNewPage(pitId: widget.pitId),
        ),
      ),
      onDelete: (picked) => db.deleteFanArts(picked.map((e) => e.id)),
      filter: ChipRow(
        options: [for (final s in fanArtSources) (s, s)],
        selected: _source,
        onSelected: (v) => setState(() => _source = v),
      ),
    );
  }
}
