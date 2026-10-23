import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 記住上次停留的分頁：主頁現坑／淺坑／封存坑、時間軸年／月／日（存在本機設定，不同步）；底部導覽不記住，永遠從坑開始。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('remember_tab');
    await db.createPit(name: '現坑甲');
    await db.createPit(name: '淺坑乙', status: PitStatus.shallow);
    await db.createPit(name: '封存丙', status: PitStatus.archived);
  });
  tearDown(() async {
    await db.close();
  });

  Future<SharedPreferences> prefsWith(Map<String, Object> v) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, ...v});
    return SharedPreferences.getInstance();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester, SharedPreferences prefs) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  int goalsIndex(WidgetTester tester) {
    final stack = find.descendant(
      of: find.byType(GoalsPage),
      matching: find.byType(IndexedStack),
    );
    return tester.widget<IndexedStack>(stack.first).index!;
  }

  group('設定存取', () {
    ProviderContainer open(SharedPreferences p) {
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(p)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('預設：現坑、年；設定後寫進 SharedPreferences，重開讀得回', () async {
      final p = await prefsWith({});
      final c = open(p);
      final s = c.read(settingsProvider);
      expect(s.lastPitsTab, PitStatus.active);
      expect(s.lastGoalsMode, 0);
      c.read(settingsProvider.notifier).setLastPitsTab(PitStatus.archived);
      c.read(settingsProvider.notifier).setLastGoalsMode(2);

      final s2 = open(p).read(settingsProvider);
      expect(s2.lastPitsTab, PitStatus.archived);
      expect(s2.lastGoalsMode, 2);
    });

    test('不合法的值（未知名稱、超出範圍、負數）一律回預設', () async {
      final p = await prefsWith({
        'lastPitsTab': 'whatever',
        'lastGoalsMode': -1,
      });
      final s = open(p).read(settingsProvider);
      expect(s.lastPitsTab, PitStatus.active);
      expect(s.lastGoalsMode, 0);
    });
  });

  testWidgets('主頁：切到封存坑後重開 App，第一幀就是封存坑；點回現坑也會記住', (tester) async {
    final p = await prefsWith({});
    await pumpApp(tester, p);
    expect(find.text('現坑甲'), findsOneWidget);
    await tester.tap(find.text('封存坑'));
    await settle(tester);
    expect(find.text('封存丙'), findsOneWidget);
    expect(p.getString('lastPitsTab'), 'archived');

    // 「重開 App」：全新的 widget 樹、同一份設定。
    await restart(tester);
    await pumpApp(tester, p);
    expect(find.text('封存丙'), findsOneWidget);
    expect(find.text('現坑甲'), findsNothing);

    await tester.tap(find.text('現坑'));
    await settle(tester);
    expect(find.text('現坑甲'), findsOneWidget);
    expect(p.getString('lastPitsTab'), 'active');
    await restart(tester);
  });

  testWidgets('主頁：存了淺坑 → 開 App 直接是淺坑；存了壞值 → 現坑', (tester) async {
    await pumpApp(tester, await prefsWith({'lastPitsTab': 'shallow'}));
    expect(find.text('淺坑乙'), findsOneWidget);
    expect(find.text('現坑甲'), findsNothing);
    await restart(tester);

    await pumpApp(tester, await prefsWith({'lastPitsTab': '???'}));
    expect(find.text('現坑甲'), findsOneWidget);
    await restart(tester);
  });

  testWidgets('時間軸頁：切到日 → 存起來；重開仍從坑開始，切回時間軸頁停在日；壞值回年', (tester) async {
    final p = await prefsWith({});
    await pumpApp(tester, p);
    await tester.tap(find.text('時間軸'));
    await settle(tester);
    expect(goalsIndex(tester), 0);
    await tester.tap(find.text('日'));
    await settle(tester);
    expect(p.getInt('lastGoalsMode'), 2);
    // 底部導覽不記住。
    expect(p.getInt('lastNavTab'), isNull);

    await restart(tester);
    await pumpApp(tester, p);
    expect(find.byType(PitsPage).hitTestable(), findsOneWidget);
    expect(find.byType(GoalsPage).hitTestable(), findsNothing);
    await tester.tap(find.text('時間軸'));
    await settle(tester);
    expect(goalsIndex(tester), 2);
    await restart(tester);

    await pumpApp(tester, await prefsWith({'lastGoalsMode': 7}));
    await tester.tap(find.text('時間軸'));
    await settle(tester);
    expect(goalsIndex(tester), 0);
    await restart(tester);
  });

  testWidgets('底部導覽不記住：切到「我的」→ 重開仍從坑開始；舊版殘留的 lastNavTab 也不理', (tester) async {
    final p = await prefsWith({});
    await pumpApp(tester, p);
    await tester.tap(find.text('我的').last);
    await settle(tester);
    expect(p.getInt('lastNavTab'), isNull);
    await restart(tester);

    await pumpApp(tester, p);
    expect(find.byType(PitsPage).hitTestable(), findsOneWidget);
    await restart(tester);

    await pumpApp(tester, await prefsWith({'lastNavTab': 2}));
    expect(find.byType(PitsPage).hitTestable(), findsOneWidget);
    await restart(tester);
  });
}
