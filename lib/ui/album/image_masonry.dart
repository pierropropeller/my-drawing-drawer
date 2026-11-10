import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/drag_select.dart';
import '../common/media_widgets.dart';
import '../common/responsive.dart';
import '../common/window_class.dart';
import '../common/svg_icon.dart';
import '../material/material_icons.dart';
import 'album_image.dart';
import 'album_set_badge.dart';

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
            final tile = AlbumMasonryTile(
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

/// 瀑布流的一格：圖＋說明列。編輯排序（D-134）也用它，[lifted]＝正被拖著（加陰影）。
class AlbumMasonryTile extends StatelessWidget {
  const AlbumMasonryTile({
    super.key,
    required this.image,
    required this.selecting,
    required this.isSelected,
    required this.onTap,
    this.highlighted = false,
    this.onLongPress,
    this.lifted = false,
  });

  /// 估計這格的高度（編輯排序量到真正高度前用）：圖＋說明列。
  static double estimateHeight(AlbumImage image, double width) {
    var h = width / image.aspect.clamp(0.4, 2.5);
    if ((image.author ?? '').isNotEmpty || (image.groupName ?? '').isNotEmpty) {
      h += 26;
    }
    if ((image.note ?? '').isNotEmpty) h += 40;
    return h;
  }

  final AlbumImage image;
  final bool selecting;
  final bool isSelected;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tile = AspectRatio(
      aspectRatio: image.aspect.clamp(0.4, 2.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (lifted)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.image),
                boxShadow: liftShadow,
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.image),
            child: MediaThumb(image.media, cacheWidth: 500, badgeInset: 7),
          ),
          if (image.fromInspo)
            const Positioned(left: 7, top: 7, child: InspoBadge()),
          if (isSelected || highlighted)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.image),
                border: Border.all(color: t.accent, width: 2),
              ),
            ),
          // 多圖（D-136）：右下「⧉ N」（左下是 GIF／影片標記，離邊同 7）；多選時也看得到。
          Positioned(right: 7, bottom: 7, child: AlbumSetBadge(image.imageKey)),
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

/// 拖動排序時浮起那張的陰影（稿：0 14 28 rgba(43,38,34,.28)）。
const liftShadow = [
  BoxShadow(color: Color(0x472B2622), offset: Offset(0, 14), blurRadius: 28),
];

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
              if (im.fromInspo)
                const Positioned(left: 6, top: 6, child: InspoBadge()),
              Positioned(
                right: 6,
                bottom: 6,
                child: AlbumSetBadge(im.imageKey),
              ),
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
    final note = image.note ?? '';
    final row = Row(
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
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author.isNotEmpty || group.isNotEmpty) row,
          // 說明（RefList，D-141）：12px、兩行。
          if (note.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: author.isNotEmpty || group.isNotEmpty ? 5 : 0,
              ),
              child: Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.text2, fontSize: 12, height: 1.45),
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

/// 「來自靈感廣場」角標（RefList，D-142）：22px 半透明暗黃圓＋白色燈泡，透明度同 GIF／影片標記。
class InspoBadge extends StatelessWidget {
  const InspoBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.inspoFromInspo,
    child: Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x9EC9961A),
      ),
      alignment: Alignment.center,
      child: const SvgIcon(
        MaterialLibIcons.bulb,
        size: 13,
        color: Colors.white,
        strokeWidth: 2,
      ),
    ),
  );
}
