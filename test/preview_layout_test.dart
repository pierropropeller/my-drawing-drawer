import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/tables.dart' show TagTarget;
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/preview_shell.dart';
import 'package:huakeng/ui/common/dismissible_preview.dart';
import 'package:huakeng/ui/common/media_source.dart';
import 'package:huakeng/ui/common/media_widgets.dart' show MediaViewer;
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/preview_layout.dart';

/// 預覽頁版面（手機 390x844）：圖片區鋪滿整個螢幕（放大時也是）、頂欄／底欄 80% 不透明疊在圖上、
/// 長圖（高 > 寬）寬度鋪滿貼齊最上面並垂直捲動、資訊區靠左。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitId;
  const screen = Size(390, 844);

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('preview_layout');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pushPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
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

  /// 一個用 [PreviewShell] 組出來的預覽頁；[sizes] 是每張圖的 (寬, 高)。
  Widget shell(List<(int, int)> sizes, {PageController? controller}) {
    final c = controller ?? PageController();
    return PreviewShell(
      title: '坑A · 官方圖冊',
      counter: '1 / ${sizes.length}',
      controller: c,
      media: [
        for (var i = 0; i < sizes.length; i++)
          MediaSource(file: 'p$i.png', width: sizes[i].$1, height: sizes[i].$2),
      ],
      currentIndex: 0,
      onPageChanged: (_) {},
      info: const Padding(
        padding: EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: Text('資訊區'),
      ),
      actions: [PreviewAction('', '分享', () {})],
    );
  }

  Finder viewer() => find.byType(InteractiveViewer).first;

  TransformationController tcOf(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(viewer()).transformationController!;

  Offset center(WidgetTester tester) =>
      tester.getCenter(find.byType(PreviewMediaArea).first);

  double opacityOf(WidgetTester tester, Finder f) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;

  Future<void> pinchOut(WidgetTester tester, Offset at) async {
    final a = await tester.startGesture(at - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(at + const Offset(20, 0), pointer: 2);
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(at - Offset(20.0 + i * 12, 0));
      await b.moveTo(at + Offset(20.0 + i * 12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('版面：圖片區鋪滿整個螢幕，頂欄／底欄疊在上面', () {
    testWidgets('圖片區（IV）＝整個螢幕；兩個橫幅底色是預覽底色 80%', (tester) async {
      await pushPage(tester, shell([(300, 200)]));
      expect(tester.getRect(viewer()), Offset.zero & screen);
      final banner = PreviewLayout.bannerOf(PreviewPalette.bg);
      expect(banner.a, closeTo(0.8, 0.001));
      final n = tester
          .widgetList<ColoredBox>(
            find.descendant(
              of: find.byType(PreviewLayout),
              matching: find.byType(ColoredBox),
            ),
          )
          .where((b) => b.color == banner)
          .length;
      expect(n, 2);
      expect(tester.getRect(find.text('坑A · 官方圖冊')).top, lessThan(80));
      final action = tester.getRect(find.text('分享'));
      expect(action.bottom, lessThanOrEqualTo(screen.height));
      expect(action.top, greaterThan(screen.height - 140));
      await unmount(tester);
    });

    testWidgets('寬圖：原樣置中在兩個橫幅之間；收起橫幅時圖不動', (tester) async {
      await pushPage(tester, shell([(300, 200)]));
      final header = tester.getRect(find.text('坑A · 官方圖冊'));
      final footer = tester.getRect(find.text('資訊區'));
      Rect box() => tester.getRect(
        find.descendant(of: viewer(), matching: find.byType(MediaViewer)).first,
      );
      final before = box();
      expect(before.top, greaterThan(header.bottom));
      expect(before.bottom, lessThan(footer.top));
      await tester.tapAt(center(tester));
      await settle(tester);
      expect(opacityOf(tester, find.text('分享')), 0);
      expect(box(), before);
      await unmount(tester);
    });

    testWidgets('雙指放大：視窗仍是整個螢幕、放大後內容涵蓋頂欄與底欄範圍；放大中垂直拖曳不退出', (tester) async {
      await pushPage(tester, shell([(300, 200)]));
      final tc = tcOf(tester);
      expect(tc.value.getMaxScaleOnAxis(), 1);
      await pinchOut(tester, center(tester));
      expect(tc.value.getMaxScaleOnAxis(), greaterThan(1.5));
      expect(tester.getRect(viewer()), Offset.zero & screen);
      final content = MatrixUtils.transformRect(tc.value, Offset.zero & screen);
      expect(content.top, lessThanOrEqualTo(0));
      expect(content.bottom, greaterThanOrEqualTo(screen.height));
      expect(content.height, greaterThan(screen.height * 1.5));
      await tester.dragFrom(center(tester), const Offset(0, 300));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PreviewShell), findsOneWidget);
      await unmount(tester);
    });
  });

  group('長圖（高 > 寬）', () {
    testWidgets('寬度＝螢幕寬度、貼齊最上面（y=0，在頂欄底下），高度依比例', (tester) async {
      await pushPage(tester, shell([(100, 400)]));
      final child =
          tester.widget<InteractiveViewer>(viewer()).child as SizedBox;
      expect(child.width, 390);
      expect(child.height, closeTo(1560, 0.01));
      final box = find.descendant(
        of: viewer(),
        matching: find.byType(SizedBox),
      );
      expect(tester.getTopLeft(box.first), Offset.zero);
      expect(tcOf(tester).value.getTranslation().y, 0);
      // 頂欄疊在圖上：頂欄文字落在圖片範圍內。
      expect(tester.getRect(find.text('坑A · 官方圖冊')).top, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('垂直拖曳＝捲動（像條漫），不退出；捲到底為止', (tester) async {
      await pushPage(tester, shell([(100, 400)]));
      final tc = tcOf(tester);
      await tester.dragFrom(center(tester), const Offset(0, -300));
      await settle(tester);
      expect(find.byType(PreviewShell), findsOneWidget);
      expect(tc.value.getTranslation().y, closeTo(-300, 40));
      expect(tc.value.getMaxScaleOnAxis(), 1);
      for (var i = 0; i < 6; i++) {
        await tester.dragFrom(center(tester), const Offset(0, -400));
        await settle(tester);
      }
      expect(find.byType(PreviewShell), findsOneWidget);
      expect(tc.value.getTranslation().y, closeTo(-(1560 - 844), 1));
      await unmount(tester);
    });

    testWidgets('捲到一半往下拉＝捲回去、不退出；回到最上面再往下拉才退出', (tester) async {
      await pushPage(tester, shell([(100, 400)]));
      final tc = tcOf(tester);
      await tester.dragFrom(center(tester), const Offset(0, -500));
      await settle(tester);
      final y1 = tc.value.getTranslation().y;
      expect(y1, lessThan(-300));
      await tester.dragFrom(center(tester), const Offset(0, 200));
      await settle(tester);
      expect(find.byType(PreviewShell), findsOneWidget);
      expect(tc.value.getTranslation().y, greaterThan(y1));
      // 捲回最上面。
      await tester.dragFrom(center(tester), const Offset(0, 400));
      await settle(tester);
      await tester.dragFrom(center(tester), const Offset(0, 400));
      await settle(tester);
      expect(tc.value.getTranslation().y, closeTo(0, 1));
      expect(find.byType(PreviewShell), findsOneWidget);
      // 停在最上面再往下拉：退出。
      await tester.dragFrom(center(tester), const Offset(0, 260));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PreviewShell), findsNothing);
      await unmount(tester);
    });

    testWidgets('停在最上面往上拖＝捲動，不退出', (tester) async {
      await pushPage(tester, shell([(100, 400)]));
      await tester.dragFrom(center(tester), const Offset(0, -260));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PreviewShell), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('點一下圖：橫幅收起／叫出；雙指放大仍可用且視窗是整個螢幕', (tester) async {
      await pushPage(tester, shell([(100, 400)]));
      expect(opacityOf(tester, find.text('分享')), 1);
      await tester.tapAt(center(tester));
      await settle(tester);
      expect(opacityOf(tester, find.text('分享')), 0);
      expect(opacityOf(tester, find.text('坑A · 官方圖冊')), 0);
      await tester.tapAt(center(tester));
      await settle(tester);
      expect(opacityOf(tester, find.text('分享')), 1);
      await pinchOut(tester, center(tester));
      expect(tcOf(tester).value.getMaxScaleOnAxis(), greaterThan(1.5));
      expect(tester.getRect(viewer()), Offset.zero & screen);
      await unmount(tester);
    });

    testWidgets('不用捲動的矮長圖（100x150）：貼齊最上面，垂直拖曳照樣退出', (tester) async {
      await pushPage(tester, shell([(100, 150)]));
      final tc = tcOf(tester);
      await tester.dragFrom(center(tester), const Offset(0, -80));
      await settle(tester);
      expect(tc.value.getTranslation().y, closeTo(0, 0.5));
      await tester.dragFrom(center(tester), const Offset(0, -260));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PreviewShell), findsNothing);
      await unmount(tester);
    });

    testWidgets('多張圖：長圖與寬圖混排，水平拖曳照常換頁', (tester) async {
      final c = PageController();
      await pushPage(tester, shell([(100, 400), (300, 200)], controller: c));
      await tester.dragFrom(center(tester), const Offset(-300, 0));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.page, 1);
      // 換到寬圖：IV 是整個螢幕大的（constrained）。
      expect(tester.widget<InteractiveViewer>(viewer()).constrained, isTrue);
      await unmount(tester);
    });
  });

  group('資訊區靠左（設計稿 padding 8/24/14，左對齊）', () {
    testWidgets('官方圖冊預覽：分組標、tag、日期都靠左', (tester) async {
      final tagId = await db.createTag(pitId, 'Clawd');
      await db.setTags(TagTarget.official, 'a.png', [tagId]);
      await pushPage(
        tester,
        ImagePreviewPage(
          pitId: pitId,
          images: [
            AlbumImage(
              id: 'a.png',
              file: 'a.png',
              width: 300,
              height: 200,
              kind: AlbumKind.official,
              groupName: '海報宣傳',
              createdAt: DateTime(2026, 10, 24),
            ),
          ],
          initialIndex: 0,
        ),
      );
      expect(tester.getTopLeft(find.text('海報宣傳')).dx, closeTo(24 + 9, 0.5));
      expect(tester.getTopLeft(find.text('#Clawd')).dx, closeTo(24 + 10, 0.5));
      expect(tester.getTopLeft(find.text('2026 / 10 / 24 加入')).dx, 24);
      await unmount(tester);
    });

    testWidgets('同人圖預覽：作者、tag、日期都靠左', (tester) async {
      final tagId = await db.createTag(pitId, '夏日企劃');
      await db.setTags(TagTarget.fanArt, 'a.png', [tagId]);
      await pushPage(
        tester,
        FanArtPreviewPage(
          pitId: pitId,
          images: [
            AlbumImage(
              id: 'a.png',
              file: 'a.png',
              width: 300,
              height: 200,
              kind: AlbumKind.fanArt,
              author: '@illust_ka',
              groupName: '推特',
              createdAt: DateTime(2026, 10, 24),
            ),
          ],
          initialIndex: 0,
        ),
      );
      expect(tester.getTopLeft(find.text('@illust_ka')).dx, 24);
      expect(tester.getTopLeft(find.text('#夏日企劃')).dx, closeTo(24 + 10, 0.5));
      expect(tester.getTopLeft(find.text('2026 / 10 / 24 加入')).dx, 24);
      await unmount(tester);
    });
  });
}
