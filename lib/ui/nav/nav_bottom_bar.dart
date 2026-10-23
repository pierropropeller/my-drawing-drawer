import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'nav_tabs.dart';

/// 手機（compact）底部導覽列：坑／時間軸／我的。設計稿導覽列高 74（64＋底部 10）。
class NavBottomBar extends StatelessWidget {
  const NavBottomBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final tab in navTabs)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab.id == index,
                    onTap: () => onSelect(tab.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.accent : t.text4;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.string(
            tab.svg(selected ? 2 : 1.8),
            width: 24,
            height: 24,
            theme: SvgTheme(currentColor: color),
          ),
          const SizedBox(height: 3),
          Text(
            tab.label(context.l10n),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
