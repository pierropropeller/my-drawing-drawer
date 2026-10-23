import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/login/welcome_page.dart';
import 'package:huakeng/ui/me/profile_page.dart';
import 'package:huakeng/ui/nav/adaptive_nav.dart';
import 'package:huakeng/ui/nav/nav_bottom_bar.dart';
import 'package:huakeng/ui/nav/nav_rail.dart';
import 'package:huakeng/ui/nav/nav_sidebar.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';

/// 自適應導覽：390×844 底部列、834×1194 icon rail、1194×834 sidebar，
/// 以及拉窗（分屏收窄再放大）時分頁與頁面堆疊不丟。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  void resize(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester,
    double w,
    double h, {
    bool withPit = false,
  }) async {
    resize(tester, w, h);
    addTearDown(tester.view.reset);
    if (withPit) {
      await tester.runAsync(() => db.createPit(name: '坑A'));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('390×844：底部導覽列，沒有 rail／sidebar', (tester) async {
    await pumpApp(tester, 390, 844);
    expect(find.byType(NavBottomBar), findsOneWidget);
    expect(find.byType(NavRail), findsNothing);
    expect(find.byType(NavSidebar), findsNothing);
    await unmount(tester);
  });

  testWidgets('834×1194：左側 icon rail 84，可切換分頁', (tester) async {
    await pumpApp(tester, 834, 1194);
    expect(find.byType(NavBottomBar), findsNothing);
    expect(find.byType(NavSidebar), findsNothing);
    expect(find.byType(NavRail), findsOneWidget);
    expect(tester.getSize(find.byType(NavRail)).width, 84);
    // 項目 64×60。
    expect(
      tester.getSize(
        find
            .descendant(
              of: find.byType(NavRail),
              matching: find.byType(InkWell),
            )
            .first,
      ),
      const Size(64, 60),
    );
    await tester.tap(
      find.descendant(of: find.byType(NavRail), matching: find.text('我的')),
    );
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('1194×834：坑／時間軸用 sidebar 260，我的用 rail', (tester) async {
    await pumpApp(tester, 1194, 834, withPit: true);
    expect(find.byType(NavSidebar), findsOneWidget);
    expect(tester.getSize(find.byType(NavSidebar)).width, 260);
    expect(find.byType(NavRail), findsNothing);
    // 坑分頁：現坑清單＋開新坑。
    expect(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('現坑')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('坑A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('開新坑')),
      findsOneWidget,
    );

    // 時間軸分頁：sidebar 顯示年份。
    await tester.tap(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('時間軸')),
    );
    await settle(tester);
    expect(find.byType(GoalsPage), findsOneWidget);
    expect(find.byType(NavSidebar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('年份')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('現坑')),
      findsNothing,
    );
    final year = DateTime.now().year;
    expect(
      find.descendant(
        of: find.byType(NavSidebar),
        matching: find.text('${year - 1}'),
      ),
      findsOneWidget,
    );

    // 我的分頁：icon rail。
    await tester.tap(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('我的')),
    );
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(NavRail), findsOneWidget);
    expect(find.byType(NavSidebar), findsNothing);
    await unmount(tester);
  });

  testWidgets('sidebar 點一個坑會開啟該坑', (tester) async {
    await pumpApp(tester, 1194, 834, withPit: true);
    await tester.tap(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('坑A')),
    );
    await settle(tester);
    expect(find.byType(PitPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('navBarHiddenCount > 0 時 rail／sidebar／底部列都藏起來', (tester) async {
    for (final size in const [
      Size(390, 844),
      Size(834, 1194),
      Size(1194, 834),
    ]) {
      await pumpApp(tester, size.width, size.height);
      final finder = size.width < 600
          ? find.byType(NavBottomBar)
          : size.width < 840
          ? find.byType(NavRail)
          : find.byType(NavSidebar);
      expect(finder, findsOneWidget, reason: '$size');
      navBarHiddenCount.value++;
      await tester.pump();
      expect(finder, findsNothing, reason: '$size');
      navBarHiddenCount.value--;
      await tester.pump();
      expect(finder, findsOneWidget, reason: '$size');
      await unmount(tester);
    }
  });

  testWidgets('拉窗：1194 → 400 → 1194，分頁與頁面堆疊保留、頁面不重建', (tester) async {
    await pumpApp(tester, 1194, 834, withPit: true);
    // 坑分頁開一個坑（堆疊：主頁 → 坑內頁）。
    await tester.tap(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('坑A')),
    );
    await settle(tester);
    final pitElement = tester.element(find.byType(PitPage));
    final pitsElement = tester.element(
      find.byType(PitsPage, skipOffstage: false),
    );

    // 窄分屏。
    resize(tester, 400, 900);
    await settle(tester);
    expect(find.byType(NavBottomBar), findsOneWidget);
    expect(find.byType(NavSidebar), findsNothing);
    expect(tester.element(find.byType(PitPage)), same(pitElement));
    expect(
      tester.element(find.byType(PitsPage, skipOffstage: false)),
      same(pitsElement),
    );

    // 手機版切到「我的」，再放大：仍在「我的」，rail 取代 sidebar。
    await tester.tap(
      find.descendant(of: find.byType(NavBottomBar), matching: find.text('我的')),
    );
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    resize(tester, 1194, 834);
    await settle(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(NavRail), findsOneWidget);

    // 回到坑分頁：坑內頁還在（同一個 element），sidebar 回來。
    await tester.tap(
      find.descendant(of: find.byType(NavRail), matching: find.text('坑')),
    );
    await settle(tester);
    expect(tester.element(find.byType(PitPage)), same(pitElement));
    await unmount(tester);
  });

  testWidgets('頁面用 SideNavStyleHint 宣告 sidebar／rail，彈出的 sheet 不影響', (
    tester,
  ) async {
    await pumpApp(tester, 1194, 834);
    // 我的分頁 rail → 推一個宣告 sidebar 的頁面。
    await tester.tap(
      find.descendant(of: find.byType(NavSidebar), matching: find.text('我的')),
    );
    await settle(tester);
    expect(find.byType(NavRail), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).at(1));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const SideNavStyleHint.sidebar(
          child: Scaffold(body: Text('hinted')),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('hinted'), findsOneWidget);
    expect(find.byType(NavSidebar), findsOneWidget);
    // 彈出 dialog（popup route）時 sidebar 不變。
    showDialog<void>(
      context: nav.context,
      useRootNavigator: false,
      builder: (_) => const AlertDialog(title: Text('dlg')),
    );
    await settle(tester);
    expect(find.text('dlg'), findsOneWidget);
    expect(find.byType(NavSidebar), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Welcome：寬版左牆右按鈕，窄版沿用手機版面', (tester) async {
    Future<void> pumpWelcome(double w, double h) async {
      resize(tester, w, h);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: ThemeData(extensions: const [AppTokens.light]),
            home: const WelcomePage(),
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(tester.view.reset);
    await pumpWelcome(1194, 834);
    expect(tester.takeException(), isNull);
    expect(find.text('用 Google 帳號開始'), findsOneWidget);
    expect(find.text('離線使用，暫不同步'), findsOneWidget);
    // 右半置中：按鈕闊度 ≤360。
    expect(tester.getSize(find.text('離線使用，暫不同步').first).width, lessThan(360));
    final btn = tester.getRect(
      find.ancestor(
        of: find.text('用 Google 帳號開始'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(btn.width, 360);
    expect(btn.height, 52);
    expect(btn.center.dx, greaterThan(597));

    await pumpWelcome(390, 844);
    expect(tester.takeException(), isNull);
    expect(find.text('用 Google 帳號開始'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
