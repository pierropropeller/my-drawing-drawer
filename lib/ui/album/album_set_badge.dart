import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../common/svg_icon.dart';
import 'album_icons.dart';

/// 多圖的官方圖／同人圖在列表縮圖右上角的「⧉ N」小標（D-136，OfficialListMulti）：
/// 深色半透明膠囊、疊圖 icon＋總張數。只有一張時不畫。
class AlbumSetBadge extends ConsumerWidget {
  const AlbumSetBadge(this.imageKey, {super.key});
  final String imageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extra = ref.watch(albumExtraCountsProvider).value?[imageKey] ?? 0;
    if (extra <= 0) return const SizedBox.shrink();
    final n = extra + 1;
    return Semantics(
      label: context.l10n.albumSetCount(n),
      child: Container(
        key: const ValueKey('albumSetBadge'),
        padding: const EdgeInsets.fromLTRB(6, 3, 7, 3),
        decoration: BoxDecoration(
          color: const Color(0x8C2B2622),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SvgIcon(
              AlbumIcons.stack,
              size: 12,
              color: Colors.white,
              strokeWidth: 2.2,
            ),
            const SizedBox(width: 3),
            Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
