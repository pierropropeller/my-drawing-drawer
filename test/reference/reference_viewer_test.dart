import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/ref_view_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/reference/ref_filmstrip.dart';
import 'package:huakeng/ui/reference/ref_stage.dart';
import 'package:huakeng/ui/reference/ref_toolbar.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';

/// 參考圖檢視：自適應版型（390／834／1194／1366／404）、狀態還原、拉窗、翻轉、資料面板。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late File original;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('ref_viewer');
    await Directory('${tmp.path}/images').create(recursive: true);
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${tmp.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    original = File('${tmp.path}/images/a.png');
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  List<RefImage> sample() => [
    for (final (i, n) in ['a.png', 'b.png', 'c.png'].indexed)
      RefImage(
        id: 'id$i',
        file: n,
        width: 1000,
        height: 1500,
        title: '坑A · 官方圖冊',
        category: '設定圖',
        tags: const ['角色1', '服裝參考'],
        addedAt: DateTime(2026, 9, 21),
      ),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  void sizeTo(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
  }

  Future<void> pumpViewer(
    WidgetTester tester, {
    Size size = const Size(834, 1194),
    List<RefImage>? images,
    int index = 0,
  }) async {
    sizeTo(tester, size);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: Scaffold(
            body: ReferenceViewer(
              images: images ?? sample(),
              initialIndex: index,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    // 讓資料庫 stream 關閉時排的 Timer 跑完。
    await tester.pump(const Duration(milliseconds: 50));
  }

  RefStageState stage(WidgetTester tester) =>
      tester.state<RefStageState>(find.byType(RefStage));

  Future<void> pinch(
    WidgetTester tester, {
    double from = 30,
    double to = 90,
  }) async {
    final c = tester.getCenter(find.byType(RefStage));
    final a = await tester.startGesture(c - Offset(from, 0));
    final b = await tester.startGesture(c + Offset(from, 0));
    await tester.pump();
    await a.moveTo(c - Offset(to, 0));
    await b.moveTo(c + Offset(to, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pump();
  }

  Finder tool(String semanticsLabel) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == semanticsLabel,
  );

  int percentShown() {
    final texts = find.textContaining('%');
    final s = (texts.evaluate().first.widget as Text).data!;
    return int.parse(RegExp(r'(\d+)%').firstMatch(s)!.group(1)!);
  }

  group('自適應版型', () {
    for (final c in const [
      // (寬, 高, 縮圖直排, 工具列文字, 資料面板)
      (390.0, 844.0, false, false, false),
      (404.0, 900.0, false, false, false),
      (834.0, 1194.0, false, true, false),
      (1194.0, 834.0, true, false, true),
      (1366.0, 1024.0, true, false, true),
    ]) {
      testWidgets('${c.$1.toInt()}×${c.$2.toInt()}', (tester) async {
        await pumpViewer(tester, size: Size(c.$1, c.$2));
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<RefFilmstrip>(find.byType(RefFilmstrip)).vertical,
          c.$3,
          reason: '縮圖列方向',
        );
        if (c.$3) {
          expect(find.byType(RefBottomToolbar), findsNothing);
          expect(find.byType(RefFloatingBar), findsOneWidget);
        } else {
          expect(
            tester
                .widget<RefBottomToolbar>(find.byType(RefBottomToolbar))
                .showLabels,
            c.$4,
          );
          expect(find.byType(RefZoomChip), findsOneWidget);
        }
        // 資料面板（分類／tag／加入日期）只在 ≥840 直接顯示。
        expect(find.text('分類'), c.$5 ? findsOneWidget : findsNothing);
        expect(find.text('#角色1'), c.$5 ? findsOneWidget : findsNothing);
        expect(
          find.text('2026 / 09 / 21 加入'),
          c.$5 ? findsOneWidget : findsNothing,
        );
        expect(find.text('坑A · 官方圖冊'), findsOneWidget);
        expect(find.text('1 / 3'), findsOneWidget);
        // 工具列文字：窄版只有 icon。
        expect(
          find.text('左右翻轉'),
          (c.$4 || c.$3) ? findsOneWidget : findsNothing,
        );
        await unmount(tester);
      });
    }

    testWidgets('390 版：資料收在「更多」', (tester) async {
      await pumpViewer(tester, size: const Size(390, 844));
      await tester.tap(tool('更多'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('分類'), findsOneWidget);
      expect(find.text('設定圖'), findsOneWidget);
      expect(find.text('#服裝參考'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('資料面板可以開關，拉窄再拉寬時開關狀態保留', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      expect(find.text('分類'), findsOneWidget);
      await tester.tap(tool('資料面板'));
      await settle(tester);
      expect(find.text('分類'), findsNothing);
      sizeTo(tester, const Size(500, 900));
      await settle(tester);
      sizeTo(tester, const Size(1194, 834));
      await settle(tester);
      expect(find.text('分類'), findsNothing, reason: '關閉的狀態沒有因拉窗而重置');
      await unmount(tester);
    });

    testWidgets('寬版資料面板有動作列（設為封面／下載／分享／編輯／刪除只在有來源時）', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      // 沒有 album 來源 → 沒有動作。
      expect(find.text('下載'), findsNothing);
      await unmount(tester);
    });
  });

  group('檢視狀態', () {
    testWidgets('縮放、鎖定、位置存起來；離開再進來原位還原', (tester) async {
      await pumpViewer(tester);
      expect(percentShown(), 100);
      await pinch(tester);
      final zoomed = percentShown();
      expect(zoomed, greaterThan(150));
      await tester.tap(find.byType(RefZoomChip));
      await settle(tester);
      expect(find.textContaining('已鎖定'), findsOneWidget);
      final before = stage(tester).currentSnapshot();
      await unmount(tester);

      final saved = await tester.runAsync(() => db.getRefViewState('a.png'));
      expect(saved, isNotNull);
      expect(saved!.locked, isTrue);
      expect(saved.zoom, closeTo(before.zoom, 1e-6));
      expect(saved.scale, closeTo(before.scale, 1e-6));

      await pumpViewer(tester);
      expect(percentShown(), zoomed);
      expect(find.textContaining('已鎖定'), findsOneWidget);
      final after = stage(tester).currentSnapshot();
      expect(after.zoom, closeTo(before.zoom, 1e-6));
      expect(after.centerX, closeTo(before.centerX, 1e-6));
      expect(after.centerY, closeTo(before.centerY, 1e-6));
      await unmount(tester);
    });

    testWidgets('切到背景（App 切換）時馬上存檔', (tester) async {
      await pumpViewer(tester);
      await pinch(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      final saved = await tester.runAsync(() => db.getRefViewState('a.png'));
      expect(saved, isNotNull);
      expect(saved!.zoom, greaterThan(1.5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await unmount(tester);
    });

    testWidgets('鎖定縮放時拉窗（含轉方向）不重新 fit：絕對縮放不變、中央仍是同一點', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      await pinch(tester);
      // 點「鎖定縮放」。
      await tester.tap(find.text('鎖定縮放'));
      await settle(tester);
      final before = stage(tester).currentSnapshot();
      expect(before.locked, isTrue);
      for (final size in const [
        Size(404, 900),
        Size(834, 1194),
        Size(1366, 1024),
        Size(390, 844),
      ]) {
        sizeTo(tester, size);
        await settle(tester);
        expect(tester.takeException(), isNull);
        final now = stage(tester).currentSnapshot();
        expect(now.locked, isTrue);
        expect(now.scale, closeTo(before.scale, 1e-6), reason: '$size 絕對縮放');
        expect(now.centerX, closeTo(before.centerX, 1e-6), reason: '$size');
        expect(now.centerY, closeTo(before.centerY, 1e-6), reason: '$size');
      }
      await unmount(tester);
    });

    testWidgets('沒鎖定時拉窗也不彈回 fit：保持倍數與位置', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      await pinch(tester);
      final before = stage(tester).currentSnapshot();
      expect(before.zoom, greaterThan(1.5));
      sizeTo(tester, const Size(834, 1194));
      await settle(tester);
      final now = stage(tester).currentSnapshot();
      expect(now.zoom, closeTo(before.zoom, 1e-6));
      expect(now.centerX, closeTo(before.centerX, 1e-6));
      expect(now.centerY, closeTo(before.centerY, 1e-6));
      await unmount(tester);
    });

    testWidgets('鎖定縮放後捏合不再縮放，仍可平移', (tester) async {
      await pumpViewer(tester);
      await tester.tap(find.byType(RefZoomChip));
      await settle(tester);
      await pinch(tester);
      expect(percentShown(), 100);
      await unmount(tester);
    });

    testWidgets('每張圖各自一份狀態', (tester) async {
      await pumpViewer(tester);
      await tester.tap(find.byType(RefZoomChip)); // 第 1 張鎖定
      await settle(tester);
      expect(find.textContaining('已鎖定'), findsOneWidget);
      await tester.tap(tool('第 2 張'));
      await settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.textContaining('未鎖定'), findsOneWidget);
      await tester.tap(tool('第 1 張'));
      await settle(tester);
      expect(find.textContaining('已鎖定'), findsOneWidget);
      await unmount(tester);
      expect(
        (await tester.runAsync(() => db.getRefViewState('a.png')))!.locked,
        isTrue,
      );
    });

    testWidgets('flags: 翻轉、灰階、背景是檢視狀態：會存，但不改原圖檔', (tester) async {
      final bytesBefore = original.readAsBytesSync();
      final mtime = original.lastModifiedSync();
      await pumpViewer(tester, size: const Size(1194, 834));
      await tester.tap(find.text('左右翻轉'));
      await tester.pump();
      await tester.tap(find.text('灰階'));
      await tester.pump();
      await tester.tap(find.text('背景'));
      await settle(tester);
      expect(find.byType(ColorFiltered), findsWidgets);
      await unmount(tester);
      final s = (await tester.runAsync(() => db.getRefViewState('a.png')))!;
      expect(s.flipped, isTrue);
      expect(s.gray, isTrue);
      expect(s.lightBg, isTrue);
      expect(original.readAsBytesSync(), bytesBefore);
      expect(original.lastModifiedSync(), mtime);

      await pumpViewer(tester, size: const Size(1194, 834));
      expect(stage(tester).currentSnapshot().flipped, isTrue);
      await unmount(tester);
    });

    testWidgets('背景切到淺色後整頁換成淺色配色', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      Color paneBg() => tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((e) => e.color)
          .firstWhere(
            (c) => c == const Color(0xFF1E1B18) || c == const Color(0xFFF3EFE9),
          );
      expect(paneBg(), const Color(0xFF1E1B18));
      await tester.tap(find.text('背景'));
      await settle(tester);
      expect(paneBg(), const Color(0xFFF3EFE9));
      await unmount(tester);
    });

    testWidgets('翻轉時視窗中央那一點不動', (tester) async {
      await pumpViewer(tester, size: const Size(1194, 834));
      await pinch(tester);
      final before = stage(tester).currentSnapshot();
      await tester.tap(find.text('左右翻轉'));
      await settle(tester);
      final now = stage(tester).currentSnapshot();
      expect(now.flipped, isTrue);
      expect(now.centerX, closeTo(before.centerX, 1e-6));
      expect(now.centerY, closeTo(before.centerY, 1e-6));
      expect(now.zoom, closeTo(before.zoom, 1e-6));
      await unmount(tester);
    });
  });

  group('資料面板動作（官方圖）', () {
    testWidgets('刪除：確認後從資料庫與檢視器拿掉', (tester) async {
      final pitId = await tester.runAsync(() => db.createPit(name: '坑A'));
      final groupId = (await tester.runAsync(
        () => db.watchGroups(pitId!).first,
      ))!.first.id;
      await tester.runAsync(
        () => db.addOfficial(pitId!, groupId, const [
          NewImage(file: 'a.png', width: 10, height: 10),
          NewImage(file: 'b.png', width: 10, height: 10),
        ]),
      );
      final rows = (await tester.runAsync(
        () => db.select(db.officialImages).get(),
      ))!;
      final images = [
        for (final r in rows)
          RefImage.fromAlbum(
            AlbumImage(
              id: r.id,
              file: r.imageFile,
              width: 10,
              height: 10,
              kind: AlbumKind.official,
              groupName: '設定圖',
              groupId: groupId,
              createdAt: DateTime(2026, 9, 21),
            ),
            pitId: pitId!,
            title: '坑A · 官方圖冊',
          ),
      ];
      await pumpViewer(tester, size: const Size(1194, 834), images: images);
      expect(find.text('1 / 2'), findsOneWidget);
      for (final t in ['設為封面', '下載', '分享', '編輯', '刪除']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.tap(find.text('刪除'));
      await settle(tester);
      // 確認框。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      final left = (await tester.runAsync(
        () => db.select(db.officialImages).get(),
      ))!;
      expect(left.where((r) => r.deletedAt == null), hasLength(1));
      await unmount(tester);
    });
  });
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
