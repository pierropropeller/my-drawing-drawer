import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../theme/tokens.dart';
import 'album_image.dart';

/// 兩欄瀑布流。選取模式時左上顯示圓圈，選中為 2px 主色框＋22px 實心主色圓圈白剔。
class ImageMasonry extends StatelessWidget {
  const ImageMasonry({
    super.key,
    required this.images,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = const {},
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AspectRatio(
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
                left: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? t.accent : Colors.black26,
                    border: isSelected
                        ? null
                        : Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
