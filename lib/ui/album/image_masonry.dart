import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import 'album_image.dart';

/// 兩欄瀑布流（間距 12）。選取模式時右上顯示 22px 圓圈（未選：白框半透明；選中：2px 主色框＋實心主色圓圈白勾）。
class ImageMasonry extends StatelessWidget {
  const ImageMasonry({
    super.key,
    required this.images,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = const {},
    this.padding = const EdgeInsets.fromLTRB(20, 2, 20, 96),
  });

  final List<AlbumImage> images;
  final void Function(AlbumImage image, int index) onTap;
  final void Function(AlbumImage image)? onLongPress;
  final bool selecting;
  final Set<String> selected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: padding,
      crossAxisCount: columnsForWidth(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: images.length,
      itemBuilder: (_, i) {
        final im = images[i];
        return _Tile(
          image: im,
          selecting: selecting,
          isSelected: selected.contains(im.id),
          onTap: () => onTap(im, i),
          onLongPress: onLongPress == null ? null : () => onLongPress!(im),
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
    this.onLongPress,
  });

  final AlbumImage image;
  final bool selecting;
  final bool isSelected;
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
            child: StoredImage(image.file, cacheWidth: 500),
          ),
          if (isSelected)
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
    this.selecting = false,
    this.selected = const {},
    this.padding = const EdgeInsets.fromLTRB(0, 6, 0, 96),
  });

  final List<AlbumImage> images;
  final void Function(AlbumImage image, int index) onTap;
  final void Function(AlbumImage image)? onLongPress;
  final bool selecting;
  final Set<String> selected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnsForWidth(
          MediaQuery.sizeOf(context).width,
          phone: 3,
        ),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final im = images[i];
        final isSelected = selected.contains(im.id);
        return GestureDetector(
          onTap: () => onTap(im, i),
          onLongPress: onLongPress == null ? null : () => onLongPress!(im),
          child: Stack(
            fit: StackFit.expand,
            children: [
              StoredImage(im.file, cacheWidth: 400),
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
      },
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
            Flexible(
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
