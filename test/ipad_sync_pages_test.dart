import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/login/sync_first_page.dart';
import 'package:huakeng/ui/login/welcome_page.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/me/me_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Accounts implements AccountService {
  bool signedOut = false;
  @override
  Future<Map<String, String>> headers() async => {};
  @override
  Future<String?> restore() async => null;
  @override
  Future<String> signIn() async => 'molly@example.com';
  @override
  Future<void> signOut() async => signedOut = true;
}

class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
}

/// Connect／SyncFirst／Backup（含取消連結確認）的 iPad 版型：
/// 390×844 手機不變，834／1194／1366 寬版，400×900 分屏回到手機樣式。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late _Accounts accounts;

  setUp(() {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    accounts = _Accounts();
  });

  void setView(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget home, {
    bool linked = false,
    bool fakeSync = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      if (linked) 'accountEmail': 'molly@example.com',
      if (linked) 'syncedAccount': 'molly@example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          accountServiceProvider.overrideWithValue(accounts),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          if (fakeSync) syncControllerProvider.overrideWith(_FakeSync.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: home,
        ),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  /// 對話框的卡片本體（Dialog 自己是滿版）。
  Finder dialogCard() => find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('Connect', () {
    testWidgets('1194×834：左牆＋右表單，CTA 400 寬 52 高，選帳號後可按', (tester) async {
      setView(tester, 1194, 834);
      await pump(tester, const ConnectPage());
      expect(find.text('連結 Google 帳號'), findsOneWidget);
      expect(find.text('連結後，iPad 與手機會自動同步'), findsOneWidget);
      // 右半：表單的中心在右半。
      expect(tester.getCenter(find.text('連結 Google 帳號')).dx, closeTo(895, 5));
      final cta = find.widgetWithText(FilledButton, '連結並開始');
      expect(tester.getSize(cta), const Size(400, 52));
      expect(tester.widget<FilledButton>(cta).onPressed, isNull);
      // 返回鈕 44×44。
      expect(tester.getSize(find.bySemanticsLabel('返回')), const Size(44, 44));

      await tester.tap(find.text('加 Google 帳號'));
      await settle(tester);
      expect(find.text('molly@example.com'), findsOneWidget);
      expect(find.text('使用其他帳號'), findsNothing);
      expect(find.text('用另一個帳號'), findsOneWidget);
      expect(tester.widget<FilledButton>(cta).onPressed, isNotNull);
      await unmount(tester);
    });

    testWidgets('1366×1024 仍是寬版；834 直向與 390 手機維持手機版面', (tester) async {
      setView(tester, 1366, 1024);
      await pump(tester, const ConnectPage());
      expect(find.text('連結後，iPad 與手機會自動同步'), findsOneWidget);
      await unmount(tester);

      setView(tester, 834, 1194);
      await pump(tester, const ConnectPage());
      expect(find.text('連結後，跨設備自動同步'), findsOneWidget);
      await unmount(tester);

      setView(tester, 390, 844);
      await pump(tester, const ConnectPage());
      expect(find.text('連結後，跨設備自動同步'), findsOneWidget);
      expect(tester.getSize(find.bySemanticsLabel('返回')).width, 40);
      await unmount(tester);
    });
  });

  group('SyncFirst', () {
    testWidgets('1194×834：內容 ≤460 寬置中、按鈕 52 高；進度跟著同步狀態', (tester) async {
      setView(tester, 1194, 834);
      final c = await pump(tester, const SyncFirstPage(), fakeSync: true);
      (c.read(syncControllerProvider.notifier) as _FakeSync).set(
        const SyncState(
          phase: SyncPhase.syncing,
          imagesDone: 128,
          imagesTotal: 342,
        ),
      );
      await tester.pump();
      expect(find.text('正在同步'), findsOneWidget);
      expect(find.text('正在下載你在 Google Drive 的資料'), findsOneWidget);
      expect(find.text('圖片 128 / 342'), findsOneWidget);
      expect(find.text('37%'), findsOneWidget);
      expect(find.text('同步會在背景繼續'), findsOneWidget);
      final btn = tester.getRect(
        find
            .ancestor(of: find.text('先開始使用'), matching: find.byType(Container))
            .first,
      );
      expect(btn.width, 460);
      expect(btn.height, 52);
      expect(tester.getCenter(find.text('正在同步')).dx, closeTo(597, 1));
      await unmount(tester);
    });

    testWidgets('390×844 與 834×1194 維持手機版面（按鈕在底部、全寬減邊距）', (tester) async {
      for (final (w, h) in [(390.0, 844.0), (834.0, 1194.0)]) {
        setView(tester, w, h);
        await pump(tester, const SyncFirstPage(), fakeSync: true);
        expect(find.text('正在同步'), findsOneWidget);
        final btn = tester.getRect(
          find
              .ancestor(
                of: find.text('先開始使用'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(btn.width, w - 56);
        await unmount(tester);
      }
    });
  });

  group('Backup', () {
    testWidgets('1194×834 右側面板：分段間隔、兩顆按鈕並排、取消連結靠左', (tester) async {
      setView(tester, 1194, 834);
      final c = await pump(
        tester,
        const Scaffold(body: BackupPage(embedded: true)),
        linked: true,
      );
      expect(find.text('備份與同步'), findsOneWidget);
      for (final m in ['1 分鐘', '5 分鐘', '15 分鐘', '30 分鐘']) {
        expect(find.text(m), findsOneWidget);
      }
      expect(find.byType(PopupMenuButton<int>), findsNothing);
      await tester.tap(find.text('15 分鐘'));
      await settle(tester);
      expect(c.read(settingsProvider).refreshMinutes, 15);

      // 立即同步／更換帳號並排、等高 48。
      final a = tester.getRect(find.widgetWithText(FilledButton, '立即同步'));
      final b = tester.getRect(find.text('更換同步的 Google 帳號'));
      expect(a.height, 48);
      expect((a.center.dy - b.center.dy).abs() < 2, isTrue);
      expect(b.left > a.right, isTrue);
      // 取消連結靠左（與面板內容同左緣）。
      expect(
        tester.getTopLeft(find.text('取消連結')).dx,
        tester.getTopLeft(find.byType(MePanel).first).dx,
      );
      await unmount(tester);
    });

    testWidgets('取消連結確認：≥600 置中 340 寬、左右兩顆全寬按鈕；取消與確認', (tester) async {
      setView(tester, 1194, 834);
      final c = await pump(
        tester,
        const Scaffold(body: BackupPage(embedded: true)),
        linked: true,
      );
      await tester.tap(find.text('取消連結'));
      await settle(tester);
      expect(find.text('取消連結 Google 帳號？'), findsOneWidget);
      final title = tester.getRect(find.text('取消連結 Google 帳號？'));
      expect(title.center.dx, closeTo(597, 2)); // 文字置中
      final cancel = tester.getRect(find.text('取消'));
      final ok = tester.getRect(find.text('確認取消連結'));
      expect(cancel.center.dx < 597 && ok.center.dx > 597, isTrue);
      expect(tester.getSize(dialogCard()).width, 340);
      // 取消：關掉，仍是已連結。
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.text('取消連結 Google 帳號？'), findsNothing);
      expect(c.read(settingsProvider).accountEmail, isNotNull);

      await tester.tap(find.text('取消連結'));
      await settle(tester);
      await tester.tap(find.text('確認取消連結'));
      await settle(tester);
      expect(c.read(settingsProvider).accountEmail, isNull);
      expect(accounts.signedOut, isTrue);
      await unmount(tester);
    });

    testWidgets('390×844 與 400×900：手機樣式（下拉間隔、對話框文字靠左）', (tester) async {
      for (final (w, h) in [(390.0, 844.0), (400.0, 900.0)]) {
        setView(tester, w, h);
        await pump(tester, const BackupPage(), linked: true);
        expect(find.byType(PopupMenuButton<int>), findsOneWidget);
        expect(find.text('每 5 分鐘'), findsOneWidget);
        await tester.ensureVisible(find.text('取消連結'));
        await tester.tap(find.text('取消連結'));
        await settle(tester);
        final title = tester.getRect(find.text('取消連結 Google 帳號？'));
        expect(title.left < w / 2 - title.width / 2 - 1, isTrue); // 靠左
        await tester.tap(find.text('取消'));
        await settle(tester);
        await unmount(tester);
      }
    });

    testWidgets('對話框開著時視窗從 400 拉到 834：即時換成置中樣式', (tester) async {
      setView(tester, 400, 900);
      await pump(tester, const BackupPage(), linked: true);
      await tester.ensureVisible(find.text('取消連結'));
      await tester.tap(find.text('取消連結'));
      await settle(tester);
      expect(find.text('確認取消連結'), findsOneWidget);
      setView(tester, 834, 1194);
      await settle(tester);
      expect(tester.getSize(dialogCard()).width, 340);
      expect(
        tester.getRect(find.text('取消連結 Google 帳號？')).center.dx,
        closeTo(417, 2),
      );
      await unmount(tester);
    });
  });
}
