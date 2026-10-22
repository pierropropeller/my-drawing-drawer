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
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_detail_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/oshi/oshi_detail_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';
import 'package:huakeng/ui/search/pit_search_result_page.dart';
import 'package:huakeng/ui/search/pit_search_tab.dart';
import 'package:huakeng/ui/search/search_widgets.dart';
import 'package:huakeng/ui/search/filter_pills.dart';

/// 坑內搜尋與點 tag 進搜尋結果（D-051、D-061、D-065、D-089、D-107）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late String tagA;
  late String tagB;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('search_ui');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '測試坑');
    tagA = await db.createTag(pitId, '角色1');
    tagB = await db.createTag(pitId, '夏日');
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 導覽列計數在 microtask 裡變動，多一格讓 ValueListenableBuilder 重建。
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${dir.path}/images')),
    ),
  ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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

  Future<void> pumpApp(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> back(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await settle(tester);
  }

  Future<void> seedFan(int n, {List<String> tags = const []}) => db.addFanArts(
    pitId,
    [for (var i = 0; i < n; i++) NewImage(file: 'a.png')],
    author: '@作者',
    tagIds: tags,
  );

  Future<String> newIdea(String title, {List<String> tags = const []}) =>
      db.saveIdea(
        pitId: pitId,
        title: title,
        body: '內文',
        images: const [],
        tagIds: tags,
        draftIds: const [],
        pieceIds: const [],
      );

  Future<String> newDraft(String title, {List<String> tags = const []}) =>
      db.saveDraft(
        pitId: pitId,
        title: title,
        body: '',
        images: const [NewImage(file: 'b.png')],
        tagIds: tags,
        ideaIds: const [],
      );

  Future<String> newPiece(String title, {List<String> tags = const []}) =>
      db.savePiece(
        pitId: pitId,
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

  Future<String> newOshi(int day, {List<String> tags = const []}) =>
      db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, day),
        title: '推活$day',
        images: const [NewImage(file: 'c.png')],
        tagIds: tags,
      );

  Finder pill(String name) => find.descendant(
    of: find.byType(TagFilterPill),
    matching: find.text('#$name'),
  );

  testWidgets('D-107 同人圖預覽點 tag：進坑內搜尋結果頁（tag pill、相冊「全部」、沒有導覽列），返回回到預覽', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await seedFan(1, tags: [tagA]);
      await seedFan(2, tags: [tagB]);
    });
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.byTooltip('返回'), findsOneWidget);

    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.text('目標'), findsNothing); // 預覽沒有導覽列
    // 預覽可能是 tagA 或 tagB 的圖；點它顯示的那顆 tag。
    final tagChip = find.textContaining('#').first;
    final tapped = (tester.widget<Text>(tagChip).data ?? '').substring(1);
    await tester.tap(tagChip);
    await settle(tester);

    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(pill(tapped), findsOneWidget);
    expect(find.text('目標'), findsNothing); // 搜尋頁沒有導覽列
    // 相冊預設「全部」：pills 只列有結果的（這裡只有同人圖）。
    expect(find.textContaining(RegExp(r'^全部 \d+$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^同人圖 \d+$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^成圖 \d+$')), findsNothing);

    await back(tester);
    expect(find.byType(FanArtPreviewPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('D-107 腦洞卡片、詳情點 tag：都進搜尋結果頁（不再回列表篩選）', (tester) async {
    await tester.runAsync(() async {
      await newIdea('甲腦洞', tags: [tagA]);
      await newIdea('乙腦洞', tags: [tagB]);
      await newIdea('丙腦洞', tags: [tagA, tagB]);
    });
    await pumpPage(tester, IdeaListPage(pitId: pitId));
    expect(find.text('甲腦洞'), findsOneWidget);
    expect(find.text('乙腦洞'), findsOneWidget);

    // 卡片上的 tag。
    await tester.tap(find.text('#角色1').first);
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('甲腦洞'), findsOneWidget);
    expect(find.text('丙腦洞'), findsOneWidget);
    expect(find.text('乙腦洞'), findsNothing);
    await back(tester);
    expect(find.byType(IdeaListPage), findsOneWidget);

    // 詳情裡的 tag：搜尋頁疊在詳情上，返回先回詳情再回列表。
    await tester.tap(find.text('甲腦洞'));
    await settle(tester);
    expect(find.byType(IdeaDetailPage), findsOneWidget);
    await tester.tap(find.text('#角色1').last);
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    await back(tester);
    expect(find.byType(IdeaDetailPage), findsOneWidget);
    await back(tester);
    expect(find.byType(IdeaListPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('四個列表右上都有搜尋 icon，開啟 PitSearch 並隱藏導覽列', (tester) async {
    await tester.runAsync(() async {
      await seedFan(1, tags: [tagA]);
      await newIdea('腦洞');
      await newDraft('摸魚');
      await newPiece('成圖');
    });
    for (final page in <Widget>[
      FanArtListPage(pitId: pitId),
      IdeaListPage(pitId: pitId),
      DraftListPage(pitId: pitId),
      FinishedListPage(pitId: pitId),
    ]) {
      await pumpPage(tester, page);
      expect(find.bySemanticsLabel('搜尋'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('搜尋'));
      await settle(tester);
      expect(find.byType(PitSearchPage), findsOneWidget);
      await unmount(tester);
    }
  });

  testWidgets('PitSearch：分頁順序、常用 tag 按使用次數排序；沒有導覽列', (tester) async {
    await tester.runAsync(() async {
      await seedFan(1, tags: [tagB]);
      await newIdea('腦洞一', tags: [tagA]);
      await newIdea('腦洞二', tags: [tagA]);
    });
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('搜尋'));
    await settle(tester);

    expect(find.byType(PitSearchPage), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    final labels = ['全部', '成圖', '官方圖', '同人圖', '推活', '摸魚', '腦洞'];
    final xs = [
      for (final l in labels)
        tester.getTopLeft(find.widgetWithText(Container, l).first).dx,
    ];
    expect([...xs]..sort(), xs);
    expect(find.text('常用 tag'), findsOneWidget);
    // 角色1 用了 2 次、夏日 1 次。
    expect(
      tester.getTopLeft(find.textContaining('#角色1')).dx <
          tester.getTopLeft(find.textContaining('#夏日')).dx,
      isTrue,
    );
    await back(tester);
    expect(find.text('目標'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('點常用 tag 進結果：分段順序 成圖→同人圖→推活→摸魚→腦洞，+N 與沒有導覽列', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await newPiece('成圖$i', tags: [tagA]);
      }
      await seedFan(4, tags: [tagA]);
      for (var i = 1; i <= 7; i++) {
        await newOshi(i, tags: [tagA]);
      }
      for (var i = 0; i < 3; i++) {
        await newDraft('摸魚$i', tags: [tagA]);
      }
      await newIdea('腦洞甲', tags: [tagA]);
    });
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('搜尋'));
    await settle(tester);
    await tester.tap(find.textContaining('#角色1'));
    await settle(tester);

    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    expect(pill('角色1'), findsOneWidget);
    // 分頁帶數字。
    expect(find.text('全部 20'), findsOneWidget);
    expect(find.text('成圖 5'), findsOneWidget);
    expect(find.text('同人圖 4'), findsOneWidget);
    expect(find.text('推活 7'), findsOneWidget);
    expect(find.text('摸魚 3'), findsOneWidget);
    expect(find.text('腦洞 1'), findsOneWidget);
    // 沒有「全部」連結在段頭。
    expect(find.text('查看全部'), findsNothing);

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    final ys = [y('成圖  5'), y('好看同人圖  4'), y('推活  7'), y('摸魚  3'), y('腦洞  1')];
    expect([...ys]..sort(), ys);
    // 成圖 5 筆＝+2，同人圖 4 筆＝+1，推活 7 筆＝+4，摸魚剛好 3 筆沒有 +N。
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.textContaining('+'), findsNWidgets(3));

    // 點 +2：留在結果頁，切到「成圖」相冊（PitSearchResultTab）——九宮格列出 5 筆全部，沒有導覽列。
    await tester.tap(find.text('+2'));
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(find.byType(PitSearchResultTab), findsOneWidget);
    expect(find.byKey(const ValueKey('searchTabGrid')), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5));
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    // 點「全部」回到分段總覽。
    await tester.tap(find.text('全部 20'));
    await settle(tester);
    expect(find.byType(PitSearchResultTab), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('推活段：點「+N」切到推活相冊，點其他格開推活詳情', (tester) async {
    await tester.runAsync(() async {
      for (var i = 1; i <= 5; i++) {
        await newOshi(i, tags: [tagA]);
      }
    });
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('搜尋'));
    await settle(tester);
    await tester.tap(find.textContaining('#角色1'));
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    // 其他格：進推活詳情，返回仍在結果頁。
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsNothing);
    expect(find.byType(OshiDetailPage), findsOneWidget);
    await back(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);

    await tester.tap(find.text('+2'));
    await settle(tester);
    expect(find.byType(PitSearchResultTab), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5)); // 推活 5 筆全部
    await unmount(tester);
  });

  testWidgets('D-061 PitSearchFew：不滿 3 筆照實際張數、各自圓角、沒有 +N；0 筆的段與分頁不顯示', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await newPiece('成圖甲', tags: [tagA]);
      await newPiece('成圖乙', tags: [tagA]);
      await seedFan(1, tags: [tagA]);
      await newIdea('腦洞甲', tags: [tagA]);
    });
    await pumpPage(tester, PitSearchResultPage(pitId: pitId, tagId: tagA));
    // 分頁：只有有結果的；順序 全部／成圖／同人圖／腦洞。
    expect(find.text('全部 4'), findsOneWidget);
    expect(find.text('成圖 2'), findsOneWidget);
    expect(find.text('同人圖 1'), findsOneWidget);
    expect(find.text('腦洞 1'), findsOneWidget);
    expect(find.textContaining('推活'), findsNothing);
    expect(find.textContaining('摸魚'), findsNothing);
    expect(find.textContaining('+'), findsNothing);

    // 成圖 2 張＋同人圖 1 張，一共 3 張圖；格寬仍是 1/3，間距 4。
    final imgs = find.byType(Image);
    expect(imgs, findsNWidgets(3));
    final r0 = tester.getRect(imgs.at(0));
    final r1 = tester.getRect(imgs.at(1));
    final r2 = tester.getRect(imgs.at(2));
    expect((r1.left - r0.right).abs(), closeTo(4, 0.01));
    expect(r0.width, closeTo(r0.height, 0.01));
    expect(r2.left, closeTo(r0.left, 0.01)); // 同人圖那段只有一張，靠左
    expect(r2.width, closeTo(r0.width, 0.01));
    // 每張各自 10px 圓角。
    final clips = tester
        .widgetList<ClipRRect>(
          find.ancestor(of: imgs.at(0), matching: find.byType(ClipRRect)),
        )
        .where((c) => c.borderRadius == BorderRadius.circular(10));
    expect(clips, isNotEmpty);
    await unmount(tester);
  });

  testWidgets('少於 3 筆的推活段：實際張數、沒有 +N；點分頁只看那一類', (tester) async {
    await tester.runAsync(() async {
      await newOshi(1, tags: [tagA]);
      await newOshi(2, tags: [tagA]);
    });
    await pumpPage(tester, PitSearchResultPage(pitId: pitId, tagId: tagA));
    expect(find.text('推活  2'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.textContaining('+'), findsNothing);
    await tester.tap(find.text('推活 2'));
    await settle(tester);
    expect(find.byType(Image), findsNWidgets(2));
    await unmount(tester);
  });

  test('SearchCategory 順序：全部／成圖／官方圖／同人圖／推活／摸魚／腦洞', () {
    expect(SearchCategory.values, [
      SearchCategory.all,
      SearchCategory.piece,
      SearchCategory.official,
      SearchCategory.fan,
      SearchCategory.oshi,
      SearchCategory.draft,
      SearchCategory.idea,
    ]);
  });

  testWidgets('文字搜尋：找標題、作者與 tag 名稱；沒有 tag 的 +N 開完整列表', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await newDraft('夏日摸魚$i');
      }
      await newDraft('別的');
      await newIdea('夏日祭典');
      await newIdea('冬天', tags: [tagB]);
      await newIdea('無關');
    });
    await pumpPage(tester, PitSearchPage(pitId: pitId));
    await tester.enterText(find.byType(TextField), '夏日');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(find.text('摸魚  4'), findsOneWidget);
    expect(find.text('腦洞  2'), findsOneWidget); // 標題命中＋tag 名稱命中
    expect(find.text('夏日祭典'), findsOneWidget);
    expect(find.text('冬天'), findsOneWidget);
    expect(find.text('無關'), findsNothing);
    expect(find.text('成圖  1'), findsNothing);

    // 只看某一類。
    await tester.ensureVisible(find.text('腦洞 2'));
    await tester.pump();
    await tester.tap(find.text('腦洞 2'));
    await settle(tester);
    expect(find.text('摸魚  4'), findsNothing);
    expect(find.text('夏日祭典'), findsOneWidget);

    await tester.ensureVisible(find.text('全部 6'));
    await tester.pump();
    await tester.tap(find.text('全部 6'));
    await settle(tester);
    await tester.tap(find.text('+1'));
    await settle(tester);
    // 「+1」＝摸魚相冊（4 筆全部）；沒有 tag 的純文字搜尋也一樣留在結果頁。
    expect(find.byType(PitSearchResultTab), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(4));
    await unmount(tester);
  });

  testWidgets('結果頁圖片段：一排 3 格、4px 間距、第 3 格 +N 其餘照常開詳情', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await newDraft('摸魚$i', tags: [tagA]);
      }
    });
    await pumpPage(tester, PitSearchResultPage(pitId: pitId, tagId: tagA));
    final imgs = find.byType(Image);
    expect(imgs, findsNWidgets(3));
    final r0 = tester.getRect(imgs.at(0));
    final r1 = tester.getRect(imgs.at(1));
    expect((r1.left - r0.right).abs(), closeTo(4, 0.01));
    expect(r0.width, closeTo(r0.height, 0.01));
    expect(find.text('+1'), findsOneWidget);
    await tester.tap(imgs.at(0));
    await settle(tester);
    expect(find.text('目標'), findsNothing);
    await unmount(tester);
  });

  testWidgets('腦洞結果直向全列、分批載入', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 45; i++) {
        await newIdea('批量腦洞${i.toString().padLeft(2, '0')}', tags: [tagA]);
      }
    });
    await pumpPage(tester, PitSearchResultPage(pitId: pitId, tagId: tagA));
    expect(find.text('腦洞  45'), findsOneWidget);
    // 一開始只載入第一批（20 個），底部有載入中的標記。
    final pos = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    final extents = <double>[pos.maxScrollExtent];
    // 每次捲到底就會再載入一批：45 個＝20 + 20 + 5。
    for (var i = 0; i < 5; i++) {
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      extents.add(pos.maxScrollExtent);
    }
    expect(extents[1], greaterThan(extents[0]));
    expect(extents[2], greaterThan(extents[1]));
    expect(extents[3], extents[2]); // 全部載完就不再增加
    expect(find.byKey(const Key('ideas-loading')), findsNothing);
    expect(find.textContaining('批量腦洞'), findsWidgets);
    await unmount(tester);
  });

  Future<void> seedOfficial(int n, {List<String> tags = const []}) async {
    final g = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(pitId, g.id, [
      for (var i = 0; i < n; i++)
        NewImage(file: 'b.png', width: 10, height: 10),
    ], tagIds: tags);
  }

  testWidgets('D-089 搜尋結果：官方圖冊在成圖之後、同人圖之前；分頁有「官方圖」；+N 進官方圖相冊', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await newPiece('成圖$i', tags: [tagA]);
      }
      await seedOfficial(5, tags: [tagA]);
      await seedOfficial(1); // 沒有 tag 的不算
      await seedFan(2, tags: [tagA]);
    });
    await pumpPage(tester, PitSearchResultPage(pitId: pitId, tagId: tagA));
    expect(find.text('官方圖 5'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    final ys = [y('成圖  4'), y('官方圖冊  5'), y('好看同人圖  2')];
    expect([...ys]..sort(), ys);
    // 官方圖 5 筆＝+2。
    expect(find.text('+2'), findsOneWidget);
    // 點 pill「官方圖 5」＝單一相冊（九宮格，沒有分段標題與 +N）。
    await tester.tap(find.text('官方圖 5'));
    await settle(tester);
    expect(find.byType(PitSearchResultTab), findsOneWidget);
    expect(find.text('成圖  4'), findsNothing);
    expect(find.text('+2'), findsNothing);
    await tester.tap(find.text('全部 11'));
    await settle(tester);
    // 同一個結果點 +2 也是進同一個相冊。
    await tester.tap(find.text('+2'));
    await settle(tester);
    expect(find.byType(PitSearchResultTab), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5));
    expect(pill('角色1'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('D-107 官方圖預覽點 tag：進坑內搜尋結果頁，只列有該 tag 的官方圖', (tester) async {
    await tester.runAsync(() async {
      await seedOfficial(1, tags: [tagA]);
      await seedOfficial(1);
    });
    await pumpPage(tester, OfficialListPage(pitId: pitId));
    expect(find.byType(Image), findsNWidgets(2));
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
    expect(find.text('#角色1'), findsOneWidget);
    await tester.tap(find.text('#角色1'));
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('官方圖 1'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    // 按 pill 的 ×：沒有別的條件就離開搜尋頁，回到預覽。
    await tester.tap(find.bySemanticsLabel('移除篩選'));
    await settle(tester);
    expect(find.byType(ImagePreviewPage), findsOneWidget);
    await unmount(tester);
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
