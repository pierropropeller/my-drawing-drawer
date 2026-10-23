import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/tokens.dart';
import '../state/sensitive.dart';
import '../state/settings.dart';
import '../sync/sync_driver.dart';
import 'common/root_overlay_guard.dart';
import 'goals/goals_page.dart';
import 'login/welcome_page.dart';
import 'nav/adaptive_nav.dart';
import 'nav/adaptive_scaffold.dart';
import 'nav/nav_tabs.dart';
import 'pits/pit_new_page.dart';
import 'pits/pit_page.dart';
import 'me/profile_page.dart';
import 'pits/pits_page.dart';
import 'share/share_host.dart';

/// 導覽外框：手機＝底部列，平板＝左側 icon rail／sidebar（見 `nav/adaptive_nav.dart`）。
/// 坑／目標／我的各有自己的 Navigator，分頁 index 與頁面堆疊都放在這個 State，
/// 視窗拉闊收窄（導覽型態切換）時不會丟。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index = _restoreIndex();

  /// 上次停留的分頁（設定裡的值不合法就回坑）。
  int _restoreIndex() {
    final i = ref.read(settingsProvider).lastNavTab;
    return i >= 0 && i < navTabs.length ? i : 0;
  }

  /// 切換分頁並記住（下次開 App 回到這裡）。
  void _setIndex(int i) {
    setState(() => _index = i);
    ref.read(settingsProvider.notifier).setLastNavTab(i);
  }

  final _navKeys = List.generate(
    navTabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );
  final _sideNav = SideNavController();
  late final _observers = [
    for (var i = 0; i < navTabs.length; i++) SideNavObserver(_sideNav, i),
  ];

  @override
  void dispose() {
    _sideNav.dispose();
    super.dispose();
  }

  // 坑、目標的根頁在橫向寬螢幕用完整 sidebar；我的用 rail（設計稿 Main／Goal／Profile）。
  Widget _root(int i) => switch (i) {
    0 => const SideNavStyleHint.sidebar(child: PitsPage()),
    1 => const SideNavStyleHint.sidebar(child: GoalsPage()),
    2 => const ProfilePage(),
    _ => const SizedBox.shrink(),
  };

  /// sidebar 點一個坑：切到坑分頁，回到主頁後開啟該坑。
  void _openPit(String pitId) {
    _setIndex(0);
    final nav = _navKeys[0].currentState;
    if (nav == null) return;
    nav.popUntil((r) => r.isFirst);
    nav.push(MaterialPageRoute<void>(builder: (_) => PitPage(pitId: pitId)));
  }

  /// 同步進度 popover 的「同步設定」：切到我的，右側面板顯示備份與同步。
  void _openSyncSettings() {
    ref
        .read(profileSectionRequestProvider.notifier)
        .request(ProfileSection.backup);
    _setIndex(2);
  }

  void _newPit() {
    _setIndex(0);
    _navKeys[0].currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const PitNewPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 第一次開啟：開頭畫面（用 Google 帳號開始，或離線繼續）。
    if (!ref.watch(settingsProvider.select((s) => s.onboarded))) {
      return const WelcomePage();
    }
    // 敏感內容（D-104）：總開關開著時，一進主畫面就先查好哪些圖是敏感的，列表縮圖一出來就不會露出。
    ref.watch(sensitiveWarmupProvider);
    // 分享進來的「加入到」sheet 要在主畫面常駐監聽（D-053）。
    return SyncDriver(
      child: ShareHost(
        pitsNavigator: _navKeys[0],
        showPitsTab: () {
          if (_index != 0) _setIndex(0);
        },
        profileNavigator: _navKeys[2],
        showProfileTab: () {
          if (_index != 2) _setIndex(2);
        },
        child: _buildShell(context, t),
      ),
    );
  }

  Widget _buildShell(BuildContext context, AppTokens t) {
    return AdaptiveNavScaffold(
      index: _index,
      controller: _sideNav,
      onSelect: (i) => _setIndex(i),
      onOpenPit: _openPit,
      onNewPit: _newPit,
      onOpenSyncSettings: _openSyncSettings,
      // 每個分頁各自一個 Navigator，子頁面時導覽仍留在所屬分頁。
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final nav = _navKeys[_index].currentState!;
          if (nav.canPop()) {
            nav.pop();
          } else if (_index != 0) {
            _setIndex(0);
          } else {
            SystemNavigator.pop();
          }
        },
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < navTabs.length; i++)
              SideNavTabScope(
                controller: _sideNav,
                tab: i,
                child: TabBackScope(
                  active: i == _index,
                  child: Navigator(
                    key: _navKeys[i],
                    observers: [_observers[i]],
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => _root(i)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
