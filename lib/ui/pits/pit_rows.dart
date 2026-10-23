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
import 'pit_type_widgets.dart';

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
  });
  final List<Pit> pits;
  final PitStatus status;
  final bool tablet;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final padH = tablet ? (wide ? 40.0 : 32.0) : 20.0;
    final withNew = status == PitStatus.shallow;
    if (tablet) {
      // iPad（MainShallow／MainArchived，P-027）：兩欄卡片列表，淺坑最後一格虛線「開新淺坑」。
      final count = pits.length + (withNew ? 1 : 0);
      return GridView.builder(
        key: const ValueKey('pitCardGrid'),
        padding: EdgeInsets.fromLTRB(padH, 22, padH, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 16,
          mainAxisExtent:
              90 * math.max(1.0, MediaQuery.textScalerOf(context).scale(1)),
        ),
        itemCount: count,
        itemBuilder: (_, i) => i == pits.length
            ? const _NewShallowCard()
            : PitRow(pit: pits[i], index: i, status: status, card: true),
      );
    }
    final list = ListView(
      padding: EdgeInsets.fromLTRB(padH, 4, padH, 24),
      children: [
        for (var i = 0; i < pits.length; i++)
          PitRow(pit: pits[i], index: i, status: status),
        if (withNew) const _NewShallowRow(),
      ],
    );
    return list;
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
  });
  final Pit pit;
  final int index;
  final PitStatus status;

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
            PitSectionKey.piece => l.commonCountImages(stats.pieces),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pit.id))),
      child: Container(
        padding: card
            ? const EdgeInsets.fromLTRB(12, 12, 14, 12)
            : const EdgeInsets.symmetric(vertical: 12),
        decoration: card
            ? BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.borderCard),
                borderRadius: BorderRadius.circular(18),
              )
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: t.chipBg)),
              ),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
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
