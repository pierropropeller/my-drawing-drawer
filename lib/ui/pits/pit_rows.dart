import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
import 'pit_new_page.dart';
import 'pit_page.dart';
import 'pit_reorder_grid.dart';
import 'pits_icons.dart';
import 'pit_type_widgets.dart';

/// iPad 淺坑／封存坑卡片的欄數（P-040）：內容區闊度（扣掉 sidebar／icon rail）≥ 640 兩欄，否則一欄。
int pitCardColumns(double contentWidth) => contentWidth >= 640 ? 2 : 1;

/// 主頁「淺坑」「封存坑」分頁的純列表（MainShallow／MainArchived，D-088）：
/// 左邊 56px 小正方形封面（圓角 12；沒封面＝坑名第一個字＋淡色底）、坑名（粗）＋一行副標、右箭頭。
/// [PitStatus.shallow] 的最底多一列「＋ 開新淺坑」。
class PitRows extends StatelessWidget {
  const PitRows({
    super.key,
    required this.pits,
    required this.status,
    this.tablet = false,
    this.wide = false,
    this.editing = false,
    this.onEnterEdit,
    this.onReorder,
    this.onCoverTap,
  });
  final List<Pit> pits;
  final PitStatus status;
  final bool tablet;
  final bool wide;

  /// 編輯排序（D-132，MainShallowSortEdit）：右箭頭換成拖動把手、點小封面＝[onCoverTap]，
  /// 「開新淺坑」先隱藏。長按任何一列＝[onEnterEdit] 並開始拖。
  final bool editing;
  final VoidCallback? onEnterEdit;
  final void Function(int from, int to)? onReorder;
  final void Function(Pit pit)? onCoverTap;

  @override
  Widget build(BuildContext context) {
    final padH = tablet ? (wide ? 40.0 : 32.0) : 20.0;
    final withNew = status == PitStatus.shallow && !editing;
    final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
    return LayoutBuilder(
      builder: (context, box) {
        // iPad（MainShallow／MainArchived，P-027／P-040）：卡片列表，淺坑最後一格虛線「開新淺坑」。
        // 欄數看內容區（扣掉 sidebar／icon rail 之後）的闊度：≥ 640 兩欄，否則一欄。
        final pad = tablet
            ? EdgeInsets.fromLTRB(padH, 22, padH, 24)
            : EdgeInsets.fromLTRB(padH, 4, padH, 24);
        final cols = tablet ? pitCardColumns(box.maxWidth) : 1;
        final gapX = tablet ? 16.0 : 0.0;
        final cellW =
            (box.maxWidth - pad.horizontal - gapX * (cols - 1)) / cols;
        final cellH = (tablet ? 90.0 : 80.0) * scale;
        return SingleChildScrollView(
          key: tablet ? const ValueKey('pitCardGrid') : null,
          padding: pad,
          child: PitReorderGrid(
            count: pits.length,
            columns: cols,
            cellWidth: cellW,
            cellHeight: cellH,
            gapX: gapX,
            gapY: tablet ? 14 : 0,
            placeholderRadius: tablet ? 18 : 14,
            liftScale: 1.03,
            onDragStart: onEnterEdit,
            onReorder: (from, to) => onReorder?.call(from, to),
            trailing: withNew
                ? (tablet ? const _NewShallowCard() : const _NewShallowRow())
                : null,
            itemBuilder: (_, i, dragging, lifted) => PitRow(
              pit: pits[i],
              index: i,
              status: status,
              card: tablet,
              editing: editing || dragging,
              dragging: dragging,
              lifted: lifted,
              onCoverTap: () => onCoverTap?.call(pits[i]),
            ),
          ),
        );
      },
    );
  }
}

/// 沒封面時的淡色底（和坑卡片的佔位同一組顏色）。
List<Color> pitRowTints(BuildContext context) {
  final t = context.tokens;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    t.official.bg,
    t.fanArt.bg,
    t.draft.bg,
    dark ? const Color(0xFF2C3529) : const Color(0xFFE7EFE4),
  ];
}

class PitRow extends ConsumerWidget {
  const PitRow({
    super.key,
    required this.pit,
    required this.index,
    required this.status,
    this.card = false,
    this.editing = false,
    this.dragging = false,
    this.lifted = false,
    this.onCoverTap,
  });
  final Pit pit;
  final int index;
  final PitStatus status;

  /// 編輯排序（D-132）：見 [PitRows.editing]。[lifted]＝浮起的那列（白底圓角＋陰影）。
  final bool editing;
  final bool dragging;
  final bool lifted;
  final VoidCallback? onCoverTap;

  /// iPad 卡片版（P-027）：白底圓角卡、64px 封面（圓角 14）、坑名 16、副標 13。
  final bool card;

  /// 副標：淺坑＝描述，沒有描述就列出開啟格子的張數／數量，兩者都沒有＝null（不畫副標）；封存坑＝成圖／摸魚數。
  String? subtitle(BuildContext context, PitStats stats) {
    final l = context.l10n;
    if (status == PitStatus.shallow) {
      final d = pit.description?.trim() ?? '';
      if (d.isNotEmpty) {
        // 只列第一行；後面還有內容時硬換行不會自動出現省略號，這裡補上。
        final lines = d.split('\n');
        final more = lines.skip(1).any((e) => e.trim().isNotEmpty);
        return more ? '${lines.first.trimRight()}…' : lines.first;
      }
      final open = [
        for (final k in PitSectionKey.values)
          if (pit.sectionOpen(k)) k,
      ];
      if (open.isEmpty) return null;
      return [
        for (final k in open)
          l.shallowSubtitlePart(pitSectionMeta(context, k).label, switch (k) {
            PitSectionKey.official => l.commonCountImages(stats.official),
            PitSectionKey.fan => l.commonCountImages(stats.fanArts),
            PitSectionKey.idea => l.pitsCountIdeas(stats.ideas),
            PitSectionKey.draft => l.pitsCountDrafts(stats.drafts),
            PitSectionKey.piece => l.pitsCountPieces(stats.pieces),
            PitSectionKey.oshi => l.pitsCellOshiCount(stats.oshi),
            PitSectionKey.junk => l.commonCountImages(stats.junk),
          }),
      ].join(' · ');
    }
    if (stats.pieces == 0 && stats.drafts == 0 && stats.official > 0) {
      return l.shallowSubtitlePart(
        l.pitsOfficial,
        l.commonCountImages(stats.official),
      );
    }
    return l.shallowArchivedSubtitle(stats.pieces, stats.drafts);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(pitStatsProvider(pit.id)).value ?? PitStats.empty;
    final coverFile = ref.watch(coverFileProvider(pit.id)).value;
    final sub = subtitle(context, stats);
    final tint = pitRowTints(context)[index % 4];
    final first = pit.name.trim().isEmpty
        ? ''
        : String.fromCharCode(pit.name.trim().runes.first);
    final coverSize = card ? 64.0 : 56.0;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(card ? 14 : 12),
      child: SizedBox(
        width: coverSize,
        height: coverSize,
        child: PitCoverImage(
          file: coverFile,
          hasCoverRef: pit.hasCoverRef,
          cacheWidth: card ? 192 : 168,
          placeholderColor: tint,
          fallback: ColoredBox(
            color: tint,
            child: Center(
              child: Text(
                first,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: card ? 24 : 22,
                  fontWeight: FontWeight.w700,
                  color: t.text2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget coverArea = cover;
    if (editing && !dragging) {
      final badge = card ? 26.0 : 24.0;
      coverArea = Semantics(
        button: true,
        label: context.l10n.pitsortCoverEdit,
        child: GestureDetector(
          key: ValueKey('pitCoverEdit-${pit.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onCoverTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              cover,
              Positioned(
                right: -5,
                bottom: -5,
                width: badge,
                height: badge,
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332B2622),
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgIcon(
                      AppIcons.image,
                      size: 13,
                      strokeWidth: 2,
                      color: t.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final BoxDecoration decoration;
    if (lifted) {
      decoration = BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(card ? 18 : 14),
        boxShadow: pitLiftShadow,
      );
    } else if (card) {
      decoration = BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.borderCard),
        borderRadius: BorderRadius.circular(18),
      );
    } else {
      decoration = BoxDecoration(
        border: Border(bottom: BorderSide(color: t.chipBg)),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 編輯排序時點列的其他地方不做事（也不算「點空白處」）。
      onTap: editing
          ? () {}
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pit.id)),
            ),
      child: Container(
        padding: card || lifted
            ? EdgeInsets.fromLTRB(card ? 12 : 8, 12, 14, 12)
            : const EdgeInsets.symmetric(vertical: 12),
        decoration: decoration,
        child: Row(
          children: [
            coverArea,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                // 卡片（iPad）文字靠上；列表（手機）整組垂直置中。
                mainAxisSize: card ? MainAxisSize.max : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: card ? 16 : 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sub != null) ...[
                    SizedBox(height: card ? 4 : 3),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: t.text2),
                    ),
                  ],
                ],
              ),
            ),
            if (editing)
              Semantics(
                label: context.l10n.pitsortDragHandle,
                child: SvgIcon(
                  PitsIcons.dragHandle,
                  size: 20,
                  strokeWidth: 2,
                  color: lifted ? t.ink : t.text3,
                ),
              )
            else
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

/// 淺坑列表最底：虛線小方塊＋「開新淺坑」。
class _NewShallowRow extends StatelessWidget {
  const _NewShallowRow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: context.l10n.shallowNewRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openNewPit(context, initialStatus: PitStatus.shallow),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: DashedBox(
                  color: t.dashed,
                  radius: 12,
                  child: Center(
                    child: SvgIcon(AppIcons.plus, size: 22, color: t.text4),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                context.l10n.shallowNewRow,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: t.text4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iPad 淺坑卡片列表最後一格（MainShallow）：虛線圓角卡、64px 空封面位放加號、「開新淺坑」。
class _NewShallowCard extends StatelessWidget {
  const _NewShallowCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: context.l10n.shallowNewRow,
      child: GestureDetector(
        key: const ValueKey('newShallowCard'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openNewPit(context, initialStatus: PitStatus.shallow),
        child: DashedBox(
          color: t.dashed,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Center(
                    child: SvgIcon(AppIcons.plus, size: 24, color: t.text4),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  context.l10n.shallowNewRow,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.text4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
