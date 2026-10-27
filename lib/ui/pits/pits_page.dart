import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../search/search_icons.dart';
import '../search/tagged_list.dart';
import '../sync/pit_sync.dart';
import '../sync/sync_avatar.dart';
import '../common/sliding_pills.dart';
import '../common/swipe_pager.dart';
import 'pit_new_page.dart';
import 'pit_page.dart';
import 'pit_rows.dart';

/// 主頁：現坑／淺坑／封存坑三個分頁，右上是「搜尋全部坑」鍵（D-105）。現坑＝固定田字的坑卡片、開新坑（最後一格的虛線格）；
/// 淺坑、封存坑＝純列表（小封面、坑名、一行副標、右箭頭），淺坑列表最底有「開新淺坑」（D-088）。
class PitsPage extends ConsumerStatefulWidget {
  const PitsPage({super.key});

  @override
  ConsumerState<PitsPage> createState() => _PitsPageState();
}

void _openNewPit(BuildContext context, {PitStatus status = PitStatus.active}) =>
    openNewPit(context, initialStatus: status);

class _PitsPageState extends ConsumerState<PitsPage> {
  // 上次停留的分頁（設定，啟動即還原，第一格就是它）。
  late PitStatus _tab = ref.read(settingsProvider).lastPitsTab;

  static const _order = [
    PitStatus.active,
    PitStatus.shallow,
    PitStatus.archived,
  ];

  /// 左右滑的小數頁碼，pills 的深色底跟著它滑（D-118）。
  late final _progress = ValueNotifier<double>(_order.indexOf(_tab).toDouble());

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

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
    final wide = wc.isWide; // ≥840：標題、分頁與搜尋鍵同一列（Main）；否則獨立一行（MainPortrait）
    final padH = tablet ? (wide ? 40.0 : 32.0) : 20.0;
    void setTab(PitStatus st) {
      setState(() => _tab = st);
      ref.read(settingsProvider.notifier).setLastPitsTab(st);
    }

    String label(PitStatus st) => switch (st) {
      PitStatus.active => context.l10n.pitsActive,
      PitStatus.shallow => context.l10n.shallowName,
      PitStatus.archived => context.l10n.pitsArchived,
    };
    // 深色底跟著左右滑的進度滑（D-118）。
    final pills = SlidingPillRow(
      count: _order.length,
      progress: _progress,
      fill: context.tokens.surface,
      border: context.tokens.border,
      capsuleColor: context.tokens.ink,
      capsuleBorder: context.tokens.border,
      radius: Radii.chip,
      pill: (context, i, mix, decorated) => _FilterChip(
        label: label(_order[i]),
        selected: mix >= 0.5,
        mix: mix,
        decorated: decorated,
        big: tablet,
        onTap: () => setTab(_order[i]),
      ),
    );
    // 主頁右上的「搜尋全部坑」鍵（D-105，取代田字／瀑布切換）；三個分頁都有。
    final searchButton = _SearchAllButton(big: tablet);
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
                      searchButton,
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
                    if (!nothingAtAll) searchButton,
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
              // 左右滑動切換 現坑／淺坑／封存坑（不循環），內容跟著手指走（D-118）。
              child: SwipePager<PitStatus>(
                enabled: !nothingAtAll,
                order: _order,
                current: _tab,
                progress: _progress,
                onChanged: setTab,
                itemBuilder: (context, st) => Consumer(
                  builder: (context, ref, _) => ref
                      .watch(pitsByStatusProvider(st))
                      .when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text(context.l10n.pitsLoadFailed('$e')),
                        ),
                        data: (list) => switch (st) {
                          PitStatus.active =>
                            list.isEmpty
                                ? _Empty(tab: st)
                                : _PitList(
                                    pits: list,
                                    tablet: tablet,
                                    wide: wide,
                                  ),
                          PitStatus.shallow || PitStatus.archived =>
                            list.isEmpty
                                ? _Empty(tab: st)
                                : PitRows(
                                    pits: list,
                                    status: st,
                                    tablet: tablet,
                                    wide: wide,
                                  ),
                        },
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主頁右上的搜尋鍵（Main）：42px 白底圓角方塊＋放大鏡，點了進全坑搜尋（GlobalSearch）。
/// iPad 沿用同一顆（觸控目標 44）。
class _SearchAllButton extends StatelessWidget {
  const _SearchAllButton({this.big = false});
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = big ? 44.0 : 42.0;
    return Semantics(
      button: true,
      label: context.l10n.globalSearchHint,
      child: GestureDetector(
        key: const ValueKey('mainSearchButton'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openGlobalSearch(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SvgIcon(
              SearchIcons.search,
              size: 21,
              strokeWidth: 1.9,
              color: t.ink,
            ),
          ),
        ),
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
    this.mix,
    this.decorated = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// [SlidingPillRow] 用：字色在未選（0）和選中（1）之間的位置。
  final double? mix;

  /// false＝底色和框透明（由 [SlidingPillRow] 畫），大小不變。
  final bool decorated;

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
          color: decorated ? (selected ? t.ink : t.surface) : null,
          border: Border.all(color: decorated ? t.border : Colors.transparent),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: mix != null
                ? Color.lerp(t.text2, t.surface, mix!)
                : (selected ? t.surface : t.text2),
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
  const _PitList({required this.pits, this.tablet = false, this.wide = false});
  final List<Pit> pits;

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
    final gapY = tablet ? 22.0 : 14.0;
    final itemCount = pits.length + 1;
    return LayoutBuilder(
      builder: (context, c) {
        // 手機沿用既有欄數；iPad 欄數 = max(2, floor(可用闊 ÷ 180))，拉窗逐格增減（RespSpec）。
        final cols = tablet
            ? gridColumnsFor(c.maxWidth - pad.horizontal)
            : columnsForWidth(MediaQuery.sizeOf(context).width);
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
              : PitCard(pit: pits[i], index: i, tablet: tablet),
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
/// 封面固定正方形（D-105：主頁現坑固定田字，沒有瀑布檢視）。
class PitCard extends ConsumerWidget {
  const PitCard({
    super.key,
    required this.pit,
    this.index = 0,
    this.tablet = false,
  });
  final Pit pit;
  final int index;

  /// iPad（Main 稿）：封面圓角 18、名稱 16、統計 12.5。
  final bool tablet;

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
      child: PitCoverImage(
        file: coverFile,
        hasCoverRef: pit.hasCoverRef,
        cacheWidth: 600,
        placeholderColor: placeholder,
        fallback: ColoredBox(
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
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pit.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
