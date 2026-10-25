import '../common/themed_sheet.dart';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_icons.dart';
import '../album/tag_batch_sheet.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'oshi_icons.dart';
import 'oshi_select_actions.dart';
import '../common/top_toast.dart' show BottomInsetAnchor;

/// 推活多選的標題列（OshiSelect）：左「×」取消、「已選 N 筆」、右「全選」。
class OshiSelectHeader extends StatelessWidget {
  const OshiSelectHeader({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onExit,
    required this.onToggleAll,
  });
  final int count;
  final bool allSelected;
  final VoidCallback onExit;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Tooltip(
            message: l.albumCancelSelect,
            child: InkResponse(
              key: const ValueKey('oshiSelectExit'),
              radius: 24,
              onTap: onExit,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    AppIcons.closeX,
                    size: 22,
                    strokeWidth: 2,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.oshiSelectedCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('oshiSelectAll'),
            onPressed: onToggleAll,
            style: TextButton.styleFrom(
              foregroundColor: t.piece.fg,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(allSelected ? l.commonDeselectAll : l.commonSelectAll),
          ),
        ],
      ),
    );
  }
}

/// 底部三個動作：分組、tag、刪除（沒有導覽列，OshiSelect）。
class OshiSelectBar extends StatelessWidget {
  const OshiSelectBar({
    super.key,
    required this.onGroup,
    required this.onTag,
    required this.onDelete,
    this.onSensitive,
  });
  final VoidCallback onGroup;
  final VoidCallback onTag;
  final VoidCallback onDelete;

  /// 「敏感」動作（D-104）；null＝不顯示（總開關或這個坑的敏感內容沒開）。
  final VoidCallback? onSensitive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return BottomInsetAnchor(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        decoration: BoxDecoration(
          color: t.nav,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              if (onSensitive != null)
                Expanded(
                  child: _BarAction(
                    key: const ValueKey('oshiSelectSensitive'),
                    label: l.sensitiveAction,
                    svg: AppIcons.eyeSlash,
                    color: t.ink,
                    strokeWidth: 1.9,
                    onTap: onSensitive!,
                  ),
                ),
              Expanded(
                child: _BarAction(
                  key: const ValueKey('oshiSelectGroup'),
                  label: l.albumGroupLabel,
                  svg: OshiIcons.folder,
                  color: t.ink,
                  onTap: onGroup,
                ),
              ),
              Expanded(
                child: _BarAction(
                  key: const ValueKey('oshiSelectTag'),
                  label: l.shareMoveTag,
                  svg: AlbumIcons.tag,
                  color: t.ink,
                  onTap: onTag,
                ),
              ),
              Expanded(
                child: _BarAction(
                  key: const ValueKey('oshiSelectDelete'),
                  label: l.commonDelete,
                  svg: AppIcons.trash,
                  color: t.danger,
                  iconSize: 20,
                  strokeWidth: 1.8,
                  onTap: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    super.key,
    required this.label,
    required this.svg,
    required this.color,
    required this.onTap,
    this.iconSize = 22,
    this.strokeWidth = 1.7,
  });
  final String label;
  final String svg;
  final Color color;
  final VoidCallback onTap;
  final double iconSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        // 放在 bottomNavigationBar 時高度不受限，要縮到內容大小。
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgIcon(svg, size: iconSize, color: color, strokeWidth: strokeWidth),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11.5)),
        ],
      ),
    ),
  );
}

/// 多選後的 tag bottom sheet（同好看同人圖多選的 [BatchTagSheet]，對象換成推活）。
/// 回傳 true＝有套用。
Future<bool?> showOshiTagSheet(
  BuildContext context, {
  required String pitId,
  required List<String> ids,
}) {
  return showThemedSheet<bool>(
    context: context,
    builder: (_) => BatchTagSheet(
      pitId: pitId,
      backend: OshiSelectActions.tagBackend,
      ids: ids,
    ),
  );
}
