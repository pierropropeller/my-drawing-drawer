import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/timeline.dart';
import 'package:huakeng/ui/goals/day_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 時間軸月份標題置頂（D-077）：共用 TimelineView 與分頁的日頁 DayTimeline。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app(Widget body) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    theme: buildTheme(Brightness.light, useGoogleFonts: false),
    home: Scaffold(body: body),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Finder header(String text) =>
      find.widgetWithText(TimelineSectionHeader, text);

  group('TimelineView（SliverMainAxisGroup + pinned）', () {
    // 10 月 10 筆、9 月 10 筆。
    final entries = [
      for (var i = 0; i < 10; i++)
        TimelineEntry(
          id: 'o$i',
          date: DateTime(2026, 10, 20 - i),
          onTap: () {},
          title: 'o$i',
        ),
      for (var i = 0; i < 10; i++)
        TimelineEntry(
          id: 's$i',
          date: DateTime(2026, 9, 20 - i),
          onTap: () {},
          title: 's$i',
        ),
    ];

    testWidgets('捲離頂端後月份標題仍貼在頂端並出現陰影；下一個月把它推走', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(TimelineView(entries: entries, countLabel: (n) => '$n 筆')),
      );
      final oct = header('2026 年 10 月');
      expect(tester.getTopLeft(oct).dy, 0);
      expect(tester.widget<TimelineSectionHeader>(oct).stuck, isFalse);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      // 10 月的標題還在頂端，且已置頂（有陰影）。
      expect(tester.getTopLeft(oct).dy, 0);
      expect(tester.widget<TimelineSectionHeader>(oct).stuck, isTrue);

      // 接近月底：下一個月的標題頂到時，10 月標題被往上推（開始離開頂端），9 月標題還沒置頂。
      final scroll = find.byType(CustomScrollView);
      final sep = header('2026 年 9 月');
      var guard = 0;
      while (sep.evaluate().isEmpty ||
          tester.getTopLeft(sep).dy > kTimelineHeaderHeight - 1) {
        await tester.drag(scroll, const Offset(0, -40));
        await tester.pump();
        expect(++guard, lessThan(100));
      }
      final pushedTop = tester.getTopLeft(oct).dy;
      final sepTop = tester.getTopLeft(sep).dy;
      expect(pushedTop, lessThan(0));
      expect(sepTop, greaterThan(0));
      // 推走時兩個標題首尾相接。
      expect(pushedTop + kTimelineHeaderHeight, closeTo(sepTop, 0.5));

      // 再往下：9 月標題置頂，10 月標題已不在畫面。
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pump();
      expect(tester.getTopLeft(sep).dy, 0);
      expect(tester.widget<TimelineSectionHeader>(sep).stuck, isTrue);
    });

    testWidgets('置頂標題滿版、固定高度', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        app(TimelineView(entries: entries, countLabel: (n) => '$n 筆')),
      );
      final size = tester.getSize(header('2026 年 10 月'));
      expect(size.width, tester.view.physicalSize.width / 3);
      expect(size.height, kTimelineHeaderHeight);
    });
  });

  group('DayTimeline（浮層）', () {
    late AppDatabase db;
    late Directory dir;
    late String pitId;
    final key = GlobalKey<DayTimelineState>();

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dir = Directory.systemTemp.createTempSync('sticky');
      pitId = await db.createPit(name: '坑A');
    });
    tearDown(() async => db.close());

    TimelineEntry entryOf(BuildContext c, TimelineItem it) => TimelineEntry(
      id: '${it.kind.name}-${it.id}',
      date: it.time,
      onTap: () {},
      title: it.title,
    );

    Future<void> show(WidgetTester tester) async {
      phone(tester);
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPrefsProvider.overrideWithValue(prefs),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${dir.path}/images')),
            ),
          ],
          child: app(DayTimeline(key: key, entryOf: entryOf, pageSize: 8)),
        ),
      );
      await settle(tester);
    }

    /// 2025-01-01 起每天一筆，共 70 天（1 月 31 筆、2 月 28 筆、3 月 11 筆）。
    Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
      for (var i = 0; i < 70; i++) {
        await db.saveDraft(
          pitId: pitId,
          title: 'd${i.toString().padLeft(2, '0')}',
          images: const [],
          tagIds: const [],
          ideaIds: const [],
          date: DateTime(2025, 1, 1 + i, 12),
        );
      }
    });

    Finder sticky() => find.byKey(const ValueKey('day-sticky-header'));

    testWidgets('在頂端不顯示浮層；捲動後浮層是目前月份且有陰影', (tester) async {
      await seed(tester);
      await show(tester);
      expect(sticky(), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await settle(tester);
      expect(sticky(), findsOneWidget);
      expect(tester.getTopLeft(sticky()).dy, 0);
      expect(tester.widget<TimelineSectionHeader>(sticky()).stuck, isTrue);
      // 最新的是 2025-03-11，一開始在 3 月。
      expect(
        find.descendant(of: sticky(), matching: find.text('2025 年 3 月')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('捲過月底：浮層換成較舊的月份', (tester) async {
      await seed(tester);
      await show(tester);
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await settle(tester);
      }
      expect(
        find.descendant(of: sticky(), matching: find.text('2025 年 3 月')),
        findsNothing,
      );
      expect(sticky(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('下一個月的標題頂上來時把浮層往上推，兩者首尾相接', (tester) async {
      await seed(tester);
      await show(tester);
      final scroll = find.byType(CustomScrollView);
      // 3 月（11 筆）捲過後，2 月的標題會從下面頂上來。
      final feb = find.widgetWithText(TimelineSectionHeader, '2025 年 2 月');
      var guard = 0;
      while (feb.evaluate().isEmpty ||
          tester.getTopLeft(feb).dy > kTimelineHeaderHeight - 1) {
        await tester.drag(scroll, const Offset(0, -40));
        await settle(tester);
        expect(++guard, lessThan(200));
      }
      final top = tester.getTopLeft(sticky()).dy;
      expect(top, lessThan(0));
      expect(
        top + kTimelineHeaderHeight,
        closeTo(tester.getTopLeft(feb).dy, 0.5),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('跳到某天後：該天在頂端，浮層月份跟該天一致', (tester) async {
      await seed(tester);
      await show(tester);
      await tester.runAsync(
        () => key.currentState!.jumpToDay(DateTime(2025, 1, 15)),
      );
      await settle(tester);
      expect(find.text('d14'), findsOneWidget);
      // 第一列是 d14（1 月 15 日），同月的標題在上方，所以浮層出現且是 1 月。
      expect(
        find.descendant(of: sticky(), matching: find.text('2025 年 1 月')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
