import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_view.dart' show ChipRow;
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/swipe_to_switch.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';
import 'package:huakeng/ui/search/search_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 列表區左右滑動切換篩選 pills（沒有畫在設計稿，介面上看不到）。
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// 真手指的拖曳：很多個 move 事件、垂直方向有 ±[wobble] px 的抖動、有時間戳（速度由此算出）。
  /// [dx]/[dy] 是起點到終點的淨位移。
  Future<void> realDrag(
    WidgetTester tester,
    Offset from,
    Offset delta, {
    double wobble = 12,
    double wobbleX = 0,
    int steps = 24,
    Duration duration = const Duration(milliseconds: 400),
    bool release = true,
  }) async {
    final g = await tester.startGesture(from);
    var t = Duration.zero;
    final dt = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      t += dt;
      final f = i / steps;
      final wy = i == steps ? 0.0 : wobble * math.sin(i * 1.9);
      final wx = i == steps ? 0.0 : wobbleX * math.sin(i * 2.3);
      await g.moveTo(from + delta * f + Offset(wx, wy), timeStamp: t);
      await tester.pump(dt);
    }
    if (release) {
      await g.up(timeStamp: t);
      await tester.pump();
    }
  }

  const slow = Duration(milliseconds: 450);
  const fast = Duration(milliseconds: 90);

  group('SwipeToSwitch 元件', () {
    late List<String> log;
    setUp(() => log = []);

    Future<void> pump(
      WidgetTester tester, {
      bool enabled = true,
      bool hasPrev = true,
      bool hasNext = true,
      Widget? child,
    }) async {
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeToSwitch(
              enabled: enabled,
              onPrev: hasPrev ? () => log.add('prev') : null,
              onNext: hasNext ? () => log.add('next') : null,
              child:
                  child ??
                  ListView(
                    key: const Key('list'),
                    children: [
                      for (var i = 0; i < 40; i++)
                        SizedBox(height: 60, child: Text('row$i')),
                    ],
                  ),
            ),
          ),
        ),
      );
    }

    Widget carousel() => SizedBox(
      height: 100,
      child: ListView(
        key: const Key('carousel'),
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < 10; i++) SizedBox(width: 200, child: Text('c$i')),
        ],
      ),
    );

    testWidgets('往左滑＝下一個、往右滑＝上一個', (tester) async {
      await pump(tester);
      await tester.dragFrom(const Offset(200, 300), const Offset(-150, 0));
      await tester.pump();
      expect(log, ['next']);
      await tester.dragFrom(const Offset(200, 300), const Offset(150, 0));
      await tester.pump();
      expect(log, ['next', 'prev']);
    });

    testWidgets('端點不循環：沒有上一個時右滑、沒有下一個時左滑都沒事', (tester) async {
      await pump(tester, hasPrev: false);
      await tester.dragFrom(const Offset(200, 300), const Offset(150, 0));
      await tester.pump();
      expect(log, isEmpty);
      await pump(tester, hasNext: false);
      await tester.dragFrom(const Offset(200, 300), const Offset(-150, 0));
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('垂直捲動照常捲動、不切換；斜向（縱向為主）不切換', (tester) async {
      await pump(tester);
      await tester.dragFrom(const Offset(200, 500), const Offset(0, -300));
      await tester.pump();
      expect(log, isEmpty);
      expect(find.text('row0'), findsNothing); // 列表真的捲動了
      await tester.dragFrom(const Offset(200, 500), const Offset(-80, -200));
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('位移太短、太慢都不算', (tester) async {
      await pump(tester);
      await tester.dragFrom(const Offset(200, 300), const Offset(-30, 0));
      await tester.pump();
      expect(log, isEmpty);
      final g = await tester.startGesture(const Offset(200, 300));
      await g.moveBy(
        const Offset(-150, 0),
        timeStamp: const Duration(seconds: 2),
      );
      await g.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('多選中（enabled=false）不切換', (tester) async {
      await pump(tester, enabled: false);
      await tester.dragFrom(const Offset(200, 300), const Offset(-150, 0));
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('起點在螢幕左右邊緣 24px 內不切換（保留返回手勢）', (tester) async {
      await pump(tester);
      await tester.dragFrom(const Offset(10, 300), const Offset(150, 0));
      await tester.pump();
      await tester.dragFrom(const Offset(380, 300), const Offset(-150, 0));
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('起點在橫向捲動區（輪播）上：由它捲動，不切換', (tester) async {
      await pump(
        tester,
        child: Column(
          children: [
            carousel(),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      );
      await tester.drag(
        find.byKey(const Key('carousel')),
        const Offset(-150, 0),
      );
      await tester.pump();
      expect(log, isEmpty);
      // 同一個 child 的空白處照樣可以切換。
      await tester.dragFrom(const Offset(200, 500), const Offset(-150, 0));
      await tester.pump();
      expect(log, ['next']);
    });

    testWidgets('輪播已在端點（捲不動）時也不切換', (tester) async {
      await pump(tester, child: carousel());
      await tester.drag(
        find.byKey(const Key('carousel')),
        const Offset(150, 0),
      );
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('真手指：慢速（450ms）帶 ±12px 垂直抖動的橫滑，起點在有列表項目上', (tester) async {
      await pump(tester);
      await realDrag(
        tester,
        const Offset(220, 400),
        const Offset(-120, 0),
        duration: slow,
      );
      expect(log, ['next']);
      await realDrag(
        tester,
        const Offset(160, 400),
        const Offset(120, 0),
        duration: slow,
      );
      expect(log, ['next', 'prev']);
    });

    testWidgets('真手指：快速甩動（位移只有 40px 但速度夠）也算', (tester) async {
      await pump(tester);
      await realDrag(
        tester,
        const Offset(220, 400),
        const Offset(-40, 0),
        duration: const Duration(milliseconds: 40),
        steps: 8,
      );
      expect(log, ['next']);
    });

    testWidgets('真手指：位移 < 48px 且很慢＝不算', (tester) async {
      await pump(tester);
      await realDrag(
        tester,
        const Offset(220, 400),
        const Offset(-30, 0),
        duration: const Duration(milliseconds: 600),
      );
      expect(log, isEmpty);
    });

    testWidgets('真手指：起點在空白處（列表之外沒有內容）也能切換', (tester) async {
      await pump(tester, child: const SizedBox.expand());
      await realDrag(
        tester,
        const Offset(300, 600),
        const Offset(-140, 0),
        duration: slow,
      );
      expect(log, ['next']);
    });

    testWidgets('真手指：起點在卡片（可點擊）上也能切換，且不觸發點擊', (tester) async {
      var taps = 0;
      await pump(
        tester,
        child: ListView(
          children: [
            for (var i = 0; i < 20; i++)
              InkWell(
                onTap: () => taps++,
                child: SizedBox(height: 80, child: Text('card$i')),
              ),
          ],
        ),
      );
      await realDrag(
        tester,
        const Offset(200, 120),
        const Offset(-130, 0),
        duration: slow,
      );
      expect(log, ['next']);
      expect(taps, 0);
      await tester.tap(find.text('card1'));
      expect(taps, 1);
    });

    testWidgets('真手指：縱向為主（帶橫向抖動 ±12px）＝照常捲動、不切換', (tester) async {
      await pump(tester);
      await realDrag(
        tester,
        const Offset(200, 600),
        const Offset(0, -300),
        wobble: 0,
        wobbleX: 12,
        duration: slow,
      );
      expect(log, isEmpty);
      expect(find.text('row0'), findsNothing);
      // 稍斜（橫 60 縱 220）仍是縱向捲動。
      await realDrag(
        tester,
        const Offset(200, 600),
        const Offset(-60, -220),
        wobble: 0,
        wobbleX: 6,
        duration: slow,
      );
      expect(log, isEmpty);
    });

    testWidgets('真手指：橫滑時列表不會跟著捲動（捲動位置不變）', (tester) async {
      await pump(tester);
      final before = tester.getTopLeft(find.text('row3')).dy;
      await realDrag(
        tester,
        const Offset(220, 400),
        const Offset(-140, 0),
        duration: slow,
      );
      expect(log, ['next']);
      expect(tester.getTopLeft(find.text('row3')).dy, before);
    });

    testWidgets('真手指：起點在橫向輪播上＝輪播自己捲、不切換；輪播之外照常切換', (tester) async {
      await pump(
        tester,
        child: Column(
          children: [
            carousel(),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      );
      await realDrag(
        tester,
        const Offset(300, 50),
        const Offset(-150, 0),
        duration: slow,
      );
      expect(log, isEmpty);
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(
                of: find.byKey(const Key('carousel')),
                matching: find.byType(Scrollable),
              ),
            )
            .position
            .pixels,
        greaterThan(50),
      );
      await realDrag(
        tester,
        const Offset(300, 500),
        const Offset(-150, 0),
        duration: slow,
      );
      expect(log, ['next']);
    });

    testWidgets('真手指：邊緣 24px 內起手、多選（enabled=false）都不切換', (tester) async {
      await pump(tester);
      await realDrag(
        tester,
        const Offset(12, 400),
        const Offset(150, 0),
        duration: slow,
      );
      await realDrag(
        tester,
        const Offset(378, 400),
        const Offset(-150, 0),
        duration: slow,
      );
      expect(log, isEmpty);
      await pump(tester, enabled: false);
      await realDrag(
        tester,
        const Offset(200, 400),
        const Offset(-150, 0),
        duration: slow,
      );
      expect(log, isEmpty);
    });

    testWidgets('among：依序切換、兩端不循環', (tester) async {
      var cur = 'b';
      phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, set) => SwipeToSwitch.among<String>(
              order: const ['a', 'b', 'c'],
              current: cur,
              onChanged: (v) => set(() => cur = v),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      Future<void> swipe(double dx) async {
        await tester.dragFrom(const Offset(200, 300), Offset(dx, 0));
        await tester.pump();
      }

      await swipe(-150);
      expect(cur, 'c');
      await swipe(-150);
      expect(cur, 'c');
      await swipe(150);
      await swipe(150);
      expect(cur, 'a');
      await swipe(150);
      expect(cur, 'a');
    });
  });

  group('頁面', () {
    late AppDatabase db;
    late Directory tmp;
    late String pitId;
    late SharedPreferences prefs;

    setUp(() async {
      navBarHiddenCount.value = 0;
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('swipe_switch');
      pitId = await db.createPit(name: '測試坑');
    });
    tearDown(() async => db.close());

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            databaseProvider.overrideWithValue(db),
            sharedPrefsProvider.overrideWithValue(prefs),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${tmp.path}/images')),
            ),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
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

    Future<void> swipe(WidgetTester tester, double dx, {double y = 500}) async {
      await realDrag(
        tester,
        Offset(195 - dx / 4, y),
        Offset(dx, 0),
        duration: slow,
      );
      await settle(tester);
    }

    testWidgets('主頁 現坑｜淺坑｜封存坑：左右滑切換、記住分頁、端點不循環', (tester) async {
      phone(tester);
      await pumpPage(tester, const PitsPage());
      String tab() => prefs.getString('lastPitsTab') ?? 'active';
      expect(tab(), 'active');
      await swipe(tester, 150); // 第一個再右滑：沒事
      expect(tab(), 'active');
      await swipe(tester, -150);
      expect(tab(), 'shallow');
      await swipe(tester, -150);
      expect(tab(), 'archived');
      await swipe(tester, -150); // 最後一個再左滑：沒事
      expect(tab(), 'archived');
      await swipe(tester, 150);
      expect(tab(), 'shallow');
      await unmount(tester);
    });

    testWidgets('主頁有很多坑：縱向拖曳（帶橫向抖動）照常捲動不切換；橫滑（帶垂直抖動）起點在卡片上照樣切換', (
      tester,
    ) async {
      phone(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 25; i++) {
          await db.createPit(name: '坑$i');
        }
      });
      await pumpPage(tester, const PitsPage());
      await settle(tester);
      await settle(tester);
      String tab() => prefs.getString('lastPitsTab') ?? 'active';
      final firstBefore = tester.getTopLeft(find.text('坑0').first).dy;
      await realDrag(
        tester,
        const Offset(195, 650),
        const Offset(0, -350),
        wobble: 0,
        wobbleX: 12,
        duration: slow,
      );
      await settle(tester);
      expect(tab(), 'active');
      expect(
        find.text('坑0').evaluate().isEmpty ||
            tester.getTopLeft(find.text('坑0').first).dy < firstBefore - 50,
        isTrue,
        reason: '列表應該被垂直捲動',
      );
      // 起點在卡片上橫滑（快甩）。
      await realDrag(
        tester,
        const Offset(260, 300),
        const Offset(-70, 0),
        duration: fast,
        steps: 8,
      );
      await settle(tester);
      expect(tab(), 'shallow');
      await unmount(tester);
    });

    testWidgets('推活：分組 pills 橫滑切換，列表可垂直捲動', (tester) async {
      phone(tester);
      await tester.runAsync(() async {
        await Directory('${tmp.path}/images').create(recursive: true);
        for (var i = 0; i < 30; i++) {
          await db.saveOshiRecord(
            pitId: pitId,
            date: DateTime(2026, 1 + i % 10, 1 + i % 28),
            title: '推$i',
            images: [NewImage(file: 'o$i.png', width: 30, height: 40)],
          );
        }
      });
      await pumpPage(tester, OshiListPage(pitId: pitId));
      final groups = (await tester.runAsync(
        () => db.watchGroups(pitId, kind: 'oshi').first,
      ))!;
      expect(groups, isNotEmpty);
      String? selected() =>
          tester.widget<ChipRow>(find.byType(ChipRow).first).selected;
      expect(selected(), isNull);
      await swipe(tester, -150, y: 500);
      expect(selected(), groups.first.id);
      await swipe(tester, 150, y: 500);
      expect(selected(), isNull);
      await realDrag(
        tester,
        const Offset(195, 650),
        const Offset(0, -300),
        wobble: 0,
        wobbleX: 12,
        duration: slow,
      );
      await settle(tester);
      expect(selected(), isNull);
      await unmount(tester);
    });

    testWidgets('時間軸 年｜月｜日：左右滑切換並記住', (tester) async {
      phone(tester);
      await pumpPage(tester, const GoalsPage());
      expect(prefs.getInt('lastGoalsMode'), isNull);
      await swipe(tester, -150);
      expect(prefs.getInt('lastGoalsMode'), 1);
      await swipe(tester, -150);
      expect(prefs.getInt('lastGoalsMode'), 2);
      await swipe(tester, -150);
      expect(prefs.getInt('lastGoalsMode'), 2);
      await swipe(tester, 150);
      expect(prefs.getInt('lastGoalsMode'), 1);
      await unmount(tester);
    });

    testWidgets('官方圖冊分組 chips：滑動切換、端點不動、多選中不切換、列表可垂直捲動', (tester) async {
      phone(tester);
      await tester.runAsync(() async {
        await Directory('${tmp.path}/images').create(recursive: true);
        final g = (await db.watchGroups(pitId).first).first;
        await db.addOfficial(pitId, g.id, [
          for (var i = 0; i < 30; i++)
            NewImage(file: 'a$i.png', width: 10, height: 100),
        ]);
      });
      await pumpPage(tester, OfficialListPage(pitId: pitId));
      final groups = (await tester.runAsync(
        () => db.watchGroups(pitId).first,
      ))!;
      String? selected() =>
          tester.widget<ChipRow>(find.byType(ChipRow)).selected;
      expect(selected(), isNull);
      await swipe(tester, 150);
      expect(selected(), isNull); // 「全部」再右滑：沒事
      await swipe(tester, -150);
      expect(selected(), groups.first.id);
      await swipe(tester, 150);
      expect(selected(), isNull);

      // 垂直捲動不切換。
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -300));
      await settle(tester);
      expect(selected(), isNull);

      // 多選中不切換（長按任一格進多選）。
      await tester.longPressAt(const Offset(100, 400));
      await settle(tester);
      expect(find.textContaining('已選'), findsOneWidget);
      await tester.dragFrom(const Offset(195, 400), const Offset(-150, 0));
      await settle(tester);
      expect(find.textContaining('已選'), findsOneWidget);
      expect(selected(), isNull);
      await unmount(tester);
    });

    testWidgets('坑內搜尋 相冊 pills：左右滑切換', (tester) async {
      phone(tester);
      await pumpPage(tester, PitSearchPage(pitId: pitId));
      SearchCategory selected() => tester
          .widget<SearchCategoryChips>(find.byType(SearchCategoryChips))
          .selected;
      expect(selected(), SearchCategory.all);
      await swipe(tester, 150, y: 600);
      expect(selected(), SearchCategory.all);
      await swipe(tester, -150, y: 600);
      expect(selected(), SearchCategory.values[1]);
      await swipe(tester, 150, y: 600);
      expect(selected(), SearchCategory.all);
      await unmount(tester);
    });
  });
}
