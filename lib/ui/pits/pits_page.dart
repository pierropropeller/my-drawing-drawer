import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/database.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/user_avatar.dart';
import 'pit_new_page.dart';
import 'pit_page.dart';

/// 主頁：現坑／封存坑、田字／瀑布切換、坑卡片、開新坑（最後一格的虛線格）。
class PitsPage extends ConsumerStatefulWidget {
  const PitsPage({super.key});

  @override
  ConsumerState<PitsPage> createState() => _PitsPageState();
}

void _openNewPit(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PitNewPage()));

class _PitsPageState extends ConsumerState<PitsPage> {
  bool _archived = false;
  bool _grid = true; // true＝田字，false＝瀑布

  @override
  Widget build(BuildContext context) {
    final pits = ref.watch(pitsProvider(_archived));
    final otherCount = ref.watch(pitsProvider(!_archived)).value?.length ?? 0;
    final nickname = ref.watch(settingsProvider.select((s) => s.nickname));
    // 完全沒有坑（現坑、封存坑都是空）：只留頭像與名字（MainEmpty）。
    final nothingAtAll =
        !_archived &&
        pits.value != null &&
        pits.value!.isEmpty &&
        otherCount == 0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const UserAvatar(size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nickname.isEmpty ? '我的坑' : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 24, letterSpacing: 0.5),
                    ),
                  ),
                  if (!nothingAtAll)
                    _ViewToggle(
                      grid: _grid,
                      onChanged: (g) => setState(() => _grid = g),
                    ),
                ],
              ),
            ),
            if (!nothingAtAll)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    _FilterChip(
                      label: '現坑',
                      selected: !_archived,
                      onTap: () => setState(() => _archived = false),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: '封存坑',
                      selected: _archived,
                      onTap: () => setState(() => _archived = true),
                    ),
                  ],
                ),
              ),
            // 離線時顯示橫條，不用彈窗；沒有手動備份按鈕。
            if (ref.watch(onlineProvider).value == false)
              const _OfflineBanner(),
            Expanded(
              child: pits.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('載入失敗：$e')),
                data: (list) => list.isEmpty
                    ? _Empty(archived: _archived)
                    : _PitList(pits: list, grid: _grid, archived: _archived),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 田字／瀑布切換（白底小膠囊，選中＝主色底白圖示）。
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onChanged});
  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget button(bool isGrid, String label, String icon) {
      final on = grid == isGrid;
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(isGrid),
          child: Container(
            width: 38,
            height: 34,
            decoration: BoxDecoration(
              color: on ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: SvgIcon(
                icon,
                size: 20,
                color: on ? Colors.white : t.text4,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(true, '田字檢視', AppIcons.gridView),
          const SizedBox(width: 3),
          button(false, '瀑布檢視', AppIcons.waterfallView),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 設計稿的離線橫條色（沒有對應 token）。
    final bg = dark ? const Color(0xFF2E2823) : const Color(0xFFF1E8DC);
    final fg = dark ? const Color(0xFFC7B496) : const Color(0xFF7A6A52);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SvgIcon(AppIcons.cloudOff, size: 16, color: t.dashedText),
          const SizedBox(width: 8),
          Text('離線中・恢復網絡後將自動上傳', style: TextStyle(color: fg, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? t.ink : t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? t.surface : t.text2,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 空白狀態（MainEmpty）：大圓角方塊資料夾圖示、說明、開新坑按鈕。
class _Empty extends StatelessWidget {
  const _Empty({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: t.piece.bg,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Center(
                child: SvgIcon(
                  AppIcons.folder,
                  size: 42,
                  strokeWidth: 1.5,
                  color: t.piece.fg,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              archived ? '沒有封存的坑' : '還沒有坑',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (!archived) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => _openNewPit(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIcon(
                        AppIcons.plus,
                        size: 18,
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        '開新坑',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PitList extends StatelessWidget {
  const _PitList({
    required this.pits,
    required this.grid,
    required this.archived,
  });
  final List<Pit> pits;
  final bool grid;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(20, 12, 20, 24);
    final cols = columnsForWidth(MediaQuery.sizeOf(context).width);
    if (grid) {
      return LayoutBuilder(
        builder: (context, c) {
          final colW = (c.maxWidth - pad.horizontal - 14 * (cols - 1)) / cols;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return GridView.builder(
            padding: pad,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              // 正方形封面 ＋ 名稱與統計兩行。
              mainAxisExtent: colW + 56 * textScale,
            ),
            itemCount: pits.length + (archived ? 0 : 1),
            itemBuilder: (_, i) => i == pits.length
                ? Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: const _NewPitTile(),
                    ),
                  )
                : PitCard(pit: pits[i], index: i, wide: false),
          );
        },
      );
    }
    return MasonryGridView.count(
      padding: pad,
      crossAxisCount: cols,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      itemCount: pits.length + (archived ? 0 : 1),
      itemBuilder: (_, i) => i == pits.length
          ? const SizedBox(height: 120, child: _NewPitTile())
          : PitCard(pit: pits[i], index: i, wide: true),
    );
  }
}

/// 最後一格的虛線「開新坑」。
class _NewPitTile extends StatelessWidget {
  const _NewPitTile();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNewPit(context),
      child: DashedBox(
        color: t.dashed,
        radius: Radii.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(AppIcons.plus, size: 24, color: t.text4),
              const SizedBox(height: 6),
              Text(
                '開新坑',
                style: TextStyle(
                  color: t.text4,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 坑卡片：封面（沒有圖就用分類色底＋圖片佔位符）＋坑名＋「N 成圖 · N 腦洞未孵」。
/// [wide]＝瀑布檢視：封面高度依序在 132～188 之間錯落（設計稿）；否則為正方形。
class PitCard extends ConsumerWidget {
  const PitCard({
    super.key,
    required this.pit,
    required this.wide,
    this.index = 0,
  });
  final Pit pit;
  final bool wide;
  final int index;

  static const _waterfallHeights = [150.0, 188.0, 132.0, 166.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stats = ref.watch(pitStatsProvider(pit.id)).value ?? PitStats.empty;
    final coverFile = ref.watch(coverFileProvider(pit.id)).value;
    // 佔位底色依序為官方／同人／草稿色與設計稿的淡綠（沒有對應 token）。
    final tints = [
      t.official.bg,
      t.fanArt.bg,
      t.draft.bg,
      dark ? const Color(0xFF2C3529) : const Color(0xFFE7EFE4),
    ];
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: coverFile != null
          ? StoredImage(coverFile, cacheWidth: 600)
          : ColoredBox(
              color: tints[index % tints.length],
              child: Center(
                child: SvgIcon(
                  AppIcons.image,
                  size: 30,
                  strokeWidth: 1.6,
                  color: dark
                      ? Colors.white.withValues(alpha: .22)
                      : t.ink.withValues(alpha: .26),
                ),
              ),
            ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pit.id))),
      // 長按坑卡片：選擇這個坑的封面（從坑內所有圖裡挑）。
      onLongPress: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CoverPickPage(pitId: pit.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (wide)
            LayoutBuilder(
              builder: (_, c) => SizedBox(
                height:
                    _waterfallHeights[index % _waterfallHeights.length] *
                    (c.maxWidth / 168).clamp(1.0, 1.6),
                width: double.infinity,
                child: cover,
              ),
            )
          else
            Expanded(child: SizedBox.expand(child: cover)),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stats.pieces} 成圖 · ${stats.openIdeas} 腦洞未孵',
                  style: TextStyle(color: t.text2, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
