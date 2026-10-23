import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/cover_pick_page.dart';
import '../album/fan_art_list_page.dart';
import '../album/official_list_page.dart';
import '../common/app_icons.dart';
import '../common/sensitive_gate.dart';
import '../common/svg_icon.dart';
import '../entity/draft_list_page.dart';
import '../entity/finished_list_page.dart';
import '../entity/idea_list_page.dart';
import '../search/search_icons.dart';
import '../search/tagged_list.dart';
import 'pit_edit_page.dart';
import 'pit_junk_entry.dart';
import 'pit_oshi_entry.dart';
import 'pit_page.dart';
import 'pit_type_widgets.dart' show ShallowBadge, ShallowEmptyState;
import 'pits_icons.dart';

/// iPad 版坑內頁（≥600）。
///
/// - [wide]（≥840，橫向 Pit 稿）：76 封面＋坑名／描述＋搜尋＋「編輯坑」，3 欄 4:3 tile。
///   側邊欄已有導覽，所以沒有返回鈕（與稿一致）。
/// - 否則（600–839，直向 PitPortrait 稿）：返回「我的坑」＋200 高封面（換封面）＋坑名列，
///   2 欄 16:10 tile。
/// - 稿沒畫雜物入口：開啟「雜物」時沿用手機版的入口列，放在 tile 下方。
class PitPageTablet extends ConsumerWidget {
  const PitPageTablet({
    super.key,
    required this.pit,
    required this.stats,
    required this.covers,
    required this.wide,
    required this.longPress,
  });
  final Pit pit;
  final PitStats stats;
  final CellCovers covers;
  final bool wide;

  /// 長按某格＝選擇該格封面（格內沒有圖時為 null）。
  final VoidCallback? Function(int count, String kind) longPress;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final pitId = pit.id;
    final coverFile = ref.watch(coverFileProvider(pitId)).value;
    final desc = pit.description;
    final padH = wide ? 40.0 : 32.0;

    Widget coverPlaceholder(double iconSize) => ColoredBox(
      color: t.official.bg,
      child: Center(
        child: SvgIcon(
          AppIcons.image,
          size: iconSize,
          strokeWidth: 1.5,
          color: t.ink.withValues(alpha: .26),
        ),
      ),
    );

    Widget outlined(
      String label,
      String svg,
      double iconSize,
      VoidCallback onTap, {
      required bool withLabel,
      double strokeWidth = 1.9,
    }) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 44,
            constraints: const BoxConstraints(minWidth: 44),
            padding: EdgeInsets.symmetric(horizontal: withLabel ? 16 : 0),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(
                  svg,
                  size: iconSize,
                  color: t.ink,
                  strokeWidth: strokeWidth,
                ),
                if (withLabel) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final titleBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  pit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
                ),
              ),
              if (pit.isShallow) const ShallowBadge(),
            ],
          ),
          if (desc != null && desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(desc, style: TextStyle(color: t.text2, fontSize: 13)),
            ),
        ],
      ),
    );
    final actions = <Widget>[
      outlined(
        l.commonSearch,
        SearchIcons.search,
        20,
        () => openPitSearch(context, pitId),
        withLabel: false,
      ),
      SizedBox(width: wide ? 18 : 12),
      outlined(
        l.pitsEditTitle,
        AppIcons.edit,
        18,
        () => openPitEdit(context, pit),
        withLabel: true,
        strokeWidth: 1.8,
      ),
    ];

    final allCells = <_Tile>[
      _Tile(
        sectionKey: PitSectionKey.official,
        label: l.pitsOfficial,
        count: l.commonCountImages(stats.official),
        svg: AppIcons.pitOfficial,
        color: t.official,
        file: covers.official,
        onTap: () => _open(context, OfficialListPage(pitId: pitId)),
        onLongPress: longPress(stats.official, 'official'),
      ),
      _Tile(
        sectionKey: PitSectionKey.fan,
        label: l.pitsFanArt,
        count: l.commonCountImages(stats.fanArts),
        svg: AppIcons.pitFanArt,
        color: t.fanArt,
        file: covers.fanArt,
        onTap: () => _open(context, FanArtListPage(pitId: pitId)),
        onLongPress: longPress(stats.fanArts, 'fan'),
      ),
      _Tile(
        sectionKey: PitSectionKey.idea,
        label: l.pitsIdeas,
        count: l.pitsCountIdeas(stats.ideas),
        svg: AppIcons.pitIdea,
        color: t.idea,
        file: covers.idea,
        onTap: () => _open(context, IdeaListPage(pitId: pitId)),
        onLongPress: longPress(stats.ideas, 'idea'),
      ),
      _Tile(
        sectionKey: PitSectionKey.draft,
        label: l.pitsDrafts,
        count: l.pitsCountDrafts(stats.drafts),
        svg: AppIcons.edit,
        color: t.draft,
        file: covers.draft,
        onTap: () => _open(context, DraftListPage(pitId: pitId)),
        onLongPress: longPress(stats.drafts, 'draft'),
      ),
      _Tile(
        sectionKey: PitSectionKey.piece,
        label: l.pitsPieces,
        count: l.commonCountImages(stats.pieces),
        svg: stats.pieces == 0 ? AppIcons.pitPieceEmpty : AppIcons.image,
        color: t.piece,
        file: covers.piece,
        placeholder: stats.pieces > 0,
        onTap: () => _open(context, FinishedListPage(pitId: pitId)),
        onLongPress: longPress(stats.pieces, 'piece'),
      ),
      _Tile(
        sectionKey: PitSectionKey.oshi,
        label: l.pitsCellOshi,
        count: l.pitsCellOshiCount(stats.oshi),
        svg: PitsIcons.oshi,
        color: t.oshi,
        file: covers.oshi,
        onTap: () => openOshiList(context, pitId),
        onLongPress: longPress(stats.oshi, 'oshi'),
      ),
    ];
    // 淺坑只顯示開啟的格子。
    final cells = [
      for (final c in allCells)
        if (pit.sectionOpen(c.sectionKey)) c,
    ];
    final showJunk = pit.junkEnabled;
    final emptyShallow = pit.isShallow && cells.isEmpty && !showJunk;
    final cols = wide ? 3 : 2;
    final aspect = wide ? 4 / 3 : 16 / 10;
    final gapX = wide ? 22.0 : 20.0;
    final gapY = wide ? 26.0 : 24.0;
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += cols) {
      if (i > 0) rows.add(SizedBox(height: gapY));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) SizedBox(width: gapX),
              Expanded(
                child: i + j < cells.length
                    ? cells[i + j].build(context, aspect)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(padH, wide ? 30 : 24, padH, 24),
          children: [
            if (wide)
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: PitCoverImage(
                        file: coverFile,
                        hasCoverRef: pit.hasCoverRef,
                        cacheWidth: 300,
                        placeholderColor: t.official.bg,
                        fallback: coverPlaceholder(28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  titleBlock,
                  const SizedBox(width: 18),
                  ...actions,
                ],
              )
            else ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: l.pitsMyPits,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgIcon(
                            AppIcons.back,
                            size: 20,
                            strokeWidth: 1.9,
                            color: t.text2,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            l.pitsMyPits,
                            style: TextStyle(color: t.text2, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PitCoverImage(
                        file: coverFile,
                        hasCoverRef: pit.hasCoverRef,
                        cacheWidth: 900,
                        placeholderColor: t.official.bg,
                        fallback: coverPlaceholder(40),
                      ),
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: Semantics(
                          button: true,
                          label: l.ipadpitChangeCover,
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                _open(context, CoverPickPage(pitId: pitId)),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: t.surface.withValues(alpha: .92),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgIcon(
                                    AppIcons.setCover,
                                    size: 16,
                                    strokeWidth: 1.8,
                                    color: t.ink,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    l.ipadpitChangeCover,
                                    style: TextStyle(
                                      color: t.ink,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [titleBlock, const SizedBox(width: 12), ...actions],
              ),
            ],
            SizedBox(height: wide ? 30 : 26),
            // 淺坑一個格子都沒開（也沒有雜物）：空白狀態（PitShallowEmpty）。
            if (emptyShallow)
              SizedBox(
                height: 360,
                child: ShallowEmptyState(
                  onOpen: () => openPitEdit(context, pit),
                ),
              ),
            ...rows,
            if (showJunk)
              PitJunkEntryRow(
                count: stats.junk,
                onTap: () => openJunk(context, pitId),
              ),
          ],
        ),
      ),
    );
  }
}

/// 一格：封面（或 icon）鋪滿 [aspect] 比例的圓角方塊，下方名稱＋數量。
class _Tile {
  const _Tile({
    required this.sectionKey,
    required this.label,
    required this.count,
    required this.svg,
    required this.color,
    required this.onTap,
    this.file,
    this.onLongPress,
    this.placeholder = false,
  });
  final PitSectionKey sectionKey;
  final String label;
  final String count;
  final String svg;
  final CategoryColor color;
  final String? file;

  /// 沒有封面檔時用灰粉底＋淡色相框（有成圖、封面還沒好）。
  final bool placeholder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  Widget build(BuildContext context, double aspect) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: aspect,
              child: Container(
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: file == null && placeholder
                      ? (dark ? t.chipBg : const Color(0xFFEAD9E0))
                      : color.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: file != null
                    ? SizedBox.expand(
                        // 列表類縮圖：已標記的圖照安全模式處理（D-104，手機 pit_page 也是）。
                        child: SensitiveGate(
                          file: file!,
                          child: StoredImage(file!, cacheWidth: 800),
                        ),
                      )
                    : SvgIcon(
                        svg,
                        size: 40,
                        color: placeholder
                            ? t.ink.withValues(alpha: 0.24)
                            : color.fg,
                        strokeWidth: 1.5,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(count, style: TextStyle(color: t.text2, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
