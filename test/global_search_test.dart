import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/data/search_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/search/filter_pills.dart';
import 'package:huakeng/ui/search/global_search_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';
import 'package:huakeng/ui/search/pit_search_result_page.dart';
import 'package:huakeng/ui/search/pit_search_tab.dart';

/// 全坑搜尋、點 tag 進坑內搜尋、未加 tag（D-105、D-107、D-108）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('global_search');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
  });
  tearDown(() async {
    await db.close();
  });

  // ---- 資料建立 ----
  Future<String> idea(
    String pit,
    String title, {
    String body = '',
    List<String> tags = const [],
  }) => db.saveIdea(
    pitId: pit,
    title: title,
    body: body,
    images: const [],
    tagIds: tags,
    draftIds: const [],
    pieceIds: const [],
  );

  Future<String> draft(
    String pit,
    String title, {
    List<String> tags = const [],
  }) => db.saveDraft(
    pitId: pit,
    title: title,
    body: '',
    images: const [NewImage(file: 'b.png')],
    tagIds: tags,
    ideaIds: const [],
  );

  Future<String> piece(
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

  Future<String> oshi(String pit, int day, {List<String> tags = const []}) =>
      db.saveOshiRecord(
        pitId: pit,
        date: DateTime(2026, 5, day),
        title: '推活$day',
        images: const [NewImage(file: 'c.png')],
        tagIds: tags,
      );

  Future<void> fan(
    String pit,
    int n, {
    List<String> tags = const [],
    String author = '@作者',
  }) => db.addFanArts(
    pit,
    [for (var i = 0; i < n; i++) NewImage(file: 'a.png')],
    author: author,
    tagIds: tags,
  );

  Future<void> official(
    String pit,
    int n, {
    List<String> tags = const [],
  }) async {
    final g = (await db.watchGroups(pit).first).first;
    await db.addOfficial(pit, g.id, [
      for (var i = 0; i < n; i++)
        NewImage(file: 'b.png', width: 10, height: 10),
    ], tagIds: tags);
  }

  // ======================================================================
  // 資料層
  // ======================================================================
  group('未加 tag（D-108）資料層', () {
    test('數量＝官方圖、同人圖、推活、摸魚、成圖、腦洞沒有 tag 的總數；雜物不算', () async {
      final pit = await db.createPit(name: '坑A', junkEnabled: true);
      final tag = await db.createTag(pit, '角色1');
      await piece(pit, '無 tag 成圖');
      await piece(pit, '有 tag 成圖', tags: [tag]);
      await draft(pit, '無 tag 摸魚');
      await idea(pit, '無 tag 腦洞');
      await idea(pit, '有 tag 腦洞', tags: [tag]);
      await oshi(pit, 1);
      await oshi(pit, 2, tags: [tag]);
      await fan(pit, 2);
      await fan(pit, 1, tags: [tag]);
      await official(pit, 1);
      await official(pit, 1, tags: [tag]);
      // 雜物沒有 tag：再多也不算。
      await db.addJunk(pit, const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
        NewImage(file: 'c.png'),
      ]);

      expect(await db.watchUntaggedCount(pit).first, 1 + 1 + 1 + 1 + 2 + 1);
      final res = await db.watchPitSearch(pit, untagged: true).first;
      expect(res.pieces.total, 1);
      expect(res.drafts.total, 1);
      expect(res.ideas.total, 1);
      expect(res.oshi.total, 1);
      expect(res.fanArts.total, 2);
      expect(res.official.total, 1);
      expect(res.total, 7);
    });

    test('tag 被刪除後，原本只有那顆 tag 的項目算「未加 tag」；其他坑的項目不算', () async {
      final pit = await db.createPit(name: '坑A');
      final other = await db.createPit(name: '坑B');
      final tag = await db.createTag(pit, '角色1');
      await piece(pit, '甲', tags: [tag]);
      await idea(other, '別坑的腦洞');
      expect(await db.watchUntaggedCount(pit).first, 0);
      await db.deleteTag(tag);
      expect(await db.watchUntaggedCount(pit).first, 1);
      expect(await db.watchUntaggedCount(other).first, 1);
    });

    test('已刪除與被移走而隱藏的同人圖不算', () async {
      final pit = await db.createPit(name: '坑A');
      await fan(pit, 2);
      final rows = await db.watchFanArts(pit).first;
      await db.deleteFanArts([rows.first.id]);
      expect(await db.watchUntaggedCount(pit).first, 1);
    });

    test('untagged 可再搭配關鍵字', () async {
      final pit = await db.createPit(name: '坑A');
      final tag = await db.createTag(pit, '夏日');
      await idea(pit, '夏日祭典');
      await idea(pit, '冬天');
      await idea(pit, '夏日海邊', tags: [tag]);
      final res = await db
          .watchPitSearch(pit, untagged: true, text: '夏日')
          .first;
      expect(res.ideas.items.map((e) => e.idea.title), ['夏日祭典']);
    });

    test('混合多選批量補 tag：結果即時少掉那些項目', () async {
      final pit = await db.createPit(name: '坑A');
      final tag = await db.createTag(pit, '角色1');
      final p = await piece(pit, '成圖甲');
      final i = await idea(pit, '腦洞甲');
      final d = await draft(pit, '摸魚甲');
      await idea(pit, '腦洞乙');
      await fan(pit, 1);
      final fanId = (await db.watchFanArts(pit).first).single.id;

      final totals = <int>[];
      final sub = db
          .watchPitSearch(pit, untagged: true)
          .listen((r) => totals.add(r.total));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(totals.last, 5);

      final refs = [
        TagRef(TagTarget.piece, p),
        TagRef(TagTarget.idea, i),
        TagRef(TagTarget.draft, d),
        TagRef(TagTarget.fanArt, fanId),
      ];
      // 三態：都沒有。
      final cov = await db.tagCoverageMixed(refs);
      expect(cov.single.coverage, TagCoverage.none);
      expect(cov.single.total, 4);

      await db.applyBatchTagsMixed(refs, addTagIds: [tag]);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(totals.last, 1); // 只剩「腦洞乙」
      expect(
        (await db.tagCoverageMixed(refs)).single.coverage,
        TagCoverage.all,
      );
      final left = await db.watchPitSearch(pit, untagged: true).first;
      expect(left.ideas.items.map((e) => e.idea.title), ['腦洞乙']);
      await sub.cancel();
    });

    test('混合多選：部分有＝some；新 tag 只建立一次並加到每一個；跨坑選取丟錯', () async {
      final pit = await db.createPit(name: '坑A');
      final other = await db.createPit(name: '坑B');
      final tag = await db.createTag(pit, '角色1');
      final p = await piece(pit, '成圖甲', tags: [tag]);
      final i = await idea(pit, '腦洞甲');
      final refs = [TagRef(TagTarget.piece, p), TagRef(TagTarget.idea, i)];
      expect(
        (await db.tagCoverageMixed(refs)).single.coverage,
        TagCoverage.some,
      );

      await db.applyBatchTagsMixed(refs, newTagNames: ['#新 tag']);
      final tags = await db.watchTags(pit).first;
      expect(tags.where((t) => t.name == '新 tag'), hasLength(1));
      final created = tags.firstWhere((t) => t.name == '新 tag').id;
      expect(await db.watchTagIds(TagTarget.piece, p).first, contains(created));
      expect(await db.watchTagIds(TagTarget.idea, i).first, contains(created));

      final foreign = await idea(other, '別坑');
      expect(
        () => db.applyBatchTagsMixed(
          [TagRef(TagTarget.piece, p), TagRef(TagTarget.idea, foreign)],
          addTagIds: [tag],
        ),
        throwsArgumentError,
      );
    });

    test('單一相冊要全部結果（thumbLimit null），預設每段只回前 3 筆', () async {
      final pit = await db.createPit(name: '坑A');
      final tag = await db.createTag(pit, '角色1');
      for (var i = 0; i < 5; i++) {
        await piece(pit, '成圖$i', tags: [tag]);
      }
      final limited = await db.watchPitSearch(pit, tagId: tag).first;
      expect(limited.pieces.total, 5);
      expect(limited.pieces.items, hasLength(3));
      expect(limited.pieces.more, 2);
      final all = await db
          .watchPitSearch(pit, tagId: tag, thumbLimit: null)
          .first;
      expect(all.pieces.items, hasLength(5));
      expect(all.pieces.more, 0);
    });
  });

  group('全坑搜尋（D-105）資料層', () {
    test('沒輸入時按坑分組：同名 tag 分開、常用在前、沒有 tag 的坑不列、封存坑排最後', () async {
      final a = await db.createPit(name: '坑A');
      final b = await db.createPit(name: '坑B');
      final old = await db.createPit(name: '舊坑');
      await db.createPit(name: '空坑');
      final aTag = await db.createTag(a, '角色1');
      final aTag2 = await db.createTag(a, '夏日');
      final bTag = await db.createTag(b, '角色1');
      final oldTag = await db.createTag(old, '角色1');
      await idea(a, '甲', tags: [aTag, aTag2]);
      await idea(a, '乙', tags: [aTag2]);
      await idea(a, '丙', tags: [aTag2]);
      await idea(b, '丁', tags: [bTag]);
      await idea(old, '戊', tags: [oldTag]);
      await db.setPitStatus(old, PitStatus.archived);

      final groups = await db.watchGlobalTagGroups().first;
      // 封存坑一定在最後；空坑不出現。
      expect(groups.last.pit.id, old);
      expect(groups.map((g) => g.pit.name), isNot(contains('空坑')));
      expect(groups, hasLength(3));
      // 同名 tag 各在自己那組，且是不同的 tag。
      final ga = groups.firstWhere((g) => g.pit.id == a);
      final gb = groups.firstWhere((g) => g.pit.id == b);
      expect(ga.tags.map((u) => u.tag.name), ['夏日', '角色1']); // 夏日用了 3 次
      expect(ga.tags.map((u) => u.count), [3, 1]);
      expect(gb.tags.map((u) => u.tag.name), ['角色1']);
      expect(gb.tags.single.tag.id, isNot(ga.tags.last.tag.id));
      expect(gb.tags.single.count, 1);
    });

    test('輸入文字：範圍含坑名、tag、標題、內文、同人圖作者；筆數多的坑在前', () async {
      final a = await db.createPit(name: '坑A');
      final b = await db.createPit(name: '坑B');
      final tagA = await db.createTag(a, '煙花大會');
      final tagB = await db.createTag(b, '煙花');
      await idea(a, '天台看煙花'); // 標題
      await idea(a, '別的', body: '放煙花的夜晚'); // 內文
      await idea(a, '又一個', tags: [tagA]); // tag
      await fan(a, 1, author: '@煙花太太'); // 作者
      await idea(b, '煙花迷路');
      await idea(b, '無關');
      await draft(b, '無關的摸魚', tags: [tagB]);

      final r = await db.watchGlobalSearch('煙花').first;
      expect(r.pits.map((p) => p.pit.name), ['坑A', '坑B']);
      expect(r.pits[0].total, 4);
      expect(r.pits[1].total, 2); // 標題＋tag 命中的摸魚
      // tag：同名規則各自帶坑；坑A 的「煙花大會」與坑B 的「煙花」都列。
      expect(
        [for (final t in r.tags) (t.pit.name, t.tag.name)],
        [('坑A', '煙花大會'), ('坑B', '煙花')],
      );
    });

    test('坑名也是搜尋範圍；結果依筆數排序，同筆數維持主頁順序', () async {
      final a = await db.createPit(name: '星之彼端');
      final b = await db.createPit(name: '夏日偵探社');
      await idea(a, '甲');
      await idea(b, '乙');
      await idea(b, '丙');
      final byName = await db.watchGlobalSearch('偵探').first;
      expect(byName.pits.map((p) => p.pit.name), ['夏日偵探社']);
      expect(byName.pits.single.total, 2);
      // 坑名＋內容的組合：每個詞都要符合。
      final combo = await db.watchGlobalSearch('偵探 乙').first;
      expect(combo.pits.single.result.ideas.items.map((e) => e.idea.title), [
        '乙',
      ]);
      expect((await db.watchGlobalSearch('找不到').first).isEmpty, isTrue);
      expect((await db.watchGlobalSearch('   ').first).isEmpty, isTrue);
    });

    test('每坑圖片類只回前 3 筆，總數照實計算', () async {
      final a = await db.createPit(name: '坑A');
      for (var i = 0; i < 5; i++) {
        await piece(a, '煙花成圖$i');
      }
      final r = await db.watchGlobalSearch('煙花').first;
      expect(r.pits.single.result.pieces.items, hasLength(3));
      expect(r.pits.single.total, 5);
    });
  });

  // ======================================================================
  // 畫面
  // ======================================================================
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> back(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await settle(tester);
  }

  final mainSearch = find.byKey(const ValueKey('mainSearchButton'));

  group('主頁（D-105）', () {
    testWidgets('右上是搜尋鍵（三個分頁都有），沒有田字／瀑布切換；點了進全坑搜尋並隱藏導覽列', (tester) async {
      await tester.runAsync(() async {
        await db.createPit(name: '坑A');
        await db.createPit(
          name: '淺坑甲',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official},
        );
        final old = await db.createPit(name: '舊坑');
        await db.setPitStatus(old, PitStatus.archived);
      });
      await pumpApp(tester);
      expect(find.bySemanticsLabel('田字檢視'), findsNothing);
      expect(find.bySemanticsLabel('瀑布檢視'), findsNothing);
      for (final tab in ['現坑', '淺坑', '封存坑']) {
        await tester.tap(find.text(tab));
        await settle(tester);
        expect(mainSearch, findsOneWidget, reason: tab);
      }
      // 42px 方塊。
      expect(tester.getSize(mainSearch), const Size(42, 42));
      await tester.tap(mainSearch);
      await settle(tester);
      expect(find.byType(GlobalSearchPage), findsOneWidget);
      expect(find.text('目標'), findsNothing);
      expect(find.text('搜尋全部坑'), findsOneWidget); // 輸入框的 hint
      await back(tester);
      expect(find.text('目標'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('完全沒有坑（MainEmpty）不放搜尋鍵', (tester) async {
      await pumpApp(tester);
      expect(mainSearch, findsNothing);
      await unmount(tester);
    });
  });

  group('全坑搜尋頁（GlobalSearch／GlobalSearchResult）', () {
    testWidgets('沒輸入：按坑分組的常用 tag，同名 tag 分開；點 tag 進該坑的搜尋結果並帶上它', (tester) async {
      late String a, b, tagA, tagB;
      await tester.runAsync(() async {
        a = await db.createPit(name: '坑A');
        b = await db.createPit(name: '坑B');
        tagA = await db.createTag(a, '角色1');
        tagB = await db.createTag(b, '角色1');
        await idea(a, '坑A的腦洞', tags: [tagA]);
        await idea(a, '坑A的腦洞二', tags: [tagA]);
        await idea(b, '坑B的腦洞', tags: [tagB]);
      });
      await pumpPage(tester, const GlobalSearchPage());
      expect(find.byKey(ValueKey('globalTagGroup-$a')), findsOneWidget);
      expect(find.byKey(ValueKey('globalTagGroup-$b')), findsOneWidget);
      // 兩顆「#角色1」是兩個不同的 tag，次數各自計算。
      expect(find.byKey(ValueKey('globalTag-$tagA')), findsOneWidget);
      expect(find.byKey(ValueKey('globalTag-$tagB')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('globalTag-$tagA')),
          matching: find.textContaining('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey('globalTag-$tagB')),
          matching: find.textContaining('1'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('globalTag-$tagB')));
      await settle(tester);
      expect(find.byType(PitSearchResultPage), findsOneWidget);
      expect(find.byType(TagFilterPill), findsOneWidget);
      // 只列坑B 的內容。
      expect(find.text('坑B的腦洞'), findsOneWidget);
      expect(find.text('坑A的腦洞'), findsNothing);
      expect(find.textContaining(RegExp(r'^全部 \d+$')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('輸入文字：符合的 tag（右邊小標坑名）→ 依筆數分組的內容；點組標題進該坑搜尋並帶關鍵字', (
      tester,
    ) async {
      late String a, b;
      await tester.runAsync(() async {
        a = await db.createPit(name: '坑A');
        b = await db.createPit(name: '坑B');
        final tagA = await db.createTag(a, '煙花大會');
        final tagB = await db.createTag(b, '煙花');
        await idea(a, '天台看煙花', body: '兩人偷偷溜上天台', tags: [tagA]);
        await piece(a, '煙花成圖');
        await piece(a, '煙花成圖二');
        await idea(b, '煙火大會迷路');
        await draft(b, '煙花草稿', tags: [tagB]);
        await idea(b, '無關');
      });
      await pumpPage(tester, const GlobalSearchPage());
      await tester.enterText(find.byType(TextField), '煙花');
      await settle(tester);

      // tag：#煙花大會｜坑A、#煙花｜坑B。
      expect(find.text('#煙花大會'), findsOneWidget);
      expect(find.text('#煙花'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlobalSearchPage),
          matching: find.text('坑A'),
        ),
        findsWidgets,
      );
      // 坑A（3 筆：2 成圖＋1 腦洞）排在坑B（1 筆）前面。
      double y(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('globalPit-$id'))).dy;
      expect(y(a) < y(b), isTrue);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('天台看煙花'), findsOneWidget); // 腦洞用文字卡
      expect(find.text('無關'), findsNothing);

      // 點組標題＝進該坑的坑內搜尋，帶著同一個關鍵字。
      await tester.tap(find.text('3'));
      await settle(tester);
      expect(find.byType(PitSearchResultPage), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '煙花');
      expect(find.text('天台看煙花'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('沒有符合的內容：顯示「沒有找到符合的內容」', (tester) async {
      await tester.runAsync(() async {
        final a = await db.createPit(name: '坑A');
        await idea(a, '甲');
      });
      await pumpPage(tester, const GlobalSearchPage());
      await tester.enterText(find.byType(TextField), '不存在的關鍵字');
      await settle(tester);
      expect(find.text('沒有找到符合的內容'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('圖片類合成一排 3 格，第 3 格是「+N」，點它進該坑的坑內搜尋', (tester) async {
      late String a;
      await tester.runAsync(() async {
        a = await db.createPit(name: '坑A');
        for (var i = 0; i < 5; i++) {
          await piece(a, '煙花成圖$i');
        }
      });
      await pumpPage(tester, const GlobalSearchPage());
      await tester.enterText(find.byType(TextField), '煙花');
      await settle(tester);
      expect(find.byType(Image), findsNWidgets(3));
      expect(find.text('+2'), findsOneWidget);
      await tester.tap(find.text('+2'));
      await settle(tester);
      expect(find.byType(PitSearchResultPage), findsOneWidget);
      expect(find.text('成圖  5'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('PitSearch 的「未加 tag」（D-108）', () {
    testWidgets('卡片顯示數量；點進去搜尋列是灰色「未加 tag ×」，pills 只列有結果的', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A', junkEnabled: true);
        final tag = await db.createTag(pit, '角色1');
        await piece(pit, '無 tag 成圖');
        await draft(pit, '無 tag 摸魚');
        await draft(pit, '無 tag 摸魚二');
        await idea(pit, '有 tag 腦洞', tags: [tag]);
        await db.addJunk(pit, const [NewImage(file: 'a.png')]);
      });
      await pumpPage(tester, PitSearchPage(pitId: pit));
      expect(find.byKey(const ValueKey('searchUntaggedCard')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('searchUntaggedCount')))
            .data,
        '3', // 成圖 1＋摸魚 2；腦洞有 tag、雜物不算
      );
      await tester.tap(find.byKey(const ValueKey('searchUntaggedCard')));
      await settle(tester);

      expect(find.byType(PitSearchResultPage), findsOneWidget);
      expect(find.byType(UntaggedFilterPill), findsOneWidget);
      expect(find.byType(TagFilterPill), findsNothing);
      // 灰色（和主色的 tag chip 區分）。
      final pillBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(UntaggedFilterPill),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (pillBox.decoration as BoxDecoration).color,
        UntaggedFilterPill.color,
      );
      // 只列有結果的相冊。
      expect(find.text('全部 3'), findsOneWidget);
      expect(find.text('成圖 1'), findsOneWidget);
      expect(find.text('摸魚 2'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^腦洞')), findsNothing);
      expect(find.textContaining(RegExp(r'^官方圖 ')), findsNothing);
      expect(find.text('有 tag 腦洞'), findsNothing);
      expect(find.byType(Image), findsNWidgets(3));
      await unmount(tester);
    });

    testWidgets('按灰色 chip 的 ×：沒有別的條件就回到 PitSearch', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A');
        await idea(pit, '腦洞');
      });
      await pumpPage(tester, PitSearchPage(pitId: pit));
      await tester.tap(find.byKey(const ValueKey('searchUntaggedCard')));
      await settle(tester);
      expect(find.byType(UntaggedFilterPill), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('移除篩選'));
      await settle(tester);
      expect(find.byType(PitSearchResultPage), findsNothing);
      expect(find.byType(PitSearchPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('長按多選 → 底部 tag 批量補 tag → 補完的項目即時從結果消失、數字減少', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A');
        await db.createTag(pit, '角色1');
        await piece(pit, '成圖甲');
        await piece(pit, '成圖乙');
        await draft(pit, '摸魚甲');
        await idea(pit, '腦洞甲');
        await idea(pit, '腦洞乙');
      });
      await pumpPage(tester, PitSearchResultPage(pitId: pit, untagged: true));
      expect(find.text('全部 5'), findsOneWidget);
      expect(find.text('成圖 2'), findsOneWidget);
      expect(find.text('腦洞  2'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3)); // 成圖 2＋摸魚 1

      // 長按第一張成圖進入多選；再點一則腦洞卡加選。
      await tester.longPress(find.byType(Image).first);
      await settle(tester);
      expect(find.text('已選 1 筆'), findsOneWidget);
      expect(find.byKey(const ValueKey('searchSelectTag')), findsOneWidget);
      await tester.tap(find.text('腦洞甲'));
      await settle(tester);
      expect(find.text('已選 2 筆'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('searchSelectTag')));
      await settle(tester);
      // sheet 裡坑內的 tag：都沒有。
      await tester.tap(find.byKey(const ValueKey('batchTag-角色1-none')));
      await settle(tester);
      await tester.tap(find.text('完成').last);
      await settle(tester);

      // 離開多選；補了 tag 的兩筆從「未加 tag」結果消失，數字減少。
      expect(find.text('已選 2 筆'), findsNothing);
      expect(find.text('全部 3'), findsOneWidget);
      expect(find.text('腦洞  1'), findsOneWidget);
      expect(find.text('腦洞甲'), findsNothing);
      expect(find.text('腦洞乙'), findsOneWidget);
      expect(find.text('成圖 1'), findsOneWidget);
      // 資料庫裡真的有 tag。
      await tester.runAsync(() async {
        expect(await db.watchUntaggedCount(pit).first, 3);
        final tags = await db.watchTags(pit).first;
        final res = await db.watchPitSearch(pit, tagId: tags.single.id).first;
        expect(res.total, 2);
      });
      await unmount(tester);
    });

    testWidgets('多選時按返回先離開多選；全部補完後出現「沒有找到符合的內容」', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A');
        await db.createTag(pit, '角色1');
        await idea(pit, '腦洞甲');
      });
      await pumpPage(tester, PitSearchResultPage(pitId: pit, untagged: true));
      await tester.longPress(find.text('腦洞甲'));
      await settle(tester);
      expect(find.text('已選 1 筆'), findsOneWidget);
      // 系統返回：先離開多選，頁面還在。
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('已選 1 筆'), findsNothing);
      expect(find.byType(PitSearchResultPage), findsOneWidget);

      await tester.longPress(find.text('腦洞甲'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('searchSelectTag')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('batchTag-角色1-none')));
      await settle(tester);
      await tester.tap(find.text('完成').last);
      await settle(tester);
      expect(find.text('沒有找到符合的內容'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('單一相冊（PitSearchResultTab，D-107）', () {
    testWidgets('圖片類＝九宮格：貼邊、間距 2px；點 pill 切換、點「全部」回總覽', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A');
        final tag = await db.createTag(pit, '角色1');
        for (var i = 0; i < 7; i++) {
          await piece(pit, '成圖$i', tags: [tag]);
        }
        await idea(pit, '腦洞甲', tags: [tag]);
      });
      final tag = (await tester.runAsync(() => db.watchTags(pit).first))!
          .single;
      await pumpPage(tester, PitSearchResultPage(pitId: pit, tagId: tag.id));
      expect(find.text('+4'), findsOneWidget); // 7 筆＝3 格＋4
      await tester.tap(find.text('成圖 7'));
      await settle(tester);

      expect(find.byType(PitSearchResultTab), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(7));
      final grid = find.byKey(const ValueKey('searchTabGrid'));
      final gridRect = tester.getRect(grid);
      final screenW =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(gridRect.left, 0); // 貼邊
      expect(gridRect.width, closeTo(screenW, 0.01));
      final r0 = tester.getRect(find.byType(Image).at(0));
      final r1 = tester.getRect(find.byType(Image).at(1));
      expect(r0.left, 0);
      expect(r1.left - r0.right, closeTo(2, 0.01));
      expect(r0.width, closeTo(r0.height, 0.01));
      expect(find.text('+4'), findsNothing);

      // 選腦洞 pill：文字卡。
      await tester.tap(find.text('腦洞 1'));
      await settle(tester);
      expect(find.byKey(const ValueKey('searchTabIdeas')), findsOneWidget);
      expect(find.text('腦洞甲'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await tester.tap(find.text('全部 8'));
      await settle(tester);
      expect(find.byType(PitSearchResultTab), findsNothing);
      await unmount(tester);
    });

    testWidgets('不在長按多選：一般搜尋結果長按沒有反應', (tester) async {
      late String pit;
      await tester.runAsync(() async {
        pit = await db.createPit(name: '坑A');
        final tag = await db.createTag(pit, '角色1');
        await piece(pit, '成圖甲', tags: [tag]);
      });
      final tag = (await tester.runAsync(() => db.watchTags(pit).first))!
          .single;
      await pumpPage(tester, PitSearchResultPage(pitId: pit, tagId: tag.id));
      await tester.longPress(find.byType(Image).first);
      await settle(tester);
      expect(find.byKey(const ValueKey('searchSelectTag')), findsNothing);
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
