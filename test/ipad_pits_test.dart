import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
import 'package:huakeng/ui/common/adaptive_modal.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pit_section_tabs.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/sync/sync_avatar.dart';

/// iPad 版 Main／Pit／PitEdit／NewPit 與 PitSectionTabBar、showAdaptiveModal
/// （390×844、834×1194、1194×834、1366×1024）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_ipadpit');
    pitId = await db.createPit(name: '坑A', description: '原作動畫');
  });

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

  Future<void> pumpHome(
    WidgetTester tester,
    Widget home, {
    bool online = true,
    double navWidth = 0,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(online)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          // 用 navWidth 模擬 rail／sidebar 佔掉的左側（頁面內容區不含導覽）。
          home: navWidth == 0
              ? home
              : Row(
                  children: [
                    SizedBox(width: navWidth),
                    Expanded(child: home),
                  ],
                ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedPits(int n) async {
    for (var i = 1; i < n; i++) {
      await db.createPit(name: '坑${String.fromCharCode(65 + i)}');
    }
  }

  /// 第一列 PitCard 的欄數（左緣不同的 x 數）。
  int firstRowColumns(WidgetTester tester) {
    final rects = tester.widgetList(find.byType(PitCard)).map((w) {
      return tester.getTopLeft(find.byWidget(w));
    }).toList();
    final minY = rects.map((o) => o.dy).reduce((a, b) => a < b ? a : b);
    return rects.where((o) => (o.dy - minY).abs() < 1).length;
  }

  group('Main', () {
    testWidgets('390×844：手機版面不變（頭像、暱稱列、pills 在標題下）', (tester) async {
      setView(tester, 390, 844);
      await tester.runAsync(() => seedPits(3));
      await pumpHome(tester, const PitsPage());
      expect(find.byType(SyncAvatar), findsOneWidget);
      expect(firstRowColumns(tester), 2);
      // pills 在標題列下面。
      expect(
        tester.getTopLeft(find.text('現坑')).dy >
            tester.getTopLeft(find.byType(SyncAvatar)).dy,
        isTrue,
      );
      expect(find.text('開新坑'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('834 直向（含 84 rail）：標題「我的坑」，pills 獨立一行，3 欄', (tester) async {
      setView(tester, 834, 1194);
      await tester.runAsync(() => seedPits(6));
      await pumpHome(tester, const PitsPage(), navWidth: 84);
      expect(find.byType(SyncAvatar), findsNothing); // 頭像在 rail
      final title = tester.getTopLeft(find.text('我的坑'));
      final pill = tester.getTopLeft(find.text('現坑'));
      expect(pill.dy > title.dy + 20, isTrue); // 獨立一行
      expect(firstRowColumns(tester), 3); // (750 - 64) ÷ 180
      expect(find.text('開新坑'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('1194 橫向（含 260 sidebar）：pills 與切換在標題同列，4 欄', (tester) async {
      setView(tester, 1194, 834);
      await tester.runAsync(() => seedPits(6));
      await pumpHome(tester, const PitsPage(), navWidth: 260);
      final title = tester.getCenter(find.text('我的坑'));
      final pill = tester.getCenter(find.text('現坑'));
      expect((pill.dy - title.dy).abs() < 8, isTrue);
      expect(firstRowColumns(tester), 4); // (934 - 80) ÷ 180
      // 觸控目標 ≥44。
      final search = tester.getSize(find.bySemanticsLabel('搜尋全部坑'));
      expect(search.height >= 44, isTrue);
      expect(search.width >= 44, isTrue);
      await unmount(tester);
    });

    testWidgets('1366×1024：欄數按闊度計（沒有 sidebar 時 6 欄）', (tester) async {
      setView(tester, 1366, 1024);
      await tester.runAsync(() => seedPits(6));
      await pumpHome(tester, const PitsPage(), navWidth: 260);
      expect(firstRowColumns(tester), 5); // (1106 - 80) ÷ 180
      await unmount(tester);
    });

    testWidgets('離線橫條；拉窗後分頁選擇不丟（田字固定，D-105）', (tester) async {
      setView(tester, 1194, 834);
      await tester.runAsync(() => seedPits(3));
      await pumpHome(tester, const PitsPage(), online: false);
      expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
      expect(find.byType(MasonryGridView), findsNothing);
      // 切到封存坑（空）。
      await tester.tap(find.text('封存坑'));
      await settle(tester);
      expect(find.text('沒有封存的坑'), findsOneWidget);
      // 拉窄到 834 再拉回：選擇保留。
      setView(tester, 834, 1194);
      await settle(tester);
      expect(find.text('沒有封存的坑'), findsOneWidget);
      await tester.tap(find.text('現坑'));
      await settle(tester);
      expect(find.byType(MasonryGridView), findsNothing);
      expect(find.byType(GridView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('開新坑：1194 開置中 modal 並建立；834 也是 modal（≥600）；手機整頁', (
      tester,
    ) async {
      setView(tester, 1194, 834);
      await pumpHome(tester, const PitsPage());
      await tester.tap(find.text('開新坑'));
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('封面可於建立後在「編輯坑」中選擇。'), findsOneWidget);
      // 置中。
      final c = tester.getCenter(find.byType(Dialog));
      expect((c.dx - 597).abs() < 1 && (c.dy - 417).abs() < 40, isTrue);
      await tester.tap(find.text('建立')); // 沒填坑名
      await settle(tester);
      expect(find.text('請輸入坑名'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '新坑');
      await tester.tap(find.text('建立'));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      final pits = await tester.runAsync(
        () => db.watchPits(archived: false).first,
      );
      expect(pits!.map((p) => p.name), contains('新坑'));
      await unmount(tester);

      // 834（Medium，≥600）：RespSpec 彈出頁＝置中 form sheet。
      setView(tester, 834, 1194);
      await pumpHome(tester, const PitsPage());
      await tester.tap(find.text('開新坑'));
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(PitNewPage), findsOneWidget);
      await unmount(tester);

      // 手機（＜600、非 iPad）：整頁。
      setView(tester, 390, 844);
      await pumpHome(tester, const PitsPage());
      await tester.tap(find.text('開新坑'));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(PitNewPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Pit', () {
    testWidgets('1194 橫向：76 封面、編輯坑、搜尋、3 欄 4:3、無返回', (tester) async {
      setView(tester, 1194, 834);
      await pumpHome(tester, PitPage(pitId: pitId), navWidth: 260);
      expect(find.text('編輯坑'), findsOneWidget);
      expect(find.bySemanticsLabel('搜尋'), findsOneWidget);
      expect(find.text('原作動畫'), findsOneWidget);
      expect(find.text('我的坑'), findsNothing); // 沒有返回連結
      final o = tester.getTopLeft(find.text('官方圖冊'));
      final f = tester.getTopLeft(find.text('好看同人圖'));
      final i = tester.getTopLeft(find.text('我的腦洞'));
      final d = tester.getTopLeft(find.text('我的摸魚'));
      final p = tester.getTopLeft(find.text('我的成圖'));
      final h = tester.getTopLeft(find.text('推活'));
      expect(o.dy, f.dy);
      expect(f.dy, i.dy);
      expect(d.dy, p.dy);
      expect(p.dy, h.dy);
      expect(d.dy > o.dy, isTrue);
      expect(d.dx, o.dx);
      // 4:3：tile 寬 ÷ 高（不含說明列）。
      final tileW = f.dx - o.dx - 22;
      expect(tileW > 200, isTrue);
      // 觸控目標。
      expect(tester.getSize(find.bySemanticsLabel('搜尋')).width >= 44, isTrue);
      await unmount(tester);
    });

    testWidgets('834 直向：返回「我的坑」、換封面、2 欄', (tester) async {
      setView(tester, 834, 1194);
      await pumpHome(tester, PitPage(pitId: pitId), navWidth: 84);
      expect(find.text('我的坑'), findsOneWidget);
      expect(find.text('換封面'), findsOneWidget);
      final o = tester.getTopLeft(find.text('官方圖冊'));
      final f = tester.getTopLeft(find.text('好看同人圖'));
      final i = tester.getTopLeft(find.text('我的腦洞'));
      expect(o.dy, f.dy);
      expect(i.dy > o.dy, isTrue);
      expect(i.dx, o.dx);
      // 封面高 200。
      final cover = tester.getRect(find.byType(ClipRRect).at(0));
      expect(cover.height, 200);
      await unmount(tester);
    });

    testWidgets('390 手機：與手機版相同（沒有編輯坑文字、沒有換封面）', (tester) async {
      setView(tester, 390, 844);
      await pumpHome(tester, PitPage(pitId: pitId));
      expect(find.text('編輯坑'), findsNothing);
      expect(find.text('換封面'), findsNothing);
      expect(find.byTooltip('編輯'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('雜物入口：開啟時放在 tile 下方（1194／834）', (tester) async {
      await tester.runAsync(
        () => db.updatePit(
          pitId,
          name: '坑A',
          description: '原作動畫',
          archived: false,
          junkEnabled: true,
        ),
      );
      for (final s in [const Size(1194, 834), const Size(834, 1194)]) {
        setView(tester, s.width, s.height);
        await pumpHome(tester, PitPage(pitId: pitId));
        await tester.scrollUntilVisible(
          find.text('雜物'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('雜物'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('雜物')).dy >
              tester.getTopLeft(find.text('推活')).dy,
          isTrue,
        );
        await unmount(tester);
      }
    });

    testWidgets('1366×1024：同橫向版面，3 欄', (tester) async {
      setView(tester, 1366, 1024);
      await pumpHome(tester, PitPage(pitId: pitId), navWidth: 260);
      final o = tester.getTopLeft(find.text('官方圖冊'));
      final i = tester.getTopLeft(find.text('我的腦洞'));
      final f = tester.getTopLeft(find.text('好看同人圖'));
      expect(o.dy, f.dy);
      expect(f.dy, i.dy);
      await unmount(tester);
    });
  });

  group('PitEdit modal', () {
    Future<void> seedCoverCandidates() async {
      final g = (await db.watchGroups(pitId).first).first;
      await db.addOfficial(pitId, g.id, [
        const NewImage(file: 'o1.png', width: 10, height: 10),
        const NewImage(file: 'o2.png', width: 10, height: 10),
      ]);
    }

    testWidgets('1194：置中 modal，860×690，左候選 4 欄、右表單', (tester) async {
      setView(tester, 1194, 834);
      await tester.runAsync(seedCoverCandidates);
      await pumpHome(tester, PitPage(pitId: pitId));
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      final size = tester.getSize(
        find.descendant(of: dialog, matching: find.byType(SizedBox)).first,
      );
      expect(size.width, 860);
      expect(size.height, 690);
      expect(find.text('從坑內選圖'), findsOneWidget);
      for (final t in ['全部', '官方圖冊', '同人圖', '成圖']) {
        expect(find.text(t), findsWidgets);
      }
      expect(find.text('在坑內頁顯示雜物入口'), findsOneWidget);
      expect(find.text('刪除這個坑'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('儲存'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('選封面＋改名後按儲存才寫入；取消不動', (tester) async {
      setView(tester, 1194, 834);
      await tester.runAsync(seedCoverCandidates);
      await pumpHome(tester, PitPage(pitId: pitId));
      // 取消：不寫入。
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, '亂改');
      await tester.tap(find.bySemanticsLabel('設為封面').first);
      await tester.pump();
      await tester.tap(find.text('取消'));
      await settle(tester);
      var pit = await tester.runAsync(() => db.watchPit(pitId).first);
      expect(pit!.name, '坑A');
      expect(pit.coverImageId, isNull);
      // 儲存。
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).first, '坑改');
      await tester.tap(find.bySemanticsLabel('設為封面').first);
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      pit = await tester.runAsync(() => db.watchPit(pitId).first);
      expect(pit!.name, '坑改');
      expect(pit.coverImageId, isNotNull);
      await unmount(tester);
    });

    testWidgets('modal 內刪除：確認後回到最上層（坑已刪）', (tester) async {
      setView(tester, 1194, 834);
      await pumpHome(tester, const PitsPage());
      await tester.tap(find.text('坑A'));
      await settle(tester);
      expect(find.byType(PitPage), findsOneWidget);
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      await tester.tap(find.text('刪除這個坑'));
      await settle(tester);
      await tester.tap(find.text('刪除').last);
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(PitPage), findsNothing);
      expect(find.byType(PitsPage), findsOneWidget);
      final pits = await tester.runAsync(
        () => db.watchPits(archived: false).first,
      );
      expect(pits, isEmpty);
      await unmount(tester);
    });

    testWidgets('834（≥600）開置中 modal 編輯；窗小時 modal 縮到不超出視窗', (tester) async {
      setView(tester, 834, 1194);
      await pumpHome(tester, PitPage(pitId: pitId));
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(PitEditPage), findsOneWidget);
      await unmount(tester);

      setView(tester, 900, 600);
      await pumpHome(tester, PitPage(pitId: pitId));
      await tester.tap(find.text('編輯坑').first);
      await settle(tester);
      final r = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(r.height <= 600 - 48, isTrue);
      expect(r.width <= 900 - 48, isTrue);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('showAdaptiveModal', () {
    Widget host(void Function(BuildContext) open) => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => open(context),
          child: const Text('開'),
        ),
      ),
    );

    testWidgets('≥600 開 Dialog、手機窄窗開整頁，回傳值一致', (tester) async {
      String? got;
      Future<void> run(Size s) async {
        setView(tester, s.width, s.height);
        await pumpHome(
          tester,
          host((ctx) async {
            got = await showAdaptiveModal<String>(
              ctx,
              builder: (c, asModal) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(c).pop(asModal ? 'm' : 'p'),
                  child: Text(asModal ? '對話框' : '整頁'),
                ),
              ),
            );
          }),
        );
        await tester.tap(find.text('開'));
        await settle(tester);
      }

      await run(const Size(1194, 834));
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('對話框'));
      await settle(tester);
      expect(got, 'm');
      await unmount(tester);

      await run(const Size(390, 844));
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('整頁'));
      await settle(tester);
      expect(got, 'p');
      await unmount(tester);
    });
  });

  group('PitSectionTabBar', () {
    testWidgets('<600 不顯示', (tester) async {
      setView(tester, 390, 844);
      await pumpHome(
        tester,
        Scaffold(
          body: PitSectionTabBar(
            pitId: pitId,
            selected: PitSection.official,
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('好看同人圖'), findsNothing);
      await unmount(tester);
    });

    testWidgets('≥600 六個 tab；onSelect 回呼；點選中的不觸發', (tester) async {
      setView(tester, 834, 1194);
      final picked = <PitSection>[];
      await pumpHome(
        tester,
        Scaffold(
          body: PitSectionTabBar(
            pitId: pitId,
            selected: PitSection.fanArt,
            onSelect: picked.add,
          ),
        ),
      );
      for (final t in ['官方圖冊', '好看同人圖', '我的腦洞', '我的摸魚', '我的成圖', '推活']) {
        expect(find.text(t), findsOneWidget);
        expect(tester.getSize(find.text(t)).height <= 44, isTrue);
      }
      await tester.tap(find.text('好看同人圖'));
      expect(picked, isEmpty);
      await tester.tap(find.text('我的腦洞'));
      expect(picked, [PitSection.ideas]);
      await unmount(tester);
    });

    testWidgets('預設：取代目前分區頁，返回堆疊不變深', (tester) async {
      setView(tester, 834, 1194);
      await pumpHome(tester, PitPage(pitId: pitId));
      await tester.tap(find.text('官方圖冊'));
      await settle(tester);
      expect(find.byType(OfficialListPage), findsOneWidget);
      // 官方圖冊頁本身還沒放 tab bar（其他工程師接入）；用同一個 context 呼叫取代。
      PitSectionTabBar.replaceWith(
        tester.element(find.byType(OfficialListPage)),
        pitId,
        PitSection.fanArt,
      );
      await settle(tester);
      expect(find.byType(OfficialListPage), findsNothing);
      expect(find.byType(FanArtListPage), findsOneWidget);
      // 返回一次就回到坑內頁（不是官方圖冊）。
      Navigator.of(tester.element(find.byType(FanArtListPage))).pop();
      await settle(tester);
      expect(find.byType(PitPage), findsOneWidget);
      await unmount(tester);
    });
  });
}
