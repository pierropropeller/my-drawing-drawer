import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/drag_select.dart';
import '../common/media_widgets.dart';
import '../common/responsive.dart';
import '../common/window_class.dart';
import '../common/svg_icon.dart';
import 'album_image.dart';

/// 兩欄瀑布流（間距 12）。選取模式時右上顯示 22px 圓圈（未選：白框半透明；選中：2px 主色框＋實心主色圓圈白勾）。
class ImageMasonry extends StatelessWidget {
  const ImageMasonry({
    super.key,
    required this.images,
    required this.onTap,
    this.onLongPress,
    this.onDragSelect,
    this.selecting = false,
    this.selected = const {},
    this.highlightId,
    this.columns,
    this.padding = const EdgeInsets.fromLTRB(20, 2, 20, 96),
  });

  /// 指定欄數（iPad 多選、預覽面板收起時固定 4 欄，FanArtSelect）；null＝依可用闊度。
  final int? columns;

  final List<AlbumImage> images;
  final void Function(AlbumImage image, int index) onTap;
  final void Function(AlbumImage image)? onLongPress;

  /// 長按＋拖曳連續多選（D-081）。有給就由 [DragSelectArea] 接管長按（忽略 [onLongPress]）。
  final void Function(Set<int> indices, bool finished)? onDragSelect;
  final bool selecting;
  final Set<String> selected;

  /// 寬版預覽面板目前顯示的那張（畫 2.5px 主色框；不是多選）。
  final String? highlightId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final drag = onDragSelect;
    // 手機（＜600）維持 2 欄、間距 12；平板依可用闊度逐格增減、間距 16（RespSpec）。
    final compact = WindowClass.of(context).isCompact;
    return LayoutBuilder(
      builder: (context, c) {
        final cols =
            columns ??
            (compact
                ? columnsForWidth(MediaQuery.sizeOf(context).width)
                : gridColumnsFor(c.maxWidth - padding.horizontal));
        final gap = compact ? 12.0 : 16.0;
        final grid = MasonryGridView.count(
          padding: padding,
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          itemCount: images.length,
          itemBuilder: (_, i) {
            final im = images[i];
            final tile = _Tile(
              image: im,
              selecting: selecting,
              isSelected: selected.contains(im.id),
              highlighted: highlightId == im.id,
              onTap: () => onTap(im, i),
              onLongPress: onLongPress == null || drag != null
                  ? null
                  : () => onLongPress!(im),
            );
            return drag == null ? tile : DragSelectItem(index: i, child: tile);
          },
        );
        if (drag == null) return grid;
        return DragSelectArea(
          itemCount: images.length,
          isSelected: (i) => selected.contains(images[i].id),
          onChanged: drag,
          child: grid,
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.image,
    required this.selecting,
    required this.isSelected,
    required this.onTap,
    this.highlighted = false,
    this.onLongPress,
  });

  final AlbumImage image;
  final bool selecting;
  final bool isSelected;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tile = AspectRatio(
      aspectRatio: image.aspect.clamp(0.4, 2.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.image),
            child: MediaThumb(image.media, cacheWidth: 500, badgeInset: 7),
          ),
          if (isSelected || highlighted)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.image),
                border: Border.all(color: t.accent, width: 2),
              ),
            ),
          if (selecting)
            Positioned(
              top: 8,
              right: 8,
              child: SelectMark(selected: isSelected),
            ),
        ],
      ),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: image.hasCaption
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [tile, _Caption(image)],
            )
          : tile,
    );
  }
}

/// 雜物的 3 欄正方形純圖格（JunkList／JunkSelect）：欄距 2、無圓角、不顯示說明。
/// 選取模式：右上 22px 圓圈（位置 6,6）；選中＝2px 主色內框＋實心主色圓圈白勾。
class SquareGrid extends StatelessWidget {
  const SquareGrid({
    super.key,
    required this.images,
    required this.onTap,
    this.onLongPress,
    this.onDragSelect,
    this.selecting = false,
    this.selected = const {},
    this.padding = const EdgeInsets.fromLTRB(0, 6, 0, 96),
    this.columns,
  });

  final List<AlbumImage> images;

  /// 欄數；null＝依視窗闊度（手機 3 欄）。平板版面由呼叫端依可用闊度傳入。
  final int? columns;
  final void Function(AlbumImage image, int index) onTap;
  final void Function(AlbumImage image)? onLongPress;

  /// 長按＋拖曳連續多選（D-081）。有給就由 [DragSelectArea] 接管長按（忽略 [onLongPress]）。
  final void Function(Set<int> indices, bool finished)? onDragSelect;
  final bool selecting;
  final Set<String> selected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final drag = onDragSelect;
    final grid = GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            columns ??
            (WindowClass.of(context).isCompact
                ? columnsForWidth(MediaQuery.sizeOf(context).width, phone: 3)
                : math.max(
                    3,
                    gridColumnsFor(
                      MediaQuery.sizeOf(context).width,
                      minCell: 150,
                    ),
                  )),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final im = images[i];
        final isSelected = selected.contains(im.id);
        final cell = GestureDetector(
          onTap: () => onTap(im, i),
          onLongPress: onLongPress == null || drag != null
              ? null
              : () => onLongPress!(im),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaThumb(im.media, cacheWidth: 400),
              if (isSelected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: t.accent, width: 2),
                  ),
                ),
              if (selecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: SelectMark(selected: isSelected),
                ),
            ],
          ),
        );
        return drag == null ? cell : DragSelectItem(index: i, child: cell);
      },
    );
    if (drag == null) return grid;
    return DragSelectArea(
      itemCount: images.length,
      isSelected: (i) => selected.contains(images[i].id),
      onChanged: drag,
      child: grid,
    );
  }
}

/// 選取圓圈：未選＝白框半透明深底；選中＝實心主色圓圈白勾。
class SelectMark extends StatelessWidget {
  const SelectMark({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? t.accent
            : const Color(0xFF2B2622).withValues(alpha: 0.18),
        border: selected ? null : Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? const SvgIcon(
              AppIcons.check,
              size: 13,
              color: Colors.white,
              strokeWidth: 3,
            )
          : null,
    );
  }
}

/// 圖下方的說明列：同人圖＝作者（12.5px 粗）＋分組小標；官方圖＝分組小標。各項為空就不顯示。
class _Caption extends StatelessWidget {
  const _Caption(this.image);
  final AlbumImage image;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final author = image.author ?? '';
    final group = image.groupName ?? '';
    final (Color fg, Color bg) = image.kind == AlbumKind.official
        ? (t.official.fg, t.official.bg)
        : _sourceStyle(group, dark, t);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
      child: Row(
        children: [
          if (author.isNotEmpty)
            Expanded(
              child: Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (author.isNotEmpty && group.isNotEmpty) const SizedBox(width: 6),
          if (group.isNotEmpty)
            // 標籤不搶彈性空間（作者佔滿剩餘寬度，標籤才會貼右）；太長時限制最大寬度並省略。
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 10.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// FanArtList 設計稿的出處小標配色；自訂分組用中性色。深色模式一律中性。
  static (Color, Color) _sourceStyle(String group, bool dark, AppTokens t) {
    if (dark) return (t.text2, t.chipBg);
    if (group.startsWith('推特')) {
      return (const Color(0xFF3A5A78), const Color(0xFFE7ECF2));
    }
    if (group.startsWith('小紅書')) {
      return (const Color(0xFFB23A4C), const Color(0xFFF6E7EA));
    }
    if (group.toLowerCase().startsWith('lofter')) {
      return (const Color(0xFF4A7A9A), const Color(0xFFEAF0F5));
    }
    if (group.startsWith('朋友')) {
      return (const Color(0xFF7A6A2E), const Color(0xFFF1EAD9));
    }
    return (const Color(0xFF6B6257), const Color(0xFFEFE7DC));
  }
}
