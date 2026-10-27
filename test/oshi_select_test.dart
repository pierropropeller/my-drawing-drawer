import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/drag_select.dart';
import 'package:huakeng/ui/common/timeline.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/oshi/oshi_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 推活多選（D-079）：長按進入、選取狀態、分組／tag／刪除、導覽列。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late List<OfficialGroup> groups;
  late String a, b, c;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('oshi_select');
    pitId = await db.createPit(name: '坑A');
    groups = await db.watchGroups(pitId, kind: 'oshi').first;
    navBarHiddenCount.value = 0;
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

  Future<String> rec(
    DateTime date,
    String title, {
    String? groupId,
    List<String> files = const ['a.png'],
  }) => db.saveOshiRecord(
    pitId: pitId,
    date: date,
    groupId: groupId,
    title: title,
    images: [for (final f in files) NewImage(file: f, width: 30, height: 40)],
  );

  /// a＝10/08（線下照片）、b＝10/05（線下照片）、c＝9/22（沒分組）。
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    a = await rec(DateTime(2026, 10, 8), '甲', groupId: groups[0].id);
    b = await rec(
      DateTime(2026, 10, 5),
      '乙',
      groupId: groups[0].id,
      files: ['a.png', 'b.png'],
    );
    c = await rec(DateTime(2026, 9, 22), '丙');
  });

  Future<void> show(
    WidgetTester tester, {
    Map<String, Object> prefsInit = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true, ...prefsInit});
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
          home: OshiListPage(pitId: pitId),
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder card(String title) => find.text(title);

  Future<void> longPress(WidgetTester tester, Finder f) async {
    await tester.longPress(f);
    await settle(tester);
  }

  Future<OshiRecordView?> view(WidgetTester tester, String id) async =>
      await tester.runAsync<OshiRecordView?>(() => db.getOshiRecord(id));

  group('時間軸', () {
    testWidgets('長按進入多選：標題「已選 N 筆」＋全選、導覽列隱藏、分組 pills 隱藏、底部三個動作', (
      tester,
    ) async {
      await seed(tester);
      await show(tester);
      expect(find.text('線下照片'), findsOneWidget); // pills
      expect(navBarHiddenCount.value, 0);

      await longPress(tester, card('甲'));
      expect(find.text('已選 1 筆'), findsOneWidget);
      expect(find.text('全選'), findsOneWidget);
      expect(navBarHiddenCount.value, greaterThan(0));
      // 分組 pills 隱藏（線下照片只剩分組動作之外沒有別的）。
      expect(find.text('線下照片'), findsNothing);
      // 底部：分組、tag、刪除。
      expect(find.byKey(const ValueKey('oshiSelectGroup')), findsOneWidget);
      expect(find.byKey(const ValueKey('oshiSelectTag')), findsOneWidget);
      expect(find.byKey(const ValueKey('oshiSelectDelete')), findsOneWidget);
      expect(find.text('分組'), findsOneWidget);
      expect(find.text('tag'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
      // 每張卡片右上角都有勾選圈；選中的是打勾（22px）。
      expect(find.byType(TimelineSelectMark), findsNWidgets(3));
      final mark = tester.getSize(find.byKey(ValueKey('timeline-mark-$a')));
      expect(mark, const Size(22, 22));
      // 沒有新增 FAB。
      expect(find.text('新增推活紀錄'), findsNothing);
      await unmount(tester);
    });

    testWidgets('點卡片切換選取；全選／取消全選；選到 0 筆自動離開', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(card('乙'));
      await settle(tester);
      expect(find.text('已選 2 筆'), findsOneWidget);
      await tester.tap(card('乙'));
      await settle(tester);
      expect(find.text('已選 1 筆'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('oshiSelectAll')));
      await settle(tester);
      expect(find.text('已選 3 筆'), findsOneWidget);
      expect(find.text('取消全選'), findsOneWidget);
      await tester.tap(find.text('取消全選'));
      await settle(tester);
      expect(find.text('已選 3 筆'), findsNothing);
      expect(navBarHiddenCount.value, 0);

      // 取消最後一筆也會離開。
      await longPress(tester, card('甲'));
      await tester.tap(card('甲'));
      await settle(tester);
      expect(find.byKey(const ValueKey('oshiSelectGroup')), findsNothing);
      expect(find.text('線下照片'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('左上 × 離開多選，導覽列恢復', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      expect(navBarHiddenCount.value, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('oshiSelectExit')));
      await settle(tester);
      expect(find.text('已選 1 筆'), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('分組：sheet 列出該坑分組＋不分組，預選共同分組；移動後寫入並離開多選', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(card('乙'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('oshiSelectGroup')));
      await settle(tester);
      // sheet：標題「移動到」、每個分組一列、最後「不分組」。
      expect(find.text('移動到'), findsOneWidget);
      for (final g in groups) {
        expect(find.byKey(ValueKey('oshiGroup-${g.id}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('oshiGroup-none')), findsOneWidget);
      expect(find.text('不分組'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('oshiGroup-${groups[1].id}')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('oshiGroupConfirm')));
      await settle(tester);

      expect((await view(tester, a))!.record.groupId, groups[1].id);
      expect((await view(tester, b))!.record.groupId, groups[1].id);
      expect((await view(tester, c))!.record.groupId, isNull);
      expect(find.text('已選 2 筆'), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('分組選「不分組」：群組清空；取消 sheet 不動', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(find.byKey(const ValueKey('oshiSelectGroup')));
      await settle(tester);
      // 取消：點遮罩關閉，仍在多選。
      await tester.tapAt(const Offset(180, 40));
      await settle(tester);
      expect(find.text('已選 1 筆'), findsOneWidget);
      expect((await view(tester, a))!.record.groupId, groups[0].id);

      await tester.tap(find.byKey(const ValueKey('oshiSelectGroup')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('oshiGroup-none')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('oshiGroupConfirm')));
      await settle(tester);
      expect((await view(tester, a))!.record.groupId, isNull);
      await unmount(tester);
    });

    testWidgets('tag：套用到全部選取的紀錄', (tester) async {
      await seed(tester);
      final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(card('丙'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('oshiSelectTag')));
      await settle(tester);
      expect(find.text('2 筆'), findsWidgets); // sheet 標題右側
      await tester.tap(find.byKey(const ValueKey('batchTag-角色1-none')));
      await tester.pump();
      await tester.tap(find.text('完成'));
      await settle(tester);

      expect((await view(tester, a))!.tags.map((t) => t.id), [tag]);
      expect((await view(tester, c))!.tags.map((t) => t.id), [tag]);
      expect((await view(tester, b))!.tags, isEmpty);
      expect(find.text('已選 2 筆'), findsNothing);
      await unmount(tester);
    });

    testWidgets('刪除要確認：取消不刪；確認後軟刪除並離開多選', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(card('乙'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('oshiSelectDelete')));
      await settle(tester);
      expect(find.text('刪除 2 項？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(await view(tester, a), isNotNull);
      expect(find.text('已選 2 筆'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('oshiSelectDelete')));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      expect(await view(tester, a), isNull);
      expect(await view(tester, b), isNull);
      expect(await view(tester, c), isNotNull);
      expect(find.text('甲'), findsNothing);
      expect(find.text('丙'), findsOneWidget);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });
  });

  group('九宮格', () {
    testWidgets('長按圖進入多選：選中 2px 主色框＋勾；點圖切換；沒有文字', (tester) async {
      await seed(tester);
      await show(tester, prefsInit: {'oshiLayout': 'grid'});
      expect(find.text('甲'), findsNothing); // 九宮格沒有字
      await longPress(tester, find.byKey(ValueKey('oshi-grid-$a')));
      expect(find.text('已選 1 筆'), findsOneWidget);
      expect(navBarHiddenCount.value, greaterThan(0));
      expect(find.text('線下照片'), findsNothing); // pills 隱藏
      await tester.tap(find.byKey(ValueKey('oshi-grid-$b')));
      await settle(tester);
      expect(find.text('已選 2 筆'), findsOneWidget);

      // 刪除後九宮格更新。
      await tester.tap(find.byKey(const ValueKey('oshiSelectDelete')));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      expect(find.byKey(ValueKey('oshi-grid-$a')), findsNothing);
      expect(find.byKey(ValueKey('oshi-grid-$c')), findsOneWidget);
      await unmount(tester);
    });
  });

  /// 長按後不放手（先等長按成立），回傳手勢。
  Future<TestGesture> holdAt(WidgetTester tester, Offset p) async {
    final g = await tester.startGesture(p);
    await tester.pump(const Duration(milliseconds: 600));
    return g;
  }

  Future<void> release(WidgetTester tester, TestGesture g) async {
    await g.up();
    await settle(tester);
  }

  group('拖曳連續多選（D-081）', () {
    testWidgets('時間軸：長按甲拖到丙（跨月份）→ 三筆都選；拖回乙只剩甲乙', (tester) async {
      await seed(tester);
      await show(tester);
      final g = await holdAt(tester, tester.getCenter(card('甲')));
      expect(find.text('已選 1 筆'), findsOneWidget);
      await g.moveTo(tester.getCenter(card('丙')));
      await tester.pump();
      expect(find.text('已選 3 筆'), findsOneWidget);
      await g.moveTo(tester.getCenter(card('乙')));
      await tester.pump();
      expect(find.text('已選 2 筆'), findsOneWidget);
      await release(tester, g);
      // 放手後維持多選，點卡片仍可切換。
      expect(find.text('已選 2 筆'), findsOneWidget);
      expect(navBarHiddenCount.value, greaterThan(0));
      await tester.tap(card('丙'));
      await settle(tester);
      expect(find.text('已選 3 筆'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('時間軸：起點是已選 → 連續取消；全部取消放手＝離開多選', (tester) async {
      await seed(tester);
      await show(tester);
      await longPress(tester, card('甲'));
      await tester.tap(card('乙'));
      await tester.tap(card('丙'));
      await settle(tester);
      expect(find.text('已選 3 筆'), findsOneWidget);
      // 從乙開始往下拖＝取消乙、丙，甲不受影響。
      var g = await holdAt(tester, tester.getCenter(card('乙')));
      await g.moveTo(tester.getCenter(card('丙')));
      await tester.pump();
      expect(find.text('已選 1 筆'), findsOneWidget);
      await release(tester, g);
      // 再從甲取消到最後一筆 → 全空，放手後離開多選。
      g = await holdAt(tester, tester.getCenter(card('甲')));
      expect(find.text('已選 0 筆'), findsOneWidget); // 拖曳中仍在多選
      await release(tester, g);
      expect(find.text('全選'), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('九宮格：長按拖過格子連續選取（左→右、上→下），間隙沿用上一格', (tester) async {
      await seed(tester);
      await show(tester, prefsInit: {'oshiLayout': 'grid'});
      final ga = find.byKey(ValueKey('oshi-grid-$a'));
      final gc = find.byKey(ValueKey('oshi-grid-$c'));
      final g = await holdAt(tester, tester.getCenter(ga));
      await g.moveTo(tester.getCenter(gc));
      await tester.pump();
      expect(find.text('已選 3 筆'), findsOneWidget);
      await release(tester, g);
      expect(find.text('已選 3 筆'), findsOneWidget);
      // 從已選的乙取消到丙。
      final g2 = await holdAt(
        tester,
        tester.getCenter(find.byKey(ValueKey('oshi-grid-$b'))),
      );
      await g2.moveTo(tester.getCenter(gc));
      await tester.pump();
      expect(find.text('已選 1 筆'), findsOneWidget);
      await release(tester, g2);
      await unmount(tester);
    });

    testWidgets('時間軸：貼著下緣自動捲動，月份標題不是項目，繼續往下選', (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < 40; i++) {
          await rec(
            DateTime(2026, 12, 28).subtract(Duration(days: i * 4)),
            'r$i',
          );
        }
      });
      await show(tester);
      expect(find.byType(DragSelectArea), findsOneWidget);
      final scrollable = Scrollable.of(tester.element(find.text('r0')));
      expect(scrollable.position.pixels, 0);
      final g = await holdAt(tester, tester.getCenter(find.text('r0')));
      final area = tester.getRect(find.byType(DragSelectArea));
      await g.moveTo(Offset(area.center.dx, area.bottom - 8));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(scrollable.position.pixels, greaterThan(200));
      final n = int.parse(
        RegExp(r'已選 (\d+) 筆')
            .firstMatch(
              tester
                  .widgetList<Text>(find.textContaining('已選'))
                  .map((t) => t.data!)
                  .first,
            )!
            .group(1)!,
      );
      expect(n, greaterThan(8));
      await release(tester, g);
      await unmount(tester);
    });
  });

  group('OshiSelection', () {
    test('begin／toggle／selectAll／exit', () {
      final s = OshiSelection()..updateOrder(['1', '2', '3']);
      expect(s.active, isFalse);
      s.begin('2');
      expect(s.active, isTrue);
      expect(s.ids, {'2'});
      s.toggle('1');
      expect(s.ids, {'1', '2'});
      s.toggle('1');
      s.toggle('2');
      expect(s.active, isFalse); // 選到 0 筆自動離開
      s.selectAll();
      expect(s.allSelected, isTrue);
      s.exit();
      expect(s.ids, isEmpty);
      s.dispose();
    });

    test('setRange 照列表順序（可反向）選取與取消，給拖曳多選接', () {
      final s = OshiSelection()..updateOrder(['1', '2', '3', '4', '5']);
      s.begin('2');
      s.setRange('2', '4');
      expect(s.ids, {'2', '3', '4'});
      s.setRange('5', '3'); // 反向
      expect(s.ids, {'2', '3', '4', '5'});
      s.setRange('3', '5', select: false);
      expect(s.ids, {'2'});
      s.dispose();
    });

    test('applyIndices：index 對應 order；拖曳中允許暫時為空，放手才離開', () {
      final s = OshiSelection()..updateOrder(['1', '2', '3']);
      s.applyIndices({0, 2}, finished: false);
      expect(s.ids, {'1', '3'});
      expect(s.active, isTrue);
      s.applyIndices({}, finished: false);
      expect(s.active, isTrue);
      s.applyIndices({}, finished: true);
      expect(s.active, isFalse);
      s.applyIndices({1, 9}, finished: true); // 超出範圍略過
      expect(s.ids, {'2'});
      s.dispose();
    });

    test('列表資料變動時丟掉已不存在的 id', () async {
      final s = OshiSelection()..updateOrder(['1', '2']);
      s.begin('1');
      s.toggle('2');
      s.updateOrder(['2']);
      expect(s.ids, {'2'});
      s.updateOrder([]);
      expect(s.active, isFalse);
      await Future<void>.delayed(Duration.zero);
      s.dispose();
    });
  });
}
