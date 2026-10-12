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
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/goals/month_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 連續日頁（D-072）：分頁載入、月份標題、跳到某天、資料刷新不跑位。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  final key = GlobalKey<DayTimelineState>();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('dayflow');
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> draft(String title, DateTime date) => db.saveDraft(
    pitId: pitId,
    title: title,
    images: const [],
    tagIds: const [],
    ideaIds: const [],
    date: date,
  );

  /// 2025-01-01 起每天一筆 d00…d{n-1}；d39＝2025-02-09。
  Future<void> seed(WidgetTester tester, {int n = 40}) =>
      tester.runAsync(() async {
        for (var i = 0; i < n; i++) {
          await draft(
            'd${i.toString().padLeft(2, '0')}',
            DateTime(2025, 1, 1 + i, 12),
          );
        }
      });

  TimelineEntry entryOf(BuildContext c, TimelineItem it) => TimelineEntry(
    id: '${it.kind.name}-${it.id}',
    date: it.time,
    onTap: () {},
    title: it.title,
  );

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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

  Widget timeline({int pageSize = 5}) => Scaffold(
    body: DayTimeline(key: key, entryOf: entryOf, pageSize: pageSize),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> dragUp(WidgetTester tester, [double dy = 600]) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -dy));
    await settle(tester);
  }

  Future<void> jump(WidgetTester tester, DateTime day) async {
    await tester.runAsync(() => key.currentState!.jumpToDay(day));
    await settle(tester);
  }

  testWidgets('沒有紀錄：顯示空狀態文字', (tester) async {
    await show(tester, timeline());
    expect(find.text('還沒有紀錄'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('分頁：一開始只載入第一頁，捲到底才載下一頁，最後讀完', (tester) async {
    await seed(tester);
    await show(tester, timeline());
    expect(find.text('d39'), findsOneWidget);
    expect(find.text('d00'), findsNothing);
    var guard = 0;
    while (find.text('d00').evaluate().isEmpty) {
      await dragUp(tester);
      expect(++guard, lessThan(80));
    }
    expect(find.text('d00'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('月份標題：月份＋整月項數（不受已載入筆數影響）', (tester) async {
    await seed(tester);
    await show(tester, timeline());
    expect(find.text('2025 年 2 月'), findsOneWidget);
    expect(find.text('9 項'), findsOneWidget); // 2/1～2/9
    var guard = 0;
    while (find.text('2025 年 1 月').evaluate().isEmpty) {
      await dragUp(tester);
      expect(++guard, lessThan(80));
    }
    await dragUp(tester, 300);
    expect(find.text('31 項'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('同一天兩筆：第二筆不顯示日期，改小灰點', (tester) async {
    await tester.runAsync(() async {
      await draft('早', DateTime(2025, 1, 5, 9));
      await draft('晚', DateTime(2025, 1, 5, 21));
    });
    await show(tester, timeline());
    expect(find.text('05'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-dot')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('跳到某天：該天放在頂端，往上仍可捲回較新的', (tester) async {
    await seed(tester);
    await show(tester, timeline());
    await jump(tester, DateTime(2025, 1, 10));
    // 2025-01-10 ＝ d09
    expect(find.text('d09'), findsOneWidget);
    expect(tester.getTopLeft(find.text('d09')).dy, lessThan(200));
    expect(find.text('d10'), findsNothing); // 在視窗上方
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await settle(tester);
    expect(find.text('d10'), findsOneWidget);
    await dragUp(tester, 1500);
    expect(find.text('d00'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('跳到沒內容的日子：捲到它之前最近有內容的一天；之前都沒有＝頂端', (tester) async {
    await tester.runAsync(() async {
      await draft('舊', DateTime(2024, 6, 1, 8));
      await draft('新', DateTime(2025, 1, 3, 8));
    });
    await show(tester, timeline());
    await jump(tester, DateTime(2024, 7, 1));
    expect(find.text('舊'), findsOneWidget);
    expect(tester.getTopLeft(find.text('舊')).dy, lessThan(200));
    await jump(tester, DateTime(2023, 1, 1));
    expect(find.text('新'), findsOneWidget);
    expect(tester.getTopLeft(find.text('新')).dy, lessThan(200));
    await unmount(tester);
  });

  testWidgets('資料變動即時刷新，且不改變目前的捲動位置', (tester) async {
    await seed(tester);
    await show(tester, timeline());
    await dragUp(tester, 500);
    await dragUp(tester, 500);
    final probe = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith('d3') && w.data != 'd39',
    );
    expect(probe, findsWidgets);
    final text = (tester.widget(probe.first) as Text).data!;
    final before = tester.getTopLeft(find.text(text)).dy;
    await tester.runAsync(() => draft('新來的', DateTime(2025, 3, 1, 9)));
    await settle(tester);
    expect(tester.getTopLeft(find.text(text)).dy, closeTo(before, 0.5));
    // 回到最上面看得到新項目與新的月份標題
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 5000));
    await settle(tester);
    expect(find.text('新來的'), findsOneWidget);
    expect(find.text('2025 年 3 月'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('刪除項目後列表更新', (tester) async {
    await tester.runAsync(() async {
      await draft('甲', DateTime(2025, 1, 5, 9));
      await draft('乙', DateTime(2025, 1, 4, 9));
    });
    await show(tester, timeline());
    expect(find.text('乙'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.drafts).get());
    final id = rows!.firstWhere((d) => d.title == '乙').id;
    await tester.runAsync(() => db.deleteDrafts([id]));
    await settle(tester);
    expect(find.text('乙'), findsNothing);
    expect(find.text('甲'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('未來日期的項目在今天之上：一開始從今天開始，往上捲才看得到', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await draft('明天的', DateTime(now.year, now.month, now.day + 3, 9));
      await draft('今天的', DateTime(now.year, now.month, now.day, 9));
      await draft('昨天的', DateTime(now.year, now.month, now.day - 1, 9));
    });
    await show(tester, timeline());
    expect(find.text('明天的'), findsNothing);
    expect(tester.getTopLeft(find.text('今天的')).dy, lessThan(200));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
    await settle(tester);
    expect(find.text('明天的'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('日分頁沒有逐日切換列', (tester) async {
    await show(tester, const GoalsPage());
    await tester.tap(find.text('日'));
    await settle(tester);
    expect(find.bySemanticsLabel('前一天'), findsNothing);
    expect(find.bySemanticsLabel('後一天'), findsNothing);
    expect(find.byType(DayTimeline), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('月頁點日曆：切到「日」並捲到該日', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await draft('本月一日', DateTime(now.year, now.month, 1, 8));
      await draft('今天的', DateTime(now.year, now.month, now.day, 9));
    });
    await show(tester, const GoalsPage());
    await tester.tap(find.text('月'));
    await settle(tester);
    expect(find.byType(MonthView), findsOneWidget);
    await tester.tap(
      find
          .descendant(of: find.byType(MonthView), matching: find.text('1'))
          .first,
    );
    await settle(tester);
    expect(find.text('本月一日'), findsOneWidget);
    expect(tester.getTopLeft(find.text('本月一日')).dy, lessThan(500));
    await unmount(tester);
  });
}
