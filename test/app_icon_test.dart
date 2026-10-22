import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/app_icon.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/ui/common/app_icons.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/svg_icon.dart';
import 'package:huakeng/ui/login/welcome_page.dart';
import 'package:huakeng/ui/me/about_page.dart';
import 'package:huakeng/ui/me/app_icon_image.dart';
import 'package:huakeng/ui/me/app_icon_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccounts implements AccountService {
  @override
  Future<String> signIn() async => 'me@example.com';
  @override
  Future<String?> restore() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<Map<String, String>> headers() async => {};
}

/// D-086：App 圖示（清單、設定、平台服務、選擇頁、我的那一列、關於／開頭）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    PackageInfo.setMockInitialValues(
      appName: 'huakeng',
      packageName: 'app.huakeng',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required MemoryAppIconService icons,
    Map<String, Object> prefs = const {'onboarded': true},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPrefsProvider.overrideWithValue(p),
        accountServiceProvider.overrideWithValue(_FakeAccounts()),
        syncRemoteProvider.overrideWithValue(MemoryRemote()),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
        appIconServiceProvider.overrideWithValue(icons),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    return c;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 我的 → 個人化（D-106：App 圖示收進個人化）。
  Future<void> openPersonalize(WidgetTester tester) async {
    await tester.tap(find.text('我的').last);
    await settle(tester);
    await tester.tap(find.text('個人化'));
    await settle(tester);
  }

  Future<void> openIconPage(WidgetTester tester) async {
    await openPersonalize(tester);
    await tester.tap(find.text('App 圖示'));
    await settle(tester);
  }

  test('圖示清單：三筆（預設）、花體；key／alias／預覽圖不重複', () {
    expect(appIconOptions.map((o) => o.key), ['sanbi', 'huati']);
    expect(appIconOptions.map((o) => o.alias), ['IconSanbi', 'IconHuati']);
    expect(defaultAppIcon.key, 'sanbi');
    expect(appIconOptions.map((o) => o.key).toSet().length, 2);
    expect(appIconOptions.map((o) => o.alias).toSet().length, 2);
    expect(appIconOptions.map((o) => o.asset).toSet().length, 2);
    final l = l10nStatic;
    expect(appIconOptions.map((o) => o.name(l)), ['三筆', '花體']);
    expect(appIconByKey('huati').alias, 'IconHuati');
    // 未知或空值回預設。
    expect(appIconByKey('nope').key, 'sanbi');
    expect(appIconByKey(null).key, 'sanbi');
  });

  test('設定：預設 sanbi；setAppIcon 存進 SharedPreferences，重開讀得回', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(p)],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).appIcon, 'sanbi');
    expect(const AppSettings().appIcon, 'sanbi');
    c.read(settingsProvider.notifier).setAppIcon('huati');
    expect(c.read(settingsProvider).appIcon, 'huati');
    expect(c.read(currentAppIconProvider).key, 'huati');
    expect(p.getString('appIcon'), 'huati');

    final c2 = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(p)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(settingsProvider).appIcon, 'huati');
  });

  test('啟動校正：平台啟用的 alias 跟設定不同時以平台為準；查不到就不動', () async {
    SharedPreferences.setMockInitialValues({'appIcon': 'sanbi'});
    final p = await SharedPreferences.getInstance();
    final icons = MemoryAppIconService('IconHuati');
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        appIconServiceProvider.overrideWithValue(icons),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).appIcon, 'sanbi');
    await c.read(appIconStartupSyncProvider.future);
    expect(c.read(settingsProvider).appIcon, 'huati');
    expect(p.getString('appIcon'), 'huati');
    // 校正只動設定，不會再呼叫平台。
    expect(icons.calls, isEmpty);

    final none = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        appIconServiceProvider.overrideWithValue(MemoryAppIconService()),
      ],
    );
    addTearDown(none.dispose);
    await none.read(appIconStartupSyncProvider.future);
    expect(none.read(settingsProvider).appIcon, 'huati');
  });

  testWidgets('個人化：主題色下面有「App 圖示」列，右邊顯示目前名稱，點進去沒有導覽列', (tester) async {
    final icons = MemoryAppIconService('IconSanbi');
    await pumpApp(tester, icons: icons);
    await openPersonalize(tester);
    // 順序：主題色 → App 圖示 → 語言。
    final themeY = tester.getTopLeft(find.text('主題色')).dy;
    final iconY = tester.getTopLeft(find.text('App 圖示')).dy;
    final langY = tester.getTopLeft(find.text('語言')).dy;
    expect(themeY, lessThan(iconY));
    expect(iconY, lessThan(langY));
    expect(find.text('三筆'), findsOneWidget);
    // 左邊是目前那款的小圖（不是主題色底的 SVG 方塊）。
    final img = tester.widget<AppIconImage>(find.byType(AppIconImage));
    expect(img.option.key, 'sanbi');
    expect(img.size, 38);

    await tester.tap(find.text('App 圖示'));
    await settle(tester);
    expect(find.byType(AppIconPickPage), findsOneWidget);
    expect(navBarHiddenCount.value, greaterThan(0));
    await unmount(tester);
  });

  testWidgets('AppIconPickPage：兩張卡、目前那張勾選；點另一張立刻切換並顯示提示', (tester) async {
    final icons = MemoryAppIconService('IconSanbi');
    final c = await pumpApp(tester, icons: icons);
    await openIconPage(tester);

    expect(find.text('三筆'), findsOneWidget);
    expect(find.text('花體'), findsOneWidget);
    expect(find.byType(AppIconImage), findsNWidgets(2));
    // 勾只出現在目前選的那張。
    Finder checks() => find.byWidgetPredicate(
      (w) => w is SvgIcon && w.shapes == AppIcons.check,
    );
    expect(checks(), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('三筆'), matching: find.byType(Container))
            .first,
        matching: checks(),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('花體'));
    await settle(tester);
    expect(icons.calls, ['IconHuati']);
    expect(icons.alias, 'IconHuati');
    expect(c.read(settingsProvider).appIcon, 'huati');
    expect(find.text('桌面圖示已換成「花體」'), findsOneWidget);

    // 再點回三筆。
    await tester.tap(find.text('三筆'));
    await settle(tester);
    expect(icons.calls, ['IconHuati', 'IconSanbi']);
    expect(c.read(settingsProvider).appIcon, 'sanbi');
    expect(find.text('桌面圖示已換成「三筆」'), findsOneWidget);

    // 點已選的那張：不重複呼叫平台。
    await tester.tap(find.text('三筆'));
    await settle(tester);
    expect(icons.calls.length, 2);
    await unmount(tester);
  });

  testWidgets('AppIconPickPage：平台失敗時設定不變、沒有成功提示', (tester) async {
    final icons = MemoryAppIconService('IconSanbi')..failing = true;
    final c = await pumpApp(tester, icons: icons);
    await openIconPage(tester);
    await tester.tap(find.text('花體'));
    await settle(tester);
    expect(c.read(settingsProvider).appIcon, 'sanbi');
    expect(find.textContaining('桌面圖示已換成'), findsNothing);
    await unmount(tester);
  });

  testWidgets('啟動時平台已是花體：個人化的那一列顯示「花體」', (tester) async {
    final icons = MemoryAppIconService('IconHuati');
    await pumpApp(tester, icons: icons);
    await openPersonalize(tester);
    expect(find.text('花體'), findsOneWidget);
    expect(
      tester.widget<AppIconImage>(find.byType(AppIconImage)).option.key,
      'huati',
    );
    await unmount(tester);
  });

  testWidgets('關於 App：顯示目前選的圖示圖片，不再是主題色方塊', (tester) async {
    final icons = MemoryAppIconService('IconHuati');
    await pumpApp(tester, icons: icons);
    await tester.tap(find.text('我的').last);
    await settle(tester);
    await tester.tap(find.text('關於 App'));
    await settle(tester);
    expect(find.byType(AboutPage), findsOneWidget);
    final img = tester.widget<AppIconImage>(find.byType(AppIconImage));
    expect(img.option.key, 'huati');
    expect(img.size, 84);
    expect(find.text('版本 1.2.3（45）'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('開頭：顯示目前選的圖示圖片', (tester) async {
    SharedPreferences.setMockInitialValues({'appIcon': 'huati'});
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(p),
        appIconServiceProvider.overrideWithValue(MemoryAppIconService()),
        accountServiceProvider.overrideWithValue(_FakeAccounts()),
      ],
    );
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          locale: appLocale,
          supportedLocales: const [appLocale],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const WelcomePage(),
        ),
      ),
    );
    await settle(tester);
    final img = tester.widget<AppIconImage>(find.byType(AppIconImage));
    expect(img.option.key, 'huati');
    expect(img.size, 92);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
