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
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_cellcover_ui');
    pitId = await db.createPit(name: '坑A');
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHome(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder img(String file) =>
      find.byWidgetPredicate((w) => w is StoredImage && w.file == file);

  Future<void> seedOfficial() async {
    final g = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(pitId, g.id, [
      const NewImage(file: 'o1.png', width: 10, height: 10),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.addOfficial(pitId, g.id, [
      const NewImage(file: 'o2.png', width: 10, height: 10),
    ]);
  }

  Future<void> seedOshi() async {
    await db.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 5, 1),
      images: const [
        NewImage(file: 'old1.png'),
        NewImage(file: 'old2.png'),
      ],
    );
    await db.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 5, 2),
      images: const [NewImage(file: 'new1.png')],
    );
  }

  testWidgets('長按官方圖冊格：選的是這一格的封面，坑封面不變', (tester) async {
    await tester.runAsync(seedOfficial);
    await pumpHome(tester, PitPage(pitId: pitId));
    // 沒指定＝自動的一張（updatedAt 只到秒，哪張算最新不固定），選另一張。
    final auto = img('o2.png').evaluate().isNotEmpty ? 'o2.png' : 'o1.png';
    final other = auto == 'o2.png' ? 'o1.png' : 'o2.png';
    expect(img(auto), findsOneWidget);

    await tester.longPress(find.text('官方圖冊'));
    await settle(tester);
    expect(find.text('長按中：官方圖冊 封面'), findsOneWidget);
    await tester.tap(img(other));
    await settle(tester);

    expect(find.text('已設為「官方圖冊」的封面'), findsOneWidget);
    expect(find.byType(CoverPickPage), findsNothing);
    expect(img(other), findsOneWidget);
    expect(img(auto), findsNothing);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.coverImageId, isNull); // 主頁卡片的封面沒被動到
    final chosen = await tester.runAsync(
      () => db.chosenCellCoverId(pitId, 'official'),
    );
    expect(chosen, isNotNull);
    await unmount(tester);
  });

  testWidgets('摸魚格：選第二張 → 摸魚格換圖，坑封面不動', (tester) async {
    await tester.runAsync(() async {
      await db.saveDraft(
        pitId: pitId,
        images: const [
          NewImage(file: 'd1.png'),
          NewImage(file: 'd2.png'),
        ],
        tagIds: const [],
        ideaIds: const [],
      );
    });
    await pumpHome(tester, PitPage(pitId: pitId));
    expect(img('d1.png'), findsOneWidget);
    await tester.longPress(find.text('我的摸魚'));
    await settle(tester);
    await tester.tap(img('d2.png'));
    await settle(tester);
    expect(img('d2.png'), findsOneWidget);
    expect(img('d1.png'), findsNothing);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.coverImageId, isNull);
    await unmount(tester);
  });

  testWidgets('推活格：最新一筆第一張；長按列出全部推活圖、無分組 chip；選後換封面', (tester) async {
    await tester.runAsync(seedOshi);
    await pumpHome(tester, PitPage(pitId: pitId));
    expect(img('new1.png'), findsOneWidget); // 沒指定＝退回最新

    await tester.longPress(find.text('推活'));
    await settle(tester);
    expect(find.text('長按中：推活 封面'), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(img('new1.png'), findsOneWidget);
    expect(img('old1.png'), findsOneWidget);
    expect(img('old2.png'), findsOneWidget);
    await tester.tap(img('old2.png'));
    await settle(tester);

    expect(find.text('已設為「推活」的封面'), findsOneWidget);
    expect(img('old2.png'), findsOneWidget);
    expect(img('new1.png'), findsNothing);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.coverImageId, isNull);
    await unmount(tester);
  });

  testWidgets('沒有推活紀錄：推活格長按不開選擇封面', (tester) async {
    await pumpHome(tester, PitPage(pitId: pitId));
    await tester.longPress(find.text('推活'));
    await settle(tester);
    expect(find.byType(CoverPickPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('kind 為 null（編輯坑的更換封面）仍設定坑封面，不動格子封面', (tester) async {
    await tester.runAsync(seedOfficial);
    await pumpHome(tester, CoverPickPage(pitId: pitId));
    await tester.tap(img('o1.png'));
    await settle(tester);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.coverImageId, isNotNull);
    final chosen = await tester.runAsync(
      () => db.chosenCellCoverId(pitId, 'official'),
    );
    expect(chosen, isNull);
    await unmount(tester);
  });
}
