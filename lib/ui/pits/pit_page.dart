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
import '../entity/draft_list_page.dart';
import '../entity/finished_list_page.dart';
import '../entity/idea_list_page.dart';
import '../common/app_icons.dart';
import '../common/responsive.dart';
import '../common/sensitive_gate.dart';
import '../nav/adaptive_nav.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'pit_edit_page.dart';
import 'pit_junk_entry.dart';
import 'pit_oshi_entry.dart';
import 'pit_page_tablet.dart';
import 'pit_type_widgets.dart' show ShallowBadge, ShallowEmptyState;
import 'pits_icons.dart';

/// 坑內頁（Pit／PitFilled／PitDark，D-058）：六格正方形（2 欄 3 列）：官方圖冊、好看同人圖／
/// 我的草稿、我的腦洞／我的成圖、推活；文字（名稱＋數量）在格子下方。
/// 格內有封面圖時，整格鋪滿真實圖片（取代 icon）；推活格同樣有封面（指定或最新一張）。排序固定。
class PitPage extends ConsumerWidget {
  const PitPage({super.key, required this.pitId});
  final String pitId;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// 六個固定格之一（雜物不在這裡）。順序＝[PitSectionKey] 的順序。
  _Cell _cellFor(
    BuildContext context,
    PitSectionKey key,
    PitStats stats,
    CellCovers covers,
    VoidCallback? Function(int count, String kind) longPress,
    double side,
  ) {
    final t = context.tokens;
    final l = context.l10n;
    return switch (key) {
      PitSectionKey.official => _Cell(
        l.pitsOfficial,
        AppIcons.pitOfficial,
        t.official,
        l.commonCountImages(stats.official),
        side: side,
        file: covers.official,
        onTap: () => _open(context, OfficialListPage(pitId: pitId)),
        onLongPress: longPress(stats.official, 'official'),
      ),
      PitSectionKey.fan => _Cell(
        l.pitsFanArt,
        AppIcons.pitFanArt,
        t.fanArt,
        l.commonCountImages(stats.fanArts),
        side: side,
        file: covers.fanArt,
        onTap: () => _open(context, FanArtListPage(pitId: pitId)),
        onLongPress: longPress(stats.fanArts, 'fan'),
      ),
      PitSectionKey.idea => _Cell(
        l.pitsIdeas,
        AppIcons.pitIdea,
        t.idea,
        l.pitsCountIdeas(stats.ideas),
        side: side,
        file: covers.idea,
        onTap: () => _open(context, IdeaListPage(pitId: pitId)),
        onLongPress: longPress(stats.ideas, 'idea'),
      ),
      PitSectionKey.draft => _Cell(
        l.pitsDrafts,
        AppIcons.edit,
        t.draft,
        l.pitsCountDrafts(stats.drafts),
        side: side,
        file: covers.draft,
        onTap: () => _open(context, DraftListPage(pitId: pitId)),
        onLongPress: longPress(stats.drafts, 'draft'),
      ),
      PitSectionKey.piece => _Cell(
        l.pitsPieces,
        stats.pieces == 0 ? AppIcons.pitPieceEmpty : AppIcons.image,
        t.piece,
        l.pitsCountPieces(stats.pieces),
        side: side,
        file: covers.piece,
        // 有成圖但還沒有封面檔：灰粉底＋淡色相框（PitFilled）。
        placeholder: stats.pieces > 0,
        onTap: () => _open(context, FinishedListPage(pitId: pitId)),
        onLongPress: longPress(stats.pieces, 'piece'),
      ),
      _ => _Cell(
        l.pitsCellOshi,
        PitsIcons.oshi,
        t.oshi,
        l.pitsCellOshiCount(stats.oshi),
        side: side,
        file: covers.oshi,
        onTap: () => openOshiList(context, pitId),
        onLongPress: longPress(stats.oshi, 'oshi'),
      ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pit = ref.watch(pitProvider(pitId)).value;
    final stats = ref.watch(pitStatsProvider(pitId)).value ?? PitStats.empty;
    final covers =
        ref.watch(cellCoversProvider(pitId)).value ?? const CellCovers();
    if (pit == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final desc = pit.description;

    VoidCallback? longPress(int count, String kind) => count == 0
        ? null
        // 長按進入選擇封面（格內有圖才可）。
        : () => _open(context, CoverPickPage(pitId: pitId, kind: kind));

    // ≥600：iPad 版面（Pit／PitPortrait 稿）；＜600 維持手機版。
    final wc = WindowClass.of(context);
    if (!wc.isCompact) {
      return SideNavStyleHint.sidebar(
        currentPitId: pitId,
        child: PitPageTablet(
          pit: pit,
          stats: stats,
          covers: covers,
          wide: wc.isWide,
          longPress: longPress,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 返回／編輯 icon 對「標題＋描述」整塊垂直置中（Molly 10/23：有描述時 icon 在兩行中間，
                    // 同一般 app 的大小標題列；沒有描述時整塊就是標題，自然對齊）。
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _HeaderButton(
                          tooltip: context.l10n.commonBack,
                          svg: AppIcons.back,
                          size: 24,
                          strokeWidth: 1.9,
                          color: t.ink,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 6),
                        // 標題與描述放在同一欄，左邊緣由結構保證一致（不靠各自的 padding 數字）。
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 40,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          pit.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      if (pit.isShallow) const ShallowBadge(),
                                    ],
                                  ),
                                ),
                              ),
                              if (desc != null && desc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    desc,
                                    style: TextStyle(
                                      color: t.text2,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _HeaderButton(
                          tooltip: context.l10n.commonEdit,
                          svg: AppIcons.edit,
                          size: 21,
                          strokeWidth: 1.8,
                          color: t.text2,
                          onTap: () => openPitEdit(context, pit),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 正方形格邊長。
                    final side = (c.maxWidth - 40 - 12) / 2;
                    final cells = <_Cell>[
                      for (final k in PitSectionKey.values)
                        if (k != PitSectionKey.junk && pit.sectionOpen(k))
                          _cellFor(context, k, stats, covers, longPress, side),
                    ];
                    final showJunk = pit.junkEnabled;
                    // 淺坑一個格子都沒開（也沒有雜物）：空白狀態（PitShallowEmpty）。
                    if (pit.isShallow && cells.isEmpty && !showJunk) {
                      return ShallowEmptyState(
                        onOpen: () => openPitEdit(context, pit),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        for (var i = 0; i < cells.length; i += 2) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: cells[i]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: i + 1 < cells.length
                                    ? cells[i + 1]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ],
                        // 開啟「雜物」才出現，放在最底（PitJunk）。
                        if (showJunk)
                          PitJunkEntryRow(
                            count: stats.junk,
                            onTap: () => openJunk(context, pitId),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 坑內頁最底的「雜物」入口（手機與 iPad 共用）：上緣細線、icon、名稱、數量、箭頭。
class PitJunkEntryRow extends StatelessWidget {
  const PitJunkEntryRow({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: Row(
          children: [
            SvgIcon(PitsIcons.junk, size: 20, strokeWidth: 1.7, color: t.text4),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.junkTitle,
                style: TextStyle(
                  color: t.text2,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              context.l10n.commonCountImages(count),
              style: TextStyle(color: t.text4, fontSize: 12.5),
            ),
            const SizedBox(width: 12),
            SvgIcon(
              AppIcons.chevronRight,
              size: 18,
              strokeWidth: 2,
              color: t.text4,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.svg,
    required this.size,
    required this.strokeWidth,
    required this.color,
    required this.onTap,
  });
  final String tooltip;
  final String svg;
  final double size;
  final double strokeWidth;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    padding: EdgeInsets.zero,
    // 視覺 40×40；點擊區維持 Material 預設 48（標題列的點擊範圍就該比圖示大）。
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    icon: SvgIcon(svg, size: size, color: color, strokeWidth: strokeWidth),
  );
}

/// 名稱（15px 粗體）靠左、數量（12px）靠右，放在格子下方。
class _Caption extends StatelessWidget {
  const _Caption(this.label, this.count);
  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
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
                fontSize: 15,
              ),
            ),
          ),
          Text(count, style: TextStyle(color: t.text2, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(
    this.label,
    this.svg,
    this.color,
    this.count, {
    required this.side,
    this.onTap,
    this.onLongPress,
    this.file,
    this.placeholder = false,
  });

  final String label;
  final String svg;
  final CategoryColor color;
  final String count;
  final double side;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 這一格的封面圖（有圖時整格鋪滿，取代 icon）。
  final String? file;

  /// 沒有封面檔時用灰粉底＋淡色相框（有成圖、封面還沒好）。
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: side,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: file == null && placeholder
                    ? (dark ? t.chipBg : const Color(0xFFEAD9E0))
                    : color.bg,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              alignment: Alignment.center,
              child: file != null
                  ? SizedBox.expand(
                      child: SensitiveGate(
                        file: file!,
                        child: StoredImage(file!, cacheWidth: 600),
                      ),
                    )
                  : placeholder
                  ? SvgIcon(
                      svg,
                      size: 30,
                      color: t.ink.withValues(alpha: 0.24),
                      strokeWidth: 1.6,
                    )
                  : SvgIcon(svg, size: 34, color: color.fg, strokeWidth: 1.6),
            ),
          ),
          _Caption(label, count),
        ],
      ),
    );
  }
}
