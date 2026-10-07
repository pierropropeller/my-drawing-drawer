import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../album/fan_art_list_page.dart';
import '../album/official_list_page.dart';
import 'pit_edit_page.dart';

/// 坑內頁：五格排序固定（官方圖冊、好看同人圖、我的草稿、我的腦洞、我的成圖）。
/// 成圖尚無時為空白虛線格；有成圖時為寬格。
class PitPage extends ConsumerWidget {
  const PitPage({super.key, required this.pitId});
  final String pitId;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pit = ref.watch(pitProvider(pitId)).value;
    final stats = ref.watch(pitStatsProvider(pitId)).value ?? PitStats.empty;
    if (pit == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final desc = pit.description;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '編輯',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => PitEditPage(pit: pit)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(pit.name, style: Theme.of(context).textTheme.headlineMedium),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(color: t.text2, height: 1.4)),
          ],
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Cell(
                '官方圖冊',
                Icons.photo_library_outlined,
                t.official,
                stats.official,
                onTap: () => _open(context, OfficialListPage(pitId: pitId)),
                // 長按進入選擇封面（格內有圖才可）。
                onLongPress: stats.official == 0
                    ? null
                    : () => _open(
                        context,
                        CoverPickPage(pitId: pitId, kind: AlbumKind.official),
                      ),
              ),
              _Cell(
                '好看同人圖',
                Icons.favorite_border,
                t.fanArt,
                stats.fanArts,
                onTap: () => _open(context, FanArtListPage(pitId: pitId)),
                onLongPress: stats.fanArts == 0
                    ? null
                    : () => _open(
                        context,
                        CoverPickPage(pitId: pitId, kind: AlbumKind.fanArt),
                      ),
              ),
              _Cell('我的草稿', Icons.draw_outlined, t.draft, stats.drafts),
              _Cell('我的腦洞', Icons.lightbulb_outline, t.idea, stats.ideas),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: _Cell(
              '我的成圖',
              Icons.palette_outlined,
              t.piece,
              stats.pieces,
              wide: true,
              empty: stats.pieces == 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.label,
    this.icon,
    this.color,
    this.count, {
    this.wide = false,
    this.empty = false,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final CategoryColor color;
  final int count;
  final bool wide;
  final bool empty;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = empty ? t.dashedText : color.fg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: empty ? Colors.transparent : color.bg,
          borderRadius: BorderRadius.circular(Radii.card),
          border: empty ? Border.all(color: t.dashed, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: fg, size: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: wide ? 22 : 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
