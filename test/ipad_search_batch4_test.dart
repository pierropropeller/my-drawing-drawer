import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/search/filter_pills.dart';
import 'package:huakeng/ui/search/global_search_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';
import 'package:huakeng/ui/search/pit_search_result_page.dart';
import 'package:huakeng/ui/search/search_wide.dart';

/// iPad 批次 4（P-027 主頁三分頁、P-028 全坑搜尋、P-029 坑內搜尋、P-030 推活）的寬版版面。
/// 1194×834 橫向、834×1194 直向；手機（390 寬）維持原樣。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipad_search4');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async {
    navBarHiddenCount.value = 0;
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  void view(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    double w = 1194,
    double h = 834,
    Brightness brightness = Brightness.light,
  }) async {
    view(tester, w, h);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(brightness, useGoogleFonts: false),
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

  Future<void> seedFan(String pit, int n, {List<String> tags = const []}) =>
      db.addFanArts(
        pit,
        [for (var i = 0; i < n; i++) NewImage(file: 'a.png')],
        author: '煙花作者',
        tagIds: tags,
      );

  Future<String> newIdea(
    String pit,
    String title, {
    List<String> tags = const [],
  }) => db.saveIdea(
    pitId: pit,
    title: title,
    body: '兩人在天台看煙花',
    images: const [],
    tagIds: tags,
    draftIds: const [],
    pieceIds: const [],
  );

  Future<String> newPiece(
    String pit,
    String title, {
    List<String> tags = const [],
  }) => db.savePiece(
    pitId: pit,
    title: title,
    body: '',
    images: const [NewImage(file: 'a.png')],
    tagIds: tags,
    links: const [],
    targetLikes: 0,
    finishedAt: DateTime(2026, 5, 1),
    ideaIds: const [],
    draftIds: const [],
  );

  group('P-027 主頁（淺坑／封存坑 兩欄卡片列表）', () {
    testWidgets('橫向：沒有田字／瀑布切換；三個分頁都有 44px 搜尋鍵；淺坑兩欄卡片＋開新淺坑', (tester) async {
      await tester.runAsync(() async {
        await db.createPit(
          name: '星之彼端',
          description: '第 3 集再決定要不要入',
          status: PitStatus.shallow,
        );
        await db.createPit(name: '夏日偵探社', status: PitStatus.shallow);
        await db.createPit(name: '舊坑・學園篇', status: PitStatus.archived);
      });
      await pump(tester, const PitsPage());
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.bySemanticsLabel('田字檢視'), findsNothing);
      expect(find.bySemanticsLabel('瀑布檢視'), findsNothing);
      for (final label in [l.pitsActive, l.shallowName, l.pitsArchived]) {
        expect(find.text(label), findsOneWidget);
      }

      Future<void> expectSearchButton() async {
        final btn = find.byKey(const ValueKey('mainSearchButton'));
        expect(btn, findsOneWidget);
        expect(tester.getSize(btn), const Size(44, 44));
      }

      await expectSearchButton();

      await tester.tap(find.text(l.shallowName));
      await settle(tester);
      await expectSearchButton();
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('pitCardGrid')),
      );
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      // 兩張卡並排（同一列），沒封面＝坑名第一個字。
      final a = tester.getTopLeft(find.text('星之彼端'));
      final b = tester.getTopLeft(find.text('夏日偵探社'));
      expect(a.dy, b.dy);
      expect(b.dx, greaterThan(a.dx));
      expect(find.text('星'), findsOneWidget);
      expect(find.text('夏'), findsOneWidget);
      // 64px 封面。
      expect(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 64 && w.height == 64,
        ),
        findsWidgets,
      );
      // 副標。
      expect(find.text('第 3 集再決定要不要入'), findsOneWidget);
      // 最後一格虛線「開新淺坑」。
      expect(find.byKey(const ValueKey('newShallowCard')), findsOneWidget);
      expect(find.text(l.shallowNewRow), findsOneWidget);

      await tester.tap(find.text(l.pitsArchived));
      await settle(tester);
      await expectSearchButton();
      expect(find.byKey(const ValueKey('pitCardGrid')), findsOneWidget);
      expect(find.text('舊坑・學園篇'), findsOneWidget);
      expect(find.text('舊'), findsOneWidget);
      // 封存坑沒有「開新」格。
      expect(find.byKey(const ValueKey('newShallowCard')), findsNothing);
      await unmount(tester);
    });

    testWidgets('深色與直向（834）也有搜尋鍵；淺坑仍是兩欄', (tester) async {
      await tester.runAsync(() async {
        await db.createPit(name: '星之彼端', status: PitStatus.shallow);
      });
      await pump(
        tester,
        const PitsPage(),
        w: 834,
        h: 1194,
        brightness: Brightness.dark,
      );
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(
        tester.getSize(find.byKey(const ValueKey('mainSearchButton'))),
        const Size(44, 44),
      );
      await tester.tap(find.text(l.shallowName));
      await settle(tester);
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('pitCardGrid')),
      );
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('mainSearchButton'))),
        const Size(44, 44),
      );
      await unmount(tester);
    });

    testWidgets('手機：淺坑維持單欄列表（沒有卡片格）', (tester) async {
      await tester.runAsync(() async {
        await db.createPit(name: '星之彼端', status: PitStatus.shallow);
      });
      await pump(tester, const PitsPage(), w: 390, h: 844);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.text(l.shallowName));
      await settle(tester);
      expect(find.byKey(const ValueKey('pitCardGrid')), findsNothing);
      expect(find.byType(ListView), findsWidgets);
      expect(
        tester.getSize(find.byKey(const ValueKey('mainSearchButton'))),
        const Size(42, 42),
      );
      await unmount(tester);
    });
  });

  group('P-028 全坑搜尋', () {
    testWidgets('未輸入：每坑一張白卡、兩欄瀑布、封存坑最後並有「封存」小標；寬版不隱藏導覽', (tester) async {
      await tester.runAsync(() async {
        final t1 = await db.createTag(pitId, '角色1');
        final p2 = await db.createPit(name: '坑B');
        final t2 = await db.createTag(p2, '校園paro');
        final p3 = await db.createPit(name: '坑X', status: PitStatus.archived);
        final t3 = await db.createTag(p3, '學園篇');
        await newPiece(pitId, '圖1', tags: [t1]);
        await newPiece(p2, '圖2', tags: [t2]);
        await newPiece(p3, '圖3', tags: [t3]);
      });
      await pump(tester, const GlobalSearchPage());
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      // 寬版：導覽（sidebar）保留，所以頁面不要求隱藏。
      expect(navBarHiddenCount.value, 0);
      expect(find.byKey(const ValueKey('globalTagMasonry')), findsOneWidget);
      final masonry = tester.widget<MasonryGridView>(
        find.byKey(const ValueKey('globalTagMasonry')),
      );
      expect(
        (masonry.gridDelegate
                as SliverSimpleGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      final cards = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key! as ValueKey).value.toString().startsWith('globalTagGroup-'),
      );
      expect(cards, findsNWidgets(3));
      // 兩欄：前兩張並排，第三張在第一欄下面。
      final p = [
        for (final e in cards.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)),
      ];
      expect(p[0].dy, p[1].dy);
      expect(p[1].dx, greaterThan(p[0].dx));
      expect(p[2].dx, p[0].dx);
      // 封存坑排最後，帶「封存」小標；其他坑沒有。
      expect(find.text(l.ipadsearchArchivedBadge), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      // 取消＝回上一頁；寬輸入框 48 高。
      expect(find.text(l.commonCancel), findsOneWidget);
      expect(tester.getSize(find.byType(WideSearchInput)).height, 48);
      await unmount(tester);
    });

    testWidgets('手機：輸入框列與原本一樣，導覽列照舊隱藏', (tester) async {
      await tester.runAsync(() async {
        final t1 = await db.createTag(pitId, '角色1');
        await newPiece(pitId, '圖1', tags: [t1]);
      });
      await pump(tester, const GlobalSearchPage(), w: 390, h: 844);
      expect(navBarHiddenCount.value, 1);
      expect(find.byKey(const ValueKey('globalTagMasonry')), findsNothing);
      expect(find.byType(WideSearchInput), findsNothing);
      await unmount(tester);
      expect(navBarHiddenCount.value, 0);
    });

    testWidgets('輸入後：符合的 tag 帶坑名小標；每坑標題列、一排 6 格第 6 格「+N」、腦洞卡兩欄', (
      tester,
    ) async {
      late String tagId;
      await tester.runAsync(() async {
        tagId = await db.createTag(pitId, '煙花大會');
        final p2 = await db.createPit(name: '坑B');
        await db.createTag(p2, '煙花');
        await seedFan(pitId, 8);
        await newIdea(pitId, '天台看煙花');
        await newIdea(pitId, '煙花下的告白');
        await newIdea(p2, '煙火大會迷路（煙花）');
      });
      await pump(tester, const GlobalSearchPage());
      await tester.enterText(find.byType(TextField), '煙花');
      await settle(tester);
      // 符合的 tag：名稱＋坑名小標。
      expect(find.byKey(ValueKey('globalTagHit-$tagId')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('globalTagHit-$tagId')),
          matching: find.text('坑A'),
        ),
        findsOneWidget,
      );
      // 坑A 的組：8 張同人圖＝6 格＋「+2」。
      final group = find.byKey(ValueKey('globalPit-$pitId'));
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.text('+2')),
        findsOneWidget,
      );
      final row = find.descendant(
        of: group,
        matching: find.byType(WideThumbRow),
      );
      expect(row, findsOneWidget);
      // 6 格同高同寬，間距 4。
      final cells = find.descendant(
        of: row,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width != null && w.width == w.height,
        ),
      );
      expect(cells, findsNWidgets(6));
      final c0 = tester.getRect(cells.at(0));
      final c1 = tester.getRect(cells.at(1));
      expect(c1.left - c0.right, 4);
      // 腦洞卡兩欄並排。
      final i1 = tester.getTopLeft(find.text('天台看煙花'));
      final i2 = tester.getTopLeft(find.text('煙花下的告白'));
      expect(i1.dy, i2.dy);
      expect((i2.dx - i1.dx).abs(), greaterThan(100));
      // 清除鈕在、取消鈕在。
      expect(find.byKey(const ValueKey('globalSearchClear')), findsOneWidget);
      expect(find.byKey(const ValueKey('globalSearchCancel')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('點坑標題列＝進該坑坑內搜尋（帶同一個關鍵字）', (tester) async {
      await tester.runAsync(() async {
        await newIdea(pitId, '天台看煙花');
      });
      await pump(tester, const GlobalSearchPage());
      await tester.enterText(find.byType(TextField), '煙花');
      await settle(tester);
      await tester.tap(find.text('坑A').last);
      await settle(tester);
      expect(find.byType(PitSearchResultPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('P-029 坑內搜尋', () {
    testWidgets('PitSearch：返回＋寬輸入框、相冊 pills、常用 tag、未加 tag 卡寬 420；rail 保留', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final t1 = await db.createTag(pitId, '角色1');
        await newPiece(pitId, '圖1', tags: [t1]);
        await newPiece(pitId, '圖2');
      });
      await pump(tester, PitSearchPage(pitId: pitId));
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(navBarHiddenCount.value, 0);
      expect(tester.getSize(find.byType(WideSearchInput)).height, 48);
      expect(find.byKey(const ValueKey('searchWideBack')), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      // 相冊 pills 高 38。
      expect(
        tester.getSize(find.byKey(const ValueKey('searchCategory-all'))).height,
        38,
      );
      expect(find.text(l.searchUntagged), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('searchUntaggedCard'))).width,
        420,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('searchUntaggedCount'))).width,
        greaterThan(0),
      );
      await unmount(tester);
    });

    testWidgets(
      'PitSearchResult：左邊 210 寬相冊清單（只列有結果的、帶數字）；右邊分段一排 6 格＋「+N」、腦洞兩欄',
      (tester) async {
        late String tag;
        await tester.runAsync(() async {
          tag = await db.createTag(pitId, '角色1');
          for (var i = 0; i < 8; i++) {
            await newPiece(pitId, '成圖$i', tags: [tag]);
          }
          await seedFan(pitId, 3, tags: [tag]);
          await newIdea(pitId, '天台看煙花', tags: [tag]);
          await newIdea(pitId, '制服 paro', tags: [tag]);
        });
        await pump(tester, PitSearchResultPage(pitId: pitId, tagId: tag));
        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
        expect(navBarHiddenCount.value, 0);
        // tag pill 在搜尋列裡。
        expect(find.byType(TagFilterPill), findsOneWidget);
        // 左邊相冊清單：全部＋有結果的（成圖／同人圖／腦洞），沒有官方圖、推活、摸魚。
        final nav = find.byType(WideAlbumNav);
        expect(nav, findsOneWidget);
        expect(tester.getSize(nav).width, 210);
        expect(find.byKey(const ValueKey('searchAlbum-all')), findsOneWidget);
        expect(find.byKey(const ValueKey('searchAlbum-piece')), findsOneWidget);
        expect(find.byKey(const ValueKey('searchAlbum-fan')), findsOneWidget);
        expect(find.byKey(const ValueKey('searchAlbum-idea')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('searchAlbum-official')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('searchAlbum-oshi')), findsNothing);
        expect(find.byKey(const ValueKey('searchAlbum-draft')), findsNothing);
        // 數字：全部 13（8+3+2）、成圖 8。
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('searchAlbum-all')),
            matching: find.text('13'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('searchAlbum-piece')),
            matching: find.text('8'),
          ),
          findsOneWidget,
        );
        // 右邊：成圖 8 筆＝6 格＋「+2」；同人圖 3 張不補空格、沒有「+N」。
        final pieceSec = find.byKey(const ValueKey('searchSection-pieces'));
        expect(pieceSec, findsOneWidget);
        expect(
          find.descendant(of: pieceSec, matching: find.text('+2')),
          findsOneWidget,
        );
        final fanSec = find.byKey(const ValueKey('searchSection-fanArts'));
        expect(
          find.descendant(of: fanSec, matching: find.byType(RichText)),
          findsWidgets,
        );
        expect(
          find.descendant(of: fanSec, matching: find.textContaining('+')),
          findsNothing,
        );
        // 腦洞卡兩欄。
        final i1 = tester.getTopLeft(find.text('天台看煙花'));
        final i2 = tester.getTopLeft(find.text('制服 paro'));
        expect(i1.dy, i2.dy);
        expect((i2.dx - i1.dx).abs(), greaterThan(100));

        // 選某個相冊＝右邊變 6 欄九宮格，間距 2。
        await tester.tap(find.byKey(const ValueKey('searchAlbum-fan')));
        await settle(tester);
        final grid = tester.widget<GridView>(
          find.byKey(const ValueKey('searchTabGrid')),
        );
        final d =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(d.crossAxisCount, 6);
        expect(d.crossAxisSpacing, 2);
        expect(d.mainAxisSpacing, 2);
        expect(
          find.byKey(const ValueKey('searchSection-pieces')),
          findsNothing,
        );
        // 其餘相冊仍在清單裡，選中的是同人圖。
        expect(find.text(l.ipadsearchAlbums), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('未加 tag：灰色 chip；長按多選，右下工具列「已選 N 項｜全選｜加 tag」；補完 tag 的項目即時消失', (
      tester,
    ) async {
      late String p1;
      late String tag;
      await tester.runAsync(() async {
        tag = await db.createTag(pitId, '角色1');
        p1 = await newPiece(pitId, '成圖甲');
        await newPiece(pitId, '成圖乙');
        await newPiece(pitId, '成圖丙');
      });
      await pump(tester, PitSearchResultPage(pitId: pitId, untagged: true));
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.byType(UntaggedFilterPill), findsOneWidget);
      expect(find.byType(WideSelectBar), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('searchAlbum-all')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      // 長按第一格進入多選。
      final cell = find.byKey(const ValueKey('searchSection-pieces'));
      final first = find
          .descendant(of: cell, matching: find.byType(GestureDetector))
          .first;
      await tester.longPress(first);
      await settle(tester);
      expect(find.byType(WideSelectBar), findsOneWidget);
      expect(find.text(l.ipadsearchSelectedItems(1)), findsOneWidget);
      expect(find.text(l.commonSelectAll), findsOneWidget);
      expect(find.text(l.ipadsearchAddTag), findsOneWidget);
      // 工具列在右邊內容區底部（右下），不是整頁底部的導覽列。
      final bar = tester.getRect(find.byType(WideSelectBar));
      expect(bar.bottom, 834);
      expect(bar.height, 64);
      expect(bar.left, greaterThan(210));
      // 全選。
      await tester.tap(find.byKey(const ValueKey('searchSelectAll')));
      await settle(tester);
      expect(find.text(l.ipadsearchSelectedItems(3)), findsOneWidget);
      expect(find.text(l.commonDeselectAll), findsOneWidget);
      // 補完 tag 的項目即時消失（資料流更新，選取數不變時工具列仍在）。
      await tester.runAsync(
        () => db.applyBatchTagsMixed(
          [TagRef(TagTarget.piece, p1)],
          addTagIds: [tag],
        ),
      );
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('searchAlbum-all')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // 取消多選。
      await tester.tap(find.byKey(const ValueKey('searchSelectExit')));
      await settle(tester);
      expect(find.byType(WideSelectBar), findsNothing);
      await unmount(tester);
    });

    testWidgets('手機：結果頁仍是頂部 pills，沒有左邊相冊清單，導覽列隱藏', (tester) async {
      late String tag;
      await tester.runAsync(() async {
        tag = await db.createTag(pitId, '角色1');
        await newPiece(pitId, '成圖甲', tags: [tag]);
      });
      await pump(
        tester,
        PitSearchResultPage(pitId: pitId, tagId: tag),
        w: 390,
        h: 844,
      );
      expect(find.byType(WideAlbumNav), findsNothing);
      expect(navBarHiddenCount.value, 1);
      await unmount(tester);
    });
  });

  group('P-030 推活（iPad）', () {
    Future<void> seedOshi() async {
      await db.ensureOshiGroups(pitId);
      for (var i = 1; i <= 8; i++) {
        await db.saveOshiRecord(
          pitId: pitId,
          date: DateTime(2026, 5, i),
          title: '推活$i',
          images: const [NewImage(file: 'c.png')],
          tagIds: const [],
        );
      }
    }

    testWidgets('右邊面板沒有搜尋框與角色 tag；標題列有搜尋鍵→坑內搜尋；第二種版面＝6 欄九宮格', (tester) async {
      await tester.runAsync(seedOshi);
      await pump(tester, OshiListPage(pitId: pitId));
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l.ipadListsOshiCharacterTags), findsNothing);
      expect(find.text(l.albumGroupLabel), findsOneWidget);
      expect(find.text(l.ipadListsOshiJumpToMonth), findsOneWidget);
      // 切到九宮格。
      await tester.tap(find.bySemanticsLabel(l.pieceViewNine));
      await settle(tester);
      final gridFinder = find.byKey(const ValueKey('oshiWideNineGrid'));
      expect(gridFinder, findsOneWidget);
      final d =
          tester.widget<GridView>(gridFinder).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(d.crossAxisCount, 6);
      expect(d.crossAxisSpacing, 2);
      expect(d.mainAxisSpacing, 2);
      // 格子沒有圓角、沒有日期字。
      expect(
        find.descendant(of: gridFinder, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      expect(find.text('5/3'), findsNothing);
      // 搜尋鍵進坑內搜尋。
      await tester.tap(find.bySemanticsLabel(l.commonSearch));
      await settle(tester);
      expect(find.byType(PitSearchPage), findsOneWidget);
      await unmount(tester);
    });
  });
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
