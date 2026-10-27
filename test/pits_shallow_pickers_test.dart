import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/move_sheet.dart';
import 'package:huakeng/ui/goals/day_add_sheet.dart';
import 'package:huakeng/ui/goals/goal_new_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 選擇清單（D-088）：分享匯入、圖片移動、日頁新增、新增目標——
/// 淺坑列出但只開放開啟的格子，封存坑不列。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String active;
  late String shallow;
  late String archived;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('shallow_pickers');
    active = await db.createPit(name: '現坑甲');
    shallow = await db.createPit(
      name: '淺坑乙',
      status: PitStatus.shallow,
      enabledSections: {PitSectionKey.fan, PitSectionKey.draft},
    );
    archived = await db.createPit(name: '封存丙');
    await db.setPitStatus(archived, PitStatus.archived);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHome(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          sharedPrefsProvider.overrideWithValue(prefs),
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

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(ShareSheet), matching: f);

  testWidgets('分享匯入：坑 chips 含淺坑、不含封存坑；淺坑只列開啟的格子', (tester) async {
    await pumpHome(
      tester,
      Scaffold(
        body: ShareSheet(paths: const [], initialPitId: active),
      ),
    );
    expect(inSheet(find.text('現坑甲')), findsOneWidget);
    expect(inSheet(find.text('淺坑乙')), findsOneWidget);
    expect(inSheet(find.text('封存丙')), findsNothing);
    // 現坑六格（沒開雜物所以沒有雜物）
    for (final s in ['官方圖冊', '好看同人圖', '推活', '摸魚', '腦洞', '成圖']) {
      expect(inSheet(find.text(s)), findsOneWidget, reason: s);
    }
    await tester.tap(inSheet(find.text('淺坑乙')));
    await settle(tester);
    expect(inSheet(find.text('好看同人圖')), findsOneWidget);
    expect(inSheet(find.text('摸魚')), findsOneWidget);
    for (final s in ['官方圖冊', '推活', '腦洞', '成圖', '雜物']) {
      expect(inSheet(find.text(s)), findsNothing, reason: s);
    }
    await unmount(tester);
  });

  testWidgets('分享匯入：淺坑開了雜物就有雜物格', (tester) async {
    await db.setPitSectionEnabled(shallow, PitSectionKey.junk, true);
    await pumpHome(
      tester,
      Scaffold(
        body: ShareSheet(paths: const [], initialPitId: shallow),
      ),
    );
    expect(inSheet(find.text('雜物')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('移動 sheet：坑 chips 含淺坑、不含封存坑；換到淺坑只剩開啟的格子', (tester) async {
    await pumpHome(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMoveSheet(
              context,
              pitId: active,
              from: AlbumCell.official,
              count: 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    Finder s(String t) =>
        find.descendant(of: find.byType(MoveSheet), matching: find.text(t));
    expect(s('現坑甲'), findsOneWidget);
    expect(s('淺坑乙'), findsOneWidget);
    expect(s('封存丙'), findsNothing);
    expect(s('官方圖冊'), findsOneWidget);
    await tester.tap(s('淺坑乙'));
    await settle(tester);
    // 淺坑乙沒開官方圖冊：只剩好看同人圖，並且自動換到它
    expect(s('官方圖冊'), findsNothing);
    expect(s('好看同人圖'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('日頁新增：淺坑只在它開啟的類型出現', (tester) async {
    final pits = (await tester.runAsync(() => db.watchSelectablePits().first))!;
    expect(pits.map((p) => p.id).toSet(), {active, shallow});
    DayAddChoice? result;
    await pumpHome(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showDayAddSheet(context, pits: pits),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    // 腦洞：只有現坑甲開著 → 直接選它
    await tester.tap(find.text('腦洞'));
    await settle(tester);
    expect(result?.pitId, active);
    expect(result?.kind, GoalKind.idea);

    // 摸魚：現坑甲和淺坑乙都開著 → 列出兩個坑
    result = null;
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('摸魚'));
    await settle(tester);
    expect(find.text('現坑甲'), findsOneWidget);
    expect(find.text('淺坑乙'), findsOneWidget);
    expect(find.text('封存丙'), findsNothing);
    await tester.tap(find.text('淺坑乙'));
    await settle(tester);
    expect(result?.pitId, shallow);
    await unmount(tester);
  });

  testWidgets('新增目標：選坑清單含現坑與淺坑、不含封存坑', (tester) async {
    await pumpHome(
      tester,
      const GoalNewPage(period: GoalPeriod.year, year: 2026),
    );
    final chip = find.text('選擇');
    await tester.ensureVisible(chip.first);
    await tester.tap(chip.first);
    await settle(tester);
    // D-124：選擇坑面板（可多選）
    expect(find.text('現坑甲'), findsOneWidget);
    expect(find.textContaining('淺坑乙'), findsOneWidget);
    expect(find.textContaining('封存丙'), findsNothing);
    await unmount(tester);
  });
}
