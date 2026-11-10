import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/network_kind.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';
import 'package:huakeng/ui/sync/sync_popover.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-150：使用流動數據上傳（預設關＝只在 Wi-Fi 上傳）與「等待 Wi-Fi」狀態（SyncSheetWifi）。

class _Accounts implements AccountService {
  @override
  Future<Map<String, String>> headers() async => {'Authorization': 'Bearer t'};
  @override
  Future<String?> restore() async => null;
  @override
  Future<String> signIn() async => 'molly@example.com';
  @override
  Future<void> signOut() async {}
}

class _FakeSync extends SyncController {
  int syncNowCalls = 0;
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
  @override
  Future<bool> syncNow() async {
    syncNowCalls++;
    return true;
  }
}

SyncTransfer _ul(String f, [TransferState s = TransferState.waiting]) =>
    SyncTransfer(file: f, direction: TransferDirection.upload, state: s);
SyncTransfer _dl(String f, [TransferState s = TransferState.waiting]) =>
    SyncTransfer(file: f, direction: TransferDirection.download, state: s);

SyncState _waitingWifi(List<SyncTransfer> transfers) => SyncState(
  phase: SyncPhase.idle,
  lastSyncAt: DateTime.now(),
  lastResult: SyncResult()
    ..transfers = transfers
    ..waitingWifi = true,
  waitingWifi: true,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('引擎：等 Wi-Fi', () {
    late AppDatabase db;
    late Directory dir;
    late MemoryRemote remote;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dir = await Directory.systemTemp.createTemp('wifi_up');
      remote = MemoryRemote();
      final pitId = await db.createPit(name: 'x');
      final group = (await db.watchGroups(pitId).first).first;
      for (final n in ['0.png', '1.png']) {
        File('${dir.path}/$n').writeAsBytesSync(Uint8List.fromList([1, 2]));
      }
      await db.addOfficial(pitId, group.id, [
        for (final n in ['0.png', '1.png']) NewImage(file: n),
      ]);
    });
    tearDown(() => db.close());

    SyncEngine engine({bool hold = false}) => SyncEngine(
      db: db,
      remote: remote,
      images: ImageStore(dir),
      progressInterval: Duration.zero,
      holdUploads: hold,
    );

    test('流動數據：圖片留在佇列（排隊中）、不算失敗；換 Wi-Fi 後補傳', () async {
      final seen = <SyncProgress>[];
      final r = await engine(hold: true).sync(onProgress: seen.add);
      expect(r.waitingWifi, isTrue);
      expect(r.imagesUp, 0);
      expect(r.uploadFailures, 0);
      expect(r.failedTransfers, isEmpty);
      expect(r.unuploadedCount, 2);
      expect(r.transfers.every((t) => t.isUpload && t.isWaiting), isTrue);
      expect(remote.files.keys.where((k) => k.startsWith('images__')), isEmpty);
      expect(seen.last.waitingWifi, isTrue);

      final r2 = await engine().sync();
      expect(r2.waitingWifi, isFalse);
      expect(r2.imagesUp, 2);
      expect(remote.files.containsKey('images__0.png'), isTrue);
      expect(remote.files.containsKey('images__1.png'), isTrue);
    });
  });

  group('設定', () {
    test('使用流動數據上傳：預設關，存進偏好設定', () async {
      SharedPreferences.setMockInitialValues({});
      expect(const AppSettings().uploadOnMobile, isFalse);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(settingsProvider).uploadOnMobile, isFalse);
      c.read(settingsProvider.notifier).setUploadOnMobile(true);
      expect(c.read(settingsProvider).uploadOnMobile, isTrue);
      expect(prefs.getBool('uploadOnMobile'), isTrue);
    });
  });

  testWidgets('備份頁：「使用流動數據上傳」開關（預設關、沒有小字）、「檢查同步間隔」', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'accountEmail': 'molly@example.com',
      'syncedAccount': 'molly@example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          accountServiceProvider.overrideWithValue(_Accounts()),
          syncRemoteProvider.overrideWithValue(MemoryRemote()),
          syncControllerProvider.overrideWith(_FakeSync.new),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: const Scaffold(body: BackupPage()),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('使用流動數據上傳'), findsOneWidget);
    expect(find.text('檢查同步間隔'), findsOneWidget);
    expect(find.text('前台自動刷新'), findsNothing);
    final sw = find.byKey(const Key('backup-upload-on-mobile'));
    expect(tester.widget<AppSwitch>(sw).value, isFalse);
    await tester.tap(sw);
    await tester.pump();
    expect(prefs.getBool('uploadOnMobile'), isTrue);
    expect(tester.widget<AppSwitch>(sw).value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  group('頭像小點與 sheet', () {
    late AppDatabase db;
    late Directory tmp;
    late String pitId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      navBarHiddenCount.value = 0;
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('wifi_dot');
      pitId = await db.createPit(name: '坑A', description: '描述');
    });
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<ProviderContainer> pumpApp(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${tmp.path}/images')),
            ),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            networkKindProvider.overrideWith(
              (ref) => Stream.value(NetworkKind.cellular),
            ),
            syncControllerProvider.overrideWith(_FakeSync.new),
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
      await tester.runAsync(() async {
        final groups = await db.select(db.officialGroups).get();
        await db.addOfficial(pitId, groups[0].id, [
          for (final f in ['a.png', 'b.png', 'c.png', 'd.png'])
            NewImage(file: f),
        ]);
      });
      return ProviderScope.containerOf(tester.element(find.byType(SyncRing)));
    }

    _FakeSync fake(ProviderContainer c) =>
        c.read(syncControllerProvider.notifier) as _FakeSync;

    const wifiDot = ValueKey('syncRingDot:wifi');

    final layouts = <(String, Size, bool)>[
      ('手機', const Size(390, 844), false),
      ('iPad 橫式', const Size(1194, 834), true),
    ];

    for (final (name, size, ipad) in layouts) {
      testWidgets('$name：灰色 Wi-Fi 小點→「等待 Wi-Fi」、等待上傳、同步設定→備份頁', (tester) async {
        final c = await pumpApp(tester, size);
        fake(c).set(
          _waitingWifi([
            _ul('a.png'),
            _ul('b.png'),
            _ul('c.png'),
            _ul('d.png'),
            _dl('e.png', TransferState.done),
          ]),
        );
        await tester.pump();
        expect(find.byKey(wifiDot), findsOneWidget);

        await tester.tap(find.byKey(wifiDot));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);
        expect(find.byType(ipad ? SyncPopover : SyncSheet), findsOneWidget);
        expect(find.byKey(const Key('sync-wifi-title')), findsOneWidget);
        expect(find.text('等待 Wi-Fi'), findsWidgets);
        expect(find.text('4 張待上傳'), findsOneWidget);
        expect(find.byKey(const Key('sync-waiting-wifi')), findsNWidgets(3));
        expect(find.text('還有 1 張等待上傳'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(const Key('sync-wifi-title')), findsOneWidget);

        await tester.tap(find.byKey(const Key('sync-wifi-settings-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        expect(find.byKey(const Key('sync-wifi-title')), findsNothing);
        expect(find.byType(BackupPage), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
      });
    }

    testWidgets('有失敗時琥珀點優先，不顯示 Wi-Fi 小點', (tester) async {
      final c = await pumpApp(tester, const Size(390, 844));
      fake(c).set(
        SyncState(
          phase: SyncPhase.idle,
          lastResult: SyncResult()
            ..transfers = [_ul('a.png', TransferState.failed), _ul('b.png')]
            ..waitingWifi = true,
          waitingWifi: true,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('syncRingDot:failed')), findsOneWidget);
      expect(find.byKey(wifiDot), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
