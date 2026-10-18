import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../sync/sync_avatar.dart';
import 'adaptive_nav.dart';
import 'nav_tabs.dart';

/// 完整 sidebar（Main／Pit／Goal，設計稿 260）：頭像＋名字、坑／目標／我的、
/// 下半部依分頁：坑＝「現坑」清單（含成圖數）＋「開新坑」，目標＝「年份」。
class NavSidebar extends ConsumerWidget {
  const NavSidebar({
    super.key,
    required this.width,
    required this.index,
    required this.spec,
    required this.onSelect,
    required this.onOpenPit,
    required this.onNewPit,
    this.onOpenSyncSettings,
  });

  /// 闊度範圍的取法：視窗闊度的 22%，夾在 232～260（設計稿 260）。
  static double widthFor(double windowWidth) =>
      (windowWidth * 0.22).clamp(232.0, 260.0).toDouble();

  final double width;
  final int index;
  final SideNavSpec spec;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onOpenPit;
  final VoidCallback onNewPit;

  /// 同步進度 popover 的「同步設定」連結：前往我的 › 備份與同步。
  final VoidCallback? onOpenSyncSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final nickname = ref.watch(settingsProvider.select((s) => s.nickname));
    final custom = spec.sidebarSection;
    final Widget? section = custom != null
        ? custom(context)
        : switch (index) {
            0 => _PitSection(
              currentPitId: spec.currentPitId,
              onOpenPit: onOpenPit,
              onNewPit: onNewPit,
            ),
            1 => const SidebarYearSection(),
            _ => null,
          };
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
          child: Semantics(
            container: true,
            label: context.l10n.ipadnavMainMenu,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      // 同步狀態收在頭像外圈（MainSyncing／SyncPopover）。
                      SyncAvatar(
                        size: 40,
                        onOpenSettings: onOpenSyncSettings,
                        serif: true,
                        background: t.accentSoft,
                        foreground: t.accentStrong,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          nickname.isEmpty ? context.l10n.pitsMyPits : nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: 22, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                for (final tab in navTabs) ...[
                  _SidebarTab(
                    tab: tab,
                    selected: tab.id == index,
                    onTap: () => onSelect(tab.id),
                  ),
                  if (tab.id != navTabs.last.id) const SizedBox(height: 4),
                ],
                if (section != null) Expanded(child: section),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({
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
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SvgPicture.string(
                    tab.svg(selected ? 2 : 1.8),
                    width: 22,
                    height: 22,
                    theme: SvgTheme(currentColor: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tab.label(context.l10n),
                    style: TextStyle(
                      fontSize: 15,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 區塊小標（「現坑」「年份」）。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 28, 12, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.tokens.text3,
        letterSpacing: 1,
      ),
    ),
  );
}

/// sidebar 清單列（44 高、圓角 12）：[selected] 時淡底＋粗體。
class SidebarRow extends StatelessWidget {
  const SidebarRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? t.chipBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PitSection extends ConsumerWidget {
  const _PitSection({
    required this.currentPitId,
    required this.onOpenPit,
    required this.onNewPit,
  });

  final String? currentPitId;
  final ValueChanged<String> onOpenPit;
  final VoidCallback onNewPit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pits = ref.watch(pitsProvider(false)).value ?? const [];
    // 色塊依序用與坑卡片佔位相同的分類色。
    final tints = [
      t.official.bg,
      t.fanArt.bg,
      t.draft.bg,
      dark ? const Color(0xFF2C3529) : const Color(0xFFE7EFE4),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(context.l10n.ipadnavCurrentPits),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: pits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (_, i) {
              final pit = pits[i];
              final selected = pit.id == currentPitId;
              return SidebarRow(
                selected: selected,
                onTap: () => onOpenPit(pit.id),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: tints[i % tints.length],
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${ref.watch(pitStatsProvider(pit.id)).value?.pieces ?? 0}',
                      style: TextStyle(fontSize: 12, color: t.text3),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onNewPit,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SvgIcon(
                    AppIcons.plus,
                    size: 20,
                    strokeWidth: 1.8,
                    color: t.text2,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.pitsNewTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: t.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 目標頁 sidebar 的「年份」清單；選取狀態在 [goalSidebarYearProvider]。
/// 年份＝今年與去年（設計稿 2026／2025），目前選的年份若更早也會列出。
class SidebarYearSection extends ConsumerWidget {
  const SidebarYearSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(goalSidebarYearProvider);
    final now = DateTime.now().year;
    final years = {now, now - 1, selected}.toList()
      ..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(context.l10n.ipadnavYears),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: years.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (_, i) {
              final y = years[i];
              final on = y == selected;
              return SidebarRow(
                selected: on,
                onTap: () =>
                    ref.read(goalSidebarYearProvider.notifier).select(y),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$y',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
