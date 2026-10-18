import 'dart:io';

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
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';
import 'package:huakeng/ui/sync/download_badge.dart';

/// 還沒下載完的圖片角標（D-052）在平板版面也要出現：Main 坑卡片、Pit 分區 tile／封面、
/// 官方圖冊／好看同人圖的列表與預覽、參考圖檢視舞台（834／1194／1366／404）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_ipadbadge');
    pitId = await db.createPit(name: '坑A');
    final groups = await db.select(db.officialGroups).get();
    await db.addOfficial(pitId, groups[0].id, [
      for (final f in ['o1.png', 'o2.png', 'o3.png'])
        NewImage(file: f, width: 100, height: 150),
    ]);
    await db.addFanArts(pitId, [
      for (final f in ['f1.png', 'f2.png']) NewImage(file: f),
    ], author: '作者');
    final first = (await db.select(db.officialImages).get()).first;
    await db.setCover(pitId, first.id);
  });

  void setView(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHome(
    WidgetTester tester,
    Widget home, {
    double navWidth = 0,
    double? progress,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          // 所有圖片都還沒下載。
          imageTransferProvider.overrideWith(
            (ref, file) =>
                ImageDownloadStatus(isMissing: true, progress: progress),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Scaffold(
            body: navWidth == 0
                ? home
                : Row(
                    children: [
                      SizedBox(width: navWidth),
                      Expanded(child: home),
                    ],
                  ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  const sizes = <(double, double, double)>[
    (834, 1194, 84),
    (1194, 834, 260),
    (1366, 1024, 260),
  ];

  for (final (w, h, nav) in sizes) {
    group('$w×$h', () {
      testWidgets('Main 坑卡片封面', (tester) async {
        setView(tester, w, h);
        await pumpHome(tester, const PitsPage(), navWidth: nav);
        expect(find.byType(DownloadBadge), findsWidgets);
        await unmount(tester);
      });

      testWidgets('坑內頁：封面與分區 tile', (tester) async {
        setView(tester, w, h);
        await pumpHome(tester, PitPage(pitId: pitId), navWidth: nav);
        expect(find.byType(DownloadBadge), findsWidgets);
        await unmount(tester);
      });

      testWidgets('官方圖冊列表', (tester) async {
        setView(tester, w, h);
        await pumpHome(tester, OfficialListPage(pitId: pitId), navWidth: 84);
        expect(find.byType(DownloadBadge), findsWidgets);
        await unmount(tester);
      });

      testWidgets('好看同人圖列表與預覽面板', (tester) async {
        setView(tester, w, h);
        await pumpHome(
          tester,
          FanArtListPage(pitId: pitId),
          navWidth: 84,
          progress: .5,
        );
        expect(find.byType(DownloadBadge), findsWidgets);
        expect(find.bySemanticsLabel('下載中 50%'), findsWidgets);
        await unmount(tester);
      });
    });
  }

  group('參考圖檢視舞台', () {
    List<RefImage> sample() => [
      for (final (i, n) in ['o1.png', 'o2.png', 'o3.png'].indexed)
        RefImage(
          id: 'id$i',
          file: n,
          width: 1000,
          height: 1500,
          title: '坑A · 官方圖冊',
          category: '設定圖',
          tags: const [],
          addedAt: DateTime(2026, 9, 21),
        ),
    ];

    for (final (w, h) in [(1194.0, 834.0), (834.0, 1194.0), (404.0, 834.0)]) {
      testWidgets('$w×$h：舞台上的圖還沒下載也有角標', (tester) async {
        setView(tester, w, h);
        await pumpHome(tester, ReferenceViewer(images: sample()));
        expect(find.byType(DownloadBadge), findsWidgets);
        await unmount(tester);
      });
    }
  });
}
