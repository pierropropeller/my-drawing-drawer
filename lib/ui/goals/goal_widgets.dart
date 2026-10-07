import 'package:flutter/material.dart';

import '../../data/goal_queries.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';

String kindLabel(String kind) => kind;

/// 目標卡片：名稱、進度條；坑是一顆白色 pill（前面放封面小方塊），tag 每個獨立一顆灰色 pill。
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.view,
    required this.onTap,
    this.coverFile,
  });
  final GoalView view;
  final VoidCallback onTap;
  final String? coverFile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: t.borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    view.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (view.done)
                  Icon(Icons.check_circle, color: t.accent, size: 20),
                const SizedBox(width: 6),
                Text(
                  '${view.progress} / ${view.target}',
                  style: TextStyle(color: t.text2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.chip),
              child: LinearProgressIndicator(
                value: view.ratio,
                minHeight: 8,
                color: t.accent,
                backgroundColor: t.chipBg,
              ),
            ),
            if (view.pit != null || view.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (view.pit != null)
                    _PitPill(name: view.pit!.name, coverFile: coverFile),
                  for (final tag in view.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: t.chipBg,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Text(
                        '#${tag.name}',
                        style: TextStyle(color: t.text2, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PitPill extends StatelessWidget {
  const _PitPill({required this.name, this.coverFile});
  final String name;
  final String? coverFile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: coverFile == null
                  ? ColoredBox(color: t.piece.bg)
                  : StoredImage(coverFile!, cacheWidth: 80),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(color: Color(0xFF2B2622), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 年／月切換的標頭：‹ 2026 ›
class PeriodHeader extends StatelessWidget {
  const PeriodHeader({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}
