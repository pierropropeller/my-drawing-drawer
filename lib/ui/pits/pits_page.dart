import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../sync/pit_sync.dart';
import '../sync/sync_avatar.dart';
import 'pit_new_page.dart';
import 'pit_page.dart';
import 'pit_rows.dart';

/// 主頁：現坑／淺坑／封存坑三個分頁。現坑＝田字／瀑布切換、坑卡片、開新坑（最後一格的虛線格）；
/// 淺坑、封存坑＝純列表（小封面、坑名、一行副標、右箭頭），淺坑列表最底有「開新淺坑」（D-088）。
class PitsPage extends ConsumerStatefulWidget {
  const PitsPage({super.key});

  @override
  ConsumerState<PitsPage> createState() => _PitsPageState();
}

void _openNewPit(BuildContext context, {PitStatus status = PitStatus.active}) =>
    openNewPit(context, initialStatus: status);

class _PitsPageState extends ConsumerState<PitsPage> {
  PitStatus _tab = PitStatus.active;
  bool _grid = true; // true＝田字，false＝瀑布

  @override
  Widget build(BuildContext context) {
    final pits = ref.watch(pitsByStatusProvider(_tab));
    // 完全沒有坑（現坑、淺坑、封存坑都是空）：只留頭像與名字（MainEmpty）。
    final others = [
      for (final st in PitStatus.values)
        if (st != _tab) ref.watch(pitsByStatusProvider(st)).value,
    ];
    final nothingAtAll =
        pits.value != null &&
        pits.value!.isEmpty &&
        others.every((o) => o != null && o.isEmpty);
    final nickname = ref.watch(settingsProvider.select((s) => s.nickname));
    final wc = WindowClass.of(context);
    // ≥600 用 iPad 版面（頭像在 rail／sidebar，頁面標題是「我的坑」）；＜600 與手機版完全一樣。
    final tablet = !wc.isCompact;
    final wide = wc.isWide; // ≥840：現坑／封存坑與檢視切換同一列（Main）；否則獨立一行（MainPortrait）
    final padH = tablet ? (wide ? 40.0 : 32.0) : 20.0;
    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, st) in [
          (0, PitStatus.active),
          (1, PitStatus.shallow),
          (2, PitStatus.archived),
        ]) ...[
          if (i > 0) const SizedBox(width: 8),
          _FilterChip(
            label: switch (st) {
              PitStatus.active => context.l10n.pitsActive,
              PitStatus.shallow => context.l10n.shallowName,
              PitStatus.archived => context.l10n.pitsArchived,
            },
            selected: _tab == st,
            big: tablet,
            onTap: () => setState(() => _tab = st),
          ),
        ],
      ],
    );
    final toggle = _ViewToggle(
      grid: _grid,
      big: tablet,
      onChanged: (g) => setState(() => _grid = g),
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tablet)
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 30, padH, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.pitsMyPits,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontSize: wide ? 30 : 28,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (!nothingAtAll) ...[
                      if (wide) ...[pills, const SizedBox(width: 16)],
                      // 田字／瀑布只在「現坑」分頁。
                      if (_tab == PitStatus.active) toggle,
                    ],
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    // 同步狀態收在頭像外圈（D-052）；外圈不佔位，同步開始或結束頁面不會動。
                    const SyncAvatar(size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nickname.isEmpty ? context.l10n.pitsMyPits : nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontSize: 24, letterSpacing: 0.5),
                      ),
                    ),
                    if (!nothingAtAll && _tab == PitStatus.active) toggle,
                  ],
                ),
              ),
            if (!nothingAtAll && tablet && !wide)
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 16, padH, 0),
                child: pills,
              ),
            if (!nothingAtAll && !tablet)
              Padding(
                // 與列表的分組 pills 同一組間距（ChipRow：上 6、下 12）。
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: pills,
              ),
            // 離線時顯示離線橫條，不用彈窗。同步狀態在頭像外圈，不佔版面（D-052）。
            if (ref.watch(onlineProvider).value == false)
              _OfflineBanner(
                padH: padH,
                top: tablet ? (wide ? 18 : 16) : 2,
                fontSize: tablet ? 13 : 12,
              ),
            Expanded(
              child: pits.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(context.l10n.pitsLoadFailed('$e'))),
                data: (list) => switch (_tab) {
                  PitStatus.active =>
                    list.isEmpty
                        ? _Empty(tab: _tab)
                        : _PitList(
                            pits: list,
                            grid: _grid,
                            tablet: tablet,
                            wide: wide,
                          ),
                  PitStatus.shallow || PitStatus.archived =>
                    list.isEmpty
                        ? _Empty(tab: _tab)
                        : PitRows(
                            pits: list,
                            status: _tab,
                            tablet: tablet,
                            wide: wide,
                          ),
                },
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
  const _ViewToggle({
    required this.grid,
    required this.onChanged,
    this.big = false,
  });
  final bool grid;

  /// iPad：按鈕 44×38（觸控目標 ≥44）；手機 38×34。
  final bool big;
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
            width: big ? 44 : 38,
            height: big ? 38 : 34,
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
          button(true, context.l10n.pitsViewGrid, AppIcons.gridView),
          const SizedBox(width: 3),
          button(false, context.l10n.pitsViewWaterfall, AppIcons.waterfallView),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.padH = 20, this.top = 2, this.fontSize = 12});
  final double padH;
  final double top;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 設計稿的離線橫條色（沒有對應 token）。
    final bg = dark ? const Color(0xFF2E2823) : const Color(0xFFF1E8DC);
    final fg = dark ? const Color(0xFFC7B496) : const Color(0xFF7A6A52);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(padH, top, padH, 0),
      padding: EdgeInsets.symmetric(
        horizontal: padH == 20 ? 12 : 14,
        vertical: padH == 20 ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SvgIcon(AppIcons.cloudOff, size: 16, color: t.dashedText),
          const SizedBox(width: 8),
          Text(
            context.l10n.pitsOffline,
            style: TextStyle(color: fg, fontSize: fontSize),
          ),
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
    this.big = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// iPad：高 40、字 14（Main 稿）；手機維持 13。
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: big ? 40 : null,
        alignment: big ? Alignment.center : null,
        padding: EdgeInsets.symmetric(
          horizontal: big ? 18 : 16,
          vertical: big ? 0 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? t.ink : t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? t.surface : t.text2,
            fontSize: big ? 14 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 空白狀態（MainEmpty）：大圓角方塊資料夾圖示、說明、開新坑按鈕。
class _Empty extends StatelessWidget {
  const _Empty({required this.tab});
  final PitStatus tab;

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
              switch (tab) {
                PitStatus.active => context.l10n.pitsEmpty,
                PitStatus.shallow => context.l10n.shallowListEmpty,
                PitStatus.archived => context.l10n.pitsEmptyArchived,
              },
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (tab != PitStatus.archived) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () => _openNewPit(context, status: tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Row(
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
                        tab == PitStatus.shallow
                            ? context.l10n.shallowNewRow
                            : context.l10n.pitsNewTitle,
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
    this.tablet = false,
    this.wide = false,
  });
  final List<Pit> pits;
  final bool grid;

  /// ≥600：iPad 版面（欄數按闊度計、間距與字級照 Main／MainPortrait 稿）。
  final bool tablet;

  /// ≥840（橫向 Main）；false 為直向 MainPortrait 的間距。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final pad = tablet
        ? EdgeInsets.fromLTRB(wide ? 40 : 32, 22, wide ? 40 : 32, 24)
        : const EdgeInsets.fromLTRB(20, 12, 20, 24);
    final gapX = tablet ? (wide ? 20.0 : 18.0) : 14.0;
    final gapY = tablet ? (grid ? 22.0 : 20.0) : 14.0;
    final itemCount = pits.length + 1;
    return LayoutBuilder(
      builder: (context, c) {
        // 手機沿用既有欄數；iPad 欄數 = max(2, floor(可用闊 ÷ 180))，拉窗逐格增減（RespSpec）。
        final cols = tablet
            ? gridColumnsFor(c.maxWidth - pad.horizontal)
            : columnsForWidth(MediaQuery.sizeOf(context).width);
        if (grid) {
          final colW = (c.maxWidth - pad.horizontal - gapX * (cols - 1)) / cols;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return GridView.builder(
            padding: pad,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: gapY,
              crossAxisSpacing: gapX,
              // 正方形封面 ＋ 名稱與統計兩行。
              mainAxisExtent: colW + (tablet ? 62 : 56) * textScale,
            ),
            itemCount: itemCount,
            itemBuilder: (_, i) => i == pits.length
                ? Align(
                    alignment: Alignment.topCenter,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _NewPitTile(tablet: tablet),
                    ),
                  )
                : PitCard(pit: pits[i], index: i, wide: false, tablet: tablet),
          );
        }
        return MasonryGridView.count(
          padding: pad,
          crossAxisCount: cols,
          mainAxisSpacing: gapY,
          crossAxisSpacing: gapX,
          itemCount: itemCount,
          itemBuilder: (_, i) => i == pits.length
              ? SizedBox(height: 120, child: _NewPitTile(tablet: tablet))
              : PitCard(pit: pits[i], index: i, wide: true, tablet: tablet),
        );
      },
    );
  }
}

/// 最後一格的虛線「開新坑」。
class _NewPitTile extends StatelessWidget {
  const _NewPitTile({this.tablet = false});

  /// iPad：圓角 18、加號 26、字 14（Main 稿）。
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNewPit(context),
      child: DashedBox(
        color: t.dashed,
        radius: tablet ? 18 : Radii.card,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(AppIcons.plus, size: tablet ? 26 : 24, color: t.text4),
              SizedBox(height: tablet ? 8 : 6),
              Text(
                context.l10n.pitsNewTitle,
                style: TextStyle(
                  color: t.text4,
                  fontSize: tablet ? 14 : 13,
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
    this.tablet = false,
  });
  final Pit pit;
  final bool wide;
  final int index;

  /// iPad（Main 稿）：封面圓角 18、名稱 16、統計 12.5、瀑布封面高 180～260。
  final bool tablet;

  static const _waterfallHeights = [150.0, 188.0, 132.0, 166.0];
  static const _tabletWaterfallHeights = [
    210.0,
    260.0,
    180.0,
    236.0,
    196.0,
    248.0,
  ];

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
    final placeholder = tints[index % tints.length];
    // 還沒下載完的封面由 StoredImage 自己畫佔位底色＋淡色＋下載角標（D-052）。
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(tablet ? 18 : Radii.card),
      child: coverFile != null
          ? StoredImage(
              coverFile,
              cacheWidth: 600,
              placeholderColor: placeholder,
            )
          : ColoredBox(
              color: placeholder,
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
                height: tablet
                    // 稿的欄寬約 198，高度隨欄寬等比，限制在 0.8～1.4 倍。
                    ? _tabletWaterfallHeights[index %
                              _tabletWaterfallHeights.length] *
                          (c.maxWidth / 198).clamp(0.8, 1.4)
                    : _waterfallHeights[index % _waterfallHeights.length] *
                          (c.maxWidth / 168).clamp(1.0, 1.6),
                width: double.infinity,
                child: cover,
              ),
            )
          else
            Expanded(child: SizedBox.expand(child: cover)),
          Padding(
            padding: EdgeInsets.fromLTRB(2, tablet ? 10 : 8, 2, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tablet ? 16 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // iPad：這個坑有圖片正在下載時，統計換成「同步中…」（MainSyncing 稿）。
                  tablet && ref.watch(pitSyncingProvider(pit.id))
                      ? context.l10n.ipadsyncPitSyncingMeta
                      : context.l10n.pitsStatsLine(
                          stats.pieces,
                          stats.openIdeas,
                        ),
                  style: TextStyle(
                    color: t.text2,
                    fontSize: tablet ? 12.5 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
