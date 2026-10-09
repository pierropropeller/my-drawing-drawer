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
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';

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

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_syncui');
    pitId = await db.createPit(name: '坑A', description: '描述');
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool online = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(online)),
          syncControllerProvider.overrideWith(_FakeSync.new),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(SyncRing)));
  }

  _FakeSync fake(ProviderContainer c) =>
      c.read(syncControllerProvider.notifier) as _FakeSync;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  SyncRingMode ringMode(WidgetTester tester) =>
      tester.widget<SyncRing>(find.byType(SyncRing)).mode;

  Future<void> addImages(WidgetTester tester, List<String> files) =>
      tester.runAsync(() async {
        final groups = await db.select(db.officialGroups).get();
        await db.addOfficial(pitId, groups[0].id, [
          for (final f in files) NewImage(file: f),
        ]);
      });

  testWidgets('同步中沒有頂部橫條，頁面不會位移；離線橫條照舊', (tester) async {
    final c = await pumpApp(tester, online: false);
    await settle(tester);
    final before = tester.getTopLeft(find.text('現坑'));
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);

    fake(c).set(_transferring([_dl('x.png', s: TransferState.active, p: .3)]));
    await settle(tester);
    expect(find.textContaining('同步中・圖片'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.getTopLeft(find.text('現坑')), before);
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('外圈：檢查中轉圈不可點；傳輸中是進度環；沒東西傳就淡出', (tester) async {
    final sem = tester.ensureSemantics();
    final c = await pumpApp(tester);
    await settle(tester);
    expect(ringMode(tester), SyncRingMode.none);
    expect(find.bySemanticsLabel('同步中，正在檢查'), findsNothing);

    fake(c).set(const SyncState(phase: SyncPhase.syncing));
    await tester.pump();
    expect(ringMode(tester), SyncRingMode.checking);
    expect(find.bySemanticsLabel('同步中，正在檢查'), findsOneWidget);
    // 檢查中點頭像沒有反應。
    await tester.tap(find.byType(SyncRing));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SyncSheet), findsNothing);

    // 檢查完沒有東西要傳：外圈淡出，沒有 sheet。
    fake(c)
        .set(const SyncState(phase: SyncPhase.syncing, transfersPlanned: true));
    await tester.pump();
    expect(ringMode(tester), SyncRingMode.none);
    await tester.pump(const Duration(milliseconds: 400));
    final fade = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(SyncRing),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(fade.opacity, 0);
    await tester.tap(find.byType(SyncRing));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SyncSheet), findsNothing);

    fake(c).set(
      _transferring([_dl('a.png', s: TransferState.done, p: 1), _dl('b.png')]),
    );
    await tester.pump();
    expect(ringMode(tester), SyncRingMode.transferring);
    expect(find.bySemanticsLabel('同步中，查看進度'), findsOneWidget);
    expect(tester.widget<SyncRing>(find.byType(SyncRing)).fraction, 0.5);
    sem.dispose();
    await unmount(tester);
  });

  testWidgets('傳輸中點頭像：同步進度 sheet 列出前幾張，傳完自動關閉', (tester) async {
    await addImages(tester, [
      'u0.png',
      'd1.png',
      'd2.png',
      'd3.png',
      'd4.png',
      'd5.png',
      'd6.png',
    ]);
    final c = await pumpApp(tester);
    await settle(tester);

    // 1 張已完成、2 張進行中、其餘 4 張（含上傳）等待：未完成 6 張，只列 4 張。
    final list = [
      _dl('d1.png', s: TransferState.done, p: 1),
      _ul('u0.png', s: TransferState.active, p: .72),
      _dl('d2.png', s: TransferState.active, p: .62),
      _dl('d3.png'),
      _dl('d4.png'),
      _dl('d5.png'),
      _dl('d6.png'),
    ];
    fake(c).set(_transferring(list));
    await tester.pump();
    await tester.tap(find.byType(SyncRing));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    expect(find.byType(SyncSheet), findsOneWidget);
    expect(find.text('同步中'), findsOneWidget);
    expect(find.text('1 / 7'), findsOneWidget);
    expect(find.text('上傳 1 張'), findsOneWidget);
    expect(find.text('下載 6 張'), findsOneWidget);
    // 已完成的不列；其餘依序列出前 4 張，位置是「坑 · 格」。
    expect(find.text('坑A · 官方圖冊'), findsNWidgets(4));
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('等待中'), findsNWidgets(2));
    expect(find.text('還有 2 張等待中'), findsOneWidget);
    expect(find.text('上傳'), findsOneWidget);
    expect(find.text('下載'), findsNWidgets(3));

    // 進度更新時 sheet 即時跟著變。
    fake(c).set(
      _transferring([
        for (final x in list.take(2))
          x.copyWith(state: TransferState.done, progress: 1),
        _dl('d2.png', s: TransferState.active, p: .8),
        ...list.skip(3),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('2 / 7'), findsOneWidget);
    expect(find.text('還有 1 張等待中'), findsOneWidget);

    // 傳完：sheet 自動關閉。
    fake(c).set(const SyncState());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SyncSheet), findsNothing);
    await unmount(tester);
  });

  testWidgets('還沒下載的封面：淡色＋角標，有進度時顯示百分比，下載完消失', (tester) async {
    final sem = tester.ensureSemantics();
    await addImages(tester, ['cover.png']);
    await tester.runAsync(() async {
      final id = (await db.select(db.officialImages).get()).first.id;
      await db.setCover(pitId, id);
    });
    final c = await pumpApp(tester);
    await settle(tester);
    // 排隊中（沒有進度）：轉圈。
    expect(find.bySemanticsLabel('尚未下載'), findsOneWidget);

    fake(c)
        .set(_transferring([_dl('cover.png', s: TransferState.active, p: .5)]));
    await settle(tester);
    expect(find.bySemanticsLabel('下載中 50%'), findsOneWidget);
    expect(find.bySemanticsLabel('尚未下載'), findsNothing);

    // 檔案到了：角標消失。
    await tester.runAsync(() async {
      final store = await c.read(imageStoreProvider.future);
      await store.save('cover.png', Uint8List.fromList(const [0]));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('下載中 50%'), findsNothing);
    expect(find.bySemanticsLabel('尚未下載'), findsNothing);
    sem.dispose();
    await unmount(tester);
  });
}
