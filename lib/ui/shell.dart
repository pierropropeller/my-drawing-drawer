import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';
import '../state/settings.dart';
import '../sync/sync_driver.dart';
import 'common/nav_bar_hidden.dart';
import 'goals/goals_page.dart';
import 'login/welcome_page.dart';
import 'me/profile_page.dart';
import 'pits/pits_page.dart';

/// 底部導覽列：坑／目標／我的。各分頁內容之後逐步補上。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

/// 導覽列的 icon 直接取自設計稿（Main／GoalYear／Profile 的 nav）：
/// 資料夾、雙圓靶心、人像；未選中線寬 1.8，選中線寬 2。
class _Tab {
  const _Tab(this.label, this.shapes);
  final String label;

  /// SVG（24×24）內的圖形，線寬在建立時帶入。
  final String shapes;

  String svg(double strokeWidth) =>
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
      'fill="none" stroke="currentColor" stroke-width="$strokeWidth" '
      'stroke-linecap="round" stroke-linejoin="round">$shapes</svg>';
}

const _tabs = [
  _Tab(
    '坑',
    '<path d="M3 7a2 2 0 0 1 2-2h3.5l2 2H19a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  ),
  _Tab(
    '目標',
    '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.4"/>',
  ),
  _Tab(
    '我的',
    '<circle cx="12" cy="8" r="4"/><path d="M4.5 20c0-4.2 3.8-6 7.5-6s7.5 1.8 7.5 6"/>',
  ),
];

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final _navKeys = List.generate(
    _tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  Widget _root(int i) => switch (i) {
    0 => const PitsPage(),
    1 => const GoalsPage(),
    2 => const ProfilePage(),
    _ => Center(
      child: Text(
        _tabs[i].label,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 第一次開啟：開頭畫面（用 Google 帳號開始，或離線繼續）。
    if (!ref.watch(settingsProvider.select((s) => s.onboarded))) {
      return const WelcomePage();
    }
    return SyncDriver(child: _buildShell(context, t));
  }

  Widget _buildShell(BuildContext context, AppTokens t) {
    return Scaffold(
      // 每個分頁各自一個 Navigator，子頁面時導覽列仍留在所屬分頁。
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _navKeys[_index].currentState!;
          if (nav.canPop()) {
            nav.pop();
          } else if (_index != 0) {
            setState(() => _index = 0);
          } else {
            SystemNavigator.pop();
          }
        },
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Navigator(
                key: _navKeys[i],
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => _root(i)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: navBarHiddenCount,
        builder: (_, hidden, _) => hidden > 0
            ? const SizedBox.shrink()
            : Container(
                decoration: BoxDecoration(
                  color: t.nav,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          Expanded(
                            child: _NavItem(
                              tab: _tabs[i],
                              selected: i == _index,
                              onTap: () => setState(() => _index = i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
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
            tab.label,
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
