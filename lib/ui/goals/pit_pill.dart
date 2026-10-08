import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 設計稿 #E3D8C9（輸入框／pill 邊線；沒有 token，深色用 border）。
Color mockLine(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? context.tokens.border
    : const Color(0xFFE3D8C9);

/// 坑的小 pill（D-004）：白底、1px 邊、導覽列同款資料夾 icon ＋ 坑名。
/// 目標卡（GoalYear／Month）用小尺寸；新增目標的「目標坑」用大尺寸並可移除。
class PitPill extends StatelessWidget {
  const PitPill({
    super.key,
    required this.name,
    this.large = false,
    this.onRemove,
  });
  final String name;

  /// 大尺寸（GoalNew 的目標坑）：icon 16、字 13。
  final bool large;

  /// 只有大尺寸會畫右側的移除叉叉。
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: large
          ? const EdgeInsets.fromLTRB(10, 7, 10, 7)
          : const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: mockLine(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(
            AppIcons.folder,
            size: large ? 16 : 13,
            strokeWidth: 1.8,
            color: t.text2,
          ),
          SizedBox(width: large ? 7 : 5),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 13 : 11,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ),
          if (large && onRemove != null) ...[
            const SizedBox(width: 7),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: context.l10n.goalsRemove,
                child: SvgIcon(
                  AppIcons.closeX,
                  size: 13,
                  strokeWidth: 2,
                  color: t.text4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
