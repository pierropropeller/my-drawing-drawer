import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/data/media_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/media/media_import.dart';
import 'package:huakeng/media/video_probe.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/media_widgets.dart';
import 'package:image_picker/image_picker.dart';

const _mp4Head = <int>[
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x70, 0x34, 0x32, //
  0x00, 0x00, 0x00, 0x00, 0x6d, 0x70, 0x34, 0x32, 0x69, 0x73, 0x6f, 0x6d,
];

class _Probe implements VideoProbe {
  VideoMeta? result;
  final calls = <String>[];
  @override
  Future<VideoMeta?> probe(String path, {int maxPosterSide = 720}) async {
    calls.add(path);
    return result;
  }
}

void main() {
  late Directory dir;
  late ImageStore store;
  late _Probe probe;
  late AppDatabase db;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('poster_heal');
    store = ImageStore(Directory('${dir.path}/images')..createSync());
    probe = _Probe()
      ..result = VideoMeta(
        width: 720,
        height: 1280,
        durationMs: 7000,
        poster: Uint8List.fromList([1, 2, 3]),
      );
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<NewImage> importVideo(String name) async {
    File('${dir.path}/$name').writeAsBytesSync(_mp4Head);
    return importPickedMedia(store, XFile('${dir.path}/$name'), probe: probe);
  }

  group('每種內容都保存 poster／長度／種類', () {
    testWidgets('官方圖、同人圖、雜物、素材庫、腦洞、草稿、成圖、推活', (tester) async {
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        final group = (await db.watchGroups(pit).first).first.id;
        final v = await importVideo('a.mp4');
        expect(v.kind, MediaKind.video);
        expect(v.posterFile, isNotNull);
        expect(v.durationMs, 7000);
        expect(store.exists(v.posterFile!), isTrue);

        await db.addOfficial(pit, group, [v]);
        await db.addFanArts(pit, [v], author: 'x');
        await db.addJunk(pit, [v]);
        await db.addMaterials(MaterialCategory.values.first, [v]);
        await db.saveIdea(
          pitId: pit,
          title: 't',
          body: '',
          images: [v],
          tagIds: const [],
          draftIds: const [],
          pieceIds: const [],
        );
        await db.saveDraft(
          pitId: pit,
          images: [v],
          tagIds: const [],
          ideaIds: const [],
        );
        await db.savePiece(
          pitId: pit,
          title: 't',
          body: '',
          images: [v],
          tagIds: const [],
          draftIds: const [],
          links: const [],
          finishedAt: DateTime(2026, 1, 1),
          ideaIds: const [],
          targetLikes: 0,
        );
        await db.saveOshiRecord(
          pitId: pit,
          date: DateTime(2026, 1, 1),
          images: [v],
        );

        for (final r in await db.select(db.officialImages).get()) {
          expect((r.kind, r.posterFile, r.durationMs), (
            MediaKind.video,
            v.posterFile,
            7000,
          ));
        }
        final fan = await db.select(db.fanArts).getSingle();
        expect((fan.kind, fan.posterFile, fan.durationMs), (
          MediaKind.video,
          v.posterFile,
          7000,
        ));
        expect(
          (await db.select(db.junkImages).getSingle()).posterFile,
          v.posterFile,
        );
        expect(
          (await db.select(db.materialImages).getSingle()).posterFile,
          v.posterFile,
        );
        final ents = await db.select(db.entityImages).get();
        expect(ents, hasLength(4)); // 腦洞、草稿、成圖、推活
        for (final e in ents) {
          expect((e.kind, e.posterFile, e.durationMs), (
            MediaKind.video,
            v.posterFile,
            7000,
          ));
        }
        expect(await db.videosWithoutPoster(), isEmpty);
      });
    });
  });

  group('補既有影片', () {
    testWidgets('舊資料：kind 還是 image 的 .mp4、沒有 poster 也沒有長度', (tester) async {
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        File('${store.dir.path}/old.mp4').writeAsBytesSync(_mp4Head);
        // 舊版本匯入：kind 預設 image、沒有媒體欄位。
        await db.addFanArts(pit, const [NewImage(file: 'old.mp4')], author: '');
        expect(
          (await db.select(db.fanArts).getSingle()).kind,
          MediaKind.image,
        );

        final n = await generateMissingPosters(db, store, probe: probe);
        expect(n, 1);
        final r = await db.select(db.fanArts).getSingle();
        expect(r.kind, MediaKind.video);
        expect(r.durationMs, 7000);
        expect(r.posterFile, isNotNull);
        expect(store.exists(r.posterFile!), isTrue);
        expect((r.width, r.height), (720, 1280));
      });
    });

    testWidgets('有 poster 但沒有長度的影片也會補長度', (tester) async {
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        File('${store.dir.path}/n.mp4').writeAsBytesSync(_mp4Head);
        await db.addFanArts(pit, const [
          NewImage(file: 'n.mp4', kind: MediaKind.video, posterFile: 'p.jpg'),
        ], author: '');
        expect(await db.videosWithoutPoster(), ['n.mp4']);
        await generateMissingPosters(db, store, probe: probe);
        expect((await db.select(db.fanArts).getSingle()).durationMs, 7000);
      });
    });

    testWidgets('截圖失敗仍寫回長度與寬高，且有冷卻不會狂試', (tester) async {
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        File('${store.dir.path}/f.mp4').writeAsBytesSync(_mp4Head);
        await db.addFanArts(pit, const [
          NewImage(file: 'f.mp4', kind: MediaKind.video),
        ], author: '');
        probe.result = const VideoMeta(
          width: 100,
          height: 50,
          durationMs: 4000,
        );
        final fixer = PosterFixer(db, store, probe: probe);
        await fixer.run();
        final r = await db.select(db.fanArts).getSingle();
        expect(r.durationMs, 4000);
        expect(r.posterFile, isNull);
        expect(probe.calls, hasLength(1));
        // 冷卻中：再跑一次不會再探測。
        await fixer.run();
        expect(probe.calls, hasLength(1));
        fixer.dispose();
      });
    });

    testWidgets('補好時通知 healedStream（畫面即時更新）', (tester) async {
      await tester.runAsync(() async {
        final pit = await db.createPit(name: '坑');
        File('${store.dir.path}/h.mp4').writeAsBytesSync(_mp4Head);
        await db.addFanArts(pit, const [
          NewImage(file: 'h.mp4', kind: MediaKind.video),
        ], author: '');
        final fixer = PosterFixer(db, store, probe: probe);
        final got = <String>[];
        final sub = fixer.healedStream.listen(got.add);
        await fixer.run();
        await Future<void>.delayed(Duration.zero);
        expect(got, ['h.mp4']);
        expect(fixer.healed['h.mp4'], isNotNull);
        await sub.cancel();
        fixer.dispose();
      });
    });
  });

  group('畫面', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child,
      List<String> requests,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageTransferProvider.overrideWith(
              (ref, file) => ImageDownloadStatus.present,
            ),
            imageStoreProvider.overrideWith((ref) async => store),
            posterRequestProvider.overrideWithValue(requests.add),
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

    testWidgets('有 poster：格子畫 poster 圖＋長度標記，不要求補', (tester) async {
      final requests = <String>[];
      await pump(
        tester,
        const MediaThumb(
          MediaSource(
            file: 'v.mp4',
            kind: MediaKind.video,
            durationMs: 7000,
            poster: 'v.jpg',
          ),
        ),
        requests,
      );
      expect(find.byType(MediaPlaceholder), findsNothing);
      expect(find.text('0:07'), findsOneWidget);
      expect(requests, isEmpty);
    });

    testWidgets('沒有 poster：佔位＋向 PosterFixer 要求', (tester) async {
      final requests = <String>[];
      await pump(
        tester,
        const MediaThumb(MediaSource(file: 'v.mp4', kind: MediaKind.video)),
        requests,
      );
      expect(find.byType(VideoPlaceholder), findsOneWidget);
      expect(find.byType(MediaPlaceholder), findsNothing);
      expect(requests, ['v.mp4']);
    });

    testWidgets('詳情未播放：沒有 poster 也會要求補', (tester) async {
      final requests = <String>[];
      await pump(
        tester,
        const VideoPlayerView(file: 'v.mp4', durationMs: 7000),
        requests,
      );
      expect(requests, ['v.mp4']);
    });
  });
}
