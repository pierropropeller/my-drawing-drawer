import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/media/media_import.dart';
import 'package:huakeng/media/player_frame_poster_generator.dart';
import 'package:huakeng/media/video_playback_gate.dart';
import 'package:huakeng/media/video_probe.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/media_widgets.dart';

const _mp4Head = <int>[
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x70, 0x34, 0x32, //
  0x00, 0x00, 0x00, 0x00, 0x6d, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6f, 0x6d,
];

class _Probe implements VideoProbe {
  VideoMeta? result;
  int calls = 0;
  @override
  Future<VideoMeta?> probe(String path, {int maxPosterSide = 720}) async {
    calls++;
    return result;
  }
}

class _Player implements PosterFrameGenerator {
  PosterFrame? result;
  bool canRun = true;
  bool throws = false;
  final calls = <String>[];
  final availability = ValueNotifier<bool>(false);
  @override
  bool get available => canRun;
  @override
  Listenable get availabilityChanges => availability;
  @override
  Future<PosterFrame?> generate(
    String path, {
    int? width,
    int? height,
    int maxSide = 720,
  }) async {
    calls.add(path);
    if (throws) throw StateError('boom');
    return result;
  }
}

PosterFrame _frame() => PosterFrame(
  bytes: Uint8List.fromList([9, 8, 7]),
  width: 480,
  height: 270,
  durationMs: 900,
);

/// 可控的假播放器：記錄動作；畫面是否「亮」由 [lit] 決定（模擬 seek 到哪一格才有畫面）。
class _FakePlayback extends ChangeNotifier implements MediaPlayback {
  _FakePlayback({
    this.lit = _always,
    this.hangInit = false,
    this.failInit = false,
    this.onDispose,
  });
  static bool _always(Duration p, bool played) => true;

  @override
  Duration get duration => const Duration(milliseconds: 900);

  /// (目前 seek 位置, 是否 play 過) → 畫面是亮的？
  final bool Function(Duration pos, bool played) lit;
  final bool hangInit;
  final bool failInit;
  final void Function()? onDispose;
  final log = <String>[];
  bool _init = false;
  bool _played = false;
  Duration _pos = Duration.zero;
  bool disposed = false;

  @override
  bool get isInitialized => _init;
  @override
  bool get isPlaying => false;
  @override
  bool get hasError => false;
  @override
  Duration get position => _pos;
  @override
  double get aspectRatio => 16 / 9;
  @override
  double get volume => 0;
  @override
  Future<void> initialize() async {
    log.add('init');
    if (hangInit) await Completer<void>().future;
    if (failInit) throw StateError('boom');
    _init = true;
  }

  @override
  Future<void> play() async {
    log.add('play');
    _played = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> seekTo(Duration position) async {
    log.add('seek ${position.inMilliseconds}');
    _pos = position;
    notifyListeners();
  }

  @override
  Future<void> setVolume(double volume) async => log.add('volume $volume');
  @override
  bool get isLooping => false;
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Widget buildView(BuildContext context) => ListenableBuilder(
    listenable: this,
    builder: (_, _) => ColoredBox(
      color: lit(_pos, _played)
          ? const Color(0xFFCC6677)
          : const Color(0xFF000000),
    ),
  );
  @override
  void dispose() {
    disposed = true;
    onDispose?.call();
    super.dispose();
  }
}

void main() {
  late Directory dir;
  late ImageStore store;
  late AppDatabase db;
  late _Probe probe;
  late _Player player;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('poster_player');
    store = ImageStore(Directory('${dir.path}/images')..createSync());
    db = AppDatabase(NativeDatabase.memory());
    probe = _Probe();
    player = _Player()..result = _frame();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> addVideo(String name) async {
    final pit = await db.createPit(name: '坑');
    File('${store.dir.path}/$name').writeAsBytesSync(_mp4Head);
    await db.addFanArts(pit, [
      NewImage(file: name, kind: MediaKind.video),
    ], author: '');
  }

  group('分層：原生 → 播放器備援', () {
    testWidgets('原生整支讀不開（null）→ 播放器備援 → 存成 poster 並補寬高長度', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = null;
        final tried = <String>[];
        final n = await generateMissingPosters(
          db,
          store,
          probe: probe,
          player: player,
          onPlayerTried: tried.add,
        );
        expect(n, 1);
        expect(player.calls, hasLength(1));
        expect(tried, ['t.mp4']);
        final r = await db.select(db.fanArts).getSingle();
        expect(r.posterFile, endsWith('.png'));
        expect(store.exists(r.posterFile!), isTrue);
        expect(store.fileOf(r.posterFile!).readAsBytesSync(), [9, 8, 7]);
        expect((r.width, r.height, r.durationMs), (480, 270, 900));
      });
    });

    testWidgets('原生有寬高長度但沒截圖 → 備援補 poster，原生的寬高長度優先', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = const VideoMeta(
          width: 640,
          height: 360,
          durationMs: 800,
        );
        await generateMissingPosters(db, store, probe: probe, player: player);
        final r = await db.select(db.fanArts).getSingle();
        expect(r.posterFile, isNotNull);
        expect((r.width, r.height, r.durationMs), (640, 360, 800));
      });
    });

    testWidgets('原生取得到截圖 → 不呼叫備援', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = VideoMeta(
          width: 720,
          height: 1280,
          durationMs: 7000,
          poster: Uint8List.fromList([1, 2, 3]),
        );
        await generateMissingPosters(db, store, probe: probe, player: player);
        expect(player.calls, isEmpty);
        expect(
          (await db.select(db.fanArts).getSingle()).posterFile,
          endsWith('.jpg'),
        );
      });
    });

    testWidgets('備援回 null／丟例外 → 沒有 poster、不崩、原生資料照寫', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = const VideoMeta(
          width: 640,
          height: 360,
          durationMs: 800,
        );
        player.result = null;
        expect(
          await generateMissingPosters(db, store, probe: probe, player: player),
          0,
        );
        player.throws = true;
        expect(
          await generateMissingPosters(db, store, probe: probe, player: player),
          0,
        );
        final r = await db.select(db.fanArts).getSingle();
        expect(r.posterFile, isNull);
        expect(r.durationMs, 800);
      });
    });

    testWidgets('備援目前不能用（沒有承載容器／在背景）→ 略過且不算試過', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = null;
        player.canRun = false;
        final tried = <String>[];
        await generateMissingPosters(
          db,
          store,
          probe: probe,
          player: player,
          onPlayerTried: tried.add,
        );
        expect(player.calls, isEmpty);
        expect(tried, isEmpty);
      });
    });
  });

  group('PosterFixer：每支影片每次執行只試一次備援', () {
    testWidgets('備援失敗後不再跑原生探測也不再跑備援', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = null;
        player.result = null;
        final fixer = PosterFixer(
          db,
          store,
          probe: probe,
          player: player,
          retryAfter: Duration.zero,
        );
        await fixer.run();
        await fixer.run();
        await fixer.run();
        expect(player.calls, hasLength(1));
        expect(probe.calls, 1);
        fixer.dispose();
      });
    });

    testWidgets('備援一開始不能用，之後可用（容器掛上）→ 自動補做並成功', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = null;
        player.canRun = false;
        final fixer = PosterFixer(
          db,
          store,
          probe: probe,
          player: player,
          debounce: const Duration(milliseconds: 10),
          retryAfter: Duration.zero,
          maxAttempts: 1,
        );
        fixer.start();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(player.calls, isEmpty);
        // 原生次數雖然用完，備援還沒輪到，仍准許再試。
        player.canRun = true;
        player.availability.value = true;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(player.calls, hasLength(1));
        expect(fixer.healed['t.mp4'], isNotNull);
        fixer.dispose();
      });
    });

    testWidgets('UI 要求（request）也會走到備援', (tester) async {
      await tester.runAsync(() async {
        await addVideo('t.mp4');
        probe.result = null;
        final fixer = PosterFixer(
          db,
          store,
          probe: probe,
          player: player,
          requestDebounce: const Duration(milliseconds: 10),
        );
        fixer.request('t.mp4');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(fixer.healed['t.mp4'], isNotNull);
        fixer.dispose();
      });
    });
  });

  group('播放中不補截圖（閘門）', () {
    testWidgets('閘門開著：PosterFixer 不探測也不開播放器；放開後補做', (tester) async {
      await tester.runAsync(() async {
        await addVideo('g.mp4');
        probe.result = null;
        final gate = VideoPlaybackGate();
        final fixer = PosterFixer(
          db,
          store,
          probe: probe,
          player: player,
          gate: gate,
          debounce: const Duration(milliseconds: 10),
          requestDebounce: const Duration(milliseconds: 10),
        );
        gate.acquire();
        expect(await fixer.run(), 0);
        fixer.request('g.mp4');
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(probe.calls, 0);
        expect(player.calls, isEmpty);

        fixer.start(); // start() 內的第一次 run 也被擋住
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(probe.calls, 0);
        expect(player.calls, isEmpty);

        gate.release(); // 放開 → 自動排一次補做
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(probe.calls, greaterThan(0));
        expect(player.calls, hasLength(1));
        expect(fixer.healed['g.mp4'], isNotNull);
        fixer.dispose();
      });
    });
  });

  group('PlayerFramePosterGenerator', () {
    late PosterCaptureSlot slot;
    late List<_FakePlayback> made;

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: PosterCaptureScope(slot: slot, child: const SizedBox.expand()),
        ),
      );
    }

    PlayerFramePosterGenerator gen(
      _FakePlayback Function() make, {
      Duration timeout = const Duration(seconds: 8),
    }) => PlayerFramePosterGenerator(
      slot: slot,
      timeout: timeout,
      settle: const Duration(milliseconds: 5),
      playbackFactory: (_, {platformView = false}) {
        final p = make();
        made.add(p);
        return p;
      },
    );

    /// 讓畫面幀（pump）與真實 async（toImage、Timer）一起前進。
    Future<T> run<T>(WidgetTester tester, Future<T> f) async {
      final done = Completer<T>();
      unawaited(f.then(done.complete, onError: done.completeError));
      for (var i = 0; i < 600 && !done.isCompleted; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      return done.future;
    }

    setUp(() {
      slot = PosterCaptureSlot();
      made = [];
    });

    testWidgets('有畫面 → 回傳 PNG（≤720）、靜音、釋放播放器並清空承載位置', (tester) async {
      await pumpHost(tester);
      final g = gen(() => _FakePlayback());
      expect(g.available, isTrue);
      final r = await run(tester, g.generate('/x/a.mp4'));
      expect(r, isNotNull);
      expect(r!.ext, 'png');
      expect(r.bytes.sublist(1, 4), [0x50, 0x4e, 0x47]); // PNG 標頭
      expect(r.width, 720);
      expect(r.durationMs, 900);
      expect(made.single.log, contains('volume 0.0'));
      // 先 seek 到 min(1s, 長度/2)＝450ms。
      expect(made.single.log, contains('seek 450'));
      expect(made.single.disposed, isTrue);
      expect(slot.builder, isNull);
    });

    testWidgets('全黑畫面 → 丟掉（null）；各時間點與輕播都試過', (tester) async {
      await pumpHost(tester);
      final g = gen(() => _FakePlayback(lit: (_, _) => false));
      final r = await run(tester, g.generate('/x/a.mp4'));
      expect(r, isNull);
      expect(made.single.log, containsAll(['seek 450', 'seek 0', 'play']));
      expect(made.single.disposed, isTrue);
    });

    testWidgets('第一個時間點是黑的、seek 到 0 才有畫面 → 取到 0 那格', (tester) async {
      await pumpHost(tester);
      final g = gen(() => _FakePlayback(lit: (p, _) => p == Duration.zero));
      final r = await run(tester, g.generate('/x/a.mp4'));
      expect(r, isNotNull);
      expect(made.single.log.last, 'seek 0');
    });

    testWidgets('seek 後仍黑、輕輕播放後才有畫面 → 取得', (tester) async {
      await pumpHost(tester);
      final g = gen(() => _FakePlayback(lit: (_, played) => played));
      final r = await run(tester, g.generate('/x/a.mp4'));
      expect(r, isNotNull);
      expect(made.single.log, contains('play'));
    });

    testWidgets('初始化卡住 → 逾時 null，播放器已釋放，下一支照常', (tester) async {
      await pumpHost(tester);
      var n = 0;
      final g = gen(
        () => n++ == 0 ? _FakePlayback(hangInit: true) : _FakePlayback(),
        timeout: const Duration(milliseconds: 200),
      );
      final first = g.generate('/x/a.mp4');
      final second = g.generate('/x/b.mp4');
      expect(await run(tester, first), isNull);
      expect(made.first.disposed, isTrue);
      expect(await run(tester, second), isNotNull);
    });

    testWidgets('初始化丟例外 → null、不崩', (tester) async {
      await pumpHost(tester);
      final g = gen(() => _FakePlayback(failInit: true));
      expect(await run(tester, g.generate('/x/a.mp4')), isNull);
      expect(made.single.disposed, isTrue);
    });

    testWidgets('同時只跑一支（排隊）', (tester) async {
      await pumpHost(tester);
      var live = 0;
      var maxLive = 0;
      final g = gen(() {
        live++;
        if (live > maxLive) maxLive = live;
        return _FakePlayback(onDispose: () => live--);
      });
      final fs = [for (var i = 0; i < 3; i++) g.generate('/x/$i.mp4')];
      final rs = await run(tester, Future.wait(fs));
      expect(rs.every((r) => r != null), isTrue);
      expect(made, hasLength(3));
      expect(maxLive, 1);
    });

    testWidgets('沒有承載容器／在背景 → 不可用，不建立播放器', (tester) async {
      final g = gen(() => _FakePlayback());
      expect(g.available, isFalse);
      expect(await g.generate('/x/a.mp4'), isNull);
      expect(made, isEmpty);

      await pumpHost(tester);
      final bg = PlayerFramePosterGenerator(
        slot: slot,
        playbackFactory: (_, {platformView = false}) => _FakePlayback(),
        isForeground: () => false,
      );
      expect(bg.available, isFalse);
    });

    testWidgets('使用者正在播放影片（閘門）→ 不可用、不建立播放器；放開後恢復並通知', (tester) async {
      await pumpHost(tester);
      final gate = VideoPlaybackGate();
      final g = PlayerFramePosterGenerator(
        slot: slot,
        playbackFactory: (_, {platformView = false}) {
          final p = _FakePlayback();
          made.add(p);
          return p;
        },
        isForeground: () => true,
        gate: gate,
      );
      expect(g.available, isTrue);
      var notified = 0;
      g.availabilityChanges!.addListener(() => notified++);
      gate.acquire();
      expect(notified, 1);
      expect(g.available, isFalse);
      expect(await g.generate('/x/a.mp4'), isNull);
      expect(made, isEmpty);
      gate.release();
      expect(notified, 2);
      expect(g.available, isTrue);
    });

    testWidgets('擷取途中使用者開始播放 → 立刻中止並釋放播放器', (tester) async {
      await pumpHost(tester);
      final gate = VideoPlaybackGate();
      final g = PlayerFramePosterGenerator(
        slot: slot,
        timeout: const Duration(milliseconds: 300),
        playbackFactory: (_, {platformView = false}) {
          final p = _FakePlayback(hangInit: true);
          made.add(p);
          return p;
        },
        isForeground: () => true,
        gate: gate,
      );
      final f = g.generate('/x/a.mp4');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(made, hasLength(1));
      gate.acquire();
      expect(made.single.disposed, isTrue);
      expect(await run(tester, f), isNull);
      await tester.pump(const Duration(seconds: 1)); // 清掉逾時計時器
    });

    test('isMostlyBlank：全黑、全透明為真；有亮點為假', () {
      ByteData img(void Function(int o, ByteData d) f) {
        final d = ByteData(64 * 64 * 4);
        for (var i = 0; i < 64 * 64; i++) {
          d.setUint8(i * 4 + 3, 255);
          f(i * 4, d);
        }
        return d;
      }

      expect(
        PlayerFramePosterGenerator.isMostlyBlank(img((o, d) {}), 64, 64),
        isTrue,
      );
      expect(
        PlayerFramePosterGenerator.isMostlyBlank(ByteData(64 * 64 * 4), 64, 64),
        isTrue,
      );
      expect(
        PlayerFramePosterGenerator.isMostlyBlank(
          img((o, d) => d.setUint8(o, 200)),
          64,
          64,
        ),
        isFalse,
      );
    });
  });

  group('畫面：沒有 poster 的影片', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageStoreProvider.overrideWith((ref) async => store),
            posterRequestProvider.overrideWithValue((_) {}),
            healedPosterProvider.overrideWith((ref, f) => Stream.value(null)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            home: Scaffold(
              body: SizedBox(width: 200, height: 200, child: child),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('格子：深色佔位＋▶＋長度，不是米色圖片佔位', (tester) async {
      await pump(
        tester,
        const MediaThumb(
          MediaSource(file: 'v.mp4', kind: MediaKind.video, durationMs: 900),
        ),
      );
      expect(find.byType(VideoPlaceholder), findsOneWidget);
      expect(find.byType(MediaPlaceholder), findsNothing);
      expect(find.text('0:01'), findsOneWidget);
      final box = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('videoPlaceholder')),
      );
      expect(box.color.computeLuminance(), lessThan(0.2));
    });

    testWidgets('詳情未播放：深色底＋大 ▶', (tester) async {
      await pump(tester, const VideoPlayerView(file: 'v.mp4', durationMs: 900));
      expect(find.byKey(const ValueKey('videoPlayButton')), findsOneWidget);
      final dark = find.descendant(
        of: find.byKey(const ValueKey('videoPoster')),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color.computeLuminance() < 0.2,
        ),
      );
      expect(dark, findsWidgets);
    });
  });
}
