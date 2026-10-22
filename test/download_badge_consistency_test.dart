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
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/sync/download_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-052 一致規則：本機檔不存在＋已連結同步＝角標；下載完成角標消失；沒連結不顯示。
/// 不覆寫 imageTransferProvider，走真正的 provider 鏈（設定帳號＋實際檔案是否存在）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late ImageStore store;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_dlbadge');
    store = ImageStore(Directory('${tmp.path}/images'));
    pitId = await db.createPit(name: '坑A');
    final groups = await db.select(db.officialGroups).get();
    await db.addOfficial(pitId, groups.firstWhere((g) => g.pitId == pitId).id, [
      for (final f in ['o1.png', 'o2.png'])
        NewImage(file: f, width: 100, height: 150),
    ]);
    await db.addFanArts(pitId, [NewImage(file: 'f1.png')], author: '作者');
    final first = (await db.select(db.officialImages).get()).first;
    await db.setCover(pitId, first.id);
    await db.createPit(
      name: '淺坑',
      status: PitStatus.shallow,
      coverFile: 's1.png',
    );
    final archivedId = await db.createPit(name: '封存坑');
    await db.setCover(archivedId, first.id);
    await db.setPitStatus(archivedId, PitStatus.archived);
    // 封面指向的圖資料列還沒同步進來（meta 還在拉）。
    final unresolvedId = await db.createPit(name: '未到的封面');
    await db.setCover(unresolvedId, 'not-synced-yet');
  });

  void setView(WidgetTester tester, double w, double h, double dpr) {
    tester.view.physicalSize = Size(w * dpr, h * dpr);
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

  Future<void> pumpHome(
    WidgetTester tester,
    Widget home, {
    required bool linked,
  }) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      // 首次同步：已連結帳號、還沒完成過同步。
      if (linked) 'accountEmail': 'molly@example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith((ref) async => store),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Scaffold(body: home),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await settle(tester);
  }

  // 手機、iPad 直向、iPad 橫向。
  const sizes = <(double, double)>[(390, 844), (834, 1194), (1194, 834)];

  for (final (w, h) in sizes) {
    group('$w×$h', () {
      testWidgets('主頁：現坑田字、淺坑、封存坑封面都有角標', (tester) async {
        setView(tester, w, h, w < 600 ? 3 : 1);
        await pumpHome(tester, const PitsPage(), linked: true);
        // 現坑田字：坑A（檔案缺）＋封面資料還沒到的坑＝兩個角標。
        expect(find.byType(DownloadBadge), findsNWidgets(2));
        await tapText(tester, '淺坑');
        expect(find.byType(DownloadBadge), findsOneWidget);
        await tapText(tester, '封存坑');
        expect(find.byType(DownloadBadge), findsOneWidget);
        await unmount(tester);
      });

      testWidgets('主頁：沒連結同步不顯示角標', (tester) async {
        setView(tester, w, h, w < 600 ? 3 : 1);
        await pumpHome(tester, const PitsPage(), linked: false);
        expect(find.byType(DownloadBadge), findsNothing);
        await tapText(tester, '淺坑');
        expect(find.byType(DownloadBadge), findsNothing);
        await unmount(tester);
      });

      testWidgets('坑內頁、官方圖冊、同人圖：有角標；沒連結則沒有', (tester) async {
        setView(tester, w, h, w < 600 ? 3 : 1);
        for (final page in [
          PitPage(pitId: pitId),
          OfficialListPage(pitId: pitId),
          FanArtListPage(pitId: pitId),
        ]) {
          await pumpHome(tester, page, linked: true);
          expect(find.byType(DownloadBadge), findsWidgets);
          await unmount(tester);
          await pumpHome(tester, page, linked: false);
          expect(find.byType(DownloadBadge), findsNothing);
          await unmount(tester);
        }
      });
    });
  }

  testWidgets('封面檔下載完成後角標消失', (tester) async {
    setView(tester, 390, 844, 3);
    await pumpHome(tester, const PitsPage(), linked: true);
    expect(find.byType(DownloadBadge), findsNWidgets(2));
    final first = (await db.select(db.officialImages).get()).first;
    await tester.runAsync(
      () => store.save(first.imageFile, File('pubspec.yaml').readAsBytesSync()),
    );
    await settle(tester);
    // 只剩封面資料還沒到的那個坑。
    expect(find.byType(DownloadBadge), findsOneWidget);
    await unmount(tester);
  });
}
