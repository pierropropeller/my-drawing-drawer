import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart' show ImageRef;
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/detail_carousel.dart';
import 'package:huakeng/ui/common/media_mini.dart';
import 'package:huakeng/ui/common/media_widgets.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/sensitive_reveal.dart';
import 'package:huakeng/ui/common/sensitive_safe_button.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-113 ①：已標記的影片、GIF 在安全模式開時顯示「模糊的第一格」——影片＝poster、GIF＝第一格靜態，
/// 中間同樣的眼睛斜線圓，**不建立播放器、不解碼動畫**；列表、詳情頁（預覽頁一律正常）；
/// 也算「這頁有已標記的圖」（詳情頁標題列有安全模式鈕）。關閉安全模式後照常播放。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('sensitive_motion');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitId = await db.createPit(name: '坑A');
    await db.setPitSensitiveEnabled(pitId, true);
    final g = (await db.watchGroups(pitId).first).first.id;
    await db.addOfficial(pitId, g, const [
      NewImage(
        file: 'v.mp4',
        kind: MediaKind.video,
        durationMs: 5000,
        posterFile: 'v.jpg',
        sensitive: true,
      ),
      NewImage(file: 'g.gif', kind: MediaKind.gif, sensitive: true),
      NewImage(file: 'plain.png'),
      NewImage(
        file: 'pv.mp4',
        kind: MediaKind.video,
        durationMs: 5000,
        posterFile: 'pv.jpg',
      ),
      NewImage(file: 'pg.gif', kind: MediaKind.gif),
    ]);
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool safe = true,
    bool master = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'sensitiveEnabled': master,
      'safeMode': safe,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: home,
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

  const blur = ValueKey('sensitiveBlur');
  const circle = ValueKey('sensitiveCircle');
  const badge = ValueKey('sensitiveBadge');
  const button = ValueKey('sensitiveSafeButton');

  const video = MediaSource(
    file: 'v.mp4',
    kind: MediaKind.video,
    durationMs: 5000,
    poster: 'v.jpg',
  );
  const gif = MediaSource(file: 'g.gif', kind: MediaKind.gif);
  const plainVideo = MediaSource(
    file: 'pv.mp4',
    kind: MediaKind.video,
    durationMs: 5000,
    poster: 'pv.jpg',
  );
  const plainGif = MediaSource(file: 'pg.gif', kind: MediaKind.gif);

  bool safeMode(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(settingsProvider)
          .safeMode;

  Widget cell(Widget child) => SizedBox(width: 120, height: 120, child: child);

  group('列表縮圖 MediaThumb', () {
    testWidgets('安全模式開：已標記的 GIF 只畫模糊的第一格（不解碼動畫）、影片畫模糊的 poster；沒標記的照常', (
      tester,
    ) async {
      await pump(
        tester,
        Wrap(
          children: [
            cell(const MediaThumb(gif, key: ValueKey('g'))),
            cell(const MediaThumb(video, key: ValueKey('v'))),
            cell(const MediaThumb(plainGif, key: ValueKey('pg'))),
            cell(const MediaThumb(plainVideo, key: ValueKey('pv'))),
          ],
        ),
      );
      Finder within(String k, Finder f) =>
          find.descendant(of: find.byKey(ValueKey(k)), matching: f);
      expect(within('g', find.byKey(blur)), findsOneWidget);
      expect(within('g', find.byKey(circle)), findsOneWidget);
      expect(within('g', find.byType(GifImage)), findsNothing);
      expect(within('g', find.byType(FirstFrameImage)), findsOneWidget);
      expect(within('v', find.byKey(blur)), findsOneWidget);
      expect(within('v', find.byKey(circle)), findsOneWidget);
      // 沒標記的 GIF 照常自動播放。
      expect(within('pg', find.byKey(blur)), findsNothing);
      expect(within('pg', find.byType(GifImage)), findsOneWidget);
      expect(within('pv', find.byKey(blur)), findsNothing);
      await unmount(tester);
    });

    testWidgets('安全模式關：GIF 照常播放、左上角小標、不模糊', (tester) async {
      await pump(tester, cell(const MediaThumb(gif)), safe: false);
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsOneWidget);
      expect(find.byType(GifImage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('MiniMediaThumb（詳情頁縮圖列）的 GIF 也只畫第一格', (tester) async {
      await pump(
        tester,
        cell(
          const MiniMediaThumb(gif, sensitiveCircle: 24, sensitiveBadge: false),
        ),
      );
      expect(find.byKey(blur), findsOneWidget);
      expect(tester.getSize(find.byKey(circle)).width, 24);
      expect(find.byType(GifImage), findsNothing);
      await unmount(tester);
    });
  });

  group('詳情頁輪播 DetailImageStage', () {
    const images = [
      ImageRef(
        'v.mp4',
        1,
        1,
        kind: MediaKind.video,
        durationMs: 5000,
        poster: 'v.jpg',
        sensitive: true,
      ),
      ImageRef('g.gif', 1, 1, kind: MediaKind.gif, sensitive: true),
      ImageRef('plain.png', 1, 1),
    ];

    testWidgets('第 1 頁（已標記的影片）：安全模式開＝模糊 poster＋52px 圓，沒有播放器；縮圖列的 GIF 24px 圓', (
      tester,
    ) async {
      await pump(
        tester,
        const Scaffold(body: DetailImageStage(images: images)),
      );
      expect(find.byType(VideoPlayerView), findsNothing);
      final sizes = [
        for (final e in find.byKey(circle).evaluate())
          tester.getSize(find.byWidget(e.widget)).width,
      ]..sort();
      // 主圖（影片 52）＋縮圖列：影片 24、GIF 24。
      expect(sizes, [24, 24, 52]);
      expect(find.byType(GifImage), findsNothing);
      await unmount(tester);
    });

    testWidgets('安全模式關：影片出現播放器、不模糊', (tester) async {
      await pump(
        tester,
        const Scaffold(body: DetailImageStage(images: images)),
        safe: false,
      );
      expect(find.byKey(blur), findsNothing);
      expect(find.byType(VideoPlayerView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('翻到第 2 頁（已標記的 GIF）：模糊的第一格，不是 GifImage；點縮圖列切頁', (tester) async {
      await pump(
        tester,
        const Scaffold(body: DetailImageStage(images: images)),
      );
      await tester.tap(find.byType(MiniMediaThumb).at(1));
      await settle(tester);
      expect(find.byType(VideoPlayerView), findsNothing);
      expect(find.byType(GifImage), findsNothing);
      expect(find.byKey(blur), findsWidgets);
      await unmount(tester);
    });

    testWidgets('點模糊的影片頁＝開全螢幕預覽；預覽頁一律正常（不模糊、沒有安全模式鈕、影片可播）', (tester) async {
      await pump(
        tester,
        const Scaffold(body: DetailImageStage(images: images)),
      );
      await tester.tap(find.byType(PageView).first);
      await settle(tester);
      expect(find.byType(ImageGalleryPage), findsOneWidget);
      Finder inGallery(Finder f) =>
          find.descendant(of: find.byType(ImageGalleryPage), matching: f);
      expect(inGallery(find.byKey(blur)), findsNothing);
      expect(inGallery(find.byKey(circle)), findsNothing);
      expect(inGallery(find.byKey(button)), findsNothing);
      expect(inGallery(find.byType(VideoPlayerView)), findsOneWidget);
      await unmount(tester);
    });
  });

  group('詳情頁的安全模式鈕', () {
    testWidgets('只有影片是標記的 → 鈕出現；點一下關閉 → 影片出現播放器；再點又模糊且播放器拆掉', (tester) async {
      await pump(
        tester,
        const Scaffold(
          body: Column(
            children: [
              SensitiveSafeButton(files: ['v.mp4']),
              Expanded(
                child: DetailImageStage(
                  images: [
                    ImageRef(
                      'v.mp4',
                      1,
                      1,
                      kind: MediaKind.video,
                      durationMs: 5000,
                      poster: 'v.jpg',
                      sensitive: true,
                    ),
                    ImageRef('plain.png', 1, 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(button), findsOneWidget);
      expect(find.byKey(blur), findsWidgets);
      expect(find.byType(VideoPlayerView), findsNothing);

      await tester.tap(find.byKey(button));
      await settle(tester);
      expect(safeMode(tester), isFalse);
      expect(find.byKey(blur), findsNothing);
      expect(find.byType(VideoPlayerView), findsOneWidget);

      await tester.tap(find.byKey(button));
      await settle(tester);
      expect(safeMode(tester), isTrue);
      expect(find.byKey(blur), findsWidgets);
      expect(find.byType(VideoPlayerView), findsNothing);
      await unmount(tester);
    });

    testWidgets('flaggableFiles：影片、GIF 也算', (tester) async {
      expect(
        flaggableFiles(const [
          ImageRef('v.mp4', 1, 1, kind: MediaKind.video),
          ImageRef('g.gif', 1, 1, kind: MediaKind.gif),
          ImageRef('a.png', 1, 1),
        ]),
        ['v.mp4', 'g.gif', 'a.png'],
      );
    });
  });

  group('iPad 面板的單張顯示（SensitiveReveal，P-038）', () {
    testWidgets('影片：模糊時不建立播放器；撳開這一張才出現播放器，不影響安全模式', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SensitiveReveal(
            current: 'v.mp4',
            child: Stack(
              children: const [
                SizedBox(
                  width: 300,
                  height: 300,
                  child: SensitiveMediaViewer(video, showBadge: false),
                ),
                SensitiveRevealOverlayButton(),
              ],
            ),
          ),
        ),
      );
      expect(find.byKey(blur), findsOneWidget);
      expect(find.byType(VideoPlayerView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sensitiveRevealButton')));
      await settle(tester);
      expect(find.byKey(blur), findsNothing);
      expect(find.byType(VideoPlayerView), findsOneWidget);
      expect(safeMode(tester), isTrue);
      // 再按一次又模糊，播放器拆掉。
      await tester.tap(find.byKey(const ValueKey('sensitiveRevealButton')));
      await settle(tester);
      expect(find.byKey(blur), findsOneWidget);
      expect(find.byType(VideoPlayerView), findsNothing);
      await unmount(tester);
    });
  });
}
