import 'package:flutter/material.dart';

import '../../data/goal_queries.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

String kindLabel(String kind) => kind;

/// 目標卡片（GoalYear／Month）：名稱 14.5/600、右側 完成數（主色 15/700）/ 目標數，
/// 8px 進度條；坑是白色 pill（前面放封面小方塊），tag 每個獨立一顆灰色 pill。
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
    return GoalCardBody(
      label: view.displayName,
      progress: view.progress,
      target: view.target,
      onTap: onTap,
      pitName: view.pit?.name,
      coverFile: coverFile,
      tags: [for (final tag in view.tags) '#${tag.name}'],
    );
  }
}

/// 目標卡的外觀（新增頁預覽共用）。
class GoalCardBody extends StatelessWidget {
  const GoalCardBody({
    super.key,
    required this.label,
    required this.progress,
    required this.target,
    this.onTap,
    this.pitName,
    this.coverFile,
    this.tags = const [],
  });
  final String label;
  final int progress;
  final int target;
  final VoidCallback? onTap;
  final String? pitName;
  final String? coverFile;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: t.borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    text: '$progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                    children: [
                      TextSpan(
                        text: ' / $target',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: t.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: t.accent,
                backgroundColor: t.chipBg,
              ),
            ),
            if (pitName != null || tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (pitName != null)
                    PitPill(name: pitName!, coverFile: coverFile),
                  for (final tag in tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: t.chipBg,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(color: t.text2, fontSize: 11),
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

/// 設計稿 #E3D8C9（輸入框／pill 邊線；沒有 token，深色用 border）。
Color mockLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.tokens.border
    : const Color(0xFFE3D8C9);

/// 坑 pill：白底、1px 邊、封面小方塊 16（圓角 5）＋坑名 11/600。
class PitPill extends StatelessWidget {
  const PitPill({super.key, required this.name, this.coverFile});
  final String name;
  final String? coverFile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 9, 2),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: mockLine(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: coverFile == null
                  ? ColoredBox(color: t.official.bg)
                  : StoredImage(coverFile!, cacheWidth: 80),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// 區塊標題列：左 16/700 標題，右側放「新增」等動作。
class GoalSectionRow extends StatelessWidget {
  const GoalSectionRow({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 20, bottom: 10),
  });
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 「＋ 新增」文字連結（主色 13/600，加號 17）。
class AddLink extends StatelessWidget {
  const AddLink({super.key, required this.onTap, this.label = '新增'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          SvgIcon(AppIcons.plus, size: 17, strokeWidth: 2.2, color: c),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// 月／日頁的切換列：‹ 標題（襯線 18/700）›（Month 設計稿）。
class PeriodNav extends StatelessWidget {
  const PeriodNav({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.prevTooltip = '上一個',
    this.nextTooltip = '下一個',
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String prevTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(String icon, String tip, VoidCallback tap) => Semantics(
      button: true,
      label: tip,
      child: GestureDetector(
        onTap: tap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SvgIcon(icon, size: 20, strokeWidth: 2, color: t.text3),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          btn(AppIcons.back, prevTooltip, onPrev),
          const SizedBox(width: 18),
          Text(
            label,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 18),
          btn(AppIcons.chevronRight, nextTooltip, onNext),
        ],
      ),
    );
  }
}
