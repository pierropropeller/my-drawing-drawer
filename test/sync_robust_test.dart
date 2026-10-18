import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/network_kind.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_driver.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/login/sync_first_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假的 Drive 後端（只實作 appDataFolder 的 files.list 與 alt=media 下載），
/// 可注入：分頁、請求 hang、回應內容串流 hang、401、5xx。
class FakeDrive {
  FakeDrive({this.pageSize = 2});
  final Map<String, Uint8List> files = {};
  int pageSize;

  /// 這些回呼回傳 true＝這個請求要 hang（永遠不回應）。
  bool Function(Uri uri, int attempt)? hangRequest;

  /// 下載這個檔名時回應頭正常、內容串流送一段後卡住。
  Set<String> stallBodyOf = {};

  /// 回傳非 null＝直接以這個狀態碼回應。
  int? Function(Uri uri, int attempt)? forceStatus;

  final requests = <Uri>[];
  final listPages = <int>[];
  int _n = 0;

  List<String> get _names => files.keys.toList();
  String _idOf(String name) => 'id:$name';

  late final http.Client client = MockClient.streaming((req, body) async {
    final attempt = ++_n;
    final uri = req.url;
    requests.add(uri);
    if (hangRequest?.call(uri, attempt) == true) {
      await Completer<void>().future; // 永遠不回應
    }
    final status = forceStatus?.call(uri, attempt);
    if (status != null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"error":"forced $status"}')),
        status,
      );
    }
    final isMedia = uri.queryParameters['alt'] == 'media';
    if (isMedia) {
      final id = uri.pathSegments.last;
      final name = id.substring('id:'.length);
      final bytes = files[name];
      if (bytes == null) return http.StreamedResponse(Stream.value([]), 404);
      if (stallBodyOf.contains(name)) {
        final c = StreamController<List<int>>();
        c.add(bytes.sublist(0, bytes.length ~/ 2));
        return http.StreamedResponse(c.stream, 200);
      }
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
      );
    }
    // files.list
    expect(uri.queryParameters['spaces'], 'appDataFolder');
    expect(uri.queryParameters['fields'], contains('nextPageToken'));
    final start = int.tryParse(uri.queryParameters['pageToken'] ?? '') ?? 0;
    listPages.add(start);
    final names = _names;
    final end = (start + pageSize).clamp(0, names.length);
    final page = [
      for (final n in names.sublist(start, end))
        {'id': _idOf(n), 'name': n, 'modifiedTime': '2026-01-01T00:00:00Z'},
    ];
    final json = jsonEncode({
      'files': page,
      if (end < names.length) 'nextPageToken': '$end',
    });
    return http.StreamedResponse(Stream.value(utf8.encode(json)), 200);
  });
}

DriveRemote driveOver(
  FakeDrive d, {
  Future<void> Function()? refreshAuth,
  Future<Map<String, String>> Function()? headers,
}) => DriveRemote(
  headers: headers ?? () async => {'Authorization': 'Bearer t'},
  client: d.client,
  refreshAuth: refreshAuth,
  requestTimeout: const Duration(milliseconds: 150),
  idleTimeout: const Duration(milliseconds: 150),
  uploadTimeout: const Duration(milliseconds: 300),
  headersTimeout: const Duration(milliseconds: 150),
  retryDelay: const Duration(milliseconds: 5),
);

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

/// 一個遞進式的遠端：list 永遠不回（模擬卡住的 Future 鏈）。
class _HangRemote implements SyncRemote {
  @override
  Future<List<RemoteFile>> list() => Completer<List<RemoteFile>>().future;
  @override
  Future<Uint8List?> download(String name, {TransferProgress? onProgress}) =>
      Completer<Uint8List?>().future;
  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) => Completer<String>().future;
}

class _SwitchRemote implements SyncRemote {
  _SwitchRemote(this.current);
  SyncRemote current;
  @override
  Future<List<RemoteFile>> list() => current.list();
  @override
  Future<Uint8List?> download(String name, {TransferProgress? onProgress}) =>
      current.download(name, onProgress: onProgress);
  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) => current.upload(
    name,
    bytes,
    contentType: contentType,
    onProgress: onProgress,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('DriveRemote：逾時、重試、分頁、401', () {
    test('files.list 跟著 nextPageToken 取完所有分頁（第二頁以後才有圖片）', () async {
      final d = FakeDrive(pageSize: 2);
      for (final n in [
        'meta__pits__a.json',
        'meta__pits__b.json',
        'meta__official__c.json',
        'images__1.png',
        'images__2.png',
      ]) {
        d.files[n] = _b(n);
      }
      final list = await driveOver(d).list();
      expect(list.map((f) => f.name), d.files.keys);
      expect(d.listPages, [0, 2, 4]);
      expect(list.where((f) => f.name.startsWith('images__')), hasLength(2));
    });

    test('請求 hang 住：逾時後重試成功', () async {
      final d = FakeDrive();
      d.files['x.json'] = _b('{}');
      d.hangRequest = (_, attempt) => attempt == 1; // 只有第一次 hang
      final list = await driveOver(d).list();
      expect(list, hasLength(1));
      expect(d.requests.length, 2);
    });

    test('請求一直 hang：不會無限等，重試用盡後丟 SyncNetworkException', () async {
      final d = FakeDrive();
      d.hangRequest = (_, _) => true;
      await expectLater(
        driveOver(d).list().timeout(const Duration(seconds: 5)),
        throwsA(isA<SyncNetworkException>()),
      );
      expect(d.requests.length, 3); // maxAttempts
    });

    test('下載回應內容串流中途卡住：閒置逾時後報錯', () async {
      final d = FakeDrive();
      d.files['images__a.png'] = Uint8List(1000);
      d.stallBodyOf = {'images__a.png'};
      final r = driveOver(d);
      await r.list();
      await expectLater(
        r.download('images__a.png').timeout(const Duration(seconds: 5)),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('503 暫時性錯誤重試；恢復後成功', () async {
      final d = FakeDrive();
      d.files['a'] = _b('a');
      d.forceStatus = (_, attempt) => attempt <= 2 ? 503 : null;
      expect(await driveOver(d).list(), hasLength(1));
      expect(d.requests.length, 3);
    });

    test('401：刷新授權後重試一次並成功', () async {
      final d = FakeDrive();
      d.files['a'] = _b('a');
      d.forceStatus = (_, attempt) => attempt == 1 ? 401 : null;
      var refreshed = 0;
      final r = driveOver(d, refreshAuth: () async => refreshed++);
      expect(await r.list(), hasLength(1));
      expect(refreshed, 1);
    });

    test('401 一直失敗：丟 SyncAuthException（不是無聲吞掉）', () async {
      final d = FakeDrive();
      d.forceStatus = (_, _) => 401;
      var refreshed = 0;
      final r = driveOver(d, refreshAuth: () async => refreshed++);
      await expectLater(r.list(), throwsA(isA<SyncAuthException>()));
      expect(refreshed, 1);
      expect(d.requests.length, 2);
    });

    test('取得授權標頭卡住：逾時後丟 SyncAuthException', () async {
      final d = FakeDrive();
      final r = driveOver(
        d,
        headers: () => Completer<Map<String, String>>().future,
      );
      await expectLater(
        r.list().timeout(const Duration(seconds: 5)),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('403 權限不足：丟 SyncAuthException 並帶出原因', () async {
      final d = FakeDrive();
      d.forceStatus = (_, _) => 403;
      await expectLater(
        driveOver(d).list(),
        throwsA(
          isA<SyncAuthException>().having(
            (e) => e.message,
            'message',
            contains('403'),
          ),
        ),
      );
    });
  });

  group('連線判斷：沒有明確斷線就視為可嘗試', () {
    test('VPN／other／空清單都不是離線', () {
      expect(isExplicitlyOffline([ConnectivityResult.vpn]), isFalse);
      expect(isExplicitlyOffline([ConnectivityResult.other]), isFalse);
      expect(isExplicitlyOffline(const []), isFalse);
      expect(
        isExplicitlyOffline([ConnectivityResult.vpn, ConnectivityResult.wifi]),
        isFalse,
      );
      expect(isExplicitlyOffline([ConnectivityResult.none]), isTrue);
      expect(networkKindOf([ConnectivityResult.vpn]), NetworkKind.other);
      expect(networkKindOf(const []), NetworkKind.other);
      expect(networkKindOf([ConnectivityResult.none]), NetworkKind.none);
      expect(
        networkKindOf([ConnectivityResult.vpn, ConnectivityResult.mobile]),
        NetworkKind.cellular,
      );
    });
  });

  group('引擎＋假 Drive 整合', () {
    late AppDatabase src; // 手機端（資料來源）
    late AppDatabase dst; // iPad（空的）
    late Directory srcDir;
    late Directory dstDir;
    late FakeDrive drive;

    setUp(() async {
      src = AppDatabase(NativeDatabase.memory());
      dst = AppDatabase(NativeDatabase.memory());
      srcDir = await Directory.systemTemp.createTemp('rob_src');
      dstDir = await Directory.systemTemp.createTemp('rob_dst');
      drive = FakeDrive(pageSize: 2);
    });
    tearDown(() async {
      await src.close();
      await dst.close();
    });

    /// 手機端建 [pits] 個坑、第一個坑有 [images] 張官方圖，上傳到假 Drive。
    Future<void> seedAndUpload({int pits = 3, int images = 4}) async {
      String? first;
      for (var i = 0; i < pits; i++) {
        final id = await src.createPit(name: '坑$i');
        first ??= id;
      }
      final group = (await src.watchGroups(first!).first).first;
      final imgs = <NewImage>[];
      for (var i = 0; i < images; i++) {
        File('${srcDir.path}/$i.png')
            .writeAsBytesSync(Uint8List.fromList([i, i, i]));
        imgs.add(NewImage(file: '$i.png'));
      }
      await src.addOfficial(first, group.id, imgs);
      final mem = MemoryRemote();
      await SyncEngine(db: src, remote: mem, images: ImageStore(srcDir)).sync();
      drive.files.addAll(mem.files);
    }

    SyncEngine iPad(DriveRemote r) =>
        SyncEngine(db: dst, remote: r, images: ImageStore(dstDir));

    test('多頁列表：所有坑、官方圖、圖片檔都拉得下來，進度由 0 走到 1', () async {
      await seedAndUpload();
      expect(drive.files.length, greaterThan(drive.pageSize * 3));
      final seen = <SyncProgress>[];
      final r = await iPad(driveOver(drive)).sync(onProgress: seen.add);
      expect(drive.listPages.length, greaterThan(2));
      expect((await dst.select(dst.pits).get()), hasLength(3));
      expect((await dst.select(dst.officialImages).get()), hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(File('${dstDir.path}/$i.png').existsSync(), isTrue);
      }
      expect(r.skippedDocs, isEmpty);
      // 拉取階段有「資料 N / M」進度，且單調遞增、最後完成。
      final pulls = seen
          .where((p) => p.stage == SyncStage.pulling && p.docsTotal > 0)
          .toList();
      expect(pulls, isNotEmpty);
      expect(pulls.last.docsDone, pulls.last.docsTotal);
      for (var i = 1; i < pulls.length; i++) {
        expect(pulls[i].docsDone, greaterThanOrEqualTo(pulls[i - 1].docsDone));
      }
    });

    test('壞 meta 只略過那幾份，其餘照常同步並記錄', () async {
      await seedAndUpload();
      drive.files['meta__pits__bad1.json'] = _b('not json {{{');
      drive.files['meta__pits__bad2.json'] = _b(
        jsonEncode({'v': 1, 'updatedAt': 'oops', 'data': {}}),
      );
      drive.files['meta__official__bad3.json'] = _b(
        jsonEncode({
          'v': 1,
          'updatedAt': 5,
          'data': {'id': 7}, // 欄位型別不符
        }),
      );
      final r = await iPad(driveOver(drive)).sync();
      expect(r.skippedDocs, hasLength(3));
      expect((await dst.select(dst.pits).get()), hasLength(3));
      expect((await dst.select(dst.officialImages).get()), hasLength(4));
      expect(File('${dstDir.path}/0.png').existsSync(), isTrue);
    });

    test('單張圖片下載失敗只略過那張；其餘仍下載', () async {
      await seedAndUpload();
      drive.forceStatus = (uri, _) =>
          uri.pathSegments.last == 'id:images__1.png' ? 500 : null;
      final r = await iPad(driveOver(drive)).sync();
      expect(r.imageFailures, 1);
      expect(File('${dstDir.path}/1.png').existsSync(), isFalse);
      for (final i in [0, 2, 3]) {
        expect(File('${dstDir.path}/$i.png').existsSync(), isTrue);
      }
    });

    test('圖片全部連續失敗：達上限就整次報錯，不會逐張等到天亮', () async {
      await seedAndUpload(images: 8);
      drive.forceStatus = (uri, _) =>
          uri.queryParameters['alt'] == 'media' &&
              uri.pathSegments.last.startsWith('id:images__')
          ? 500
          : null;
      await expectLater(
        iPad(driveOver(drive)).sync(),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('看門狗取消旗標：被中止時引擎在步驟之間停下並丟 SyncStalledException', () async {
      await seedAndUpload();
      final cancel = SyncCancel();
      await expectLater(
        iPad(driveOver(drive)).sync(
          cancel: cancel,
          onProgress: (p) {
            if (p.stage == SyncStage.pulling && p.docsTotal > 0) {
              cancel.cancel();
            }
          },
        ),
        throwsA(isA<SyncStalledException>()),
      );
    });
  });

  group('SyncController：看門狗、錯誤狀態、不被連線判斷擋住', () {
    late AppDatabase db;
    late Directory dir;
    late _SwitchRemote remote;
    late ProviderContainer container;

    ProviderContainer make({
      Stream<bool>? online,
      Duration stall = const Duration(milliseconds: 300),
    }) => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        imageStoreProvider.overrideWith((ref) async => ImageStore(dir)),
        syncRemoteProvider.overrideWithValue(remote),
        onlineProvider.overrideWith((ref) => online ?? Stream.value(true)),
        syncStallTimeoutProvider.overrideWithValue(stall),
      ],
    );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dir = await Directory.systemTemp.createTemp('rob_ctl');
      remote = _SwitchRemote(MemoryRemote());
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('請求卡死：看門狗中止、顯示可重試的錯誤，_running 不會卡住', () async {
      remote.current = _HangRemote();
      container = make();
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      final c = container.read(syncControllerProvider.notifier);
      expect(await c.syncNow().timeout(const Duration(seconds: 5)), isTrue);
      final s = container.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.retryable, isTrue);
      expect(s.message, l10nStatic.syncuiStalled);
      // 後續觸發不會被「正在同步」略過：換成正常遠端就能完成。
      remote.current = MemoryRemote();
      expect(await c.syncNow(), isTrue);
      expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
      expect(container.read(firstSyncPendingProvider), isFalse);
    });

    test('授權失敗：顯示錯誤訊息、不可自動重試', () async {
      final d = FakeDrive()..forceStatus = (_, _) => 401;
      remote.current = driveOver(d);
      container = make();
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      await container.read(syncControllerProvider.notifier).syncNow();
      final s = container.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.message, l10nStatic.syncAuthExpired);
      expect(s.retryable, isFalse);
    });

    test('網絡逾時：錯誤訊息點出是逾時，可自動重試', () async {
      final d = FakeDrive()..hangRequest = (_, _) => true;
      remote.current = driveOver(d);
      container = make(stall: const Duration(seconds: 10));
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      await container.read(syncControllerProvider.notifier).syncNow();
      final s = container.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.message, contains('連線逾時'));
      expect(s.retryable, isTrue);
    });

    test('connectivity 回報離線（或 VPN 型）也照樣嘗試同步', () async {
      container = make(online: Stream.value(false));
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      container.listen(onlineProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(onlineProvider).value, isFalse);
      final ran = await container
          .read(syncControllerProvider.notifier)
          .syncNow();
      expect(ran, isTrue);
      expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
    });

    test('有壞 meta：整體仍完成並記下帳號，但狀態顯示略過幾份', () async {
      final mem = MemoryRemote();
      await mem.upload('meta__pits__bad.json', _b('###'));
      await mem.upload('meta__pits__bad2.json', _b('###'));
      remote.current = mem;
      container = make();
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      await container.read(syncControllerProvider.notifier).syncNow();
      final s = container.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.message, l10nStatic.syncuiSkippedDocs(2));
      expect(container.read(firstSyncPendingProvider), isFalse);
    });

    test('進度：先「列出雲端內容」，再有資料 N / M，之後才是圖片', () async {
      final mem = MemoryRemote();
      final srcDb = AppDatabase(NativeDatabase.memory());
      addTearDown(srcDb.close);
      final id = await srcDb.createPit(name: 'p');
      await srcDb.createPit(name: 'q');
      expect(id, isNotEmpty);
      await SyncEngine(
        db: srcDb,
        remote: mem,
        images: ImageStore(await Directory.systemTemp.createTemp('rob_x')),
      ).sync();
      remote.current = mem;
      container = make();
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      final seen = <SyncState>[];
      container.listen(syncControllerProvider, (_, s) => seen.add(s));
      await container.read(syncControllerProvider.notifier).syncNow();
      expect(seen.first.isListing, isTrue);
      expect(seen.first.progressFraction, isNull);
      final docs = seen.where((s) => s.hasDocProgress).toList();
      expect(docs, isNotEmpty);
      expect(docs.last.progressFraction, 1.0);
      for (final s in docs) {
        expect(s.progressFraction, inInclusiveRange(0.0, 1.0));
      }
      expect((await db.select(db.pits).get()), hasLength(2));
    });
  });

  group('SyncDriver 自動重試', () {
    testWidgets('暫時性失敗後 15 秒自動重排，成功就停', (tester) async {
      _FailThenOk.calls = 0;
      SharedPreferences.setMockInitialValues({
        'accountEmail': 'me@example.com',
        'syncedAccount': 'me@example.com',
        'onboarded': true,
        'refreshMinutes': 60,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPrefsProvider.overrideWithValue(prefs),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            syncControllerProvider.overrideWith(_FailThenOk.new),
          ],
          child: const MaterialApp(home: SyncDriver(child: SizedBox())),
        ),
      );
      await tester.pump();
      expect(_FailThenOk.calls, 1);
      await tester.pump(const Duration(seconds: 14));
      expect(_FailThenOk.calls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(_FailThenOk.calls, 2);
      await tester.pump(const Duration(minutes: 3));
      expect(_FailThenOk.calls, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('SyncFirst 畫面', () {
    testWidgets('列出雲端內容：不確定進度條＋說明；資料 N / M：確定進度由左到右', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'accountEmail': 'me@example.com',
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPrefsProvider.overrideWithValue(prefs),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
            syncControllerProvider.overrideWith(_FakeSync.new),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            home: const SyncFirstPage(),
          ),
        ),
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(SyncFirstPage)),
      );
      final fake = c.read(syncControllerProvider.notifier) as _FakeSync;

      fake.set(const SyncState(phase: SyncPhase.syncing, isFirstSync: true));
      await tester.pump();
      expect(find.text('正在列出雲端內容'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );

      fake.set(
        const SyncState(
          phase: SyncPhase.syncing,
          isFirstSync: true,
          docsDone: 3,
          docsTotal: 12,
        ),
      );
      await tester.pump();
      expect(find.text('資料 3 / 12'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.25,
      );
      // 方向由左到右（非 RTL）。
      expect(
        Directionality.of(tester.element(find.byType(LinearProgressIndicator))),
        TextDirection.ltr,
      );

      fake.set(
        const SyncState(
          phase: SyncPhase.error,
          isFirstSync: true,
          message: '同步失敗：x',
        ),
      );
      await tester.pump();
      expect(find.text('同步失敗：x'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}

class _FailThenOk extends SyncController {
  static int calls = 0;
  @override
  Future<bool> syncNow() async {
    calls++;
    state = calls == 1
        ? const SyncState(phase: SyncPhase.error, message: 'x', retryable: true)
        : const SyncState();
    return true;
  }
}

class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
  @override
  Future<bool> syncNow() async => false;
  @override
  void startFirstSyncInBackground() {}
}
