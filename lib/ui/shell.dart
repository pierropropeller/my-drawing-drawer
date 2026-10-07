import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'pits/pits_page.dart';

/// 底部導覽列：坑／目標／我的。各分頁內容之後逐步補上。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('坑', Icons.collections_bookmark_outlined, Icons.collections_bookmark),
  _Tab('目標', Icons.flag_outlined, Icons.flag),
  _Tab('我的', Icons.person_outline, Icons.person),
];

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _navKeys = List.generate(
    _tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  Widget _root(int i) => switch (i) {
    0 => const PitsPage(),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.nav,
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
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
          Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            tab.label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
