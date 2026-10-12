import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/common/detail_carousel.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';

/// 詳情頁圖片框（D-073）：比例規則、框固定、contain、頁碼膠囊、點圖開看圖。
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('detail_frame'));

  const wide = ImageRef('w.png', 400, 300); // 4:3
  const tall = ImageRef('t.png', 300, 400); // 3:4
  const veryTall = ImageRef('vt.png', 100, 400); // 1:4
  const flat = ImageRef('f.png', 1000, 300); // 3.33:1
  const square = ImageRef('s.png', 50, 50);
  const unknown = ImageRef('u.png', 0, 0);

  group('detailFrameAspect', () {
    test('tallest image decides', () {
      expect(detailFrameAspect([wide, square, const ImageRef('x', 4, 5)]), 0.8);
      expect(detailFrameAspect([wide, tall]), 3 / 4);
    });
    test('clamps at 3:4 and 1.91:1', () {
      expect(detailFrameAspect([wide, veryTall]), 3 / 4);
      expect(detailFrameAspect([flat]), 1.91);
      expect(detailFrameAspect([flat, flat]), 1.91);
    });
    test('single image uses its own ratio', () {
      expect(detailFrameAspect([wide]), closeTo(4 / 3, 1e-9));
      expect(detailFrameAspect([tall]), 3 / 4);
    });
    test('unknown size counts as 1:1; empty uses fallback', () {
      expect(detailFrameAspect([unknown]), 1);
      expect(detailFrameAspect([wide, unknown]), 1);
      expect(detailFrameAspect(const [], emptyAspect: 4 / 3), 4 / 3);
    });
  });

  Future<void> show(
    WidgetTester tester,
    List<ImageRef> images, {
    bool dark = false,
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // 圖檔真的存在，才會走 Image.file（而不是「尚未下載」的佔位）。
    Directory('${dir.path}/images').createSync(recursive: true);
    for (final im in images) {
      File('${dir.path}/images/${im.file}')
          .writeAsBytesSync(Uint8List.fromList(_png1x1));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 圖都視為已在本機，走 Image.file 而不是「尚未下載」佔位。
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: ListView(children: [DetailCarousel(images: images)]),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder frame() => find.byType(DetailCarousel);
  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('frame is 3:4 from the tallest image and never jumps', (
    tester,
  ) async {
    await show(tester, [wide, tall, square]);
    final before = tester.getSize(frame());
    expect(before.width, 360);
    expect(before.height, closeTo(480, 0.01));
    await swipe(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(tester.getSize(frame()), before);
    await swipe(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(tester.getSize(frame()), before);
  });

  testWidgets('single landscape image: frame is its own ratio, no pill', (
    tester,
  ) async {
    await show(tester, [wide]);
    final s = tester.getSize(frame());
    expect(s.width / s.height, closeTo(4 / 3, 0.001));
    expect(find.byKey(const ValueKey('detailPagePill')), findsNothing);
  });

  testWidgets('very flat single image clamps to 1.91:1', (tester) async {
    await show(tester, [flat]);
    final s = tester.getSize(frame());
    expect(s.width / s.height, closeTo(1.91, 0.001));
  });

  testWidgets('images use contain, letterbox color fills the rest', (
    tester,
  ) async {
    await show(tester, [wide, tall]);
    final img = tester.widget<StoredImage>(find.byType(StoredImage).first);
    expect(img.fit, BoxFit.contain);
    final raw = tester.widget<Image>(find.byType(Image).first);
    expect(raw.fit, BoxFit.contain);
    final bg = tester.widget<ColoredBox>(
      find.descendant(of: frame(), matching: find.byType(ColoredBox)).first,
    );
    expect(bg.color, const Color(0xFFEFE8DE));
  });

  testWidgets('pill sits at the frame top-right and stays put', (tester) async {
    await show(tester, [wide, tall]);
    final pill = find.byKey(const ValueKey('detailPagePill'));
    expect(find.text('1 / 2'), findsOneWidget);
    final f = tester.getRect(frame());
    final p = tester.getRect(pill);
    expect(f.right - p.right, closeTo(12, 0.01));
    expect(p.top - f.top, closeTo(12, 0.01));
    final deco = tester.widget<Container>(pill).decoration as BoxDecoration;
    expect(deco.color, const Color(0xFF2B2622).withValues(alpha: .62));
    await swipe(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.getRect(pill).topRight, p.topRight);
  });

  testWidgets('tap opens the full-screen viewer at that index', (tester) async {
    await show(tester, [wide, tall]);
    await swipe(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(tester.getCenter(frame()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final g = tester.widget<ImageGalleryPage>(find.byType(ImageGalleryPage));
    expect(g.initialIndex, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dark mode and tablet width build without errors', (
    tester,
  ) async {
    await show(tester, [wide, tall], dark: true, size: const Size(2400, 1600));
    expect(tester.takeException(), isNull);
    final s = tester.getSize(frame());
    expect(s.height, lessThanOrEqualTo(1600 / 3 * 0.62 + 0.01));
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
