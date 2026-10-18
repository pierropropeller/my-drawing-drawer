import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart' show ImageRef;
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/media_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/media/media_import.dart';
import 'package:huakeng/media/video_probe.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/detail_carousel.dart';
import 'package:huakeng/ui/common/media_widgets.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:image_picker/image_picker.dart';

/// 影片與 GIF（D-080）：標記、GIF 只在畫面上時動、影片不自動播、控制列自動隱藏、匯入判斷。
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('media_widgets'));
  tearDown(() => dir.deleteSync(recursive: true));

  Directory images() => Directory('${dir.path}/images')..createSync();

  Future<void> pumpApp(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ImageStore(images());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
          imageStoreProvider.overrideWith((ref) async => store),
          posterRequestProvider.overrideWithValue((_) {}),
          healedPosterProvider.overrideWith((ref, f) => Stream.value(null)),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('formatMediaDuration', () {
    test('m:ss、四捨五入、超過一小時加時', () {
      expect(formatMediaDuration(24000), '0:24');
      expect(formatMediaDuration(23600), '0:24');
      expect(formatMediaDuration(65000), '1:05');
      expect(formatMediaDuration(3723000), '1:02:03');
      expect(formatMediaDuration(null), '0:00');
    });
  });

  group('標記與格子', () {
    testWidgets('GIF 小標、影片小標＋長度、張數標記可同時出現', (tester) async {
      await pumpApp(
        tester,
        Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: MediaThumb(
                const MediaSource(file: 'a.gif', kind: MediaKind.gif),
                animate: false,
              ),
            ),
            SizedBox(
              width: 120,
              height: 120,
              child: MediaThumb(
                const MediaSource(
                  file: 'v.mp4',
                  kind: MediaKind.video,
                  durationMs: 65000,
                  poster: 'v.jpg',
                ),
                count: 3,
              ),
            ),
            const SizedBox(
              width: 120,
              height: 120,
              child: MediaThumb(MediaSource(file: 'p.png'), count: 2),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeGif')), findsOneWidget);
      expect(find.text('GIF'), findsOneWidget);
      expect(find.byKey(const ValueKey('badgeVideo')), findsOneWidget);
      expect(find.text('1:05'), findsOneWidget);
      // 影片格同時有左下角標記與右下角張數；圖片格只有張數。
      expect(find.byKey(const ValueKey('badgeCount')), findsNWidgets(2));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // 左下角在左、右下角在右。
      final video = tester.getRect(find.byKey(const ValueKey('badgeVideo')));
      final count = tester.getRect(find.text('3'));
      expect(video.center.dx, lessThan(count.center.dx));
      expect((video.bottom - count.bottom).abs(), lessThan(4));
    });

    testWidgets('showBadge: false 與一般圖片不畫小標', (tester) async {
      await pumpApp(
        tester,
        const Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: MediaThumb(
                MediaSource(file: 'a.gif', kind: MediaKind.gif),
                showBadge: false,
                animate: false,
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: MediaThumb(MediaSource(file: 'p.jpg')),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('badgeGif')), findsNothing);
      expect(find.byKey(const ValueKey('badgeVideo')), findsNothing);
    });

    testWidgets('影片格不自動播放：不建立播放器，只有 poster＋標記', (tester) async {
      var created = 0;
      await pumpApp(
        tester,
        const SizedBox(
          width: 200,
          height: 200,
          child: MediaThumb(
            MediaSource(
              file: 'v.mp4',
              kind: MediaKind.video,
              durationMs: 24000,
              poster: 'v.jpg',
            ),
          ),
        ),
        overrides: [
          playbackFactoryProvider.overrideWithValue((f) {
            created++;
            return FakePlayback();
          }),
        ],
      );
      await tester.pump(const Duration(seconds: 3));
      expect(created, 0);
      expect(find.byType(VideoPlayerView), findsNothing);
      expect(find.text('0:24'), findsOneWidget);
    });

    testWidgets('沒有 poster 的影片顯示佔位而不是壞圖', (tester) async {
      await pumpApp(
        tester,
        const SizedBox(
          width: 100,
          height: 100,
          child: MediaThumb(
            MediaSource(file: 'v.mp4', kind: MediaKind.video, durationMs: 5000),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MediaPlaceholder), findsOneWidget);
      expect(find.text('0:05'), findsOneWidget);
    });
  });

  group('GIF 只在畫面上時動', () {
    Finder animating(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byKey(const ValueKey('gifAnimating')),
    );
    Finder still(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byKey(const ValueKey('gifStill')),
    );

    testWidgets('捲出畫面的停止、捲進來的開始', (tester) async {
      for (var i = 0; i < 3; i++) {
        File('${images().path}/g$i.gif').writeAsBytesSync(_gif1x1);
      }
      await pumpApp(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(
                  key: ValueKey('tile$i'),
                  height: 600,
                  child: MediaThumb(
                    MediaSource(file: 'g$i.gif', kind: MediaKind.gif),
                    cacheWidth: 100,
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // 手機 360×800：第 0 格全在、第 1 格露出一截、第 2 格在畫面外。
      expect(animating('tile0'), findsOneWidget);
      expect(animating('tile1'), findsOneWidget);
      expect(animating('tile2'), findsNothing);
      expect(still('tile2'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(animating('tile0'), findsNothing);
      expect(still('tile0'), findsOneWidget);
      expect(animating('tile2'), findsOneWidget);
    });

    testWidgets('animate: false 與 StaticMediaImage 只畫第一格', (tester) async {
      File('${images().path}/g.gif').writeAsBytesSync(_gif1x1);
      await pumpApp(
        tester,
        const Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: MediaThumb(
                MediaSource(file: 'g.gif', kind: MediaKind.gif),
                animate: false,
              ),
            ),
            SizedBox(
              width: 100,
              height: 100,
              child: StaticMediaImage(
                MediaSource(file: 'g.gif', kind: MediaKind.gif),
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('gifAnimating')), findsNothing);
    });

    testWidgets('詳情頁的 GIF 不畫標記，active 為 false 時停止', (tester) async {
      File('${images().path}/g.gif').writeAsBytesSync(_gif1x1);
      Widget page(bool active) => SizedBox(
        width: 300,
        height: 300,
        child: MediaViewer(
          const MediaSource(file: 'g.gif', kind: MediaKind.gif),
          active: active,
        ),
      );
      await pumpApp(tester, page(true));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('gifAnimating')), findsOneWidget);
      expect(find.byKey(const ValueKey('badgeGif')), findsNothing);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageTransferProvider.overrideWith(
              (ref, file) => ImageDownloadStatus.present,
            ),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(images()),
            ),
            posterRequestProvider.overrideWithValue((_) {}),
            healedPosterProvider.overrideWith((ref, f) => Stream.value(null)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            home: Scaffold(body: page(false)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('gifAnimating')), findsNothing);
    });
  });

  group('FirstFrameImage 與詳情輪播', () {
    testWidgets('GIF 第一格解出後畫成 RawImage', (tester) async {
      File('${images().path}/g.gif').writeAsBytesSync(_gif1x1);
      await pumpApp(
        tester,
        SizedBox(
          width: 50,
          height: 50,
          child: FirstFrameImage(
            provider: FileImage(File('${images().path}/g.gif')),
          ),
        ),
      );
      // 解碼在真實的非同步裡，最多等 6 秒。
      for (var i = 0; i < 24 && find.byType(RawImage).evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
      }
      expect(find.byType(RawImage), findsOneWidget);
    });

    testWidgets('輪播：影片頁點一下播放不開預覽、GIF 頁無標記、換頁暫停影片', (tester) async {
      final fake = FakePlayback();
      File('${images().path}/v.mp4').writeAsBytesSync([0, 1, 2]);
      File('${images().path}/g.gif').writeAsBytesSync(_gif1x1);
      File('${images().path}/p.png').writeAsBytesSync(_png1x1);
      await pumpApp(
        tester,
        const DetailCarousel(
          images: [
            ImageRef(
              'v.mp4',
              1920,
              1080,
              kind: MediaKind.video,
              durationMs: 24000,
              poster: 'v.jpg',
            ),
            ImageRef('g.gif', 100, 100, kind: MediaKind.gif),
            ImageRef('p.png', 100, 100),
          ],
        ),
        overrides: [playbackFactoryProvider.overrideWithValue((f) => fake)],
      );
      await tester.pump();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('videoPlayButton')), findsOneWidget);
      expect(find.text('0:24'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('videoPoster')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(fake.isPlaying, isTrue);
      expect(find.byType(ImageGalleryPage), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2 / 3'), findsOneWidget);
      expect(fake.isPlaying, isFalse);
      expect(find.byKey(const ValueKey('badgeGif')), findsNothing);
      expect(find.byKey(const ValueKey('badgeVideo')), findsNothing);
    });
  });

  group('ControlsAutoHide', () {
    testWidgets('2 秒後隱藏、點一下叫出來、暫停時不隱藏', (tester) async {
      final h = ControlsAutoHide();
      addTearDown(h.dispose);
      h.show();
      expect(h.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(h.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(h.visible, isFalse);
      h.toggle(); // 點畫面叫出來
      expect(h.visible, isTrue);
      // 操作會重新倒數。
      await tester.pump(const Duration(milliseconds: 1500));
      h.show();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(h.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      expect(h.visible, isFalse);
      // 暫停（hold）：一直顯示，點畫面也收不起來。
      h.setHold(true);
      expect(h.visible, isTrue);
      await tester.pump(const Duration(seconds: 10));
      expect(h.visible, isTrue);
      h.toggle();
      expect(h.visible, isTrue);
      // 放開 hold 又開始倒數。
      h.setHold(false);
      await tester.pump(const Duration(seconds: 3));
      expect(h.visible, isFalse);
    });
  });

  group('VideoPlayerView（假播放器）', () {
    late FakePlayback fake;
    setUp(() {
      fake = FakePlayback();
      File('${images().path}/v.mp4').writeAsBytesSync([0, 1, 2]);
    });

    Future<void> mount(
      WidgetTester tester, {
      bool active = true,
      VideoFullscreenCallback? onFullscreen,
    }) => pumpApp(
      tester,
      SizedBox(
        width: 360,
        height: 450,
        child: VideoPlayerView(
          file: 'v.mp4',
          poster: 'v.jpg',
          durationMs: 24000,
          active: active,
          onFullscreen: onFullscreen,
        ),
      ),
      overrides: [playbackFactoryProvider.overrideWithValue((f) => fake)],
    );

    Future<void> startPlaying(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('videoPoster')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('未播放：圓形播放鍵＋左下角長度；點一下才播放、有聲音', (tester) async {
      await mount(tester);
      await tester.pump();
      expect(find.byKey(const ValueKey('videoPlayButton')), findsOneWidget);
      expect(find.text('0:24'), findsOneWidget);
      expect(find.byKey(const ValueKey('videoControlBar')), findsNothing);
      expect(fake.log, isEmpty);

      await startPlaying(tester);
      expect(fake.log, containsAllInOrder(['init', 'volume 1.0', 'play']));
      expect(fake.isPlaying, isTrue);
      expect(find.byKey(const ValueKey('videoControlBar')), findsOneWidget);
      expect(find.byKey(const ValueKey('videoPlayButton')), findsNothing);
      expect(find.text('0:08 / 0:24'), findsOneWidget);
    });

    double barOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byKey(const ValueKey('videoControlBar')),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('播放中 2 秒後控制列隱藏、點畫面再叫出來；暫停時不再隱藏', (tester) async {
      await mount(tester);
      await startPlaying(tester);
      expect(barOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(barOpacity(tester), 0);

      await tester.tapAt(const Offset(180, 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(barOpacity(tester), 1);

      // 按暫停：控制列固定顯示。
      await tester.tap(find.byKey(const ValueKey('videoPlayPause')));
      await tester.pump();
      expect(fake.isPlaying, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(barOpacity(tester), 1);
    });

    testWidgets('進度條可拖、靜音鍵切換音量、全螢幕鍵交給呼叫端並暫停', (tester) async {
      Duration? fsPos;
      bool? fsPlaying;
      await mount(
        tester,
        onFullscreen: (pos, playing) {
          fsPos = pos;
          fsPlaying = playing;
        },
      );
      await startPlaying(tester);

      await tester.drag(
        find.byKey(const ValueKey('videoScrubber')),
        const Offset(120, 0),
      );
      await tester.pump();
      expect(fake.log.where((e) => e.startsWith('seek')), isNotEmpty);
      expect(fake.position, greaterThan(Duration.zero));

      await tester.tap(find.byKey(const ValueKey('videoMute')));
      await tester.pump();
      expect(fake.volume, 0);
      await tester.tap(find.byKey(const ValueKey('videoMute')));
      await tester.pump();
      expect(fake.volume, 1);

      await tester.tap(find.byKey(const ValueKey('videoFullscreen')));
      await tester.pump();
      expect(fsPlaying, isTrue);
      expect(fsPos, isNotNull);
      expect(fake.isPlaying, isFalse);
    });

    testWidgets('滑到別頁（active 變 false）自動暫停', (tester) async {
      await mount(tester);
      await startPlaying(tester);
      expect(fake.isPlaying, isTrue);
      await mount(tester, active: false);
      await tester.pump();
      expect(fake.isPlaying, isFalse);
    });

    testWidgets('初始化失敗：顯示錯誤文字，不丟例外', (tester) async {
      fake.failInit = true;
      await mount(tester);
      await startPlaying(tester);
      expect(find.text('無法播放這個影片'), findsOneWidget);
    });
  });

  group('importPickedMedia', () {
    late ImageStore store;
    late FakeProbe probe;
    setUp(() {
      store = ImageStore(images());
      probe = FakeProbe();
    });

    testWidgets('圖片、GIF 讀出寬高；影片取 probe 的寬高／長度並存 poster', (tester) async {
      File('${dir.path}/p.png').writeAsBytesSync(_png1x1);
      File('${dir.path}/a.gif').writeAsBytesSync(_gif1x1);
      File('${dir.path}/clip.mp4').writeAsBytesSync(_mp4Head);
      probe.result = VideoMeta(
        width: 1080,
        height: 1920,
        durationMs: 24000,
        poster: Uint8List.fromList([1, 2, 3]),
      );
      await tester.runAsync(() async {
        final png = await importPickedMedia(
          store,
          XFile('${dir.path}/p.png'),
          probe: probe,
        );
        expect(png.kind, MediaKind.image);
        expect((png.width, png.height), (1, 1));
        expect(png.posterFile, isNull);

        final gif = await importPickedMedia(
          store,
          XFile('${dir.path}/a.gif'),
          probe: probe,
        );
        expect(gif.kind, MediaKind.gif);
        expect((gif.width, gif.height), (1, 1));
        expect(gif.file, endsWith('.gif'));

        final video = await importPickedMedia(
          store,
          XFile('${dir.path}/clip.mp4'),
          probe: probe,
        );
        expect(video.kind, MediaKind.video);
        expect((video.width, video.height), (1080, 1920));
        expect(video.durationMs, 24000);
        expect(video.posterFile, isNotNull);
        expect(store.fileOf(video.posterFile!).readAsBytesSync(), [1, 2, 3]);
        // 原檔照搬。
        expect(store.fileOf(video.file).readAsBytesSync(), _mp4Head);
        // 只有影片才會問 probe。
        expect(probe.calls, hasLength(1));
      });
    });

    testWidgets('探測失敗：影片照樣存，只是沒有 poster', (tester) async {
      File('${dir.path}/clip.mp4').writeAsBytesSync(_mp4Head);
      await tester.runAsync(() async {
        final video = await importPickedMedia(
          store,
          XFile('${dir.path}/clip.mp4'),
          probe: probe,
        );
        expect(video.kind, MediaKind.video);
        expect(video.posterFile, isNull);
        expect(video.durationMs, isNull);
        expect(store.exists(video.file), isTrue);
      });
    });

    testWidgets('generateMissingPosters：補沒有 poster 的影片，缺檔的略過', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      probe.result = VideoMeta(
        width: 640,
        height: 360,
        durationMs: 9000,
        poster: Uint8List.fromList([9, 9]),
      );
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        final group = (await db.watchGroups(pit).first).first.id;
        File('${images().path}/here.mp4').writeAsBytesSync(_mp4Head);
        await db.addOfficial(pit, group, const [
          NewImage(file: 'here.mp4', kind: MediaKind.video),
          NewImage(file: 'later.mp4', kind: MediaKind.video),
        ]);
        expect(await db.videosWithoutPoster(), hasLength(2));

        final n = await generateMissingPosters(db, store, probe: probe);
        expect(n, 1);
        // 還沒下載的影片留待下次。
        expect(await db.videosWithoutPoster(), ['later.mp4']);
        final row = await (db.select(
          db.officialImages,
        )..where((r) => r.imageFile.equals('here.mp4'))).getSingle();
        expect(row.posterFile, isNotNull);
        expect(row.durationMs, 9000);
        expect(store.exists(row.posterFile!), isTrue);
      });
    });

    testWidgets('PosterFixer：影片檔寫進來時自動補', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      probe.result = VideoMeta(
        durationMs: 3000,
        poster: Uint8List.fromList([7]),
      );
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        final group = (await db.watchGroups(pit).first).first.id;
        await db.addOfficial(pit, group, const [
          NewImage(file: 'dl.mp4', kind: MediaKind.video),
        ]);
        final fixer = PosterFixer(
          db,
          store,
          probe: probe,
          debounce: const Duration(milliseconds: 20),
        )..start();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await db.videosWithoutPoster(), ['dl.mp4']); // 檔案還沒下載
        // 模擬同步下載完成。
        await store.save('dl.mp4', Uint8List.fromList(_mp4Head));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(await db.videosWithoutPoster(), isEmpty);
        fixer.dispose();
      });
    });
  });
}

class FakeProbe implements VideoProbe {
  VideoMeta? result;
  final calls = <String>[];
  @override
  Future<VideoMeta?> probe(String path, {int maxPosterSide = 720}) async {
    calls.add(path);
    return result;
  }
}

/// 不需要外掛的假播放器：記錄被呼叫的動作。
class FakePlayback extends ChangeNotifier implements MediaPlayback {
  final log = <String>[];
  bool failInit = false;
  bool _init = false;
  bool _playing = false;
  Duration _pos = const Duration(seconds: 8);
  double _vol = 1;

  @override
  bool get isInitialized => _init;
  @override
  bool get isPlaying => _playing;
  @override
  bool get hasError => false;
  @override
  Duration get position => _pos;
  @override
  Duration get duration => const Duration(seconds: 24);
  @override
  double get aspectRatio => 16 / 9;
  @override
  double get volume => _vol;

  @override
  Future<void> initialize() async {
    log.add('init');
    if (failInit) throw StateError('boom');
    _init = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    log.add('play');
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    log.add('seek ${position.inMilliseconds}');
    _pos = position;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async {
    log.add('volume $volume');
    _vol = volume;
    notifyListeners();
  }

  @override
  Widget buildView(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fakeVideoView'));
}

const _gif1x1 = <int>[
  0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21, 0xf9, 0x04, 0x01, 0x00,
  0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
  0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
];

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];

/// ISO 基礎媒體檔開頭：size + `ftyp` + brand `mp42`。
const _mp4Head = <int>[
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x70, 0x34, 0x32, //
  0x00, 0x00, 0x00, 0x00, 0x6d, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6f, 0x6d,
];
