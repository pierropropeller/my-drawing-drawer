import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';

class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState(
    phase: SyncPhase.syncing,
    imagesDone: 128,
    imagesTotal: 342,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_pits_ui');
    pitId = await db.createPit(name: '坑A', description: '描述');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
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
          ...overrides,
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await tester.pump();
  }

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

  testWidgets('導覽列：坑內頁有，編輯坑／開新坑沒有', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.text('開新坑').last);
    await settle(tester);
    expect(find.text('目標'), findsNothing);
    await tester.tap(find.bySemanticsLabel('返回'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.text('坑A'));
    await settle(tester);
    expect(find.text('官方圖冊'), findsOneWidget);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    expect(find.text('編輯坑'), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    await tester.tap(find.bySemanticsLabel('返回'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> openEdit(WidgetTester tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('坑A'));
    await settle(tester);
    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
  }

  testWidgets('PitEdit-ntnf：坑內還沒有圖片，沒有封面區', (tester) async {
    await openEdit(tester);
    expect(find.text('編輯坑'), findsOneWidget);
    expect(find.text('封面'), findsNothing);
    await unmount(tester);
  });

  testWidgets('PitEditNoCover：有圖沒封面 → 虛線＋號，點了進選擇封面', (tester) async {
    await tester.runAsync(() => addImageAsync(db, pitId, 'a.png'));
    await openEdit(tester);
    expect(find.text('封面'), findsOneWidget);
    expect(find.bySemanticsLabel('選擇封面'), findsOneWidget);
    expect(find.text('更換封面'), findsNothing);
    await tester.tap(find.bySemanticsLabel('選擇封面'));
    await settle(tester);
    expect(find.text('編輯坑'), findsNothing); // 已進入選擇封面頁
    await unmount(tester);
  });

  testWidgets('PitEdit：有封面 → 縮圖＋更換封面', (tester) async {
    await tester.runAsync(() async {
      final id = await addImageAsync(db, pitId, 'a.png');
      await db.setCover(pitId, id);
    });
    await openEdit(tester);
    expect(find.text('更換封面'), findsOneWidget);
    expect(find.bySemanticsLabel('選擇封面'), findsNothing);
    await unmount(tester);
  });

  testWidgets('雜物開關：儲存後坑內頁最底出現雜物入口', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('坑A'));
    await settle(tester);
    expect(find.text('雜物'), findsNothing);

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await settle(tester);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.junkEnabled, isTrue);

    expect(find.text('雜物'), findsOneWidget);
    await tester.ensureVisible(find.text('雜物'));
    await tester.tap(find.text('雜物'));
    await settle(tester);
    // 佔位頁：只有「雜物」，坑內頁被蓋住。
    expect(find.text('雜物'), findsOneWidget);
    expect(find.text('官方圖冊'), findsNothing);
    await unmount(tester);
  });

  testWidgets('同步中橫條顯示圖片進度，取代離線橫條', (tester) async {
    await pumpApp(
      tester,
      online: false,
      overrides: [syncControllerProvider.overrideWith(_FakeSync.new)],
    );
    await settle(tester);
    expect(find.text('同步中・圖片 128 / 342'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsNothing);
    await unmount(tester);
  });

  testWidgets('離線橫條', (tester) async {
    await pumpApp(tester, online: false);
    await settle(tester);
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
    expect(find.textContaining('同步中'), findsNothing);
    await unmount(tester);
  });

  testWidgets('封面還沒下載：蓋淡色＋下載 icon；檔案存在時沒有', (tester) async {
    await tester.runAsync(() async {
      final id = await addImageAsync(db, pitId, 'cover.png');
      await db.setCover(pitId, id);
    });
    await pumpApp(tester);
    await settle(tester);
    expect(find.bySemanticsLabel('尚未下載'), findsOneWidget);

    Directory('${tmp.path}/images').createSync(recursive: true);
    File('${tmp.path}/images/cover.png').writeAsBytesSync(const [0]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await unmount(tester);

    // 檔案已經在本機：重新進入主頁不再有遮罩。
    await pumpApp(tester);
    await settle(tester);
    expect(find.bySemanticsLabel('尚未下載'), findsNothing);
    await unmount(tester);
  });
}

Future<String> addImageAsync(AppDatabase db, String pitId, String file) async {
  final groups = await db.select(db.officialGroups).get();
  await db.addOfficial(pitId, groups[0].id, [NewImage(file: file)]);
  return (await db.select(db.officialImages).get()).first.id;
}
