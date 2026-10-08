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
import '../common/dashed_box.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import 'pit_edit_page.dart';
import 'pit_junk_entry.dart';
import 'pits_icons.dart';

/// 坑內頁（Pit／PitFilled／PitDark）：2×2 正方形格（官方圖冊、好看同人圖、我的草稿、我的腦洞），
/// 文字（名稱＋數量）在格子下方；最後是寬格「我的成圖」，高度與上方一格正方形相同。
/// 格內有封面圖時，整格鋪滿真實圖片（取代 icon）。排序固定。
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
                    Row(
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
                        Expanded(
                          child: Text(
                            pit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        _HeaderButton(
                          tooltip: context.l10n.commonEdit,
                          svg: AppIcons.edit,
                          size: 21,
                          strokeWidth: 1.8,
                          color: t.text2,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PitEditPage(pit: pit),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (desc != null && desc.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 46, top: 2),
                        child: Text(
                          desc,
                          style: TextStyle(color: t.text2, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // 正方形格邊長；寬格高度與它相同。
                    final side = (c.maxWidth - 40 - 12) / 2;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Cell(
                                context.l10n.pitsOfficial,
                                AppIcons.pitOfficial,
                                t.official,
                                context.l10n.commonCountImages(stats.official),
                                side: side,
                                file: covers.official,
                                onTap: () => _open(
                                  context,
                                  OfficialListPage(pitId: pitId),
                                ),
                                onLongPress: longPress(
                                  stats.official,
                                  'official',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Cell(
                                context.l10n.pitsFanArt,
                                AppIcons.pitFanArt,
                                t.fanArt,
                                context.l10n.commonCountImages(stats.fanArts),
                                side: side,
                                file: covers.fanArt,
                                onTap: () => _open(
                                  context,
                                  FanArtListPage(pitId: pitId),
                                ),
                                onLongPress: longPress(stats.fanArts, 'fan'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _Cell(
                                context.l10n.pitsDrafts,
                                AppIcons.edit,
                                t.draft,
                                context.l10n.pitsCountDrafts(stats.drafts),
                                side: side,
                                file: covers.draft,
                                onTap: () =>
                                    _open(context, DraftListPage(pitId: pitId)),
                                onLongPress: longPress(stats.drafts, 'draft'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Cell(
                                context.l10n.pitsIdeas,
                                AppIcons.pitIdea,
                                t.idea,
                                context.l10n.pitsCountIdeas(stats.ideas),
                                side: side,
                                file: covers.idea,
                                onTap: () =>
                                    _open(context, IdeaListPage(pitId: pitId)),
                                onLongPress: longPress(stats.ideas, 'idea'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _PieceBlock(
                          height: side,
                          count: stats.pieces,
                          file: covers.piece,
                          onTap: () =>
                              _open(context, FinishedListPage(pitId: pitId)),
                          onLongPress: longPress(stats.pieces, 'piece'),
                        ),
                        // 開啟「雜物」才出現，放在最底（PitJunk）。
                        if (pit.junkEnabled)
                          _JunkEntry(
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

/// 坑內頁最底的「雜物」入口：上緣細線、icon、名稱、數量、箭頭。
class _JunkEntry extends StatelessWidget {
  const _JunkEntry({required this.count, required this.onTap});
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

  @override
  Widget build(BuildContext context) {
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
                color: color.bg,
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              alignment: Alignment.center,
              child: file != null
                  ? SizedBox.expand(child: StoredImage(file!, cacheWidth: 600))
                  : SvgIcon(svg, size: 34, color: color.fg, strokeWidth: 1.6),
            ),
          ),
          _Caption(label, count),
        ],
      ),
    );
  }
}

/// 寬格「我的成圖」：高度＝上方正方形格的高度。
/// 有成圖：圓角面板（內距 6）裡放縮圖＋虛線「＋」，名稱／數量在面板下方；
/// 尚無成圖：淡色卡片，置中 icon 塊＋「我的成圖」＋提示。
class _PieceBlock extends StatelessWidget {
  const _PieceBlock({
    required this.height,
    required this.count,
    required this.onTap,
    this.file,
    this.onLongPress,
  });

  final double height;
  final int count;
  final String? file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = t.piece;
    if (count == 0) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2F2420) : const Color(0xFFFBF1ED),
            border: Border.all(
              color: dark ? const Color(0xFF4A3329) : const Color(0xFFF1DBD1),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF4A3128)
                      : const Color(0xFFF6DDD3),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: SvgIcon(
                  AppIcons.pitPieceEmpty,
                  size: 28,
                  color: c.fg,
                  strokeWidth: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.pitsPieces,
                style: TextStyle(
                  color: t.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.pitsPiecesEmpty,
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFE0A28C)
                      : const Color(0xFF8A5443),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final thumbTint = dark ? t.chipBg : const Color(0xFFEAD9E0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 14,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: thumbTint,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: file != null
                        ? SizedBox.expand(
                            child: StoredImage(file!, cacheWidth: 600),
                          )
                        : SvgIcon(
                            AppIcons.image,
                            size: 28,
                            color: t.ink.withValues(alpha: 0.24),
                            strokeWidth: 1.6,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 10,
                  child: SizedBox.expand(
                    child: DashedBox(
                      color: dark ? t.dashed : const Color(0xFFE9C3B6),
                      radius: 11,
                      child: Center(
                        child: SvgIcon(
                          AppIcons.plus,
                          size: 22,
                          color: dark ? t.dashedText : const Color(0xFFD9A291),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _Caption(
            context.l10n.pitsPieces,
            context.l10n.commonCountImages(count),
          ),
        ],
      ),
    );
  }
}
