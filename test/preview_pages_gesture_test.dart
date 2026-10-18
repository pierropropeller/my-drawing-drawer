import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/common/dismissible_preview.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';

/// 各個「看大圖」預覽頁都套用了共用手勢（點一下收起 UI、垂直拖曳退出）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitId;
  final nav = GlobalKey<NavigatorState>();

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('preview_gesture');
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

  /// 把 [page] 推在首頁上（pop 之後回到首頁才驗得到「退出」）。
  Future<void> pushPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
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
          navigatorKey: nav,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: const Text('home'),
        ),
      ),
    );
    // ignore: unawaited_futures
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  double opacityOf(WidgetTester tester, Finder f) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;

  Offset center(WidgetTester tester) =>
      tester.getCenter(find.byType(PreviewMediaArea).first);

  group('官方圖冊預覽 ImagePreviewPage', () {
    testWidgets('點一下圖片收起標題列／操作列，再點叫出', (tester) async {
      await pushPage(
        tester,
        ImagePreviewPage(
          pitId: pitId,
          images: images(AlbumKind.official),
          initialIndex: 0,
        ),
      );
      expect(opacityOf(tester, find.text('分享')), 1);
      expect(opacityOf(tester, find.text('1 / 2')), 1);
      await tester.tapAt(center(tester));
      await settle(tester);
      expect(opacityOf(tester, find.text('分享')), 0);
      expect(opacityOf(tester, find.text('1 / 2')), 0);
      // 收起後只剩圖片：頁面還在。
      expect(find.byType(ImagePreviewPage), findsOneWidget);
      await tester.tapAt(center(tester));
      await settle(tester);
      expect(opacityOf(tester, find.text('分享')), 1);
      await unmount(tester);
    });

    testWidgets('垂直拖曳超過門檻退出；未過門檻彈回', (tester) async {
      await pushPage(
        tester,
        ImagePreviewPage(
          pitId: pitId,
          images: images(AlbumKind.official),
          initialIndex: 0,
        ),
      );
      final g = await tester.startGesture(center(tester));
      await g.moveBy(const Offset(0, 40));
      await g.up();
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ImagePreviewPage), findsOneWidget);
      await tester.dragFrom(center(tester), const Offset(0, 260));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ImagePreviewPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('第一張再往右拖退出；中間往右則是回上一張', (tester) async {
      await pushPage(
        tester,
        ImagePreviewPage(
          pitId: pitId,
          images: images(AlbumKind.official),
          initialIndex: 1,
        ),
      );
      expect(find.text('2 / 2'), findsOneWidget);
      // 在最後一張往右拖＝回上一張（不退出）。
      await tester.dragFrom(center(tester), const Offset(300, 0));
      await settle(tester);
      expect(find.byType(ImagePreviewPage), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      // 現在在第一張，再往右拖＝退出。
      await tester.dragFrom(center(tester), const Offset(300, 0));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ImagePreviewPage), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('同人圖預覽：點一下收起 UI、垂直拖曳退出', (tester) async {
    await pushPage(
      tester,
      FanArtPreviewPage(
        pitId: pitId,
        images: images(AlbumKind.fanArt),
        initialIndex: 0,
      ),
    );
    await tester.tapAt(center(tester));
    await settle(tester);
    expect(opacityOf(tester, find.text('1 / 2')), 0);
    await tester.dragFrom(center(tester), const Offset(0, -260));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FanArtPreviewPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('詳情頁輪播的全螢幕預覽 ImageGalleryPage', (tester) async {
    await pushPage(
      tester,
      const ImageGalleryPage(
        images: [ImageRef('a.png', 100, 150), ImageRef('b.png', 100, 150)],
      ),
    );
    expect(opacityOf(tester, find.text('分享')), 1);
    await tester.tapAt(center(tester));
    await settle(tester);
    expect(opacityOf(tester, find.text('分享')), 0);
    await tester.tapAt(center(tester));
    await settle(tester);
    await tester.dragFrom(center(tester), const Offset(0, 260));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ImageGalleryPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('參考圖檢視：點舞台收起 UI（含返回鍵）、垂直拖曳退出', (tester) async {
    await pushPage(
      tester,
      const ReferenceViewerPage(
        images: [RefImage(id: 'a', file: 'a.png', width: 100, height: 150)],
        initialIndex: 0,
      ),
    );
    expect(find.byType(ReferenceViewer), findsOneWidget);
    final stage = tester.getCenter(
      find.descendant(
        of: find.byType(ReferenceViewer),
        matching: find.byType(PreviewMediaArea),
      ),
    );
    final back = find.bySemanticsLabel('返回');
    expect(opacityOf(tester, find.text('1 / 1')), 1);
    await tester.tapAt(stage);
    await settle(tester);
    expect(opacityOf(tester, find.text('1 / 1')), 0);
    expect(
      tester
          .widget<IgnorePointer>(
            find.ancestor(of: back, matching: find.byType(IgnorePointer)).first,
          )
          .ignoring,
      isTrue,
    ); // 收起時返回鍵不可點
    await tester.tapAt(stage);
    await settle(tester);
    expect(opacityOf(tester, find.text('1 / 1')), 1);
    // 未過門檻：彈回。
    Future<void> dragSteps(double dy) async {
      final g = await tester.startGesture(stage);
      for (var i = 0; i < dy / 10; i++) {
        await g.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
    }

    await dragSteps(40);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ReferenceViewer), findsOneWidget);
    // 過門檻：退出。
    await dragSteps(260);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ReferenceViewer), findsNothing);
    await unmount(tester);
  });
}
