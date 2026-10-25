import 'dart:io';

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
import 'package:huakeng/sync/network_kind.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';
import 'package:huakeng/ui/sync/sync_popover.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-113 ③：頭像上的琥珀點／紅點可以點，開啟對應狀態的同步 sheet（手機）／popover（iPad）。
/// 沒有在傳也不會馬上關：琥珀點＝「同步完成・有失敗」（SyncSheetPartial／SyncPopoverPartial，有重試）；
/// 紅點＝標題「Drive 已滿」、等空間的上傳行、底部「管理儲存空間」→ 備份頁（BackupFull）。

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

SyncState _finished(List<SyncTransfer> transfers, {bool quotaFull = false}) =>
    SyncState(
      phase: SyncPhase.idle,
      lastSyncAt: DateTime.now(),
      lastResult: SyncResult()
        ..transfers = transfers
        ..quotaFull = quotaFull,
      quotaFull: quotaFull,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('sync_dot_tap');
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
            (ref) => Stream.value(NetworkKind.wifi),
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
        for (final f in ['a.png', 'b.png', 'c.png']) NewImage(file: f),
      ]);
    });
    return ProviderScope.containerOf(tester.element(find.byType(SyncRing)));
  }

  _FakeSync fake(ProviderContainer c) =>
      c.read(syncControllerProvider.notifier) as _FakeSync;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  const failedDot = ValueKey('syncRingDot:failed');
  const fullDot = ValueKey('syncRingDot:full');
  const manage = Key('sync-manage-storage-button');

  // (名稱, 視窗, 是不是 iPad)
  final layouts = <(String, Size, bool)>[
    ('手機', const Size(390, 844), false),
    ('iPad 直式（rail）', const Size(834, 1194), true),
    ('iPad 橫式（sidebar）', const Size(1194, 834), true),
  ];

  for (final (name, size, ipad) in layouts) {
    group(name, () {
      testWidgets('琥珀點：點小點本身→「同步完成，N 張失敗」，沒有在傳也不會關；重試、完成', (tester) async {
        final c = await pumpApp(tester, size);
        fake(c).set(
          _finished([
            _ul('a.png', TransferState.failed),
            _dl('b.png', TransferState.done),
          ]),
        );
        await tester.pump();
        expect(find.byKey(failedDot), findsOneWidget);

        // 點的是小點本身（在 48px 外圈的可點範圍內）。
        await tester.tap(find.byKey(failedDot));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);
        expect(
          find.byType(ipad ? SyncPopover : SyncSheet),
          findsOneWidget,
          reason: '沒有傳輸中也要保持開著',
        );
        expect(find.text('同步完成，1 張失敗'), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.byKey(const Key('sync-retry-button')), findsOneWidget);
        expect(find.text('管理儲存空間'), findsNothing);

        // 再等一會兒也不會自己關。
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('同步完成，1 張失敗'), findsOneWidget);

        await tester.tap(find.byKey(const Key('sync-retry-button')));
        await tester.pump();
        expect(fake(c).syncNowCalls, 1);
        await tester.tap(find.byKey(const Key('sync-done-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('同步完成，1 張失敗'), findsNothing);
        await unmount(tester);
      });

      testWidgets('紅點：點小點→標題「Drive 已滿」、「等待空間」、「管理儲存空間」→ 備份頁', (tester) async {
        final c = await pumpApp(tester, size);
        fake(c).set(
          _finished([
            _ul('a.png'),
            _ul('b.png'),
            _dl('c.png', TransferState.done),
          ], quotaFull: true),
        );
        await tester.pump();
        expect(find.byKey(fullDot), findsOneWidget);
        expect(find.byKey(failedDot), findsNothing);

        await tester.tap(find.byKey(fullDot));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);
        expect(find.byType(ipad ? SyncPopover : SyncSheet), findsOneWidget);
        expect(find.byKey(const Key('sync-full-title')), findsOneWidget);
        expect(find.text('Drive 已滿'), findsOneWidget);
        expect(find.text('2 張未上傳'), findsOneWidget);
        expect(find.byKey(const Key('sync-waiting-space')), findsNWidgets(2));
        expect(find.text('等待空間'), findsNWidgets(2));
        expect(find.byKey(manage), findsOneWidget);
        expect(find.text('管理儲存空間'), findsOneWidget);
        // iPad popover 的按鈕高 46、手機 sheet 48。
        expect(tester.getSize(find.byKey(manage)).height, ipad ? 46 : 48);
        // 沒有一般的「同步完成／重試」。
        expect(find.byKey(const Key('sync-retry-button')), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(manage), findsOneWidget);

        await tester.tap(find.byKey(manage));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await settle(tester);
        // sheet／popover 關了，前往備份頁（手機＝推一頁；iPad＝「我的」右側面板）。
        expect(find.byKey(manage), findsNothing);
        expect(find.byType(BackupPage), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('沒有小點、沒有在傳：點頭像什麼也不會開', (tester) async {
        final c = await pumpApp(tester, size);
        fake(c).set(_finished([_dl('a.png', TransferState.done)]));
        await tester.pump();
        expect(find.byKey(failedDot), findsNothing);
        expect(find.byKey(fullDot), findsNothing);
        await tester.tap(find.byType(SyncRing), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SyncSheet), findsNothing);
        expect(find.byType(SyncPopover), findsNothing);
        await unmount(tester);
      });

      testWidgets('紅點的 sheet 開著時，Drive 有空間了、上傳成功 → 轉成完成狀態', (tester) async {
        final c = await pumpApp(tester, size);
        fake(c).set(_finished([_ul('a.png')], quotaFull: true));
        await tester.pump();
        await tester.tap(find.byKey(fullDot));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settle(tester);
        expect(find.text('Drive 已滿'), findsOneWidget);

        // 開始同步（空間回來）→ 傳輸中顯示一般進度；傳完 → 完成。
        fake(c).set(
          SyncState(
            phase: SyncPhase.syncing,
            transfersPlanned: true,
            transfers: [_ul('a.png', TransferState.active)],
            quotaFull: true,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('sync-full-title')), findsNothing);
        fake(c).set(_finished([_ul('a.png', TransferState.done)]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('同步完成'), findsOneWidget);
        expect(find.byKey(const Key('sync-done-button')), findsOneWidget);
        await unmount(tester);
      });
    });
  }
}
