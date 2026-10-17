import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';

/// 從官方圖冊／同人圖預覽頁進入參考圖檢視（入口只在 ≥600，手機版面不變）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('ref_entry');
    await Directory('${tmp.path}/images').create(recursive: true);
    for (final n in ['a.png', 'b.png']) {
      File('${tmp.path}/images/$n').writeAsBytesSync([0, 1, 2]);
    }
    pitId = await db.createPit(name: '坑A');
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  List<AlbumImage> images(AlbumKind kind) => [
    for (final n in ['a.png', 'b.png'])
      AlbumImage(
        id: n,
        file: n,
        width: 100,
        height: 150,
        kind: kind,
        groupName: '設定圖',
        createdAt: DateTime(2026, 9, 21),
      ),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpPage(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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
          home: page,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('手機寬度（<600）預覽頁沒有入口，版面維持原樣', (tester) async {
    await pumpPage(
      tester,
      ImagePreviewPage(
        pitId: pitId,
        images: images(AlbumKind.official),
        initialIndex: 0,
      ),
      const Size(390, 844),
    );
    expect(find.byType(RefEntryChip), findsNothing);
    await unmount(tester);
  });

  testWidgets('官方圖預覽（834）：點「參考檢視」開檢視器，返回回到預覽', (tester) async {
    await pumpPage(
      tester,
      ImagePreviewPage(
        pitId: pitId,
        images: images(AlbumKind.official),
        initialIndex: 1,
      ),
      const Size(834, 1194),
    );
    expect(find.byType(RefEntryChip), findsOneWidget);
    await tester.tap(find.byType(RefEntryChip));
    await settle(tester);
    expect(find.byType(ReferenceViewer), findsOneWidget);
    // 從目前這張（第 2 張）開始，標題是「坑A · 官方圖冊」。
    expect(find.text('2 / 2'), findsWidgets);
    expect(find.text('坑A · 官方圖冊'), findsWidgets);
    // 檢視器沒有導覽列（HidesNavBar）。
    expect(navBarHiddenCount.value, greaterThan(0));
    await tester.tap(
      find.descendant(
        of: find.byType(ReferenceViewer),
        matching: find.bySemanticsLabel('返回'),
      ),
    );
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ReferenceViewer), findsNothing);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('同人圖預覽（1194）也有入口', (tester) async {
    await pumpPage(
      tester,
      FanArtPreviewPage(
        pitId: pitId,
        images: images(AlbumKind.fanArt),
        initialIndex: 0,
      ),
      const Size(1194, 834),
    );
    expect(find.byType(RefEntryChip), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('openReferenceViewer：選到影片開影片檢視器，列表裡的影片不進圖片檢視器', (tester) async {
    late BuildContext ctx;
    await pumpPage(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
      const Size(834, 1194),
    );
    const vid = RefImage(
      id: 'v',
      file: 'v.mp4',
      kind: MediaKind.video,
      width: 1920,
      height: 1080,
    );
    const img = RefImage(id: 'a', file: 'a.png', width: 100, height: 150);
    // 影片：只開影片頁。
    // ignore: unawaited_futures
    openReferenceViewer(ctx, images: [img, vid], index: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RefVideoViewerPage), findsOneWidget);
    expect(find.byType(ReferenceViewer), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(RefVideoViewer),
        matching: find.bySemanticsLabel('返回'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // 圖片：影片被濾掉，1 / 1。
    // ignore: unawaited_futures
    openReferenceViewer(ctx, images: [vid, img], index: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.byType(ReferenceViewer), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    await unmount(tester);
  });
}
