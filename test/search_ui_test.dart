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
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';
import 'package:huakeng/ui/search/pit_search_result_page.dart';
import 'package:huakeng/ui/search/tag_filter_bar.dart';

/// tag 篩選列表與坑內搜尋（D-043、D-051）。
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

  Finder pill(String name) => find.descendant(
    of: find.byType(TagFilterPill),
    matching: find.text('#$name'),
  );

  testWidgets('同人圖預覽點 tag：進篩選列表（pill、導覽列在），× 回完整列表', (tester) async {
    await tester.runAsync(() async {
      await seedFan(1, tags: [tagA]);
      await seedFan(2, tags: [tagB]);
    });
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    expect(find.byType(TagFilterBar), findsNothing);
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

    expect(find.byType(FanArtListPage), findsOneWidget);
    expect(pill(tapped), findsOneWidget);
    expect(find.text('目標'), findsOneWidget); // 篩選列表保有導覽列
    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.bySemanticsLabel('移除篩選'));
    await settle(tester);
    expect(find.byType(TagFilterBar), findsNothing);
    expect(find.byType(Image), findsNWidgets(3));
    await unmount(tester);
  });

  testWidgets('腦洞卡片點 tag：篩選；已在篩選中再點別的 tag＝取代，返回仍是完整列表', (tester) async {
    await tester.runAsync(() async {
      await newIdea('甲腦洞', tags: [tagA]);
      await newIdea('乙腦洞', tags: [tagB]);
      await newIdea('丙腦洞', tags: [tagA, tagB]);
    });
    await pumpPage(tester, IdeaListPage(pitId: pitId));
    expect(find.text('甲腦洞'), findsOneWidget);
    expect(find.text('乙腦洞'), findsOneWidget);

    await tester.tap(find.text('#角色1').first);
    await settle(tester);
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('甲腦洞'), findsOneWidget);
    expect(find.text('丙腦洞'), findsOneWidget);
    expect(find.text('乙腦洞'), findsNothing);

    // 在篩選列表裡點另一顆 tag：換掉篩選。
    await tester.tap(find.text('#夏日').first);
    await settle(tester);
    expect(pill('夏日'), findsOneWidget);
    expect(find.text('甲腦洞'), findsNothing);
    expect(find.text('乙腦洞'), findsOneWidget);

    // 取代而非堆疊：返回直接回到完整列表。
    await back(tester);
    expect(find.byType(TagFilterBar), findsNothing);
    expect(find.text('甲腦洞'), findsOneWidget);
    expect(find.text('乙腦洞'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('腦洞詳情點 tag：關掉詳情進篩選列表', (tester) async {
    await tester.runAsync(() async {
      await newIdea('甲腦洞', tags: [tagA]);
      await newIdea('乙腦洞');
    });
    await pumpPage(tester, IdeaListPage(pitId: pitId));
    await tester.tap(find.text('甲腦洞'));
    await settle(tester);
    await tester.tap(find.text('#角色1').first);
    await settle(tester);
    expect(find.byType(IdeaListPage), findsOneWidget);
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('乙腦洞'), findsNothing);
    await back(tester);
    expect(find.byType(TagFilterBar), findsNothing);
    expect(find.text('乙腦洞'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('草稿與成圖的篩選列表：同一條篩選列，只列有該 tag 的項目', (tester) async {
    await tester.runAsync(() async {
      await newDraft('甲草稿', tags: [tagA]);
      await newDraft('乙草稿');
      await newPiece('甲成圖', tags: [tagA]);
      await newPiece('乙成圖');
    });
    await pumpPage(tester, DraftListPage(pitId: pitId, tagId: tagA));
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('甲草稿'), findsOneWidget);
    expect(find.text('乙草稿'), findsNothing);
    await tester.tap(find.bySemanticsLabel('移除篩選'));
    await settle(tester);
    expect(find.text('乙草稿'), findsOneWidget);
    await unmount(tester);

    await pumpPage(tester, FinishedListPage(pitId: pitId, tagId: tagA));
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('甲成圖'), findsOneWidget);
    expect(find.text('乙成圖'), findsNothing);
    await tester.tap(find.bySemanticsLabel('移除篩選'));
    await settle(tester);
    expect(find.text('乙成圖'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('四個列表右上都有搜尋 icon，開啟 PitSearch 並隱藏導覽列', (tester) async {
    await tester.runAsync(() async {
      await seedFan(1, tags: [tagA]);
      await newIdea('腦洞');
      await newDraft('草稿');
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
    final labels = ['全部', '成圖', '同人圖', '草稿', '腦洞'];
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

  testWidgets('點常用 tag 進結果：分段順序 成圖→同人圖→草稿→腦洞，+N 與沒有導覽列', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await newPiece('成圖$i', tags: [tagA]);
      }
      await seedFan(4, tags: [tagA]);
      for (var i = 0; i < 3; i++) {
        await newDraft('草稿$i', tags: [tagA]);
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
    expect(find.text('全部 13'), findsOneWidget);
    expect(find.text('成圖 5'), findsOneWidget);
    expect(find.text('同人圖 4'), findsOneWidget);
    expect(find.text('草稿 3'), findsOneWidget);
    expect(find.text('腦洞 1'), findsOneWidget);
    // 沒有「全部」連結在段頭。
    expect(find.text('查看全部'), findsNothing);

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    final ys = [y('成圖  5'), y('好看同人圖  4'), y('草稿  3'), y('腦洞  1')];
    expect([...ys]..sort(), ys);
    // 成圖 5 筆＝+2，同人圖 4 筆＝+1，草稿剛好 3 筆沒有 +N。
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.textContaining('+'), findsNWidgets(2));

    // 點 +2 進成圖列表並帶同一個 tag。
    await tester.tap(find.text('+2'));
    await settle(tester);
    expect(find.byType(FinishedListPage), findsOneWidget);
    expect(pill('角色1'), findsOneWidget);
    expect(find.text('目標'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('文字搜尋：找標題、作者與 tag 名稱；沒有 tag 的 +N 開完整列表', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await newDraft('夏日草稿$i');
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
    expect(find.text('草稿  4'), findsOneWidget);
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
    expect(find.text('草稿  4'), findsNothing);
    expect(find.text('夏日祭典'), findsOneWidget);

    await tester.ensureVisible(find.text('全部 6'));
    await tester.pump();
    await tester.tap(find.text('全部 6'));
    await settle(tester);
    await tester.tap(find.text('+1'));
    await settle(tester);
    expect(find.byType(DraftListPage), findsOneWidget);
    expect(find.byType(TagFilterBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('結果頁圖片段：一排 3 格、4px 間距、第 3 格 +N 其餘照常開詳情', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await newDraft('草稿$i', tags: [tagA]);
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
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
