import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_driver.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/top_toast.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 連不到 Google（中國大陸）時：背景同步一律安靜失敗、當作離線處理——
/// 不彈任何畫面（Google／系統授權畫面、對話框、提示條），本機照常使用，之後退避重試。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('sync_quiet');
  });
  tearDown(() async => db.close());

  ProviderContainer containerWith(SyncRemote remote) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        imageStoreProvider.overrideWith((ref) async => ImageStore(dir)),
        syncRemoteProvider.overrideWithValue(remote),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    c.read(settingsProvider.notifier).setAccount('me@example.com');
    addTearDown(c.dispose);
    return c;
  }

  DriveRemote driveWith({
    required Future<Map<String, String>> Function() headers,
    http.Client? client,
  }) => DriveRemote(
    headers: headers,
    client: client ?? MockClient((_) async => http.Response('{}', 200)),
    requestTimeout: const Duration(milliseconds: 100),
    idleTimeout: const Duration(milliseconds: 100),
    uploadTimeout: const Duration(milliseconds: 100),
    headersTimeout: const Duration(milliseconds: 100),
    retryDelay: const Duration(milliseconds: 1),
  );

  group('背景同步失敗＝安靜的暫時失敗（可重試），不是需要使用者處理的錯誤', () {
    test('拿不到靜默授權（要互動才能授權）：retryable，不丟需要重新登入的錯', () async {
      final c = containerWith(
        driveWith(
          headers: () async => throw SyncAuthUnavailableException('silent'),
        ),
      );
      await c.read(syncControllerProvider.notifier).syncNow();
      final s = c.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.retryable, isTrue);
      expect(s.needsAppUpdate, isFalse);
      expect(topToastShowing, isFalse);
    });

    test('一般授權過期仍是不可自動重試（要使用者處理）', () async {
      final c = containerWith(
        driveWith(headers: () async => throw SyncAuthException('expired')),
      );
      await c.read(syncControllerProvider.notifier).syncNow();
      final s = c.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.retryable, isFalse);
    });

    test('DNS／斷線（SocketException）：retryable', () async {
      final c = containerWith(
        driveWith(
          headers: () async => {'Authorization': 'Bearer t'},
          client: MockClient(
            (_) async => throw const SocketException('Failed host lookup'),
          ),
        ),
      );
      await c.read(syncControllerProvider.notifier).syncNow();
      final s = c.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.retryable, isTrue);
    });

    test('逾時：retryable（請求逾時，不是永遠卡住）', () async {
      final c = containerWith(
        driveWith(
          headers: () async => {'Authorization': 'Bearer t'},
          client: MockClient((_) => Completer<http.Response>().future),
        ),
      );
      await c.read(syncControllerProvider.notifier).syncNow();
      final s = c.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.retryable, isTrue);
    });
  });

  test('連續失敗的退避：15 秒、1 分、3 分、10 分、最多 30 分；成功歸零', () {
    expect(SyncDriverBackoff.of(0), Duration.zero);
    expect(SyncDriverBackoff.of(1), const Duration(seconds: 15));
    expect(SyncDriverBackoff.of(2), const Duration(seconds: 60));
    expect(SyncDriverBackoff.of(3), const Duration(seconds: 180));
    expect(SyncDriverBackoff.of(4), const Duration(minutes: 10));
    expect(SyncDriverBackoff.of(5), const Duration(minutes: 30));
    expect(SyncDriverBackoff.of(50), const Duration(minutes: 30));
  });

  testWidgets('同步失敗後主頁照常可用：沒有對話框、提示條、橫幅覆蓋層，也不擋住操作', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => db.createPit(name: '本機的坑'));
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final remote = driveWith(
      headers: () async => throw SyncAuthUnavailableException('silent'),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPrefsProvider.overrideWithValue(prefs),
        imageStoreProvider.overrideWith((ref) async => ImageStore(dir)),
        syncRemoteProvider.overrideWithValue(remote),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setAccount('me@example.com');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: const PitsPage(),
        ),
      ),
    );
    await tester.runAsync(
      () => container.read(syncControllerProvider.notifier).syncNow(),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(syncControllerProvider).phase, SyncPhase.error);
    // 沒有任何覆蓋層：對話框、提示條、MaterialBanner、BottomSheet。
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(topToastShowing, isFalse);
    // 只有頁面本身一條路由（沒有彈出別的路由）。
    expect(find.byType(ModalBarrier).evaluate().length, lessThanOrEqualTo(1));
    // 本機內容照常顯示、可以點。
    expect(find.text('本機的坑'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

/// 測試用：驅動的退避表（見 [SyncDriver.backoffFor]）。
abstract final class SyncDriverBackoff {
  static Duration of(int n) => SyncDriver.backoffFor(n);
}
