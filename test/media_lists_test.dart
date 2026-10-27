import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/material/material_library_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 影片與 GIF 套到各列表（D-080）：fixture 一列 GIF、一列影片（有 poster），
/// 確認各列表的格子都用媒體感知元件——GIF 左下「GIF」、影片左下「▶ m:ss」、張數仍在右下。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;

  const gif = NewImage(
    file: 'g.gif',
    width: 30,
    height: 40,
    kind: MediaKind.gif,
  );
  const video = NewImage(
    file: 'v.mp4',
    width: 40,
    height: 30,
    kind: MediaKind.video,
    durationMs: 24000,
    posterFile: 'v.jpg',
  );
  const still = NewImage(file: 'a.png', width: 30, height: 40);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('media_lists');
    pitId = await db.createPit(name: '坑A');
    navBarHiddenCount.value = 0;
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      ...initialPrefs,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
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
          home: page,
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  final badgeGif = find.byKey(const ValueKey('badgeGif'));
  final badgeVideo = find.byKey(const ValueKey('badgeVideo'));
  final badgeCount = find.byKey(const ValueKey('badgeCount'));
  final miniGif = find.byKey(const ValueKey('miniBadgeGif'));
  final miniVideo = find.byKey(const ValueKey('miniBadgeVideo'));

  testWidgets('官方圖列表（瀑布）：GIF 與影片標記', (tester) async {
    await tester.runAsync(() async {
      final groups = await db.watchGroups(pitId).first;
      await db.addOfficial(pitId, groups.first.id, [gif, video, still]);
    });
    await show(tester, OfficialListPage(pitId: pitId));
    expect(badgeGif, findsOneWidget);
    expect(badgeVideo, findsOneWidget);
    expect(find.text('0:24'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('素材庫九宮格：GIF 與影片標記', (tester) async {
    await tester.runAsync(
      () => db.addMaterials(MaterialCategory.values.first, [gif, video, still]),
    );
    await show(
      tester,
      const MaterialLibraryPage(),
      initialPrefs: {'materialLayout': 'grid'},
    );
    expect(badgeGif, findsOneWidget);
    expect(badgeVideo, findsOneWidget);
    await unmount(tester);
  });

  testWidgets('素材庫瀑布：GIF 與影片標記', (tester) async {
    await tester.runAsync(
      () => db.addMaterials(MaterialCategory.values.first, [gif, video, still]),
    );
    await show(tester, const MaterialLibraryPage());
    expect(badgeGif, findsOneWidget);
    expect(badgeVideo, findsOneWidget);
    await unmount(tester);
  });

  testWidgets('推活網格：左下媒體標記與右下張數並存', (tester) async {
    await tester.runAsync(
      () => db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, 1),
        images: const [gif],
      ),
    );
    await tester.runAsync(
      () => db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, 2),
        images: const [video, still, still],
      ),
    );
    await show(
      tester,
      OshiListPage(pitId: pitId),
      initialPrefs: {'oshiLayout': 'grid'},
    );
    expect(badgeGif, findsOneWidget);
    expect(badgeVideo, findsOneWidget);
    expect(badgeCount, findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // 左下＝媒體標記、右下＝張數，不重疊。
    expect(
      tester.getCenter(badgeVideo).dx,
      lessThan(tester.getCenter(badgeCount).dx),
    );
    await unmount(tester);
  });

  testWidgets('推活時間軸：76px 首圖的小標記', (tester) async {
    await tester.runAsync(
      () => db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, 1),
        images: const [gif],
      ),
    );
    await tester.runAsync(
      () => db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, 2),
        images: const [video],
      ),
    );
    await show(tester, OshiListPage(pitId: pitId));
    expect(miniGif, findsOneWidget);
    expect(miniVideo, findsOneWidget);
    await unmount(tester);
  });

  testWidgets('成圖列表（瀑布）：GIF 與影片標記', (tester) async {
    Future<void> piece(String title, NewImage im) => db.savePiece(
      pitId: pitId,
      title: title,
      body: '',
      images: [im],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 5, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    await tester.runAsync(() async {
      await piece('甲', gif);
      await piece('乙', video);
    });
    await show(tester, FinishedListPage(pitId: pitId));
    await tester.tap(find.bySemanticsLabel('瀑布')); // 預設是列表（D-125）
    await tester.pump(const Duration(milliseconds: 300));
    expect(badgeGif, findsOneWidget);
    expect(badgeVideo, findsOneWidget);
    await unmount(tester);
  });

  testWidgets('摸魚列（D-087）：GIF／影片用縮小標記', (tester) async {
    await tester.runAsync(
      () => db.saveDraft(
        pitId: pitId,
        images: const [gif, video],
        tagIds: const [],
        ideaIds: const [],
      ),
    );
    await show(tester, DraftListPage(pitId: pitId));
    expect(miniGif, findsOneWidget);
    expect(miniVideo, findsOneWidget);
    await unmount(tester);
  });

  testWidgets('腦洞卡的 54px 縮圖：縮小標記', (tester) async {
    await tester.runAsync(
      () => db.saveIdea(
        pitId: pitId,
        title: '腦洞',
        body: '',
        images: const [gif, video],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      ),
    );
    await show(tester, IdeaListPage(pitId: pitId));
    expect(miniGif, findsOneWidget);
    expect(miniVideo, findsOneWidget);
    await unmount(tester);
  });
}
