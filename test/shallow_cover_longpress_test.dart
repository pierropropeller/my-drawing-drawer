import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pit_rows.dart';

/// 淺坑的封面（跟現坑一樣從坑內的圖挑）：
/// - 淺坑內頁：每個有內容的開啟格子，長按進入「選擇該格封面」，點圖後只改那一格（手機、iPad）。
/// - 主頁「淺坑」分頁的列：長按不開選封面（D-093）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_shallow_cover');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  void setView(WidgetTester tester, double w, double h, double dpr) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = dpr;
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
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
  }

  /// 淺坑：六格全開，每格兩張圖。
  Future<String> shallowPitWithEverything() async {
    final id = await db.createPit(
      name: '淺坑甲',
      status: PitStatus.shallow,
      enabledSections: {
        PitSectionKey.official,
        PitSectionKey.fan,
        PitSectionKey.draft,
        PitSectionKey.idea,
        PitSectionKey.piece,
        PitSectionKey.oshi,
      },
    );
    final g = (await db.watchGroups(id).first).first;
    await db.addOfficial(id, g.id, const [
      NewImage(file: 'o1.png'),
      NewImage(file: 'o2.png'),
    ]);
    await db.addFanArts(id, const [
      NewImage(file: 'f1.png'),
      NewImage(file: 'f2.png'),
    ], author: '');
    await db.saveDraft(
      pitId: id,
      title: 'd',
      body: '',
      images: const [NewImage(file: 'd1.png'), NewImage(file: 'd2.png')],
      tagIds: const [],
      ideaIds: const [],
      pieceIds: const [],
    );
    await db.saveIdea(
      pitId: id,
      title: 'i',
      body: '',
      images: const [NewImage(file: 'i1.png'), NewImage(file: 'i2.png')],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.savePiece(
      pitId: id,
      title: 'p',
      body: '',
      images: const [NewImage(file: 'p1.png'), NewImage(file: 'p2.png')],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 5, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    await db.saveOshiRecord(
      pitId: id,
      date: DateTime(2026, 10, 1),
      images: const [NewImage(file: 'k1.png'), NewImage(file: 'k2.png')],
    );
    return id;
  }

  const cells = [
    ('官方圖冊', 'official'),
    ('好看同人圖', 'fan'),
    ('我的摸魚', 'draft'),
    ('我的腦洞', 'idea'),
    ('我的成圖', 'piece'),
    ('推活', 'oshi'),
  ];

  Future<String?> coverOf(String id, String kind) async {
    final c = await db.watchCellCovers(id).first;
    return switch (kind) {
      'official' => c.official,
      'fan' => c.fanArt,
      'draft' => c.draft,
      'idea' => c.idea,
      'piece' => c.piece,
      _ => c.oshi,
    };
  }

  for (final (name, w, h, dpr) in [
    ('手機', 1080.0, 2400.0, 3.0),
    ('iPad 834×1194', 834.0, 1194.0, 1.0),
    ('iPad 1194×834', 1194.0, 834.0, 1.0),
  ]) {
    testWidgets('淺坑內頁（$name）：每個有內容的格子長按都進入該格的選封面，點圖只改那一格', (tester) async {
      setView(tester, w, h, dpr);
      final id = (await tester.runAsync(shallowPitWithEverything))!;
      for (final (label, kind) in cells) {
        await unmount(tester); // 清掉上一輪的「已設為封面」提示。
        await pumpPage(tester, PitPage(pitId: id));
        await tester.scrollUntilVisible(
          find.text(label),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text(label).first);
        await tester.pump();
        await tester.longPress(find.text(label).first);
        await settle(tester);
        final page = find.byType(CoverPickPage);
        expect(page, findsOneWidget, reason: label);
        expect(tester.widget<CoverPickPage>(page).kind, kind);
        expect(tester.widget<CoverPickPage>(page).pitId, id);

        // 點第二張候選圖 → 這一格的封面變成它。
        final before = await tester.runAsync(() => coverOf(id, kind));
        final tiles = find.bySemanticsLabel('設為封面');
        expect(tiles, findsNWidgets(2), reason: '$label 只列該格內的圖');
        await tester.tap(tiles.last);
        await settle(tester);
        expect(find.byType(CoverPickPage), findsNothing, reason: label);
        final after = await tester.runAsync(() => coverOf(id, kind));
        expect(after, isNotNull);
        expect(after, isNot(before), reason: '$label 的封面換成另一張');
        // 坑封面（主頁卡片）沒被動到。
        final pit = await tester.runAsync(() => db.watchPit(id).first);
        expect(pit!.coverImageId, isNull);
        expect(tester.takeException(), isNull);
      }
      await unmount(tester);
    });
  }

  testWidgets('淺坑內頁：沒有內容的格子長按沒有反應（沒圖可挑）', (tester) async {
    setView(tester, 1080, 2400, 3);
    final id = (await tester.runAsync(
      () => db.createPit(
        name: '空格',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.official, PitSectionKey.fan},
      ),
    ))!;
    await pumpPage(tester, PitPage(pitId: id));
    await tester.longPress(find.text('官方圖冊'));
    await settle(tester);
    expect(find.byType(CoverPickPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('主頁淺坑分頁的列：長按不會開選封面（D-093）', (tester) async {
    setView(tester, 1080, 2400, 3);
    final id = (await tester.runAsync(shallowPitWithEverything))!;
    final pit = (await tester.runAsync(() => db.watchPit(id).first))!;
    await pumpPage(
      tester,
      Scaffold(
        body: PitRows(pits: [pit], status: PitStatus.shallow),
      ),
    );
    await tester.longPress(find.text('淺坑甲'));
    await settle(tester);
    expect(find.byType(CoverPickPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('封存坑的列不動（長按沒有反應）', (tester) async {
    setView(tester, 1080, 2400, 3);
    final id = (await tester.runAsync(() => db.createPit(name: '封存的坑')))!;
    await tester.runAsync(() => db.setPitStatus(id, PitStatus.archived));
    final pit = (await tester.runAsync(() => db.watchPit(id).first))!;
    await pumpPage(
      tester,
      Scaffold(
        body: PitRows(pits: [pit], status: PitStatus.archived),
      ),
    );
    await tester.longPress(find.text('封存的坑'));
    await settle(tester);
    expect(find.byType(CoverPickPage), findsNothing);
    await unmount(tester);
  });
}
