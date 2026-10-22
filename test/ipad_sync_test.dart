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
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/nav/nav_rail.dart';
import 'package:huakeng/ui/nav/nav_sidebar.dart';
import 'package:huakeng/ui/sync/pit_sync.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';
import 'package:huakeng/ui/sync/sync_popover.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可由測試直接指定 [SyncState]，不真的同步。
class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
}

SyncTransfer _dl(
  String f, {
  TransferState s = TransferState.waiting,
  double? p,
}) => SyncTransfer(
  file: f,
  direction: TransferDirection.download,
  state: s,
  progress: p,
);

SyncTransfer _ul(
  String f, {
  TransferState s = TransferState.waiting,
  double? p,
}) => SyncTransfer(
  file: f,
  direction: TransferDirection.upload,
  state: s,
  progress: p,
);

SyncState _transferring(List<SyncTransfer> list) => SyncState(
  phase: SyncPhase.syncing,
  transfersPlanned: true,
  transfers: list,
);

/// iPad 同步入口：rail／sidebar 的頭像外圈、popover（≥600）與 sheet（＜600）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_ipadsync');
    await db.createPit(name: '坑A');
  });

  void setView(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

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
    bool online = true,
  }) async {
    setView(tester, w, h);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(online)),
          networkKindProvider.overrideWith(
            (ref) => Stream.value(NetworkKind.wifi),
          ),
          syncControllerProvider.overrideWith(_FakeSync.new),
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

  SyncRingMode ringMode(WidgetTester tester) =>
      tester.widget<SyncRing>(find.byType(SyncRing)).mode;

  final list = [
    _dl('d1.png', s: TransferState.done, p: 1),
    _ul('u0.png', s: TransferState.active, p: .72),
    _dl('d2.png', s: TransferState.active, p: .62),
    _dl('d3.png'),
    _dl('d4.png'),
    _dl('d5.png'),
    _dl('d6.png'),
  ];

  // (闊, 高, 導覽型態)
  final tablets = <(double, double, Type)>[
    (834, 1194, NavRail),
    (1194, 834, NavSidebar),
    (1366, 1024, NavSidebar),
  ];

  for (final (w, h, nav) in tablets) {
    group('$w×$h', () {
      testWidgets('頭像外圈在 ${nav == NavRail ? 'rail' : 'sidebar'}：狀態切換', (
        tester,
      ) async {
        final c = await pumpApp(tester, w, h);
        expect(find.byType(nav), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(nav),
            matching: find.byType(SyncRing),
          ),
          findsOneWidget,
        );
        expect(ringMode(tester), SyncRingMode.none);

        // 檢查中：短弧轉圈，不可點。
        fake(c).set(const SyncState(phase: SyncPhase.syncing));
        await tester.pump();
        expect(ringMode(tester), SyncRingMode.checking);
        await tester.tap(find.byType(SyncRing));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SyncPopover), findsNothing);
        expect(find.byType(SyncSheet), findsNothing);

        // 傳輸中：進度環。
        fake(c).set(_transferring(list));
        await tester.pump();
        expect(ringMode(tester), SyncRingMode.transferring);
        expect(
          tester.widget<SyncRing>(find.byType(SyncRing)).fraction,
          closeTo(1 / 7, 0.001),
        );
        await unmount(tester);
      });

      testWidgets('傳輸中點頭像開 popover，傳完變完成狀態（D-109 ①），按「完成」才關', (tester) async {
        await tester.runAsync(() async {
          final groups = await db.select(db.officialGroups).get();
          final pit = (await db.select(db.pits).get()).first;
          await db.addOfficial(pit.id, groups[0].id, [
            for (final f in ['u0.png', 'd1.png', 'd2.png']) NewImage(file: f),
          ]);
        });
        final c = await pumpApp(tester, w, h);
        fake(c).set(_transferring(list));
        await tester.pump();
        final avatar = tester.getRect(find.byType(SyncRing));
        await tester.tap(find.byType(SyncRing));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await settle(tester);

        expect(find.byType(SyncPopover), findsOneWidget);
        expect(find.byType(SyncSheet), findsNothing);
        expect(find.text('同步中'), findsOneWidget);
        expect(find.text('1 / 7'), findsOneWidget);
        expect(find.text('上傳 1 張'), findsOneWidget);
        expect(find.text('下載 6 張'), findsOneWidget);
        expect(find.text('Wi-Fi'), findsOneWidget);
        expect(find.text('還有 2 張等待中'), findsOneWidget);
        expect(find.text('同步設定'), findsOneWidget);
        expect(find.text('坑A · 官方圖冊'), findsNWidgets(2));

        // 寬 400、在頭像下方、左緣約 14（稿）。
        final box = tester.getRect(find.byKey(SyncPopover.cardKey));
        expect(box.width, 400);
        expect(box.top, greaterThan(avatar.bottom));
        expect(box.left, closeTo(avatar.left - 6, 8));

        // 進度更新即時反映。
        fake(c).set(
          _transferring([
            for (final x in list.take(2))
              x.copyWith(state: TransferState.done, progress: 1),
            ...list.skip(2),
          ]),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('2 / 7'), findsOneWidget);

        // 傳完：不自動關，原地變成完成狀態（同手機 D-100）。
        fake(c).set(const SyncState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SyncPopover), findsOneWidget);
        expect(find.text('同步完成'), findsOneWidget);
        expect(find.text('同步中'), findsNothing);
        expect(find.text('7 / 7'), findsOneWidget);
        expect(find.text('上傳 1 張'), findsOneWidget);
        expect(find.text('下載 6 張'), findsOneWidget);
        expect(find.text('剛剛'), findsOneWidget);
        expect(find.text('同步設定'), findsNothing); // 列表和設定連結都消失
        expect(find.text('坑A · 官方圖冊'), findsNothing);
        expect(find.text('Wi-Fi'), findsNothing);

        // 又有新的變更：切回同步中。
        fake(
          c,
        ).set(_transferring([_dl('d1.png', s: TransferState.active, p: .5)]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('同步完成'), findsNothing);
        expect(find.text('同步中'), findsOneWidget);
        fake(c).set(const SyncState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('同步完成'), findsOneWidget);

        // 按「完成」才關。
        await tester.tap(find.byKey(const Key('sync-done-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SyncPopover), findsNothing);
        await unmount(tester);
      });

      testWidgets('點彈層外面關閉；「同步設定」前往我的 › 備份與同步', (tester) async {
        final c = await pumpApp(tester, w, h);
        fake(c).set(_transferring(list));
        await tester.pump();
        await tester.tap(find.byType(SyncRing));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SyncPopover), findsOneWidget);
        await tester.tapAt(Offset(w - 10, h - 10));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SyncPopover), findsNothing);

        await tester.tap(find.byType(SyncRing));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('同步設定'));
        await settle(tester);
        expect(find.byType(SyncPopover), findsNothing);
        expect(find.byType(BackupPage), findsOneWidget);
        await unmount(tester);
      });
    });
  }

  group('正在下載的坑', () {
    Future<void> addD2() => db.select(db.pits).get().then((pits) async {
      final groups = await db.select(db.officialGroups).get();
      await db.addOfficial(pits.first.id, groups[0].id, [
        NewImage(file: 'd2.png'),
      ]);
    });

    testWidgets('1194×834：sidebar 現坑列顯示小轉圈、坑卡片寫「同步中…」；傳完換回成圖數', (tester) async {
      await tester.runAsync(addD2);
      final c = await pumpApp(tester, 1194, 834);
      expect(find.byType(PitSyncSpinner), findsNothing);
      expect(find.text('同步中…'), findsNothing);

      fake(c)
          .set(_transferring([_dl('d2.png', s: TransferState.active, p: .3)]));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(NavSidebar),
          matching: find.byType(PitSyncSpinner),
        ),
        findsOneWidget,
      );
      expect(find.text('同步中…'), findsOneWidget);

      fake(c).set(const SyncState());
      await settle(tester);
      expect(find.byType(PitSyncSpinner), findsNothing);
      expect(find.text('同步中…'), findsNothing);
      await unmount(tester);
    });

    testWidgets('390×844：手機坑卡片統計不變', (tester) async {
      await tester.runAsync(addD2);
      final c = await pumpApp(tester, 390, 844);
      fake(c)
          .set(_transferring([_dl('d2.png', s: TransferState.active, p: .3)]));
      await settle(tester);
      expect(find.text('同步中…'), findsNothing);
      await unmount(tester);
    });
  });

  group('離線', () {
    testWidgets('1194×834：離線橫條；外圈不亮', (tester) async {
      await pumpApp(tester, 1194, 834, online: false);
      expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
      expect(ringMode(tester), SyncRingMode.none);
      await unmount(tester);
    });
  });

  group('窄寬度', () {
    testWidgets('400×900：底部導覽列，頭像開底部 sheet（SyncSheet400）', (tester) async {
      final c = await pumpApp(tester, 400, 900);
      expect(find.byType(NavRail), findsNothing);
      expect(find.byType(NavSidebar), findsNothing);
      fake(c).set(_transferring(list));
      await tester.pump();
      await tester.tap(find.byType(SyncRing));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SyncSheet), findsOneWidget);
      expect(find.byType(SyncPopover), findsNothing);
      expect(find.text('Wi-Fi'), findsNothing);
      expect(find.text('同步設定'), findsNothing);
      fake(c).set(const SyncState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // D-100：傳完不自動關，變完成狀態；按「完成」才關。
      expect(find.byType(SyncSheet), findsOneWidget);
      expect(find.text('同步完成'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sync-done-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SyncSheet), findsNothing);
      await unmount(tester);
    });

    testWidgets('390×844：手機版面不變（頭像在主頁標題列、開 sheet）', (tester) async {
      final c = await pumpApp(tester, 390, 844);
      expect(
        find.descendant(
          of: find.byType(NavRail),
          matching: find.byType(SyncRing),
        ),
        findsNothing,
      );
      fake(c).set(_transferring(list));
      await tester.pump();
      await tester.tap(find.byType(SyncRing));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SyncSheet), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('popover 開著時拉窄到 400：同一個彈層換成底部 sheet 的樣子', (tester) async {
      final c = await pumpApp(tester, 834, 1194);
      fake(c).set(_transferring(list));
      await tester.pump();
      await tester.tap(find.byType(SyncRing));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPopover), findsOneWidget);
      expect(find.text('同步設定'), findsOneWidget);

      setView(tester, 400, 900);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SyncPopover), findsOneWidget);
      expect(find.byType(SyncSheetBody), findsOneWidget);
      expect(find.text('同步設定'), findsNothing);
      expect(find.text('1 / 7'), findsOneWidget);

      // 傳完：同一個彈層變完成狀態（sheet 樣子），按「完成」才關。
      fake(c).set(const SyncState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SyncPopover), findsOneWidget);
      expect(find.text('同步完成'), findsWidgets);
      await tester.tap(find.byKey(const Key('sync-done-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SyncPopover), findsNothing);
      await unmount(tester);
    });
  });
}
