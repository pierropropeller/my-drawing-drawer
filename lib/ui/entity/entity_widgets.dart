import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/entity_queries.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';

String fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 圓角卡片（文字卡片 16px）。
class EntityCard extends StatelessWidget {
  const EntityCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: selected ? t.accent : t.borderCard,
            width: selected ? 2 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 每個 tag 一顆灰色 pill。
class TagPills extends StatelessWidget {
  const TagPills(this.tags, {super.key});
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
    );
  }
}

/// 正方形縮圖；多張時右下角顯示張數。
class ThumbSquare extends StatelessWidget {
  const ThumbSquare({super.key, required this.images, this.onTap, this.size});
  final List<ImageRef> images;
  final VoidCallback? onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.image),
      child: images.isEmpty
          ? ColoredBox(color: t.chipBg)
          : StoredImage(images.first.file, cacheWidth: 400),
    );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              box,
              if (images.length > 1)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.collections_outlined,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 腦洞狀態：未孵／孵化中 · N 草稿／已孵 N 成圖。
class IdeaStatusChip extends StatelessWidget {
  const IdeaStatusChip(this.view, {super.key});
  final IdeaView view;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, bg, fg) = switch (view.status) {
      IdeaStatus.open => ('未孵', t.chipBg, t.text3),
      IdeaStatus.hatching => (
        '孵化中 · ${view.draftIds.length} 草稿',
        t.draft.bg,
        t.draft.fg,
      ),
      IdeaStatus.hatched => (
        '已孵 ${view.pieceIds.length} 成圖',
        t.piece.bg,
        t.piece.fg,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 選取模式的左側圓圈。
class SelectDot extends StatelessWidget {
  const SelectDot(this.selected, {super.key});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? t.accent : Colors.transparent,
        border: selected ? null : Border.all(color: t.dashed, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}

class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
