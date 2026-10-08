import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/entity_queries.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/image_picker_field.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';

String fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

/// 列表卡片右下的短日期（設計稿 `9/15`）。
String fmtMd(DateTime d) => '${d.month}/${d.day}';

/// 詳情頁「建立於 2026 / 09 / 03」。
String fmtSlash(DateTime d) =>
    '${d.year} / ${d.month.toString().padLeft(2, '0')} / ${d.day.toString().padLeft(2, '0')}';

/// 設計稿的子頁面標題列：返回箭頭（40×40）＋襯線標題＋右側內容。
///
/// 取代 Material AppBar，放在 `Scaffold(body: SafeArea(child: Column(...)))` 的最上面。
/// 用法：`SubPageHeader(title: '坑A · 我的腦洞', trailing: [Text('3 個')])`。
/// [leadingIcon] 預設是返回箭頭，選取模式傳 [AppIcons.closeX]。
class SubPageHeader extends StatelessWidget {
  const SubPageHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.titleSize = 19,
    this.leadingIcon = AppIcons.back,
    this.leadingSize = 24,
    this.leadingStroke = 1.9,
    this.onBack,
    this.gap = 4,
  });

  final String title;
  final List<Widget> trailing;
  final double titleSize;
  final String leadingIcon;
  final double leadingSize;
  final double leadingStroke;
  final VoidCallback? onBack;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          InkResponse(
            radius: 24,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: SvgIcon(
                  leadingIcon,
                  size: leadingSize,
                  strokeWidth: leadingStroke,
                  color: t.ink,
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// 標題列右側的小字（「3 個」「7 份」）。
class HeaderCount extends StatelessWidget {
  const HeaderCount(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
      text,
      style: TextStyle(color: context.tokens.text3, fontSize: 12),
    ),
  );
}

/// 標題列右側的圖示按鈕（詳情頁的編輯／刪除，20px，40×40 點擊區）。
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgIcon(
              icon,
              size: 20,
              color: color ?? context.tokens.text2,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 新增用的浮動按鈕：56×56、圓角 18、主色、帶陰影、加號 26。
class EntityFab extends StatelessWidget {
  const EntityFab({super.key, required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: t.accent.withValues(alpha: 0.38),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: SvgIcon(
              AppIcons.plus,
              size: 26,
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 圓角卡片（文字卡片 16px）。[selecting] 為選取模式：邊框固定 2px，選中換主色。
class EntityCard extends StatelessWidget {
  const EntityCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selecting;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bw = (selected || selecting) ? 2.0 : 1.0;
    // 邊框變粗時內距減回去，卡片內容位置不動。
    final pad = selecting
        ? EdgeInsets.fromLTRB(
            padding.left - 1,
            padding.top - 1,
            padding.right - 1,
            padding.bottom - 1,
          )
        : padding;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: selected ? t.accent : t.borderCard,
            width: bw,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 每個 tag 一顆灰色 pill（列表 11px；詳情頁傳 [large]）。
class TagPills extends StatelessWidget {
  const TagPills(this.tags, {super.key, this.large = false});
  final List<Tag> tags;
  final bool large;

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
            padding: EdgeInsets.symmetric(
              horizontal: large ? 10 : 9,
              vertical: large ? 4 : 3,
            ),
            decoration: BoxDecoration(
              color: t.chipBg,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Text(
              '#${tag.name}',
              style: TextStyle(color: t.text2, fontSize: large ? 11.5 : 11),
            ),
          ),
      ],
    );
  }
}

/// 沒有圖時的佔位格：底色＋圖片 icon（設計稿的 placeholder tile）。
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, this.color, this.iconSize = 20});
  final Color? color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: color ?? t.chipBg,
      child: Center(
        child: SvgIcon(
          AppIcons.image,
          size: iconSize,
          strokeWidth: 1.5,
          color: t.ink.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

/// 多張圖的張數徽章（右下角的深色小圓角，數字 11/700）。
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF2B2622).withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
  );
}

/// 超過張數時疊在最後一格上的「+N」。
class MoreOverlay extends StatelessWidget {
  const MoreOverlay(this.n, {super.key, this.fontSize = 18});
  final int n;
  final double fontSize;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF2B2622).withValues(alpha: 0.5),
    child: Center(
      child: Text(
        '+$n',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

/// 正方形縮圖；多張時右下角顯示張數。沒有圖時顯示佔位格。
class ThumbSquare extends StatelessWidget {
  const ThumbSquare({
    super.key,
    required this.images,
    this.onTap,
    this.size,
    this.radius = Radii.image,
    this.placeholder,
  });
  final List<ImageRef> images;
  final VoidCallback? onTap;
  final double? size;
  final double radius;
  final Color? placeholder;

  @override
  Widget build(BuildContext context) {
    final box = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: images.isEmpty
          ? ImagePlaceholder(color: placeholder)
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
                  right: 5,
                  bottom: 5,
                  child: CountBadge(images.length),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 腦洞狀態：未孵／孵化中 · N 草稿／已孵 N 成圖。[short] 只顯示「孵化中」「已孵」（詳情頁）。
class IdeaStatusChip extends StatelessWidget {
  const IdeaStatusChip(
    this.view, {
    super.key,
    this.short = false,
    this.fontSize = 10.5,
  });
  final IdeaView view;
  final bool short;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (label, bg, fg) = switch (view.status) {
      IdeaStatus.open => ('未孵', t.chipBg, t.text3),
      IdeaStatus.hatching => (
        short ? '孵化中' : '孵化中 · ${view.draftIds.length} 草稿',
        t.draft.bg,
        t.draft.fg,
      ),
      IdeaStatus.hatched => (
        short ? '已孵' : '已孵 ${view.pieceIds.length} 成圖',
        t.piece.bg,
        t.piece.fg,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 選取模式的左側圓圈（22px，2px 邊框；選中＝主色底＋白勾）。
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
        border: Border.all(color: selected ? t.accent : t.dashed, width: 2),
      ),
      child: selected
          ? const Center(
              child: SvgIcon(
                AppIcons.check,
                size: 13,
                strokeWidth: 3,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

/// 表單欄位標籤（設計稿 `.lbl`：13／600／次要色）。
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.tokens.text2,
      ),
    ),
  );
}

/// 表單輸入框外觀（設計稿 `.fld`：白底、1px 邊框、圓角 12、內距 12×14、15px）。
InputDecoration entityFieldDecoration(BuildContext context, String hint) {
  final t = context.tokens;
  final line = Theme.of(context).brightness == Brightness.dark
      ? t.border
      : const Color(0xFFE3D8C9);
  OutlineInputBorder b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.text4, fontSize: 15),
    filled: true,
    fillColor: t.surface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: b(line),
    focusedBorder: b(t.accent),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger),
  );
}

/// 表單底部的主按鈕：整條、主色、圓角 14、16/700。
class FormSubmitButton extends StatelessWidget {
  const FormSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          disabledBackgroundColor: t.accent.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 虛線小膠囊「＋ 新增」（tag、連接欄尾端）。
class DashedAddChip extends StatelessWidget {
  const DashedAddChip({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    this.label = '新增',
  });
  final VoidCallback onTap;
  final String semanticLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DashedBox(
          color: t.dashed,
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgIcon(
                AppIcons.plus,
                size: 14,
                strokeWidth: 2,
                color: t.dashedText,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: t.dashedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 虛線方塊「＋」（詳情頁連接、表單加圖）。
class DashedAddTile extends StatelessWidget {
  const DashedAddTile({
    super.key,
    required this.size,
    required this.onTap,
    required this.semanticLabel,
    this.iconSize = 22,
  });
  final double size;
  final VoidCallback onTap;
  final String semanticLabel;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: DashedBox(
            color: t.dashed,
            radius: Radii.image,
            child: Center(
              child: SvgIcon(
                AppIcons.plus,
                size: iconSize,
                strokeWidth: 1.8,
                color: t.dashedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表單的圖片區：縮圖（圓角 12，右上角 × 移除）＋虛線「＋」，自動換行。
/// 腦洞 [size]＝72，草稿＝84。
class FormImageGrid extends ConsumerWidget {
  const FormImageGrid({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    this.size = 72,
  });
  final List<ImageItem> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: items[i].picked != null
                      ? Image.file(
                          File(items[i].picked!.path),
                          cacheWidth: 300,
                          fit: BoxFit.cover,
                        )
                      : StoredImage(items[i].stored!.file, cacheWidth: 300),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SvgIcon(
                          AppIcons.closeX,
                          size: 12,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        DashedAddTile(
          size: size,
          onTap: onAdd,
          semanticLabel: '加圖',
          iconSize: 24,
        ),
      ],
    );
  }
}
