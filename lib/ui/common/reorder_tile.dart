import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 表單圖片格的長按拖曳排序：長按一張拖到另一張上放開，該張就插到那個位置。
/// [onReorder] 為 null＝不能排序，原樣回傳 [child]。
class ReorderTile extends StatelessWidget {
  const ReorderTile({
    super.key,
    required this.index,
    required this.size,
    required this.onReorder,
    required this.child,
  });

  final int index;
  final double size;
  final void Function(int from, int to)? onReorder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reorder = onReorder;
    if (reorder == null) return child;
    final t = context.tokens;
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => reorder(d.data, index),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: SizedBox(width: size, height: size, child: child),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: child),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.image),
              border: hovering ? Border.all(color: t.accent, width: 2) : null,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 把 [list] 的第 [from] 項移到第 [to] 項的位置（其餘依序挪動）。
void moveListItem<T>(List<T> list, int from, int to) {
  if (from == to || from < 0 || to < 0) return;
  if (from >= list.length || to >= list.length) return;
  list.insert(to, list.removeAt(from));
}
