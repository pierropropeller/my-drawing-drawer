import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:huakeng/data/remote_size_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/byte_size.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/storage_usage.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// 批次 18 / D-101：備份與同步頁的儲存空間。大小格式、配額解析（含無上限帳號）、
/// 畫匣用量記錄與加總（上傳時記、列表校正）、更新時機與失敗保留、卡片畫面。

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

class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
}

Uint8List _png(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 3);
  for (final p in image) {
    p
      ..r = p.x * 255 ~/ w
      ..g = p.y * 255 ~/ h
      ..b = 128;
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('formatByteSize', () {
    test('單位換算與小數：一位小數、整數不帶 .0', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1), '1 B');
      expect(formatByteSize(1023), '1023 B');
      expect(formatByteSize(1024), '1 KB');
      expect(formatByteSize(1536), '1.5 KB');
      expect(formatByteSize(30 * 1024), '30 KB');
      expect(formatByteSize(5 * 1024 * 1024 + 300 * 1024), '5.3 MB');
      expect(formatByteSize(15 * gb), '15 GB');
      expect(formatByteSize((8.3 * gb).round()), '8.3 GB');
      expect(formatByteSize((1.2 * gb).round()), '1.2 GB');
      expect(formatByteSize((7.1 * gb).round()), '7.1 GB');
      expect(formatByteSize(2 * 1024 * gb), '2 TB');
    });

    test('四捨五入後進位到下一級、負數當 0', () {
      expect(formatByteSize(1024 * 1024 - 1), '1 MB'); // 1023.999 KB → 1 MB
      expect(formatByteSize(gb - 1), '1 GB');
      expect(formatByteSize(-5), '0 B');
    });
  });

  group('StorageQuota 解析', () {
    test('有上限：Drive 以字串回傳數字', () {
      final q = StorageQuota.fromJson({
        'limit': '16106127360',
        'usage': '8912896000',
        'usageInDrive': '100',
      })!;
      expect(q.limit, 15 * gb);
      expect(q.usage, 8912896000);
      expect(q.unlimited, isFalse);
    });

    test('沒有 limit（企業無限空間）＝無上限；limit 為 0 也視為無上限', () {
      final q = StorageQuota.fromJson({'usage': '123'})!;
      expect(q.limit, isNull);
      expect(q.unlimited, isTrue);
      expect(q.usage, 123);
      expect(
        StorageQuota.fromJson({'limit': '0', 'usage': '5'})!.limit,
        isNull,
      );
    });

    test('壞資料回傳 null：沒有 usage、不是物件、數字壞掉', () {
      expect(StorageQuota.fromJson(null), isNull);
      expect(StorageQuota.fromJson('x'), isNull);
      expect(StorageQuota.fromJson({'limit': '10'}), isNull);
      expect(StorageQuota.fromJson({'usage': 'abc'}), isNull);
      expect(StorageQuota.fromJson({'usage': '-1'}), isNull);
    });
  });

  group('DriveRemote', () {
    DriveRemote make(MockClient c) => DriveRemote(
      headers: () async => {'Authorization': 'Bearer t'},
      client: c,
      retryDelay: Duration.zero,
    );

    test(
      'storageQuota：about.get?fields=storageQuota，不加新權限，解析 limit／usage',
      () async {
        late Uri seen;
        final remote = make(
          MockClient((req) async {
            seen = req.url;
            return http.Response(
              jsonEncode({
                'storageQuota': {
                  'limit': '${15 * gb}',
                  'usage': '${(8.3 * gb).round()}',
                },
              }),
              200,
            );
          }),
        );
        final q = await remote.storageQuota();
        expect(seen.path, '/drive/v3/about');
        expect(seen.queryParameters['fields'], 'storageQuota');
        expect(q.limit, 15 * gb);
        expect(q.usage, (8.3 * gb).round());
      },
    );

    test('storageQuota：無上限帳號 limit 不回傳', () async {
      final remote = make(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'storageQuota': {'usage': '999'},
            }),
            200,
          ),
        ),
      );
      final q = await remote.storageQuota();
      expect(q.unlimited, isTrue);
      expect(q.usage, 999);
    });

    test('storageQuota：回應缺 storageQuota 丟例外', () async {
      final remote = make(MockClient((_) async => http.Response('{}', 200)));
      await expectLater(remote.storageQuota(), throwsA(isA<FormatException>()));
    });

    test('list 要求並解析 size（Drive 回傳字串）；缺少時為 null', () async {
      late Uri seen;
      final remote = make(
        MockClient((req) async {
          seen = req.url;
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': '1',
                  'name': 'images__a.png',
                  'modifiedTime': 't',
                  'size': '2048',
                },
                {'id': '2', 'name': 'meta__x', 'modifiedTime': 't'},
              ],
            }),
            200,
          );
        }),
      );
      final files = await remote.list();
      expect(seen.queryParameters['fields'], contains('size'));
      expect(files[0].size, 2048);
      expect(files[1].size, isNull);
    });
  });

  group('畫匣用量記錄（SyncEngine）', () {
    late AppDatabase db, other;
    late Directory dir, dirOther;
    late ImageStore store, storeOther;
    late MemoryRemote remote;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      other = AppDatabase(NativeDatabase.memory());
      dir = await Directory.systemTemp.createTemp('quota_a');
      dirOther = await Directory.systemTemp.createTemp('quota_b');
      store = ImageStore(dir);
      storeOther = ImageStore(dirOther);
      remote = MemoryRemote();
    });
    tearDown(() async {
      await db.close();
      await other.close();
      await dir.delete(recursive: true);
      await dirOther.delete(recursive: true);
    });

    int remoteTotal() => remote.files.values.fold(0, (a, b) => a + b.length);

    Future<void> addImages(int n) async {
      final pit = await db.createPit(name: '坑A');
      final names = [for (var i = 0; i < n; i++) 'img$i.png'];
      for (final f in names) {
        File('${dir.path}/$f').writeAsBytesSync(_png(300, 200));
      }
      await db.addFanArts(pit, [
        for (final f in names) NewImage(file: f, width: 300, height: 200),
      ], author: 'x');
    }

    test('沒同步過：用量為 0', () async {
      expect(await db.drawerRemoteBytes(), 0);
    });

    test('上傳時逐檔記下大小（原圖＋占位圖＋meta＋格式標記）；加總＝遠端實際位元組', () async {
      await addImages(2);
      await SyncEngine(db: db, remote: remote, images: store).sync();
      final rows = {
        for (final r in await db.select(db.remoteFileSizes).get())
          r.name: r.size,
      };
      expect(rows.keys.toSet(), remote.files.keys.toSet());
      expect(rows.keys.where((k) => k.startsWith('images__')).length, 2);
      expect(rows.keys.where((k) => k.startsWith('thumbs__')).length, 2);
      expect(rows.keys.where((k) => k.startsWith('meta__')), isNotEmpty);
      for (final e in rows.entries) {
        expect(e.value, remote.files[e.key]!.length, reason: e.key);
      }
      expect(await db.drawerRemoteBytes(), remoteTotal());
    });

    test('覆蓋同名檔不會重複計算（以最後一次為準）', () async {
      await addImages(1);
      final engine = SyncEngine(db: db, remote: remote, images: store);
      await engine.sync();
      final rowsBefore = (await db.select(db.remoteFileSizes).get()).length;
      final pit = (await db.select(db.pits).get()).single.id;
      await db.updatePit(pit, name: '坑A改名過、名字變得比較長一點');
      await engine.sync();
      expect(await db.drawerRemoteBytes(), remoteTotal());
      expect((await db.select(db.remoteFileSizes).get()).length, rowsBefore);
    });

    test('舊資料補齊：本機沒有記錄（升級前上傳的）時，下一次同步以遠端列表校正', () async {
      await addImages(2);
      final engine = SyncEngine(db: db, remote: remote, images: store);
      await engine.sync();
      final total = remoteTotal();
      // 模擬升級前：記錄表是空的，遠端卻已經有檔案。
      await db.delete(db.remoteFileSizes).go();
      expect(await db.drawerRemoteBytes(), 0);
      await engine.sync();
      expect(await db.drawerRemoteBytes(), total);
    });

    test('其他裝置上傳的檔案也算進畫匣用量；遠端已不存在的檔案從記錄移除', () async {
      await addImages(1);
      final engine = SyncEngine(db: db, remote: remote, images: store);
      await engine.sync();
      // 另一台裝置上傳了一張圖（本機只下載）。
      remote.files['images__fromB.png'] = Uint8List(5000);
      remote.files['thumbs__fromB.png'] = Uint8List(700);
      await engine.sync();
      expect(await db.drawerRemoteBytes(), remoteTotal());
      remote.files.remove('images__fromB.png');
      await engine.sync();
      expect(await db.drawerRemoteBytes(), remoteTotal());
      expect(
        (await db.select(db.remoteFileSizes).get()).map((r) => r.name),
        isNot(contains('images__fromB.png')),
      );
    });

    test('A 傳、B 同步下來之後，B 的畫匣用量也等於遠端總量', () async {
      await addImages(2);
      await SyncEngine(db: db, remote: remote, images: store).sync();
      await SyncEngine(db: other, remote: remote, images: storeOther).sync();
      expect(await other.drawerRemoteBytes(), remoteTotal());
    });

    test('更換帳號 resetState：用量記錄清掉', () async {
      await addImages(1);
      final engine = SyncEngine(db: db, remote: remote, images: store);
      await engine.sync();
      expect(await db.drawerRemoteBytes(), greaterThan(0));
      await engine.resetState();
      expect(await db.drawerRemoteBytes(), 0);
    });
  });

  group('storageUsageProvider', () {
    late AppDatabase db;
    late MemoryRemote remote;
    late ProviderContainer c;

    Future<void> setUpContainer({bool linked = true}) async {
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        if (linked) 'accountEmail': 'molly@example.com',
      });
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          syncRemoteProvider.overrideWithValue(remote),
          syncControllerProvider.overrideWith(_FakeSync.new),
        ],
      );
      addTearDown(c.dispose);
      c.listen(storageUsageProvider, (_, _) {}); // 保持存活（頁面開著的情況）
    }

    Future<void> setDrawer(int bytes) async {
      await db.delete(db.remoteFileSizes).go();
      await db
          .into(db.remoteFileSizes)
          .insert(
            RemoteFileSizesCompanion.insert(name: 'images__x', size: bytes),
          );
    }

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      remote = MemoryRemote();
    });
    tearDown(() => db.close());

    test('refresh：帳號用量／總量＋畫匣用量；分段比例', () async {
      remote.quota = StorageQuota(usage: (8.3 * gb).round(), limit: 15 * gb);
      await setDrawer((1.2 * gb).round());
      await setUpContainer();
      expect(c.read(storageUsageProvider), isNull); // 還沒更新前不顯示
      await c.read(storageUsageProvider.notifier).refresh();
      final i = c.read(storageUsageProvider)!;
      expect(i.usage, (8.3 * gb).round());
      expect(i.limit, 15 * gb);
      expect(i.drawerBytes, (1.2 * gb).round());
      expect(i.otherBytes, (8.3 * gb).round() - (1.2 * gb).round());
      expect(i.drawerFraction, closeTo(1.2 / 15, 0.001));
      expect(i.otherFraction, closeTo(7.1 / 15, 0.001));
      expect(formatByteSize(i.otherBytes), '7.1 GB');
    });

    test('無上限帳號：limit 為 null，沒有比例', () async {
      remote.quota = const StorageQuota(usage: 5 * gb);
      await setDrawer(gb);
      await setUpContainer();
      await c.read(storageUsageProvider.notifier).refresh();
      final i = c.read(storageUsageProvider)!;
      expect(i.limit, isNull);
      expect((i.drawerFraction, i.otherFraction), (0.0, 0.0));
    });

    test('畫匣記錄比帳號用量大（記錄過時）：其他為 0，比例不超過 1', () async {
      remote.quota = const StorageQuota(usage: gb, limit: 2 * gb);
      await setDrawer(3 * gb);
      await setUpContainer();
      await c.read(storageUsageProvider.notifier).refresh();
      final i = c.read(storageUsageProvider)!;
      expect(i.otherBytes, 0);
      expect(i.drawerFraction + i.otherFraction, lessThanOrEqualTo(0.5 + 1e-9));
    });

    test('失敗（離線）：保留上一次的帳號數字；沒有舊值時維持 null', () async {
      remote.quotaError = const SocketException('offline');
      await setUpContainer();
      await c.read(storageUsageProvider.notifier).refresh();
      expect(c.read(storageUsageProvider), isNull);

      remote.quotaError = null;
      remote.quota = const StorageQuota(usage: 2 * gb, limit: 15 * gb);
      await c.read(storageUsageProvider.notifier).refresh();
      expect(c.read(storageUsageProvider)!.usage, 2 * gb);

      remote.quotaError = const SocketException('offline');
      await setDrawer(777);
      await c.read(storageUsageProvider.notifier).refresh();
      final i = c.read(storageUsageProvider)!;
      expect(i.usage, 2 * gb); // 帳號數字保留
      expect(i.drawerBytes, 777); // 本機記錄照樣更新
    });

    test('同步結束（syncing → idle／error）後自動更新一次；同步中不更新', () async {
      remote.quota = const StorageQuota(usage: gb, limit: 15 * gb);
      await setUpContainer();
      await c.read(storageUsageProvider.notifier).refresh();
      expect(remote.quotaCalls, 1);

      final sync = c.read(syncControllerProvider.notifier) as _FakeSync;
      remote.quota = const StorageQuota(usage: 2 * gb, limit: 15 * gb);
      sync.set(const SyncState(phase: SyncPhase.syncing));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(remote.quotaCalls, 1);
      sync.set(SyncState(phase: SyncPhase.idle, lastSyncAt: DateTime(2026)));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.quotaCalls, 2);
      expect(c.read(storageUsageProvider)!.usage, 2 * gb);

      sync.set(const SyncState(phase: SyncPhase.syncing));
      sync.set(const SyncState(phase: SyncPhase.error, message: 'x'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.quotaCalls, 3);
    });

    test('換帳號或取消連結：舊帳號的數字清掉', () async {
      remote.quota = const StorageQuota(usage: gb, limit: 15 * gb);
      await setUpContainer();
      await c.read(storageUsageProvider.notifier).refresh();
      expect(c.read(storageUsageProvider), isNotNull);
      c.read(settingsProvider.notifier).setAccount(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.read(storageUsageProvider), isNull);
    });
  });

  group('儲存空間卡（BackupPage）', () {
    late AppDatabase db;
    late MemoryRemote remote;

    setUp(() {
      navBarHiddenCount.value = 0;
      db = AppDatabase(NativeDatabase.memory());
      remote = MemoryRemote();
    });
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpPage(WidgetTester tester, {bool dark = false}) async {
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
      await settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('有上限：右上「8.3 GB / 15 GB」、分段進度條、兩個圖例；位於 Drive 卡與設定卡之間', (
      tester,
    ) async {
      remote.quota = StorageQuota(usage: (8.3 * gb).round(), limit: 15 * gb);
      await db
          .into(db.remoteFileSizes)
          .insert(
            RemoteFileSizesCompanion.insert(
              name: 'images__x',
              size: (1.2 * gb).round(),
            ),
          );
      await pumpPage(tester);
      expect(remote.quotaCalls, 1); // 進入頁面更新一次
      expect(find.text('儲存空間'), findsOneWidget);
      expect(
        find.textContaining('8.3 GB / 15 GB', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('畫匣 1.2 GB'), findsOneWidget);
      expect(find.text('其他 7.1 GB'), findsOneWidget);

      // 版面順序：Google Drive → 儲存空間 → 自動同步。
      final drive = tester.getTopLeft(find.text('Google Drive')).dy;
      final storage = tester.getTopLeft(find.text('儲存空間')).dy;
      final auto = tester.getTopLeft(find.text('自動同步')).dy;
      expect(drive < storage && storage < auto, isTrue);

      // 進度條：8px 高；深藍約 8%、淺藍約 47.3%（對照 Backup 稿）。
      final bar = tester.getSize(find.byKey(const ValueKey('storageBar')));
      expect(bar.height, 8);
      final d = tester.getSize(find.byKey(const ValueKey('storageBarDrawer')));
      final o = tester.getSize(find.byKey(const ValueKey('storageBarOther')));
      expect(d.width / bar.width, closeTo(0.08, 0.002));
      expect(o.width / bar.width, closeTo(0.473, 0.002));
      await unmount(tester);
    });

    testWidgets('無上限帳號：只顯示「已用 8.3 GB」，沒有進度條', (tester) async {
      remote.quota = StorageQuota(usage: (8.3 * gb).round());
      await pumpPage(tester);
      expect(
        find.textContaining('已用 8.3 GB', findRichText: true),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('storageBar')), findsNothing);
      expect(find.textContaining('畫匣 '), findsNothing);
      await unmount(tester);
    });

    testWidgets('載入失敗（離線）且沒有舊值：整張卡不顯示，頁面其餘照常', (tester) async {
      remote.quotaError = const SocketException('offline');
      await pumpPage(tester);
      expect(find.text('儲存空間'), findsNothing);
      expect(find.text('自動同步'), findsOneWidget);
      expect(find.text('立即同步'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('深色模式也能顯示（稿沒畫深色，沿用官方圖分類色）', (tester) async {
      remote.quota = const StorageQuota(usage: 2 * gb, limit: 15 * gb);
      await pumpPage(tester, dark: true);
      expect(find.text('儲存空間'), findsOneWidget);
      expect(find.byKey(const ValueKey('storageBar')), findsOneWidget);
      await unmount(tester);
    });
  });
}
