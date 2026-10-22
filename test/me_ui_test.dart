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
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart' show SyncStage;
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/login/sync_first_page.dart';
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

/// 固定在某個 [SyncState]，不真的同步。
class _FixedSync extends SyncController {
  _FixedSync(this.fixed);
  final SyncState fixed;
  @override
  SyncState build() => fixed;
  @override
  Future<bool> syncNow() async => false;
}

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
    Map<String, Object> prefs = const {'onboarded': true},
    SyncState? sync,
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
        if (sync != null)
          syncControllerProvider.overrideWith(() => _FixedSync(sync)),
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

  Future<void> openProfileRow(WidgetTester tester, String row) async {
    await tester.tap(find.text('我的').last);
    await settle(tester);
    await tester.tap(find.text(row));
    await settle(tester);
  }

  /// 我的 → 個人化 → 某一列（D-106：主題色、App 圖示、語言、敏感內容都收進個人化）。
  Future<void> openPersonalizeRow(WidgetTester tester, String row) async {
    await openProfileRow(tester, '個人化');
    await tester.tap(find.text(row));
    await settle(tester);
  }

  test('主題色色值表與 ColorSystem 一致（淺／深各 accent／strong／soft）', () {
    const expected = {
      AccentPreset.coral: [
        0xFFD9634E, 0xFFB84B38, 0xFFF6E3DC, //
        0xFFE27560, 0xFFE8876F, 0xFF3D2A24,
      ],
      AccentPreset.slate: [
        0xFF5B7A99, 0xFF46627E, 0xFFE3EAF1, //
        0xFF7F9DBB, 0xFF93AECB, 0xFF26303A,
      ],
      AccentPreset.rose: [
        0xFFB76A7C, 0xFF9A5264, 0xFFF3E2E6, //
        0xFFCF8A9B, 0xFFD99AAB, 0xFF3A2A2F,
      ],
      AccentPreset.matcha: [
        0xFF7A8B5B, 0xFF627248, 0xFFE6EBDC, //
        0xFF9AAB79, 0xFFADBD8C, 0xFF2D3324,
      ],
    };
    // D-067：次序為 玫瑰、霧藍、珊瑚、抹茶，預設玫瑰。
    expect(AccentPreset.values.map((p) => p.label), ['玫瑰', '霧藍', '珊瑚', '抹茶']);
    expect(AccentPreset.fromKey(null), AccentPreset.rose);
    expect(const AppSettings().accent, AccentPreset.rose);
    for (final e in expected.entries) {
      for (final (b, base, off) in [
        (Brightness.light, AppTokens.light, 0),
        (Brightness.dark, AppTokens.dark, 3),
      ]) {
        final t = base.withAccent(e.key, b);
        expect(t.accent, Color(e.value[off]), reason: '${e.key} $b accent');
        expect(t.accentStrong, Color(e.value[off + 1]), reason: 'strong');
        expect(t.accentSoft, Color(e.value[off + 2]), reason: 'soft');
        // 分類色、文字色、底色、danger 不隨主題改變。
        expect(t.piece.fg, base.piece.fg);
        expect(t.ground, base.ground);
        expect(t.danger, base.danger);
      }
    }
  });

  testWidgets('首次同步中：進度條與「圖片 128 / 342」，先開始使用可離開，無導覽列', (tester) async {
    final c = await pumpApp(
      tester,
      prefs: {'onboarded': true, 'accountEmail': 'me@example.com'},
      sync: const SyncState(
        phase: SyncPhase.syncing,
        stage: SyncStage.downloadingImages,
        imagesDone: 128,
        imagesTotal: 342,
        isFirstSync: true,
      ),
    );
    expect(c.read(firstSyncPendingProvider), isTrue);
    await tester.tap(find.text('我的').last);
    await settle(tester);
    // 直接在「我的」分頁的導覽器推入頁面（實際流程由連結帳號觸發）。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.push(MaterialPageRoute<void>(builder: (_) => const SyncFirstPage()));
    await settle(tester);
    expect(find.text('正在同步'), findsOneWidget);
    expect(find.text('正在下載你在 Google Drive 的資料'), findsOneWidget);
    expect(find.text('圖片 128 / 342'), findsOneWidget);
    expect(find.text('37%'), findsOneWidget);
    expect(find.text('同步會在背景繼續'), findsOneWidget);
    expect(navBarHiddenCount.value, greaterThan(0));
    await tester.tap(find.text('先開始使用'));
    await settle(tester);
    expect(find.text('正在同步'), findsNothing);
    await unmount(tester);
  });

  testWidgets('語言：English 停用並顯示「即將推出」，沒有說明小字', (tester) async {
    final c = await pumpApp(tester);
    await openPersonalizeRow(tester, '語言');
    expect(find.text('跟隨系統'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('即將推出'), findsOneWidget);
    expect(find.textContaining('目前介面只有繁體中文'), findsNothing);
    expect(find.textContaining('桌面上的 App 名稱'), findsNothing);
    expect(navBarHiddenCount.value, greaterThan(0));
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(c.read(settingsProvider).language, AppLanguage.system);
    await tester.tap(find.text('繁體中文'));
    await settle(tester);
    expect(c.read(settingsProvider).language, AppLanguage.zhTw);
    expect(
      (await SharedPreferences.getInstance()).getString('language'),
      'zhTw',
    );
    await unmount(tester);
  });

  testWidgets('我的有導覽列；編輯個人資料、主題色、備份、關於都沒有', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('我的').last);
    await settle(tester);
    expect(navBarHiddenCount.value, 0);
    for (final row in ['個人化', '備份與同步', '關於 App']) {
      await tester.tap(find.text(row));
      await settle(tester);
      expect(navBarHiddenCount.value, greaterThan(0), reason: row);
      await tester.tap(find.byTooltip('返回'));
      await settle(tester);
      expect(navBarHiddenCount.value, 0, reason: '$row 返回後');
    }
    // D-106：「我的」只剩 素材庫、個人化、備份與同步、關於 App；其餘收進個人化。
    for (final gone in ['主題色', 'App 圖示', '語言', '敏感內容']) {
      expect(find.text(gone), findsNothing, reason: '$gone 不在我的');
    }
    // 個人化裡的子頁：返回都回到個人化，不是我的。
    await tester.tap(find.text('個人化'));
    await settle(tester);
    for (final row in ['主題色', 'App 圖示', '語言', '敏感內容']) {
      await tester.tap(find.text(row));
      await settle(tester);
      expect(navBarHiddenCount.value, greaterThan(0), reason: row);
      await tester.tap(find.byTooltip('返回'));
      await settle(tester);
      expect(find.text('個人化'), findsOneWidget, reason: '$row 返回個人化');
      expect(find.text('素材庫'), findsNothing, reason: '$row 返回的不是我的');
    }
    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    expect(navBarHiddenCount.value, 0);
    await tester.tap(find.text('編輯個人資料'));
    await settle(tester);
    expect(navBarHiddenCount.value, greaterThan(0));
    await unmount(tester);
  });

  testWidgets('編輯個人資料：改暱稱按儲存才寫入', (tester) async {
    final c = await pumpApp(
      tester,
      prefs: {'onboarded': true, 'nickname': 'Molly'},
    );
    await tester.tap(find.text('我的').last);
    await settle(tester);
    await tester.tap(find.text('編輯個人資料'));
    await settle(tester);
    expect(find.text('點選頭像更換'), findsOneWidget);
    expect(find.text('暱稱'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '小畫');
    expect(c.read(settingsProvider).nickname, 'Molly');
    await tester.tap(find.text('儲存'));
    await settle(tester);
    expect(c.read(settingsProvider).nickname, '小畫');
    expect(find.text('點選頭像更換'), findsNothing);
    expect(find.text('小畫'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('關於 App：版本取自 package info，開源授權開啟授權頁', (tester) async {
    await pumpApp(tester);
    await openProfileRow(tester, '關於 App');
    expect(find.text('版本 1.2.3（45）'), findsOneWidget);
    expect(find.text('資料存放'), findsOneWidget);
    expect(find.text('所有資料只存在你的裝置和你的 Google Drive，不會上傳到其他地方。'), findsOneWidget);
    await tester.tap(find.text('開源授權'));
    await settle(tester);
    expect(find.byType(LicensePage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('備份：立即同步、更換帳號、取消連結（單一確認視窗）', (tester) async {
    final c = await pumpApp(
      tester,
      prefs: {
        'onboarded': true,
        'accountEmail': 'me@example.com',
        'syncedAccount': 'me@example.com',
      },
    );
    await openProfileRow(tester, '備份與同步');
    expect(find.text('立即同步'), findsOneWidget);
    expect(find.text('更換同步的 Google 帳號'), findsOneWidget);
    expect(find.text('取消連結'), findsOneWidget);
    expect(find.textContaining('上次備份'), findsOneWidget);
    await tester.ensureVisible(find.text('取消連結'));
    await tester.tap(find.text('取消連結'));
    await settle(tester);
    expect(find.text('取消連結 Google 帳號？'), findsOneWidget);
    expect(find.text('確認取消連結'), findsOneWidget);
    // 取消：什麼都不變。
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(c.read(settingsProvider).accountEmail, 'me@example.com');
    // 確認：解除連結。
    await tester.tap(find.text('取消連結'));
    await settle(tester);
    await tester.tap(find.text('確認取消連結'));
    await settle(tester);
    expect(c.read(settingsProvider).accountEmail, isNull);
    expect(find.text('尚未連結 Google 帳號'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('備份：顯示「此備份由較新版本建立」錯誤', (tester) async {
    await pumpApp(
      tester,
      prefs: {'onboarded': true, 'accountEmail': 'me@example.com'},
      sync: const SyncState(
        phase: SyncPhase.error,
        message: '此備份由較新版本建立，請先更新 App',
        needsAppUpdate: true,
      ),
    );
    await openProfileRow(tester, '備份與同步');
    expect(find.text('此備份由較新版本建立，請先更新 App'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('備份頁連結帳號後進入首次同步中', (tester) async {
    await pumpApp(tester);
    await openProfileRow(tester, '備份與同步');
    await tester.tap(find.text('連結 Google 帳號'));
    await settle(tester);
    // 同步很快完成時頁面會自動離開；兩種結果都代表流程有走到。
    final onSyncFirst = find.text('先開始使用').evaluate().isNotEmpty;
    if (onSyncFirst) {
      await tester.tap(find.text('先開始使用'));
      await settle(tester);
    }
    expect(find.text('me@example.com'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('深色模式與四個主題色：我的各頁都能 build', (tester) async {
    final c = await pumpApp(
      tester,
      prefs: {'onboarded': true, 'themeMode': 'dark'},
    );
    for (final p in AccentPreset.values) {
      c.read(settingsProvider.notifier).setAccent(p);
      await settle(tester);
    }
    await openPersonalizeRow(tester, '主題色');
    expect(find.text('預覽'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  group('敏感內容設定（D-104／D-106）', () {
    testWidgets('個人化四列；敏感內容預設關、只有總開關，沒有安全模式', (tester) async {
      final c = await pumpApp(tester);
      expect(c.read(settingsProvider).sensitiveEnabled, isFalse);
      expect(c.read(settingsProvider).safeMode, isTrue);
      await openProfileRow(tester, '個人化');
      for (final row in ['主題色', 'App 圖示', '語言', '敏感內容']) {
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('關閉'), findsOneWidget); // 敏感內容那一列右邊的目前值
      await tester.tap(find.text('敏感內容'));
      await settle(tester);
      expect(find.text('敏感內容標記'), findsOneWidget);
      expect(find.text('安全模式'), findsNothing);
      await unmount(tester);
    });

    testWidgets('關→開不用確認，出現安全模式（預設開）；開→關要確認，取消不變', (tester) async {
      final c = await pumpApp(tester);
      await openPersonalizeRow(tester, '敏感內容');
      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      expect(c.read(settingsProvider).sensitiveEnabled, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool('sensitiveEnabled'),
        isTrue,
      );
      expect(find.text('安全模式'), findsOneWidget);
      expect(
        find.text('開啟後會模糊顯示已標記的圖片，關閉則正常顯示'),
        findsOneWidget,
      );
      // 安全模式可以切換，且是本機設定。
      await tester.tap(find.byKey(const ValueKey('sensitiveSafeModeSwitch')));
      await settle(tester);
      expect(c.read(settingsProvider).safeMode, isFalse);
      // 開→關：確認視窗（文字照 R18SettingsOff）。
      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      expect(find.text('關閉敏感內容標記？'), findsOneWidget);
      expect(
        find.text('已標記的圖片會照常顯示，不再模糊，所有敏感內容選項也會隱藏。重新開啟後，標記會自動恢復。'),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(c.read(settingsProvider).sensitiveEnabled, isTrue);
      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      await tester.tap(find.text('關閉'));
      await settle(tester);
      expect(c.read(settingsProvider).sensitiveEnabled, isFalse);
      expect(find.text('安全模式'), findsNothing);
      // 安全模式的值保留，重新打開後原樣。
      expect(c.read(settingsProvider).safeMode, isFalse);
      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      expect(c.read(settingsProvider).sensitiveEnabled, isTrue);
      expect(find.text('安全模式'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('設定存在本機並在重開後還原', (tester) async {
      final c = await pumpApp(
        tester,
        prefs: {
          'onboarded': true,
          'sensitiveEnabled': true,
          'safeMode': false,
        },
      );
      expect(c.read(settingsProvider).sensitiveEnabled, isTrue);
      expect(c.read(settingsProvider).safeMode, isFalse);
      await unmount(tester);
    });
  });
}
