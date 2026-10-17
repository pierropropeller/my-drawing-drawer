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
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/reference/ref_frames.dart';
import 'package:huakeng/ui/reference/ref_video_playback.dart';
import 'package:huakeng/ui/reference/ref_video_viewer.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';

/// 假的播放器：不載入外掛，記錄收到的指令。
class FakeRefPlayback extends ChangeNotifier implements RefVideoPlayback {
  FakeRefPlayback({this.duration = const Duration(seconds: 24)});

  @override
  final Duration duration;
  @override
  Duration position = Duration.zero;
  @override
  bool isPlaying = false;
  @override
  bool isInitialized = true;
  @override
  bool hasError = false;
  @override
  double aspectRatio = 16 / 9;

  double speed = 1;
  bool looping = false;
  double volume = 1;
  final seeks = <Duration>[];
  bool disposed = false;

  @override
  Future<void> initialize() async {}
  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration p) async {
    seeks.add(p);
    position = p;
    notifyListeners();
  }

  @override
  Future<void> setPlaybackSpeed(double s) async => speed = s;
  @override
  Future<void> setLooping(bool l) async => looping = l;
  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Widget buildView(BuildContext context) =>
      const ColoredBox(color: Color(0xFFE6E0EE), child: SizedBox.expand());

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// 假的抽格器：時間軸 14 格 + 截取一格；fps 可指定。
class FakeFrameExtractor implements FrameExtractor {
  FakeFrameExtractor({this.fps = 24, this.fail = false});
  final double? fps;
  final bool fail;
  final calls = <List<int>>[];
  final exactCalls = <bool>[];

  @override
  Future<ExtractedFrames?> extract(
    String path,
    List<int> positionsMs, {
    int maxSide = 240,
    int quality = 70,
    bool exact = false,
  }) async {
    calls.add(positionsMs);
    exactCalls.add(exact);
    if (fail) return null;
    return ExtractedFrames(
      frames: [for (final _ in positionsMs) Uint8List.fromList(_png1x1)],
      fps: fps,
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late FakeRefPlayback fake;
  late FakeFrameExtractor extractor;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('ref_video');
    await Directory('${tmp.path}/images').create(recursive: true);
    File('${tmp.path}/images/v.mp4').writeAsBytesSync([0, 0, 0, 0x18]);
    fake = FakeRefPlayback();
    extractor = FakeFrameExtractor();
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpVideo(
    WidgetTester tester,
    RefImage image, {
    Size size = const Size(1194, 834),
  }) async {
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
          refPlaybackFactoryProvider.overrideWithValue((_) => fake),
          frameExtractorProvider.overrideWithValue(extractor),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: Scaffold(body: RefVideoViewer(image: image)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  const plain = RefImage(
    id: 'v1',
    file: 'v.mp4',
    width: 1920,
    height: 1080,
    kind: MediaKind.video,
    durationMs: 24000,
    title: '坑A · 好看同人圖',
  );

  Finder tool(String label) => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == label,
  );

  test('時間標籤', () {
    expect(refTimeLabel(const Duration(milliseconds: 8120)), '0:08.12');
    expect(refTimeLabel(const Duration(seconds: 24)), '0:24.00');
    expect(refTimeLabel(const Duration(milliseconds: 65430)), '1:05.43');
    expect(refSpeedLabel(0.25), '0.25×');
    expect(refSpeedLabel(1), '1×');
  });

  for (final s in const [
    Size(390, 844),
    Size(404, 900),
    Size(834, 1194),
    Size(1194, 834),
    Size(1366, 1024),
  ]) {
    testWidgets('版面 ${s.width.toInt()}×${s.height.toInt()}', (tester) async {
      await pumpVideo(tester, plain, size: s);
      expect(tester.takeException(), isNull);
      expect(find.text('坑A · 好看同人圖 · 影片'), findsOneWidget);
      expect(find.text('截取此格'), findsOneWidget);
      for (final t in ['0.25×', '0.5×', '1×', '2×', '循環', '左右翻轉', '靜音']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      expect(find.text('0:24.00'), findsOneWidget);
      // 時間軸 14 格縮圖。
      expect(find.byType(Image), findsNWidgets(stripCells));
      await unmount(tester);
    });
  }

  testWidgets('一格的長度來自 metadata fps；上一格／下一格用 seekTo ± 1/fps，不累積誤差', (
    tester,
  ) async {
    extractor = FakeFrameExtractor(fps: 24);
    await pumpVideo(tester, plain);
    expect(find.text('1× · 第 0 格'), findsOneWidget);
    await tester.tap(tool('下一格'));
    await settle(tester);
    await tester.tap(tool('下一格'));
    await settle(tester);
    await tester.tap(tool('下一格'));
    await settle(tester);
    expect(find.text('1× · 第 3 格'), findsOneWidget);
    // 最後一次 seek＝ 3/24 秒（以我們記的目標計算，不是播放器回報的位置）。
    expect(fake.seeks.last.inMicroseconds, closeTo(3 * 1e6 / 24, 3));
    await tester.tap(tool('上一格'));
    await settle(tester);
    expect(find.text('1× · 第 2 格'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('讀不到 fps 時用 30', (tester) async {
    extractor = FakeFrameExtractor(fps: null);
    await pumpVideo(tester, plain);
    await tester.tap(tool('下一格'));
    await settle(tester);
    expect(fake.seeks.last.inMicroseconds, closeTo(1e6 / 30, 3));
    await unmount(tester);
  });

  testWidgets('上一格不會小於 0，下一格不會超過長度', (tester) async {
    await pumpVideo(tester, plain);
    await tester.tap(tool('上一格'));
    await settle(tester);
    expect(fake.seeks.last, Duration.zero);
    fake.position = fake.duration;
    await unmount(tester);
  });

  testWidgets('播放／暫停；播放中按下一格會先暫停', (tester) async {
    await pumpVideo(tester, plain);
    await tester.tap(tool('播放'));
    await settle(tester);
    expect(fake.isPlaying, isTrue);
    expect(tool('暫停'), findsWidgets);
    await tester.tap(tool('下一格'));
    await settle(tester);
    expect(fake.isPlaying, isFalse);
    await unmount(tester);
  });

  testWidgets('速度 0.25×／0.5×／1×／2×、循環、靜音', (tester) async {
    await pumpVideo(tester, plain);
    expect(fake.looping, isTrue);
    for (final (label, v) in [
      ('0.25×', .25),
      ('0.5×', .5),
      ('2×', 2.0),
      ('1×', 1.0),
    ]) {
      await tester.tap(find.text(label).first);
      await settle(tester);
      expect(fake.speed, v);
      expect(find.textContaining('$label · 第'), findsOneWidget);
    }
    await tester.tap(find.text('循環'));
    await settle(tester);
    expect(fake.looping, isFalse);
    await tester.tap(find.text('靜音'));
    await settle(tester);
    expect(fake.volume, 0);
    await tester.tap(find.text('靜音'));
    await settle(tester);
    expect(fake.volume, 1);
    await tester.tap(find.text('左右翻轉'));
    await settle(tester);
    expect(
      tester
          .widgetList<Transform>(find.byType(Transform))
          .any((t) => t.transform.entry(0, 0) == -1),
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('點時間軸跳到對應位置；播放頭跟著走', (tester) async {
    await pumpVideo(tester, plain, size: const Size(1000, 800));
    final box = tester.getRect(find.bySemanticsLabel('時間軸'));
    await tester.tapAt(Offset(box.left + box.width * 0.5, box.center.dy));
    await settle(tester);
    expect(fake.seeks.last.inMilliseconds, closeTo(12000, 200));
    expect(find.text('0:12.00'), findsOneWidget);
    await unmount(tester);
  });

  group('截取此格', () {
    Future<RefImage> officialVideo(WidgetTester tester) async {
      final pitId = (await tester.runAsync(() => db.createPit(name: '坑A')))!;
      final gid = (await tester.runAsync(() => db.watchGroups(pitId).first))!
          .first
          .id;
      return RefImage.fromAlbum(
        AlbumImage(
          id: 'v1',
          file: 'v.mp4',
          width: 1920,
          height: 1080,
          kind: AlbumKind.official,
          groupId: gid,
          mediaKind: MediaKind.video,
          durationMs: 24000,
        ),
        pitId: pitId,
        title: '坑A · 官方圖冊',
      );
    }

    testWidgets('存成新的官方圖，放在同一個坑、同一個分組', (tester) async {
      final image = await officialVideo(tester);
      await pumpVideo(tester, image);
      await tester.tap(tool('下一格'));
      await settle(tester);
      await tester.tap(find.text('截取此格'));
      for (var i = 0; i < 6; i++) {
        await settle(tester);
      }
      expect(extractor.exactCalls.last, isTrue, reason: '截取要最接近該時間的畫面');
      final rows = (await tester.runAsync(
        () => db.select(db.officialImages).get(),
      ))!;
      expect(rows, hasLength(1));
      expect(rows.single.pitId, image.pitId);
      expect(rows.single.groupId, image.album!.groupId);
      expect(rows.single.kind, MediaKind.image);
      expect(
        File('${tmp.path}/images/${rows.single.imageFile}').existsSync(),
        isTrue,
      );
      expect(find.text('已截取此格'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('同人圖：存進同一個坑與出處', (tester) async {
      final pitId = (await tester.runAsync(() => db.createPit(name: '坑A')))!;
      final image = RefImage.fromAlbum(
        const AlbumImage(
          id: 'v1',
          file: 'v.mp4',
          width: 1920,
          height: 1080,
          kind: AlbumKind.fanArt,
          author: '某人',
          mediaKind: MediaKind.video,
          durationMs: 24000,
        ),
        pitId: pitId,
        title: '坑A · 好看同人圖',
      );
      await pumpVideo(tester, image);
      await tester.tap(find.text('截取此格'));
      for (var i = 0; i < 6; i++) {
        await settle(tester);
      }
      final rows = (await tester.runAsync(() => db.select(db.fanArts).get()))!;
      expect(rows.single.pitId, pitId);
      expect(rows.single.author, '某人');
      await unmount(tester);
    });

    testWidgets('來源不是官方圖／同人圖時不亂存，提示沒有存放位置', (tester) async {
      await pumpVideo(tester, plain);
      await tester.tap(find.text('截取此格'));
      await settle(tester);
      expect(find.text('這個來源沒有可以存放截圖的位置'), findsOneWidget);
      expect(extractor.calls.length, 1, reason: '只有時間軸抽格，沒有截取');
      await unmount(tester);
    });

    testWidgets('原生抽不到畫面：提示失敗，資料庫不變', (tester) async {
      extractor = FakeFrameExtractor(fail: true);
      final image = await officialVideo(tester);
      await pumpVideo(tester, image);
      await tester.tap(find.text('截取此格'));
      await settle(tester);
      expect(find.text('無法截取這一格'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.officialImages).get()),
        isEmpty,
      );
      await unmount(tester);
    });
  });

  testWidgets('離開頁面時釋放播放器', (tester) async {
    await pumpVideo(tester, plain);
    await unmount(tester);
    expect(fake.disposed, isTrue);
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
