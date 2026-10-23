import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/goals/review_pick_sheet.dart';
import 'package:huakeng/ui/goals/year_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-112：時間軸 · 年——月份格右上的月度小目標進度圈、點月份格進入該月、長按照舊選代表圖。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late SharedPreferences prefs;
  const year = 2026;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('month_ring');
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async {
    await db.close();
  });

  Future<String> monthGoal(int month, int count, {int y = year}) => db.saveGoal(
    period: GoalPeriod.month,
    year: y,
    month: month,
    kind: GoalKind.idea,
    count: count,
  );

  Future<void> idea(DateTime at) => db.saveIdea(
    pitId: pitId,
    title: 'i',
    body: '',
    images: const [],
    tagIds: const [],
    draftIds: const [],
    pieceIds: const [],
    createdAt: at,
  );

  Future<void> piece(String title, String file, DateTime at, int likes) async {
    final id = await db.savePiece(
      pitId: pitId,
      title: title,
      body: '',
      images: [NewImage(file: file)],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: at,
      ideaIds: const [],
      draftIds: const [],
      isPublished: true,
    );
    await db.setActualLikes(id, likes);
  }

  group('watchMonthGoalProgress', () {
    test('達成、部分、零進度、沒有小目標的月份；其他年與年度目標不算', () async {
      // 3 月：兩個目標都達成（腦洞各 1 個的目標，建立 2 個腦洞）。
      await monthGoal(3, 1);
      await monthGoal(3, 1);
      await idea(DateTime(year, 3, 5));
      // 5 月：一個達成、一個未達成。
      await monthGoal(5, 1);
      await monthGoal(5, 2);
      await idea(DateTime(year, 5, 5));
      // 7 月：一個目標，完全沒進度。
      await monthGoal(7, 3);
      // 其他年的月度目標、年度目標都不影響這一年。
      await monthGoal(4, 1, y: 2025);
      await db.saveGoal(
        period: GoalPeriod.year,
        year: year,
        kind: GoalKind.idea,
        count: 1,
      );

      final m = await db.watchMonthGoalProgress(year).first;
      expect(m.keys.toSet(), {3, 5, 7});
      expect((m[3]!.done, m[3]!.total, m[3]!.allDone), (2, 2, true));
      expect(m[3]!.ratio, 1);
      expect((m[5]!.done, m[5]!.total, m[5]!.allDone), (1, 2, false));
      expect(m[5]!.ratio, 0.5);
      expect((m[7]!.done, m[7]!.total, m[7]!.allDone), (0, 1, false));
      expect(m[7]!.ratio, 0);
      expect(m.containsKey(1), isFalse); // 沒有小目標＝不在結果裡
    });

    test('已刪除的小目標不算；整年沒有小目標＝空', () async {
      expect(await db.watchMonthGoalProgress(year).first, isEmpty);
      final id = await monthGoal(2, 1);
      expect((await db.watchMonthGoalProgress(year).first).keys, [2]);
      await db.deleteGoal(id);
      expect(await db.watchMonthGoalProgress(year).first, isEmpty);
    });
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
    bool ipad = false,
  }) async {
    tester.view.physicalSize = ipad
        ? const Size(1194, 834)
        : const Size(1080, 2400);
    tester.view.devicePixelRatio = ipad ? 1 : 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
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
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('進度圈：有小目標的月份才顯示 20px 圈；全達成與否分開判斷', (tester) async {
    await tester.runAsync(() async {
      await monthGoal(3, 1);
      await idea(DateTime(year, 3, 2));
      await monthGoal(5, 2);
    });
    await show(tester, const Scaffold(body: YearView(year: year)));
    final rings = find.byType(MonthGoalRing);
    expect(rings, findsNWidgets(2));
    expect(
      tester.getSize(find.byType(MonthGoalRing).first),
      const Size(20, 20),
    );
    final states = tester
        .widgetList<MonthGoalRing>(rings)
        .map((r) => r.progress.allDone)
        .toList();
    expect(states, [true, false]); // 3 月全達成（綠）、5 月未達成（主色）

    // 位置：3 月格右上角（距格右緣、上緣 5px）。
    final cell3 = tester.getRect(
      find
          .ancestor(of: find.text('3月'), matching: find.byType(GestureDetector))
          .first,
    );
    final ring3 = tester.getRect(rings.first);
    expect(cell3.top + 5, closeTo(ring3.top, .5));
    expect(cell3.right - 5, closeTo(ring3.right, .5));
    // 沒有小目標的 4 月格不含進度圈。
    final cell4 = find
        .ancestor(of: find.text('4月'), matching: find.byType(GestureDetector))
        .first;
    expect(
      find.descendant(of: cell4, matching: find.byType(MonthGoalRing)),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('P-039：iPad 版面（wide）進度圈 24px、離右上角 6', (tester) async {
    await tester.runAsync(() async {
      await monthGoal(3, 1);
    });
    await show(
      tester,
      const Scaffold(body: YearView(year: year, wide: true, side: 40)),
      ipad: true,
    );
    final ring = find.byType(MonthGoalRing);
    expect(ring, findsOneWidget);
    expect(tester.getSize(ring), const Size(24, 24));
    final cell3 = tester.getRect(
      find
          .ancestor(of: find.text('3月'), matching: find.byType(GestureDetector))
          .first,
    );
    final r = tester.getRect(ring);
    expect(cell3.top + 6, closeTo(r.top, .5));
    expect(cell3.right - 6, closeTo(r.right, .5));
    await unmount(tester);
  });

  testWidgets('點月份格進入該月（切到月、月頁是那個月、記住分頁）', (tester) async {
    await show(tester, const GoalsPage());
    await tester.tap(find.text('3月'));
    await settle(tester);
    expect(find.text('3 月'), findsOneWidget);
    expect(prefs.getInt('lastGoalsMode'), 1);
    expect(find.text('排版'), findsNothing); // 沒有跳去排版頁
    await unmount(tester);
  });

  testWidgets('長按照舊：多於一張成圖的月份打開選圖 sheet', (tester) async {
    await tester.runAsync(() async {
      await piece('春天', 'a.png', DateTime(year, 3, 1), 5);
      await piece('夏天', 'b.png', DateTime(year, 3, 2), 9);
    });
    await show(tester, const Scaffold(body: YearView(year: year)));
    await tester.longPress(find.text('3月'));
    await settle(tester);
    expect(find.byType(ReviewPickSheet), findsOneWidget);
    await unmount(tester);
  });
}
