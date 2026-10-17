import 'package:flutter/material.dart';

import '../common/nav_bar_hidden.dart';
import '../common/window_class.dart';
import 'adaptive_nav.dart';
import 'nav_bottom_bar.dart';
import 'nav_rail.dart';
import 'nav_sidebar.dart';

/// 目前顯示哪一種導覽。
enum NavMode { none, bottomBar, rail, sidebar }

/// 依視窗級別、頁面宣告的 [SideNavStyle] 與 `navBarHiddenCount` 決定導覽型態。
NavMode navModeFor(WindowClass wc, SideNavStyle style, {required bool hidden}) {
  if (hidden) return NavMode.none;
  if (wc.isCompact) return NavMode.bottomBar;
  if (wc.isWide && style == SideNavStyle.sidebar) return NavMode.sidebar;
  return NavMode.rail;
}

/// 自適應導覽外框：把 [body]（各分頁的 IndexedStack）放在 rail／sidebar 右邊，
/// 或在手機上把底部列放在下面。
///
/// [body] 在樹裡的位置固定（Scaffold.body → Row 的第二格），切換導覽型態只換旁邊的
/// 導覽，不會重建或重新掛載 [body]，所以拉窗時分頁 index 與各分頁的頁面堆疊都不會丟。
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.index,
    required this.controller,
    required this.onSelect,
    required this.onOpenPit,
    required this.onNewPit,
    required this.body,
  });

  final int index;
  final SideNavController controller;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onOpenPit;
  final VoidCallback onNewPit;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final wc = WindowClass.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return ValueListenableBuilder<int>(
      valueListenable: navBarHiddenCount,
      child: body,
      builder: (context, hidden, body) => ListenableBuilder(
        listenable: controller,
        child: body,
        builder: (context, body) {
          final spec = controller.specFor(index);
          final mode = navModeFor(wc, spec.style, hidden: hidden > 0);
          final side = switch (mode) {
            NavMode.rail => NavRail(index: index, onSelect: onSelect),
            NavMode.sidebar => NavSidebar(
              width: NavSidebar.widthFor(width),
              index: index,
              spec: spec,
              onSelect: onSelect,
              onOpenPit: onOpenPit,
              onNewPit: onNewPit,
            ),
            _ => const SizedBox.shrink(),
          };
          final hasSide = mode == NavMode.rail || mode == NavMode.sidebar;
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                side,
                Expanded(
                  // 左邊有導覽時，頁面的 SafeArea 不用再留左側安全區。
                  child: MediaQuery.removePadding(
                    context: context,
                    removeLeft: hasSide,
                    child: body!,
                  ),
                ),
              ],
            ),
            // 手機：藏起來時也留一個空的 slot，和原本的行為完全一致。
            bottomNavigationBar: wc.isCompact
                ? (mode == NavMode.bottomBar
                      ? NavBottomBar(index: index, onSelect: onSelect)
                      : const SizedBox.shrink())
                : null,
          );
        },
      ),
    );
  }
}
