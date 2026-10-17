import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../album/album_image.dart';
import '../album/preview_shell.dart' show PreviewPalette, previewDate;
import '../common/svg_icon.dart';
import 'ref_image.dart';
import 'ref_palette.dart';

/// 資料面板的一個動作（設為封面／下載／分享／編輯／刪除）。
class RefInfoAction {
  const RefInfoAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

/// 圖片資料：分類、tag、加入日期，以及動作列（RefFull 右側面板；<840 收在「更多」sheet）。
class RefInfoContent extends StatelessWidget {
  const RefInfoContent({
    super.key,
    required this.image,
    required this.tags,
    required this.actions,
    required this.palette,
    this.pushActionsDown = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 20),
    this.gap = 24,
  });

  final RefImage image;
  final List<String> tags;
  final List<RefInfoAction> actions;
  final RefPalette palette;

  /// 面板：動作貼底；sheet：緊接在資料後面。
  final bool pushActionsDown;
  final EdgeInsets padding;

  /// 區塊之間的間距（250 面板 20、288 面板 24）。
  final double gap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = image.category ?? '';
    final fan = image.album?.kind == AlbumKind.fanArt;
    final label = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: palette.sub,
    );
    final date = image.addedAt;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: pushActionsDown ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (category.isNotEmpty) ...[
            Text(l10n.refviewCategory, style: label),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: fan ? PreviewPalette.pillFan : PreviewPalette.pill,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  color: Color(0xFF1E1B18),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: gap),
          ],
          if (tags.isNotEmpty) ...[
            Text(l10n.refviewTags, style: label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.chip,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$t',
                      style: TextStyle(color: palette.fg, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
            SizedBox(height: gap),
          ],
          if (date != null)
            Text(
              previewDate(date, l10n),
              style: TextStyle(color: palette.sub, fontSize: 12.5),
            ),
          if (pushActionsDown) const Spacer() else SizedBox(height: gap),
          if (actions.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.line)),
              ),
              child: Column(
                children: [
                  for (final a in actions)
                    _ActionRow(action: a, palette: palette),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.palette});
  final RefInfoAction action;
  final RefPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = action.danger ? palette.danger : palette.fg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SvgIcon(action.icon, size: 20, color: color, strokeWidth: 1.7),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: TextStyle(color: color, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
