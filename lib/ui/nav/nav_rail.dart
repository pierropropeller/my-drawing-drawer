import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/user_avatar.dart';
import 'nav_tabs.dart';

/// 平板 icon rail（84）：頭像在上，下面是 64×60 的 坑／目標／我的（Profile／MainPortrait）。
class NavRail extends StatelessWidget {
  const NavRail({super.key, required this.index, required this.onSelect});

  /// rail 的闊度（設計稿）。
  static const width = 84.0;

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        right: false,
        child: Semantics(
          container: true,
          label: context.l10n.ipadnavMainMenu,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 28, bottom: 20),
            child: Column(
              children: [
                UserAvatar(
                  size: 44,
                  serif: true,
                  background: t.accentSoft,
                  foreground: t.accentStrong,
                ),
                const SizedBox(height: 20),
                for (final tab in navTabs) ...[
                  _RailItem(
                    tab: tab,
                    selected: tab.id == index,
                    onTap: () => onSelect(tab.id),
                  ),
                  if (tab.id != navTabs.last.id) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
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
    final color = selected ? t.accent : t.text2;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label(context.l10n),
      excludeSemantics: true,
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 60,
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
          ),
        ),
      ),
    );
  }
}
