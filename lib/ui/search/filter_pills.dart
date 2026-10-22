import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 搜尋列裡的篩選 chip：「#tag ×」（主色底）與「未加 tag ×」（灰色底，D-108）共用的外觀，
/// 白字 13/600，左 10 右 6 內距。
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.color,
    required this.onClear,
    this.iconSize = 14,
  });
  final String label;
  final Color color;
  final VoidCallback onClear;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClear,
            child: Semantics(
              button: true,
              label: context.l10n.searchRemoveFilter,
              child: SvgIcon(
                AppIcons.closeX,
                size: iconSize,
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「#tag ×」pill：主色底白字（PitSearchResult 搜尋列）。
class TagFilterPill extends StatelessWidget {
  const TagFilterPill({super.key, required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _FilterPill(
    label: '#$name',
    color: context.tokens.accent,
    onClear: onClear,
  );
}

/// 「未加 tag ×」灰色 chip（PitSearchUntagged，D-108）；灰色 `#8a8073` 抄自設計稿，和 tag chip 區分。
class UntaggedFilterPill extends StatelessWidget {
  const UntaggedFilterPill({super.key, required this.onClear});
  final VoidCallback onClear;

  /// 設計稿的灰色（沒有對應 token）。
  static const color = Color(0xFF8A8073);

  @override
  Widget build(BuildContext context) => _FilterPill(
    label: context.l10n.searchUntagged,
    color: color,
    onClear: onClear,
    iconSize: 13,
  );
}
