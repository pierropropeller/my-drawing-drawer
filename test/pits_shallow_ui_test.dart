import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/dashed_box.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pit_rows.dart';
import 'package:huakeng/ui/pits/pit_type_widgets.dart';
import 'package:huakeng/ui/pits/pits_page.dart';

/// 淺坑／封存坑的 UI（D-088）：主頁三分頁、開新坑／編輯坑類型與格子開關、關閉格子的確認框、空白狀態、iPad 版面。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String active;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_shallow_ui');
    active = await db.createPit(name: '坑A', description: '描述');
  });

  void phoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  void setView(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
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

  /// 要等真正的檔案 I/O（匯入選到的圖）。

  List<Override> baseOverrides() => [
    databaseProvider.overrideWithValue(db),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${tmp.path}/images')),
    ),
    onlineProvider.overrideWith((ref) => Stream.value(true)),
  ];

  Future<void> pumpApp(WidgetTester tester) async {
    phoneView(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  /// 在一個有「開啟」按鈕的外殼裡開頁面（頁面關閉時 pop 才有地方回）。
  Future<void> pumpLaunch(
    WidgetTester tester,
    Widget page, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...baseOverrides(), ...overrides],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => page)),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settle(tester);
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
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

  Future<void> addOfficial(String pitId, int n) async {
    final g = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(pitId, g.id, [
      for (var i = 0; i < n; i++) NewImage(file: 'o$pitId$i.png'),
    ]);
  }

  Future<String> addIdea(String pitId) => db.saveIdea(
    pitId: pitId,
    title: '腦洞',
    body: '',
    images: const [],
    tagIds: const [],
    draftIds: const [],
    pieceIds: const [],
  );

  Finder rowOf(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(PitSectionSwitchRow),
  );

  bool switchOn(WidgetTester tester, String label) => tester
      .widget<AppSwitch>(
        find.descendant(of: rowOf(label), matching: find.byType(AppSwitch)),
      )
      .value;

  Future<void> tapSwitch(WidgetTester tester, String label) async {
    await tester.ensureVisible(rowOf(label));
    await tester.tap(
      find.descendant(of: rowOf(label), matching: find.byType(AppSwitch)),
    );
    await settle(tester);
  }

  Future<void> tapSeg(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PitTypeSegment),
        matching: find.text(label),
      ),
    );
    await settle(tester);
  }

  Future<Pit> pitOf(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => db.watchPit(id).first))!;

  group('主頁三個分頁', () {
    late String shallowB;
    late String archived;

    Future<void> seed() async {
      await db.createPit(
        name: '星之彼端',
        description: '第 3 集再決定要不要入',
        status: PitStatus.shallow,
      );
      shallowB = await db.createPit(
        name: '坑G',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.official, PitSectionKey.fan},
      );
      await addOfficial(shallowB, 2);
      archived = await db.createPit(name: '舊坑');
      await db.savePiece(
        pitId: archived,
        title: '成圖',
        body: '',
        images: const [],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 5, 1),
        ideaIds: const [],
        draftIds: const [],
      );
      await db.saveDraft(
        pitId: archived,
        title: '摸魚',
        images: const [],
        tagIds: const [],
        ideaIds: const [],
      );
      await db.setPitStatus(archived, PitStatus.archived);
    }

    testWidgets('現坑／淺坑／封存坑三個 pills；右上的搜尋鍵三個分頁都有（D-105）', (tester) async {
      await tester.runAsync(seed);
      await pumpApp(tester);
      expect(find.text('現坑'), findsOneWidget);
      expect(find.text('淺坑'), findsOneWidget);
      expect(find.text('封存坑'), findsOneWidget);
      // 現坑：只有現坑的卡片、有搜尋鍵（沒有田字／瀑布切換）
      expect(find.text('坑A'), findsOneWidget);
      expect(find.text('星之彼端'), findsNothing);
      expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);
      expect(find.bySemanticsLabel('田字檢視'), findsNothing);

      await tester.tap(find.text('淺坑'));
      await settle(tester);
      expect(find.text('坑A'), findsNothing);
      expect(find.text('星之彼端'), findsOneWidget);
      expect(find.text('第 3 集再決定要不要入'), findsOneWidget);
      expect(find.text('坑G'), findsOneWidget);
      // 沒有描述：列出開啟格子的張數
      expect(find.text('官方圖冊 2 張 · 好看同人圖 0 張'), findsOneWidget);
      // 沒封面＝坑名第一個字
      expect(find.text('星'), findsOneWidget);
      expect(find.text('開新淺坑'), findsOneWidget);
      expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);
      // 導覽列仍在（瀏覽用的頁面）
      expect(find.text('時間軸'), findsOneWidget);

      await tester.tap(find.text('封存坑'));
      await settle(tester);
      expect(find.text('舊坑'), findsOneWidget);
      expect(find.text('成圖 1 · 摸魚 1'), findsOneWidget);
      expect(find.text('開新淺坑'), findsNothing);
      expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);

      await tester.tap(find.text('現坑'));
      await settle(tester);
      expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('淺坑列：沒有描述也沒開格子＝不畫副標，名字與封面垂直置中', (tester) async {
      await tester.runAsync(() async {
        await seed();
        await db.createPit(name: '空淺坑', status: PitStatus.shallow);
      });
      await pumpApp(tester);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      final row = find.widgetWithText(PitRow, '空淺坑');
      expect(row, findsOneWidget);
      // 只有名字一段文字（首字封面是另一段），沒有「還沒有格子／還沒有開啟格子」。
      expect(find.text('還沒有開啟格子'), findsNothing);
      expect(find.text('還沒有格子'), findsNothing);
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: row, matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .toList();
      expect(texts, ['空', '空淺坑']);
      final cover = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 56 && w.height == 56,
        ),
      );
      expect(
        tester
            .getCenter(find.descendant(of: row, matching: find.text('空淺坑')))
            .dy,
        closeTo(tester.getCenter(cover).dy, 0.5),
      );
      // 有描述／有開格子的列照舊有副標。
      expect(find.text('第 3 集再決定要不要入'), findsOneWidget);
      expect(find.textContaining('官方圖冊'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('列：56 見方封面；點淺坑進淺坑內頁並帶「淺坑」小標', (tester) async {
      await tester.runAsync(seed);
      await pumpApp(tester);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      final cover = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 56 && w.height == 56,
      );
      expect(cover, findsWidgets);
      await tester.tap(find.text('坑G'));
      await settle(tester);
      expect(find.byType(PitPage), findsOneWidget);
      expect(find.byType(ShallowBadge), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('淺坑分頁的「開新淺坑」開出類型已選淺坑的表單', (tester) async {
      await tester.runAsync(seed);
      await pumpApp(tester);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      await tester.tap(find.text('開新淺坑'));
      await settle(tester);
      expect(find.byType(PitNewPage), findsOneWidget);
      expect(find.text('開啟的格子'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('三個分頁都空：只留頭像與名字；只有淺坑時不算空', (tester) async {
      await tester.runAsync(() async {
        await db.deletePit(active);
        await db.createPit(name: '只有淺坑', status: PitStatus.shallow);
      });
      await pumpApp(tester);
      expect(find.text('現坑'), findsOneWidget); // pills 還在
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      expect(find.text('只有淺坑'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('淺坑分頁沒有任何淺坑：空白狀態＋開新淺坑', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      expect(find.text('還沒有淺坑'), findsOneWidget);
      expect(find.text('開新淺坑'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('淺坑內頁', () {
    testWidgets('只顯示開啟的格子，坑名旁有「淺坑」小標', (tester) async {
      phoneView(tester);
      final id = await tester.runAsync(
        () => db.createPit(
          name: '淺坑一號',
          description: '觀望中',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.fan, PitSectionKey.idea},
        ),
      );
      await pumpPage(tester, PitPage(pitId: id!));
      expect(find.text('好看同人圖'), findsOneWidget);
      expect(find.text('我的腦洞'), findsOneWidget);
      for (final gone in ['官方圖冊', '我的摸魚', '我的成圖', '推活', '雜物']) {
        expect(find.text(gone), findsNothing);
      }
      expect(find.text('淺坑'), findsOneWidget);
      expect(find.text('還沒有開啟格子'), findsNothing);
      // 兩格排在同一列
      expect(
        tester.getTopLeft(find.text('好看同人圖')).dy,
        tester.getTopLeft(find.text('我的腦洞')).dy,
      );
      await unmount(tester);
    });

    testWidgets('單數格子也排得下；開了雜物就出現雜物入口', (tester) async {
      phoneView(tester);
      final id = await tester.runAsync(
        () => db.createPit(
          name: '淺',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official, PitSectionKey.junk},
        ),
      );
      await pumpPage(tester, PitPage(pitId: id!));
      expect(find.text('官方圖冊'), findsOneWidget);
      expect(find.text('雜物'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('一個格子都沒開：空白狀態，「開啟格子」去編輯坑', (tester) async {
      phoneView(tester);
      final id = await tester.runAsync(
        () => db.createPit(name: '空淺坑', status: PitStatus.shallow),
      );
      await pumpPage(tester, PitPage(pitId: id!));
      expect(find.text('還沒有開啟格子'), findsOneWidget);
      expect(find.text('開啟格子'), findsOneWidget);
      expect(find.text('空淺坑'), findsOneWidget); // 標題列照舊
      expect(find.text('淺坑'), findsOneWidget);
      expect(find.text('官方圖冊'), findsNothing);
      await tester.tap(find.text('開啟格子'));
      await settle(tester);
      expect(find.byType(PitEditPage), findsOneWidget);
      expect(find.text('開啟的格子'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('現坑沒有小標，六格都在', (tester) async {
      phoneView(tester);
      await pumpPage(tester, PitPage(pitId: active));
      expect(find.byType(ShallowBadge), findsNothing);
      for (final k in ['官方圖冊', '好看同人圖', '我的腦洞', '我的摸魚', '我的成圖', '推活']) {
        expect(find.text(k), findsOneWidget);
      }
      await unmount(tester);
    });
  });

  group('開新坑', () {
    testWidgets('類型預設「坑」：沒有封面與格子；切到淺坑才出現，開關預設全關', (tester) async {
      phoneView(tester);
      await pumpLaunch(tester, const PitNewPage());
      expect(find.byType(PitTypeSegment), findsOneWidget);
      expect(find.text('類型'), findsOneWidget);
      expect(find.text('封面'), findsNothing);
      expect(find.text('開啟的格子'), findsNothing);
      // 開新坑只有「坑｜淺坑」
      expect(
        find.descendant(
          of: find.byType(PitTypeSegment),
          matching: find.text('封存'),
        ),
        findsNothing,
      );
      await tapSeg(tester, '淺坑');
      // 開新淺坑有選填封面（D-088 PitNewShallow）；開新坑（類型＝坑）沒有。
      expect(find.text('封面'), findsOneWidget);
      expect(find.byType(PitCoverPickTile), findsOneWidget);
      await tapSeg(tester, '坑');
      expect(find.text('封面'), findsNothing);
      await tapSeg(tester, '淺坑');
      expect(find.text('開啟的格子'), findsOneWidget);
      expect(find.byType(AppSwitch), findsNWidgets(7));
      for (final l in ['官方圖冊', '好看同人圖', '我的腦洞', '我的摸魚', '我的成圖', '推活', '雜物']) {
        expect(switchOn(tester, l), isFalse, reason: l);
      }
      await unmount(tester);
    });

    testWidgets('建立淺坑：封面選填（沒選＝沒有封面檔）；描述、開啟的格子都寫進去', (tester) async {
      phoneView(tester);
      await pumpLaunch(tester, const PitNewPage());
      await tapSeg(tester, '淺坑');
      expect(find.byType(PitCoverPickTile), findsOneWidget); // 封面欄位選填
      await tester.enterText(find.byKey(const ValueKey('pit-name')), '新淺坑');
      await tester.enterText(find.byKey(const ValueKey('pit-desc')), '先看看');
      await tapSwitch(tester, '官方圖冊');
      await tapSwitch(tester, '雜物');
      expect(switchOn(tester, '官方圖冊'), isTrue);
      await tester.scrollUntilVisible(
        find.text('建立'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('建立'));
      await settle(tester);
      final pits = await tester.runAsync(
        () => db.watchPitsByStatus({PitStatus.shallow}).first,
      );
      final p = pits!.single;
      expect(p.name, '新淺坑');
      expect(p.description, '先看看');
      expect(p.enabledSections, {PitSectionKey.official, PitSectionKey.junk});
      expect(p.junkEnabled, isTrue);
      expect(p.coverFile, isNull); // 沒選封面
      await unmount(tester);
    });

    testWidgets('淺坑可以一個格子都不開就建立', (tester) async {
      phoneView(tester);
      await pumpLaunch(tester, const PitNewPage());
      await tapSeg(tester, '淺坑');
      await tester.enterText(find.byKey(const ValueKey('pit-name')), '空的');
      await tester.scrollUntilVisible(
        find.text('建立'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('建立'));
      await settle(tester);
      final p = (await tester.runAsync(
        () => db.watchPitsByStatus({PitStatus.shallow}).first,
      ))!.single;
      expect(p.enabledSections, isEmpty);
      expect(p.coverFile, isNull);
      await unmount(tester);
    });

    testWidgets('類型「坑」照舊建立現坑', (tester) async {
      phoneView(tester);
      await pumpLaunch(tester, const PitNewPage());
      await tester.enterText(find.byKey(const ValueKey('pit-name')), '一般坑');
      await tester.tap(find.text('建立'));
      await settle(tester);
      final p = (await tester.runAsync(
        () => db.watchPitsByStatus({PitStatus.active}).first,
      ))!.firstWhere((p) => p.name == '一般坑');
      expect(p.status, PitStatus.active);
      await unmount(tester);
    });
  });

  group('編輯坑', () {
    Future<Pit> openEdit(WidgetTester tester, String id) async {
      final pit = await pitOf(tester, id);
      phoneView(tester);
      await pumpLaunch(tester, PitEditPage(pit: pit));
      return pit;
    }

    testWidgets('現坑：類型分段「坑｜淺坑｜封存」，雜物開關左邊有雜物箱 icon', (tester) async {
      await openEdit(tester, active);
      expect(find.text('類型'), findsOneWidget);
      for (final l in ['坑', '淺坑', '封存']) {
        expect(
          find.descendant(
            of: find.byType(PitTypeSegment),
            matching: find.text(l),
          ),
          findsOneWidget,
        );
      }
      expect(find.byType(PitJunkSwitchCard), findsOneWidget);
      expect(find.text('雜物'), findsOneWidget);
      expect(find.text('開啟的格子'), findsNothing);
      await unmount(tester);
    });

    testWidgets('坑→淺坑：有資料的格子預設為開；關掉空格子不彈框', (tester) async {
      await tester.runAsync(() async {
        await addOfficial(active, 3);
        await addIdea(active);
      });
      await openEdit(tester, active);
      await tapSeg(tester, '淺坑');
      expect(find.text('開啟的格子'), findsOneWidget);
      expect(switchOn(tester, '官方圖冊'), isTrue);
      expect(switchOn(tester, '我的腦洞'), isTrue);
      expect(switchOn(tester, '好看同人圖'), isFalse);
      expect(switchOn(tester, '雜物'), isFalse);
      // 開啟再關掉一個空格子：不彈確認框
      await tapSwitch(tester, '好看同人圖');
      expect(switchOn(tester, '好看同人圖'), isTrue);
      await tapSwitch(tester, '好看同人圖');
      expect(find.byType(AlertDialog), findsNothing);
      expect(switchOn(tester, '好看同人圖'), isFalse);
      await unmount(tester);
    });

    testWidgets('關掉有內容的格子：確認框；取消不動，確認後存檔才刪除', (tester) async {
      await tester.runAsync(() async {
        await addOfficial(active, 3);
        await addIdea(active);
      });
      await openEdit(tester, active);
      await tapSeg(tester, '淺坑');

      await tapSwitch(tester, '官方圖冊');
      expect(find.text('關閉「官方圖冊」？'), findsOneWidget);
      expect(find.text('格子裡的 3 張圖會一併刪除，無法復原。'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('關閉並刪除'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(switchOn(tester, '官方圖冊'), isTrue);

      await tapSwitch(tester, '官方圖冊');
      await tester.tap(find.text('關閉並刪除'));
      await settle(tester);
      expect(switchOn(tester, '官方圖冊'), isFalse);
      // 還沒存檔：資料還在
      expect(
        await tester.runAsync(
          () => db.sectionContentCount(active, PitSectionKey.official),
        ),
        3,
      );

      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final p = await pitOf(tester, active);
      expect(p.status, PitStatus.shallow);
      expect(p.enabledSections, {PitSectionKey.idea});
      expect(
        await tester.runAsync(
          () => db.sectionContentCount(active, PitSectionKey.official),
        ),
        0,
      );
      // 沒關的格子資料還在
      expect(
        await tester.runAsync(
          () => db.sectionContentCount(active, PitSectionKey.idea),
        ),
        1,
      );
      await unmount(tester);
    });

    testWidgets('腦洞格的確認框用「N 個腦洞」', (tester) async {
      await tester.runAsync(() async {
        await addIdea(active);
        await addIdea(active);
      });
      await openEdit(tester, active);
      await tapSeg(tester, '淺坑');
      await tapSwitch(tester, '我的腦洞');
      expect(find.text('格子裡的 2 個腦洞會一併刪除，無法復原。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      await unmount(tester);
    });

    testWidgets('淺坑→坑：資料保留，雜物沿用', (tester) async {
      final id = (await tester.runAsync(() async {
        final id = await db.createPit(
          name: '淺',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official, PitSectionKey.junk},
        );
        await addOfficial(id, 2);
        return id;
      }))!;
      await openEdit(tester, id);
      expect(switchOn(tester, '官方圖冊'), isTrue);
      await tapSeg(tester, '坑');
      expect(find.text('開啟的格子'), findsNothing);
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final p = await pitOf(tester, id);
      expect(p.status, PitStatus.active);
      expect(p.junkEnabled, isTrue);
      expect(
        await tester.runAsync(
          () => db.sectionContentCount(id, PitSectionKey.official),
        ),
        2,
      );
      await unmount(tester);
    });

    testWidgets('封存：存檔後移到封存坑，資料保留；再轉回現坑', (tester) async {
      await tester.runAsync(() => addOfficial(active, 2));
      await openEdit(tester, active);
      await tapSeg(tester, '封存');
      expect(find.text('開啟的格子'), findsNothing);
      expect(find.byType(PitJunkSwitchCard), findsNothing);
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      var p = await pitOf(tester, active);
      expect(p.status, PitStatus.archived);
      expect(
        await tester.runAsync(
          () => db.sectionContentCount(active, PitSectionKey.official),
        ),
        2,
      );
      await unmount(tester);

      await openEdit(tester, active);
      await tapSeg(tester, '坑');
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      p = await pitOf(tester, active);
      expect(p.status, PitStatus.active);
      await unmount(tester);
    });

    testWidgets('淺坑沒有圖：不顯示封面區；有圖：和現坑一樣從坑內的圖挑', (tester) async {
      final id = (await tester.runAsync(
        () => db.createPit(
          name: '淺',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official},
        ),
      ))!;
      phoneView(tester);
      var pit = await pitOf(tester, id);
      await pumpLaunch(tester, PitEditPage(pit: pit));
      expect(find.text('更換封面'), findsNothing);
      await unmount(tester);

      await tester.runAsync(() => addOfficial(id, 1));
      pit = await pitOf(tester, id);
      phoneView(tester);
      await pumpLaunch(tester, PitEditPage(pit: pit));
      await tester.tap(find.byType(DashedBox));
      await settle(tester);
      expect(find.byType(CoverPickPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('封面區（沒圖＝隱藏；有圖＝從坑內的圖挑，淺坑同現坑）', () {
    testWidgets('現坑沒有圖：不顯示封面區（PitEdit-ntnf）', (tester) async {
      final pit = await pitOf(tester, active);
      phoneView(tester);
      await pumpLaunch(tester, PitEditPage(pit: pit));
      expect(find.byType(DashedBox), findsNothing);
      expect(find.text('更換封面'), findsNothing);
      await unmount(tester);
    });

    testWidgets('現坑有圖：封面欄位仍走坑內挑圖（CoverPickPage）', (tester) async {
      await tester.runAsync(() => addOfficial(active, 1));
      final pit = await pitOf(tester, active);
      phoneView(tester);
      await pumpLaunch(tester, PitEditPage(pit: pit));
      await tester.tap(find.byType(DashedBox));
      await settle(tester);
      expect(find.byType(CoverPickPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('淺坑內頁：長按有內容的格子進入選擇該格封面 (cell-longpress)', (tester) async {
      final id = (await tester.runAsync(() async {
        final id = await db.createPit(
          name: '淺',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official, PitSectionKey.fan},
        );
        await addOfficial(id, 2);
        return id;
      }))!;
      phoneView(tester);
      await pumpPage(tester, PitPage(pitId: id));
      await tester.longPress(find.text('官方圖冊'));
      await settle(tester);
      expect(find.byType(CoverPickPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('iPad', () {
    Future<void> pumpTablet(
      WidgetTester tester,
      Widget home, {
      required double w,
      required double h,
    }) async {
      setView(tester, w, h);
      await pumpPage(tester, home);
    }

    for (final size in [(834.0, 1194.0), (1194.0, 834.0)]) {
      testWidgets(
        'Main ${size.$1.toInt()}×${size.$2.toInt()}：三個 pills、淺坑／封存坑是列表',
        (tester) async {
          await tester.runAsync(() async {
            await db.createPit(
              name: '平板淺坑',
              description: '描述',
              status: PitStatus.shallow,
            );
            final z = await db.createPit(name: '平板封存');
            await db.setPitStatus(z, PitStatus.archived);
          });
          await pumpTablet(tester, const PitsPage(), w: size.$1, h: size.$2);
          expect(find.text('現坑'), findsOneWidget);
          expect(find.text('淺坑'), findsOneWidget);
          expect(find.text('封存坑'), findsOneWidget);
          expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);
          await tester.tap(find.text('淺坑'));
          await settle(tester);
          expect(find.text('平板淺坑'), findsOneWidget);
          expect(find.text('描述'), findsOneWidget);
          expect(find.text('開新淺坑'), findsOneWidget);
          expect(find.bySemanticsLabel('搜尋全部坑'), findsOneWidget);
          await tester.tap(find.text('封存坑'));
          await settle(tester);
          expect(find.text('平板封存'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        },
      );

      testWidgets(
        '淺坑內頁 ${size.$1.toInt()}×${size.$2.toInt()}：只顯示開啟的格子與小標；空白狀態',
        (tester) async {
          final ids = (await tester.runAsync(
            () async => [
              await db.createPit(
                name: '平板淺坑',
                status: PitStatus.shallow,
                enabledSections: {PitSectionKey.fan, PitSectionKey.oshi},
              ),
              await db.createPit(name: '平板空淺坑', status: PitStatus.shallow),
            ],
          ))!;
          await pumpTablet(
            tester,
            PitPage(pitId: ids[0]),
            w: size.$1,
            h: size.$2,
          );
          expect(find.text('好看同人圖'), findsOneWidget);
          expect(find.text('推活'), findsOneWidget);
          expect(find.text('官方圖冊'), findsNothing);
          expect(find.text('我的成圖'), findsNothing);
          expect(find.byType(ShallowBadge), findsOneWidget);
          await unmount(tester);

          await pumpTablet(
            tester,
            PitPage(pitId: ids[1]),
            w: size.$1,
            h: size.$2,
          );
          expect(find.text('還沒有開啟格子'), findsOneWidget);
          expect(find.text('開啟格子'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        },
      );
    }

    testWidgets('NewPit modal 1194：類型分段；淺坑多出格子清單', (tester) async {
      setView(tester, 1194, 834);
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNewPit(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.byType(PitNewPage), findsOneWidget);
      expect(find.byType(PitTypeSegment), findsOneWidget);
      await tapSeg(tester, '淺坑');
      expect(find.text('開啟的格子'), findsOneWidget);
      expect(find.byType(AppSwitch), findsNWidgets(7));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('PitEdit modal 1194：類型分段取代封存開關；淺坑顯示格子清單與確認框', (tester) async {
      await tester.runAsync(() => addOfficial(active, 2));
      final pit = await pitOf(tester, active);
      setView(tester, 1194, 834);
      await pumpPage(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPitEdit(context, pit),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.byType(PitEditPage), findsOneWidget);
      expect(find.text('封存'), findsOneWidget); // 只剩分段裡的一個
      expect(find.byType(PitJunkSwitchCard), findsOneWidget);
      await tapSeg(tester, '淺坑');
      expect(find.text('開啟的格子'), findsOneWidget);
      await tapSwitch(tester, '官方圖冊');
      expect(find.text('關閉「官方圖冊」？'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消').last);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
