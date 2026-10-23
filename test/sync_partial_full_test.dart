import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/network_kind.dart';
import 'package:huakeng/sync/relative_time.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/storage_usage.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/me/backup_storage_card.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';
import 'package:huakeng/ui/sync/sync_popover.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:huakeng/ui/common/user_avatar.dart';
import 'package:huakeng/ui/sync/sync_time_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 批次 20 / D-109（相對時間、部分失敗、iPad 完成狀態）、批次 18 / D-103（Drive 已滿）、
/// 兩個回報的錯誤（同步完外圈不消失、立即同步停用時 icon 顏色）。

const gb = 1024 * 1024 * 1024;

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

/// 可由測試直接指定 [SyncState]，不真的同步；`syncNow` 只計次數。
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

SyncTransfer _dl(String f, [TransferState s = TransferState.waiting]) =>
    SyncTransfer(file: f, direction: TransferDirection.download, state: s);
SyncTransfer _ul(String f, [TransferState s = TransferState.waiting]) =>
    SyncTransfer(file: f, direction: TransferDirection.upload, state: s);

SyncState _syncing(List<SyncTransfer> list, {bool quotaFull = false}) =>
    SyncState(
      phase: SyncPhase.syncing,
      transfersPlanned: true,
      transfers: list,
      quotaFull: quotaFull,
    );

SyncState _finished(
  List<SyncTransfer> transfers, {
  bool quotaFull = false,
  DateTime? at,
}) => SyncState(
  phase: SyncPhase.idle,
  lastSyncAt: at ?? DateTime.now(),
  lastResult: SyncResult()
    ..transfers = transfers
    ..quotaFull = quotaFull,
  quotaFull: quotaFull,
);

/// 一台「裝置」：自己的資料庫與圖片資料夾。
class _Dev {
  _Dev(this.db, this.dir) : store = ImageStore(dir);
  final AppDatabase db;
  final Directory dir;
  final ImageStore store;

  static Future<_Dev> make() async => _Dev(
    AppDatabase(NativeDatabase.memory()),
    await Directory.systemTemp.createTemp('sync_pf'),
  );

  SyncEngine engine(SyncRemote r) => SyncEngine(
    db: db,
    remote: r,
    images: store,
    progressInterval: Duration.zero,
  );

  Future<void> addImages(List<String> names, {String pit = 'x'}) async {
    final pitId = await db.createPit(name: pit);
    final group = (await db.watchGroups(pitId).first).first;
    for (final n in names) {
      File('${dir.path}/$n').writeAsBytesSync(Uint8List.fromList([n.hashCode]));
    }
    await db.addOfficial(pitId, group.id, [
      for (final n in names) NewImage(file: n),
    ]);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('相對時間（D-109 ②）', () {
    final at = DateTime(2026, 10, 22, 22, 15, 20);

    test('1 分鐘內剛剛；1 小時內 N 分鐘前；同一天今天 HH:mm；其他日子 M/d HH:mm', () {
      String f(Duration d) => syncRelativeTime(at, at.add(d));
      expect(f(Duration.zero), '剛剛');
      expect(f(const Duration(seconds: 59)), '剛剛');
      expect(f(const Duration(seconds: -30)), '剛剛'); // 時鐘被調回去
      expect(f(const Duration(minutes: 1)), '1 分鐘前');
      expect(f(const Duration(minutes: 3, seconds: 40)), '3 分鐘前');
      expect(f(const Duration(minutes: 59, seconds: 59)), '59 分鐘前');
      expect(f(const Duration(hours: 1)), '今天 22:15');
      expect(f(const Duration(hours: 1, minutes: 30)), '今天 22:15');
      // 跨日：10/23 看 10/22 22:15
      expect(syncRelativeTime(at, DateTime(2026, 10, 23, 8)), '10/22 22:15');
      expect(
        syncRelativeTime(DateTime(2026, 3, 4, 9, 5), DateTime(2026, 10, 23)),
        '3/4 09:05',
      );
    });

    test('下一次文字改變的時間：到滿下一分鐘；滿 1 小時後不再變', () {
      expect(
        syncRelativeTimeNextChange(at, at.add(const Duration(seconds: 20))),
        const Duration(seconds: 40),
      );
      expect(syncRelativeTimeNextChange(at, at), const Duration(minutes: 1));
      expect(
        syncRelativeTimeNextChange(
          at,
          at.add(const Duration(minutes: 5, seconds: 5)),
        ),
        const Duration(seconds: 55),
      );
      expect(
        syncRelativeTimeNextChange(at, at.add(const Duration(hours: 1))),
        isNull,
      );
    });

    testWidgets('文字每分鐘更新一次；離開畫面計時器就停了', (tester) async {
      var now = DateTime(2026, 10, 22, 22, 15, 0);
      final at = now;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncClockProvider.overrideWithValue(() => now)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: SyncRelativeTimeText(at: at)),
          ),
        ),
      );
      expect(find.text('剛剛'), findsOneWidget);

      now = now.add(const Duration(seconds: 59));
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('剛剛'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1 分鐘前'), findsOneWidget);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('2 分鐘前'), findsOneWidget);

      now = at.add(const Duration(minutes: 60));
      await tester.pump(const Duration(minutes: 58));
      expect(find.text('今天 22:15'), findsOneWidget);
      // 滿 1 小時後不再排計時器。
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pumpWidget(const SizedBox());
      // 沒有殘留的計時器（testWidgets 結束時會檢查）。
    });
  });

  group('引擎：單張失敗（D-109 ③）', () {
    late _Dev a;
    late _Dev b;
    late MemoryRemote remote;

    setUp(() async {
      a = await _Dev.make();
      b = await _Dev.make();
      remote = MemoryRemote();
    });
    tearDown(() async {
      await a.db.close();
      await b.db.close();
    });

    test('上傳失敗：標成 failed、其餘照傳；失敗的那份文件留在佇列，下次同步補上', () async {
      await a.addImages(['0.png', '1.png', '2.png']);
      remote.failWith = (name, up) =>
          up && name == 'images__1.png' ? StateError('boom') : null;

      final r = await a.engine(remote).sync();
      expect(r.imageFailures, 1);
      expect(r.uploadFailures, 1);
      final failed = r.failedTransfers;
      expect(failed, hasLength(1));
      expect(failed.single.file, '1.png');
      expect(failed.single.isUpload, isTrue);
      expect(r.uploadedCount, 2);
      expect(r.transfers, hasLength(3));
      expect(remote.files.containsKey('images__0.png'), isTrue);
      expect(remote.files.containsKey('images__1.png'), isFalse);
      expect(r.quotaFull, isFalse);

      // 沒有失敗的下一次同步：失敗的補上了，不再有失敗。
      remote.failWith = null;
      final r2 = await a.engine(remote).sync();
      expect(r2.failedTransfers, isEmpty);
      expect(remote.files.containsKey('images__1.png'), isTrue);
      expect(r2.imagesUp, 1);

      // 另一台裝置拿得到全部。
      final rb = await b.engine(remote).sync();
      expect(rb.failedTransfers, isEmpty);
      for (final n in ['0.png', '1.png', '2.png']) {
        expect(File('${b.dir.path}/$n').existsSync(), isTrue);
      }
    });

    test('下載失敗：標成 failed（方向＝下載），其餘照下載；下次再試', () async {
      await a.addImages(['0.png', '1.png', '2.png']);
      await a.engine(remote).sync();

      remote.failWith = (name, up) =>
          !up && name == 'images__1.png' ? StateError('boom') : null;
      final r = await b.engine(remote).sync();
      expect(r.imageFailures, 1);
      expect(r.uploadFailures, 0);
      final failed = r.failedTransfers.single;
      expect(failed.file, '1.png');
      expect(failed.isDownload, isTrue);
      expect(r.downloadedCount, 2);
      expect(File('${b.dir.path}/1.png').existsSync(), isFalse);

      remote.failWith = null;
      final r2 = await b.engine(remote).sync();
      expect(r2.failedTransfers, isEmpty);
      expect(File('${b.dir.path}/1.png').existsSync(), isTrue);
    });

    test('連續失敗到上限（網絡或授權壞了）整次中止，仍然丟例外', () async {
      await a.addImages([for (var i = 0; i < 8; i++) '$i.png']);
      remote.failWith = (name, up) =>
          up && name.startsWith('images__') ? StateError('boom') : null;
      await expectLater(a.engine(remote).sync(), throwsA(isA<StateError>()));
    });

    test('授權過期照舊整次中止，不算單張失敗', () async {
      await a.addImages(['0.png', '1.png']);
      remote.failWith = (name, up) =>
          up && name.startsWith('images__') ? SyncAuthException() : null;
      await expectLater(
        a.engine(remote).sync(),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('進度快照：失敗的那張 state=failed，且算處理完（進度條會走滿）', () async {
      await a.addImages(['0.png', '1.png']);
      remote.failWith = (name, up) =>
          up && name == 'images__0.png' ? StateError('boom') : null;
      final seen = <SyncProgress>[];
      await a.engine(remote).sync(onProgress: seen.add);
      final last = seen.last.transfers;
      expect(last.where((t) => t.isFailed), hasLength(1));
      expect(last.every((t) => t.isSettled), isTrue);
    });
  });

  group('Drive 已滿（D-103）', () {
    late _Dev a;
    late _Dev b;
    late MemoryRemote remote;

    setUp(() async {
      a = await _Dev.make();
      b = await _Dev.make();
      remote = MemoryRemote();
    });
    tearDown(() async {
      await a.db.close();
      await b.db.close();
    });

    test('上傳留在佇列、下載照常、不丟資料、不當成失敗；有空間後自動補傳', () async {
      await a.addImages(['a0.png', 'a1.png'], pit: '坑A');
      await a.engine(remote).sync(); // A 先傳上去（那時還沒滿）
      final remoteBefore = remote.files.keys.toSet();

      await b.addImages(['b0.png', 'b1.png', 'b2.png'], pit: '坑B');
      remote.storageFull = true;
      final attemptsBefore = remote.uploadAttempts;
      final r = await b.engine(remote).sync();

      expect(r.quotaFull, isTrue);
      expect(r.failedTransfers, isEmpty); // 不是失敗
      expect(r.imageFailures, 0);
      expect(r.unuploadedCount, 3);
      expect(r.uploadedCount, 0);
      // 第一次上傳被拒絕就不再試其他的（不要對滿的 Drive 連打）。
      expect(remote.uploadAttempts - attemptsBefore, lessThanOrEqualTo(3));
      // 下載照常：A 的圖與坑都到了 B。
      expect(r.downloadedCount, 2);
      for (final n in ['a0.png', 'a1.png']) {
        expect(File('${b.dir.path}/$n').existsSync(), isTrue);
      }
      expect(
        (await b.db.select(b.db.pits).get()).map((p) => p.name),
        contains('坑A'),
      );
      // 遠端沒有多東西；本機資料還在。
      expect(remote.files.keys.toSet(), remoteBefore);
      for (final n in ['b0.png', 'b1.png', 'b2.png']) {
        expect(File('${b.dir.path}/$n').existsSync(), isTrue);
      }
      expect(
        (await b.db.select(b.db.pits).get()).map((p) => p.name),
        contains('坑B'),
      );

      // 「立即同步」再按一次：仍然滿，不報錯、仍排隊。
      final r2 = await b.engine(remote).sync();
      expect(r2.quotaFull, isTrue);
      expect(r2.unuploadedCount, 3);

      // 有空間了：下一次同步自動補傳，什麼都不用做。
      remote.storageFull = false;
      final r3 = await b.engine(remote).sync();
      expect(r3.quotaFull, isFalse);
      expect(r3.unuploadedCount, 0);
      expect(r3.imagesUp, 3);
      for (final n in ['b0.png', 'b1.png', 'b2.png']) {
        expect(remote.files.containsKey('images__$n'), isTrue);
      }
      // 另一台（A）拿得到 B 的東西。
      await a.engine(remote).sync();
      expect(File('${a.dir.path}/b2.png').existsSync(), isTrue);
    });

    test('只有文字文件要上傳時遇到已滿：文件留在佇列，不報錯', () async {
      await a.db.createPit(name: '只有文字');
      remote.storageFull = true;
      final r = await a.engine(remote).sync();
      expect(r.quotaFull, isTrue);
      expect(r.pushed, 0);
      expect(r.failedTransfers, isEmpty);
      remote.storageFull = false;
      final r2 = await a.engine(remote).sync();
      expect(r2.quotaFull, isFalse);
      expect(r2.pushed, greaterThan(0));
    });
  });

  group('DriveRemote：403 storageQuotaExceeded', () {
    DriveRemote make(MockClient c) => DriveRemote(
      headers: () async => {'Authorization': 'Bearer t'},
      client: c,
      retryDelay: Duration.zero,
    );
    String body(String reason) => jsonEncode({
      'error': {
        'code': 403,
        'message': 'The user\'s Drive storage quota has been exceeded.',
        'errors': [
          {'reason': reason, 'domain': 'usageLimits'},
        ],
      },
    });

    test('isStorageQuotaError：看 errors[].reason；壞 JSON 退回字串比對', () {
      expect(
        DriveRemote.isStorageQuotaError(body('storageQuotaExceeded')),
        isTrue,
      );
      expect(
        DriveRemote.isStorageQuotaError(body('rateLimitExceeded')),
        isFalse,
      );
      expect(
        DriveRemote.isStorageQuotaError(body('userRateLimitExceeded')),
        isFalse,
      );
      expect(
        DriveRemote.isStorageQuotaError('oops storageQuotaExceeded'),
        isTrue,
      );
      expect(DriveRemote.isStorageQuotaError('{}'), isFalse);
    });

    test(
      '上傳回 403 storageQuotaExceeded → SyncStorageFullException，不重試',
      () async {
        var calls = 0;
        final remote = make(
          MockClient((req) async {
            calls++;
            return http.Response(body('storageQuotaExceeded'), 403);
          }),
        );
        await expectLater(
          remote.upload('images__x.png', Uint8List.fromList([1, 2, 3])),
          throwsA(isA<SyncStorageFullException>()),
        );
        expect(calls, 1);
      },
    );

    test('限流的 403 仍照舊重試（不當成已滿）', () async {
      var calls = 0;
      final remote = make(
        MockClient((req) async {
          calls++;
          return http.Response(body('rateLimitExceeded'), 403);
        }),
      );
      // 新檔案上傳不自動重試；用 about（會重試）驗證限流分類沒被影響。
      await expectLater(
        remote.storageQuota(),
        throwsA(isA<SyncNetworkException>()),
      );
      expect(calls, greaterThan(1));
    });
  });

  group('SyncController：Drive 已滿與部分失敗', () {
    late _Dev dev;
    late MemoryRemote remote;
    late ProviderContainer container;

    setUp(() async {
      dev = await _Dev.make();
      remote = MemoryRemote();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(dev.db),
          imageStoreProvider.overrideWith((ref) async => dev.store),
          syncRemoteProvider.overrideWithValue(remote),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      container.read(settingsProvider.notifier).setAccount('me@example.com');
    });
    tearDown(() async {
      container.dispose();
      await dev.db.close();
    });

    SyncState state() => container.read(syncControllerProvider);
    Future<void> sync() =>
        container.read(syncControllerProvider.notifier).syncNow();

    test('Drive 已滿：同步照常結束（idle、沒有錯誤訊息），quotaFull＋未上傳張數；有空間後清掉', () async {
      await dev.addImages(['0.png', '1.png']);
      remote.storageFull = true;
      final seen = <SyncState>[];
      container.listen(syncControllerProvider, (_, s) => seen.add(s));
      await sync();
      expect(state().phase, SyncPhase.idle);
      expect(state().message, isNull);
      expect(state().quotaFull, isTrue);
      expect(state().unuploadedCount, 2);
      expect(state().hasFailures, isFalse);
      expect(container.read(driveFullProvider), isTrue);
      // 被拒絕之後、同步結束之前，同步中的狀態就已經帶 quotaFull（排隊的行寫「等待空間」）。
      expect(seen.where((s) => s.isSyncing && s.quotaFull), isNotEmpty);

      // 下一次同步開始時沿用上一次的 quotaFull（排隊的行一開始就寫「等待空間」）。
      remote.storageFull = false;
      final seen2 = <SyncState>[];
      container.listen(syncControllerProvider, (_, s) => seen2.add(s));
      await sync();
      expect(seen2.first.isSyncing && seen2.first.quotaFull, isTrue);
      expect(state().quotaFull, isFalse);
      expect(state().unuploadedCount, 0);
      expect(container.read(driveFullProvider), isFalse);
    });

    test('部分失敗：同步完成（idle），失敗的列在 lastResult，全部成功後清掉', () async {
      await dev.addImages(['0.png', '1.png', '2.png']);
      remote.failWith = (name, up) =>
          up && name == 'images__2.png' ? StateError('boom') : null;
      await sync();
      expect(state().phase, SyncPhase.idle);
      expect(state().hasFailures, isTrue);
      expect(state().failedCount, 1);
      expect(state().lastResult!.failedTransfers.single.file, '2.png');
      expect(state().lastResult!.transfers, hasLength(3));
      expect(state().unuploadedCount, 1);

      remote.failWith = null;
      await sync();
      expect(state().hasFailures, isFalse);
      expect(state().failedCount, 0);
    });

    test('整次失敗（網絡錯誤）時沿用上一次的失敗張數與已滿旗標', () async {
      await dev.addImages(['0.png', '1.png']);
      remote.failWith = (name, up) =>
          up && name == 'images__1.png' ? StateError('boom') : null;
      await sync();
      expect(state().failedCount, 1);
      remote.failWith = (name, up) => SyncAuthException();
      await sync();
      expect(state().phase, SyncPhase.error);
      expect(state().failedCount, 1); // 沒完成的同步不洗掉上次的結果
    });
  });

  group('畫面', () {
    late AppDatabase db;
    late Directory tmp;
    late String pitId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      navBarHiddenCount.value = 0;
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('sync_pf_ui');
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

    Future<ProviderContainer> pumpApp(
      WidgetTester tester,
      double w,
      double h, {
      List<Override> extra = const [],
    }) async {
      tester.view.physicalSize = Size(w, h);
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
              (ref) => Stream.value(NetworkKind.wifi),
            ),
            syncControllerProvider.overrideWith(_FakeSync.new),
            ...extra,
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(SyncRing)));
    }

    _FakeSync fake(ProviderContainer c) =>
        c.read(syncControllerProvider.notifier) as _FakeSync;

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    SyncRing ring(WidgetTester tester) =>
        tester.widget<SyncRing>(find.byType(SyncRing));

    Future<void> addImages(WidgetTester tester, List<String> files) =>
        tester.runAsync(() async {
          final groups = await db.select(db.officialGroups).get();
          await db.addOfficial(pitId, groups[0].id, [
            for (final f in files) NewImage(file: f),
          ]);
        });

    // (闊, 高)：手機、iPad 直式（rail）、iPad 橫式（sidebar）
    final layouts = <(double, double)>[(390, 844), (834, 1194), (1194, 834)];

    for (final (w, h) in layouts) {
      group('$w×$h', () {
        testWidgets('錯誤修正：全部傳完、同步還在收尾時外圈就收掉；同步結束外圈不再回來', (tester) async {
          final c = await pumpApp(tester, w, h);
          expect(ring(tester).mode, SyncRingMode.none);

          fake(
            c,
          ).set(_syncing([_dl('a.png', TransferState.active), _dl('b.png')]));
          await tester.pump();
          expect(ring(tester).mode, SyncRingMode.transferring);

          // 全部傳完（含失敗的也算處理完），但同步還在補縮圖等收尾工作：外圈不能一直停在滿圈。
          fake(c).set(
            _syncing([
              _dl('a.png', TransferState.done),
              _ul('b.png', TransferState.failed),
            ]),
          );
          await tester.pump();
          expect(ring(tester).mode, SyncRingMode.none);
          await tester.pump(const Duration(milliseconds: 400));
          final fade = tester.widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(SyncRing),
              matching: find.byType(AnimatedOpacity),
            ),
          );
          expect(fade.opacity, 0);
          // 收尾期間沒有可以點開的同步 sheet／popover。
          await tester.tap(find.byType(SyncRing));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(SyncSheet), findsNothing);
          expect(find.byType(SyncPopover), findsNothing);

          // 同步結束：外圈維持沒有；沒有失敗時也沒有小點。
          fake(c).set(_finished([_dl('a.png', TransferState.done)]));
          await tester.pump(const Duration(milliseconds: 400));
          expect(ring(tester).mode, SyncRingMode.none);
          expect(ring(tester).dot, SyncRingDot.none);
          expect(
            find.byKey(const ValueKey('syncRingDot:failed')),
            findsNothing,
          );
          await unmount(tester);
        });

        testWidgets('頭像小點：有失敗＝琥珀；Drive 已滿＝紅（優先）；同步中不畫；全部成功後消失', (tester) async {
          final c = await pumpApp(tester, w, h);
          fake(c).set(_finished([_dl('a.png', TransferState.failed)]));
          await tester.pump();
          expect(ring(tester).dot, SyncRingDot.failed);
          expect(
            find.byKey(const ValueKey('syncRingDot:failed')),
            findsOneWidget,
          );
          final dot = tester.widget<Container>(
            find.byKey(const ValueKey('syncRingDot:failed')),
          );
          expect(
            (dot.decoration as BoxDecoration).color,
            const Color(0xFFD9A23C),
          );

          fake(c).set(
            _finished([_ul('a.png', TransferState.waiting)], quotaFull: true),
          );
          await tester.pump();
          expect(ring(tester).dot, SyncRingDot.full);
          final red = tester.widget<Container>(
            find.byKey(const ValueKey('syncRingDot:full')),
          );
          expect(
            (red.decoration as BoxDecoration).color,
            const Color(0xFFC0392B),
          );

          // 同步中：外圈在轉，小點先收起來。
          fake(c)
              .set(const SyncState(phase: SyncPhase.syncing, quotaFull: true));
          await tester.pump();
          expect(ring(tester).dot, SyncRingDot.none);

          fake(c).set(_finished([_dl('a.png', TransferState.done)]));
          await tester.pump();
          expect(ring(tester).dot, SyncRingDot.none);
          await unmount(tester);
        });

        testWidgets('部分失敗：傳完變「同步完成，N 張失敗」，列出失敗的、重試只重跑一次同步、完成才關', (
          tester,
        ) async {
          await addImages(tester, ['u0.png', 'd1.png', 'd2.png']);
          final c = await pumpApp(tester, w, h);
          fake(c).set(
            _syncing([
              _ul('u0.png', TransferState.active),
              _dl('d1.png'),
              _dl('d2.png'),
            ]),
          );
          await tester.pump();
          await tester.tap(find.byType(SyncRing));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await settle(tester);
          expect(find.text('同步中'), findsOneWidget);

          fake(c).set(
            _finished([
              _ul('u0.png', TransferState.failed),
              _dl('d1.png', TransferState.done),
              _dl('d2.png', TransferState.failed),
              for (var i = 0; i < 5; i++) _dl('x$i.png', TransferState.done),
            ]),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await settle(tester);

          expect(find.text('同步完成，2 張失敗'), findsOneWidget);
          expect(find.text('6 / 8'), findsOneWidget); // 成功 / 總數
          expect(find.text('上傳 0 張'), findsOneWidget);
          expect(find.text('下載 6 張'), findsOneWidget);
          expect(find.text('剛剛'), findsOneWidget);
          // 琥珀「!」圓。
          final mark = tester.widget<Container>(
            find.byKey(const Key('sync-partial-mark')),
          );
          expect(
            (mark.decoration as BoxDecoration).color,
            const Color(0xFFD9A23C),
          );
          expect(find.text('!'), findsOneWidget);
          // 進度條：綠色成功段占 6/8。
          final bar = tester.getSize(find.byKey(const Key('sync-partial-bar')));
          final ok = tester.getSize(
            find.byKey(const Key('sync-partial-bar-ok')),
          );
          expect(ok.width / bar.width, closeTo(6 / 8, 0.001));
          // 失敗的每一張：標籤、位置、琥珀「失敗」。
          expect(find.text('失敗'), findsNWidgets(2));
          expect(find.text('坑A · 官方圖冊'), findsNWidgets(2));
          expect(find.text('上傳'), findsOneWidget);
          expect(find.text('下載'), findsOneWidget);
          expect(find.text('同步中'), findsNothing);
          expect(find.text('重試'), findsOneWidget);
          expect(find.text('完成'), findsOneWidget);

          // 重試：只觸發一次同步（成功的早就同步完了，剩下的就是失敗的）。
          await tester.tap(find.byKey(const Key('sync-retry-button')));
          await tester.pump();
          expect(fake(c).syncNowCalls, 1);

          // 重試中（同步進行中）：重試鈕停用。
          fake(c).set(const SyncState(phase: SyncPhase.syncing));
          await tester.pump();
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const Key('sync-retry-button')),
                )
                .onPressed,
            isNull,
          );
          // 重試也有傳輸時：切回同步中（只有失敗的那兩張）。
          fake(
            c,
          ).set(_syncing([_ul('u0.png', TransferState.active), _dl('d2.png')]));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('同步中'), findsOneWidget);
          expect(find.text('0 / 2'), findsOneWidget);
          // 重試全成功：變成完成狀態。
          fake(c).set(
            _finished([
              _ul('u0.png', TransferState.done),
              _dl('d2.png', TransferState.done),
            ]),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('同步完成'), findsOneWidget);
          expect(find.text('2 / 2'), findsOneWidget);
          expect(find.text('重試'), findsNothing);

          await tester.tap(find.byKey(const Key('sync-done-button')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(SyncSheet), findsNothing);
          expect(find.byType(SyncPopover), findsNothing);
          await unmount(tester);
        });

        testWidgets('部分失敗：太多只列前 4 張＋「還有 N 張失敗」；「完成」關閉', (tester) async {
          await addImages(tester, [for (var i = 0; i < 6; i++) 'f$i.png']);
          final c = await pumpApp(tester, w, h);
          fake(c).set(_syncing([_dl('f0.png', TransferState.active)]));
          await tester.pump();
          await tester.tap(find.byType(SyncRing));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await settle(tester);

          fake(c).set(
            _finished([
              for (var i = 0; i < 6; i++) _dl('f$i.png', TransferState.failed),
              _dl('ok.png', TransferState.done),
            ]),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await settle(tester);
          expect(find.text('同步完成，6 張失敗'), findsOneWidget);
          expect(find.text('1 / 7'), findsOneWidget);
          expect(find.text('失敗'), findsNWidgets(4));
          expect(find.text('還有 2 張失敗'), findsOneWidget);

          await tester.tap(find.byKey(const Key('sync-done-button')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(SyncSheet), findsNothing);
          expect(find.byType(SyncPopover), findsNothing);
          // 關掉之後頭像是琥珀小點（失敗的還在佇列）。
          expect(ring(tester).dot, SyncRingDot.failed);
          await unmount(tester);
        });

        testWidgets('Drive 已滿：排隊中的上傳寫灰字「等待空間」，下載仍寫「等待中」', (tester) async {
          await addImages(tester, ['u0.png', 'u1.png', 'd1.png']);
          final c = await pumpApp(tester, w, h);
          fake(c).set(
            _syncing([
              _ul('u0.png', TransferState.active),
              _ul('u1.png'),
              _dl('d1.png'),
            ], quotaFull: true),
          );
          await tester.pump();
          await tester.tap(find.byType(SyncRing));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await settle(tester);
          expect(find.byKey(const Key('sync-waiting-space')), findsOneWidget);
          expect(find.text('等待空間'), findsOneWidget);
          expect(find.text('等待中'), findsOneWidget);

          // 沒滿時一律「等待中」。
          fake(c).set(
            _syncing([
              _ul('u0.png', TransferState.active),
              _ul('u1.png'),
              _dl('d1.png'),
            ]),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('等待空間'), findsNothing);
          expect(find.text('等待中'), findsNWidgets(2));
          await unmount(tester);
        });
      });
    }

    testWidgets('iPad popover：部分失敗狀態（沿用手機內容）；重試、完成', (tester) async {
      await addImages(tester, ['u0.png']);
      final c = await pumpApp(tester, 834, 1194);
      fake(c)
          .set(_syncing([_ul('u0.png', TransferState.active), _dl('d.png')]));
      await tester.pump();
      await tester.tap(find.byType(SyncRing));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPopover), findsOneWidget);
      expect(find.text('同步設定'), findsOneWidget);

      fake(c).set(
        _finished([
          _ul('u0.png', TransferState.failed),
          _dl('d.png', TransferState.done),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPopover), findsOneWidget);
      expect(find.text('同步完成，1 張失敗'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('失敗'), findsOneWidget);
      expect(find.text('同步設定'), findsNothing);
      // 寬度仍是 popover 的 400。
      expect(tester.getRect(find.byKey(SyncPopover.cardKey)).width, 400);

      await tester.tap(find.byKey(const Key('sync-retry-button')));
      await tester.pump();
      expect(fake(c).syncNowCalls, 1);
      await tester.tap(find.byKey(const Key('sync-done-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SyncPopover), findsNothing);
      await unmount(tester);
    });

    // P-034：SyncPopoverDone／Partial／Full 的尺寸。
    Future<ProviderContainer> openPopover(WidgetTester tester) async {
      await addImages(tester, ['u0.png']);
      final c = await pumpApp(tester, 1194, 834);
      fake(c)
          .set(_syncing([_ul('u0.png', TransferState.active), _dl('d.png')]));
      await tester.pump();
      await tester.tap(find.byType(SyncRing));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPopover), findsOneWidget);
      return c;
    }

    testWidgets(
      'iPad SyncPopoverDone：綠勾、全滿綠條、張數與時間、46 高「完成」，沒有設定連結；頭像沒有外圈與小點',
      (tester) async {
        final c = await openPopover(tester);
        fake(c).set(
          _finished([
            _ul('u0.png', TransferState.done),
            _dl('d.png', TransferState.done),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SyncPopover), findsOneWidget); // 不自動關
        expect(find.text('同步完成'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
        expect(find.text('上傳 1 張'), findsOneWidget);
        expect(find.text('下載 1 張'), findsOneWidget);
        expect(find.text('剛剛'), findsOneWidget);
        expect(find.text('同步設定'), findsNothing);
        expect(find.text('Wi-Fi'), findsNothing);
        final bar = tester.getRect(find.byKey(const Key('sync-done-bar')));
        expect(bar.height, 6);
        expect(bar.width, 400 - 40); // 卡片 400、左右 padding 20：滿版
        final btn = tester.getRect(find.byKey(const Key('sync-done-button')));
        expect(btn.height, 46);
        // 完成鈕與卡片底相距 16（padding bottom）；與上方計數列相距 18。
        final card = tester.getRect(find.byKey(SyncPopover.cardKey));
        expect(card.bottom - btn.bottom, 16);
        expect(ring(tester).mode, SyncRingMode.none);
        expect(ring(tester).dot, SyncRingDot.none);
        await tester.tap(find.byKey(const Key('sync-done-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SyncPopover), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets(
      'iPad SyncPopoverPartial：失敗列的標籤沒有箭頭 icon、按鈕 46 高；關掉後頭像右下是 13px 琥珀點',
      (tester) async {
        final c = await openPopover(tester);
        fake(c).set(
          _finished([
            _ul('u0.png', TransferState.failed),
            _dl('d.png', TransferState.done),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('同步完成，1 張失敗'), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        // 標籤（上傳）只有字。
        final tag = find.byType(SyncDirectionTag);
        expect(tag, findsOneWidget);
        expect(
          find.descendant(of: tag, matching: find.byType(SvgPicture)),
          findsNothing,
        );
        expect(
          tester.getSize(find.byKey(const Key('sync-retry-button'))).height,
          46,
        );
        expect(
          tester.getSize(find.byKey(const Key('sync-done-button'))).height,
          46,
        );
        await tester.tap(find.byKey(const Key('sync-done-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        // 頭像小點：13px、貼著頭像（40px）的右下角。
        final dot = tester.getRect(
          find.byKey(const ValueKey('syncRingDot:failed')),
        );
        expect(dot.size, const Size(13, 13));
        final avatar = tester.getRect(find.byType(UserAvatar));
        expect(avatar.right - dot.right, closeTo(0, 0.5));
        expect(avatar.bottom - dot.bottom, closeTo(1, 0.5));
        await unmount(tester);
      },
    );

    testWidgets(
      'iPad SyncPopoverFull：只剩等空間的上傳＝沒有張數列／設定連結、列沒有進度條、灰字「等待空間」、底下「還有 N 張等待空間」；紅點',
      (tester) async {
        final c = await openPopover(tester);
        fake(c).set(
          _syncing([
            for (var i = 0; i < 5; i++) _ul('u$i.png'),
          ], quotaFull: true),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('同步中'), findsOneWidget);
        expect(find.text('上傳 5 張'), findsNothing);
        expect(find.text('同步設定'), findsNothing);
        expect(find.byKey(const Key('sync-waiting-space')), findsNWidgets(3));
        expect(
          find.byType(LinearProgressIndicator),
          findsOneWidget,
        ); // 只有頂端總進度條
        expect(find.text('還有 2 張等待空間'), findsOneWidget);
        expect(find.bySemanticsLabel('同步中，Drive 已滿'), findsWidgets);
        final label = tester.widget<Text>(
          find.byKey(const Key('sync-waiting-space')).first,
        );
        expect(label.style!.color, const Color(0xFFA49A8C));
        expect(label.style!.fontWeight, FontWeight.w600);
        await unmount(tester);
      },
    );

    testWidgets('iPad Drive 已滿但還有下載在跑：維持一般版面（張數列、同步設定）', (tester) async {
      final c = await openPopover(tester);
      fake(c).set(
        _syncing([
          _ul('u0.png'),
          _dl('d.png', TransferState.active),
        ], quotaFull: true),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('同步設定'), findsOneWidget);
      expect(find.text('上傳 1 張'), findsOneWidget);
      expect(find.text('等待空間'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('備份與同步頁', () {
    late AppDatabase db;
    late MemoryRemote remote;
    var opened = 0;

    setUp(() {
      navBarHiddenCount.value = 0;
      db = AppDatabase(NativeDatabase.memory());
      remote = MemoryRemote();
      opened = 0;
    });
    tearDown(() => db.close());

    Future<ProviderContainer> pumpPage(
      WidgetTester tester, {
      bool dark = false,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'accountEmail': 'molly@example.com',
        'syncedAccount': 'molly@example.com',
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPrefsProvider.overrideWithValue(prefs),
            accountServiceProvider.overrideWithValue(_Accounts()),
            syncRemoteProvider.overrideWithValue(remote),
            syncControllerProvider.overrideWith(_FakeSync.new),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            openGoogleStorageProvider.overrideWithValue(() async => opened++),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(
              dark ? Brightness.dark : Brightness.light,
              useGoogleFonts: false,
            ),
            home: const Scaffold(body: BackupPage()),
          ),
        ),
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(BackupPage)),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      return c;
    }

    _FakeSync fake(ProviderContainer c) =>
        c.read(syncControllerProvider.notifier) as _FakeSync;

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    /// 「立即同步」icon 的顏色與文字顏色。
    (Color?, Color?) syncNowColors(WidgetTester tester) {
      final button = find.widgetWithText(FilledButton, '立即同步');
      final svg = tester.widget<SvgPicture>(
        find.descendant(of: button, matching: find.byType(SvgPicture)),
      );
      final loader = svg.bytesLoader as SvgStringLoader;
      final label = DefaultTextStyle.of(tester.element(find.text('立即同步')))
          .style;
      return (loader.theme?.currentColor, label.color);
    }

    for (final dark in [false, true]) {
      testWidgets('錯誤修正：「立即同步」icon 和文字同色（${dark ? '深色' : '淺色'}；可按與同步中停用）', (
        tester,
      ) async {
        final c = await pumpPage(tester, dark: dark);
        final (icon, label) = syncNowColors(tester);
        expect(icon, isNotNull);
        expect(icon, label);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '立即同步'))
              .onPressed,
          isNotNull,
        );

        // 同步中（停用）：icon 和文字是同一個灰，不再是白。
        fake(c).set(const SyncState(phase: SyncPhase.syncing));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500)); // 文字顏色有過場動畫
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '立即同步'))
              .onPressed,
          isNull,
        );
        final (icon2, label2) = syncNowColors(tester);
        expect(icon2, isNotNull);
        expect(icon2, label2);
        expect(icon2, isNot(Colors.white));
        await unmount(tester);
      });
    }

    testWidgets('Drive 已滿（BackupFull）：紅框卡、N 張未上傳、管理連結、自動同步小字變紅', (
      tester,
    ) async {
      remote.quota = const StorageQuota(usage: 15 * gb, limit: 15 * gb);
      await db
          .into(db.remoteFileSizes)
          .insert(
            RemoteFileSizesCompanion.insert(
              name: 'images__x',
              size: (1.8 * gb).round(),
            ),
          );
      final c = await pumpPage(tester);
      // 正常時：藍色卡、一般小字。
      expect(find.text('儲存空間'), findsNothing); // 用量 = 上限 → 已滿
      expect(find.text('Drive 已滿'), findsOneWidget);

      fake(c).set(
        _finished([
          for (var i = 0; i < 12; i++) _ul('u$i.png', TransferState.waiting),
          _dl('d.png', TransferState.done),
        ], quotaFull: true),
      );
      await tester.pump();
      expect(find.text('Drive 已滿'), findsOneWidget);
      expect(find.text('15 GB / 15 GB', findRichText: true), findsOneWidget);
      expect(find.text('12 張未上傳', findRichText: true), findsOneWidget);
      expect(find.text('管理 Google 儲存空間'), findsOneWidget);
      expect(find.text('上傳暫停　下載正常'), findsOneWidget);
      expect(find.textContaining('上次備份'), findsNothing);

      // 紅字。
      final title = tester.widget<Text>(find.text('Drive 已滿'));
      expect(title.style!.color, const Color(0xFFC0392B));
      final sub = tester.widget<Text>(find.text('上傳暫停　下載正常'));
      expect(sub.style!.color, const Color(0xFFC0392B));
      // 紅框 1.5。
      final panel = tester
          .widgetList<Container>(find.byType(Container))
          .map((e) => e.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) =>
                d.border is Border &&
                (d.border as Border).top.width == 1.5 &&
                (d.border as Border).top.color == const Color(0xFFE7B9AE),
          )
          .toList();
      expect(panel, hasLength(1));
      // 進度條：畫匣段紅、其他段淺紅。
      final drawerBar = tester.widget<Container>(
        find.byKey(const ValueKey('storageBarDrawer')),
      );
      expect(drawerBar.color, const Color(0xFFC0392B));
      final otherBar = tester.widget<Container>(
        find.byKey(const ValueKey('storageBarOther')),
      );
      expect(otherBar.color, const Color(0xFFE7B9AE));

      // 管理連結開瀏覽器。
      await tester.tap(find.byKey(const Key('drive-full-manage')));
      await tester.pump();
      expect(opened, 1);
      expect(googleStorageUri.toString(), 'https://one.google.com/storage');
      await unmount(tester);
    });

    testWidgets('沒滿：卡片、小字維持原樣；有空間後（旗標清掉）恢復', (tester) async {
      remote.quota = const StorageQuota(usage: 8 * gb, limit: 15 * gb);
      final c = await pumpPage(tester);
      expect(find.text('儲存空間'), findsOneWidget);
      expect(find.text('Drive 已滿'), findsNothing);
      expect(find.textContaining('上次備份'), findsOneWidget);
      expect(find.text('上傳暫停　下載正常'), findsNothing);
      expect(find.text('管理 Google 儲存空間'), findsNothing);

      fake(
        c,
      ).set(_finished([_ul('a.png', TransferState.waiting)], quotaFull: true));
      await tester.pump();
      expect(find.text('Drive 已滿'), findsOneWidget);
      expect(find.text('1 張未上傳', findRichText: true), findsOneWidget);

      fake(c).set(_finished([_ul('a.png', TransferState.done)]));
      await tester.pump();
      expect(find.text('儲存空間'), findsOneWidget);
      expect(find.text('Drive 已滿'), findsNothing);
      expect(find.textContaining('上次備份'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('讀不到用量但上傳被拒絕：卡片只有標題與下方一行', (tester) async {
      remote.quotaError = StateError('offline');
      final c = await pumpPage(tester);
      expect(find.text('Drive 已滿'), findsNothing);
      fake(
        c,
      ).set(_finished([_ul('a.png', TransferState.waiting)], quotaFull: true));
      await tester.pump();
      expect(find.text('Drive 已滿'), findsOneWidget);
      expect(find.text('1 張未上傳', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('storageBar')), findsNothing);
      await unmount(tester);
    });
  });

  test('json 解碼 helper 不影響：403 body 帶中文也能解析', () {
    expect(
      DriveRemote.isStorageQuotaError(
        jsonEncode({
          'error': {
            'message': '雲端硬碟儲存空間已滿',
            'errors': [
              {'reason': 'storageQuotaExceeded'},
            ],
          },
        }),
      ),
      isTrue,
    );
  });
}
