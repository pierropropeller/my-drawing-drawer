import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
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

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
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

  testWidgets('第一次開啟顯示開頭畫面；離線繼續後進入主頁並記住', (tester) async {
    final c = await pumpApp(tester);
    expect(find.text('用 Google 帳號開始'), findsOneWidget);
    expect(find.text('我的坑'), findsNothing);
    await tester.tap(find.text('離線使用，暫不同步'));
    await settle(tester);
    expect(find.text('我的坑'), findsOneWidget);
    expect(c.read(settingsProvider).onboarded, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('onboarded'),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('連結 Google 帳號：未連結時「連結並開始」不可按', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.text('用 Google 帳號開始'));
    await settle(tester);
    final start = find.widgetWithText(FilledButton, '連結並開始');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.tap(find.text('加 Google 帳號'));
    await settle(tester);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('用另一個帳號'), findsOneWidget);
    await tester.tap(start);
    await settle(tester);
    expect(c.read(settingsProvider).accountEmail, 'me@example.com');
    expect(c.read(settingsProvider).onboarded, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('我的：主題切換會持久化；備份與同步頁', (tester) async {
    final c = await pumpApp(tester, prefs: {'onboarded': true});
    await tester.tap(find.text('我的').last);
    await settle(tester);
    expect(find.text('主題色'), findsOneWidget);
    expect(find.text('備份與同步'), findsOneWidget);

    await tester.tap(find.text('主題色'));
    await settle(tester);
    await tester.tap(find.text('霧藍'));
    await settle(tester);
    expect(c.read(settingsProvider).accent, AccentPreset.slate);
    expect(
      (await SharedPreferences.getInstance()).getString('accent'),
      'slate',
    );
    await tester.tap(find.text('深色'));
    await settle(tester);
    expect(c.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(
      (await SharedPreferences.getInstance()).getString('themeMode'),
      'dark',
    );
    await tester.tap(find.byTooltip('返回'));
    await settle(tester);

    await tester.tap(find.text('備份與同步'));
    await settle(tester);
    expect(find.text('尚未連結 Google 帳號'), findsOneWidget);
    await tester.tap(find.text('連結 Google 帳號'));
    await settle(tester);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('自動同步'), findsOneWidget);
    expect(find.text('每 5 分鐘'), findsOneWidget);
    await tester.tap(find.text('每 5 分鐘'));
    await settle(tester);
    await tester.tap(find.text('每 15 分鐘').last);
    await settle(tester);
    expect(c.read(settingsProvider).refreshMinutes, 15);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('離線時主頁顯示橫條', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
