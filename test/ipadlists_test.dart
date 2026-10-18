import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_detail_page.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_detail_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/junk/junk_list_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// IPADLISTS：六個分區列表在 390×844、834×1194、1194×834、1366×1024 的版面與狀態保留。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const phone = Size(390, 844);
  const portrait = Size(834, 1194);
  const land = Size(1194, 834);
  const big = Size(1366, 1024);

  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late String ideaId;
  late String draftId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipadlists');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png', 'd.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '坑A');
    final official = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, official.first.id, const [
      NewImage(file: 'a.png', width: 100, height: 200),
      NewImage(file: 'b.png', width: 300, height: 100),
      NewImage(file: 'c.png', width: 100, height: 100),
    ]);
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    await db.addFanArts(
      pitId,
      const [
        NewImage(file: 'a.png', width: 100, height: 200),
        NewImage(file: 'b.png', width: 300, height: 100),
        NewImage(file: 'c.png', width: 100, height: 100),
      ],
      author: '@作者甲',
      groupId: fan.first.id,
    );
    draftId = await db.saveDraft(
      pitId: pitId,
      title: '構圖草稿',
      body: '嘗試兩個側面的角度',
      images: const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
      ],
      tagIds: const [],
      ideaIds: const [],
    );
    await db.saveDraft(
      pitId: pitId,
      images: const [NewImage(file: 'c.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    ideaId = await db.saveIdea(
      pitId: pitId,
      title: '天台看煙花',
      body: '兩人在夏日祭典結束後偷偷溜上天台',
      images: const [NewImage(file: 'a.png')],
      tagIds: const [],
      draftIds: [draftId],
      pieceIds: const [],
    );
    await db.saveIdea(
      pitId: pitId,
      title: '貓咪擬人',
      body: '如果他們變成貓',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    for (var i = 0; i < 3; i++) {
      await db.savePiece(
        pitId: pitId,
        title: '成圖$i',
        body: '',
        images: const [NewImage(file: 'a.png', width: 100, height: 100)],
        tagIds: const [],
        links: const [SocialLink('推特', 'https://x.com/a')],
        targetLikes: 100,
        isPublished: true,
        finishedAt: DateTime(2026, 9, 10 + i),
        ideaIds: [ideaId],
        draftIds: const [],
      );
    }
    await db.addJunk(pitId, const [
      NewImage(file: 'a.png'),
      NewImage(file: 'b.png'),
      NewImage(file: 'c.png'),
    ]);
    final oshi = await db.watchGroups(pitId, kind: 'oshi').first;
    // 三個月、共 12 筆，讓時間軸有東西可以捲、可以跳月份。
    for (var i = 0; i < 12; i++) {
      await db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 8 + i ~/ 4, 1 + i),
        title: '紀錄$i',
        description: i.isEven ? '內文甲' : '內文乙',
        groupId: i < 6 ? oshi.first.id : null,
        images: const [NewImage(file: 'a.png')],
      );
    }
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
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pump();
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> show(WidgetTester tester, Widget page, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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
          // 模擬 IPADNAV 的左側 icon rail（84）：≥600 時列表只佔剩下的寬度。
          home: size.width >= 600
              ? Row(
                  children: [
                    const SizedBox(width: 84),
                    Expanded(child: page),
                  ],
                )
              : page,
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

  final sizes = {
    '390×844': phone,
    '834×1194': portrait,
    '1194×834': land,
    '1366×1024': big,
  };

  final pages = <String, Widget Function()>{
    'OfficialListPage': () => OfficialListPage(pitId: pitId),
    'FanArtListPage': () => FanArtListPage(pitId: pitId),
    'JunkListPage': () => JunkListPage(pitId: pitId),
    'IdeaListPage': () => IdeaListPage(pitId: pitId),
    'DraftListPage': () => DraftListPage(pitId: pitId),
    'FinishedListPage': () => FinishedListPage(pitId: pitId),
    'OshiListPage': () => OshiListPage(pitId: pitId),
  };

  for (final p in pages.entries) {
    for (final s in sizes.entries) {
      testWidgets('${p.key}：${s.key} 沒有例外', (tester) async {
        await show(tester, p.value(), s.value);
        await unmount(tester);
      });
    }
  }

  int masonryCols(WidgetTester tester) {
    final w = tester.widget<MasonryGridView>(find.byType(MasonryGridView));
    final d = w.gridDelegate as SliverSimpleGridDelegateWithFixedCrossAxisCount;
    return d.crossAxisCount;
  }

  Finder firstThumb() => find
      .descendant(
        of: find.byType(MasonryGridView),
        matching: find.byType(GestureDetector),
      )
      .first;

  group('官方圖冊／好看同人圖', () {
    testWidgets('欄數：手機 2、直向 3 以上、橫向 3、1366 為 4（逐格增減）', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), phone);
      expect(masonryCols(tester), 2);
      await unmount(tester);
      await show(tester, OfficialListPage(pitId: pitId), land);
      expect(masonryCols(tester), 3);
      await unmount(tester);
      await show(tester, OfficialListPage(pitId: pitId), big);
      expect(masonryCols(tester), 4);
      await unmount(tester);
    });

    testWidgets('寬版：沒選時顯示提示；點圖後右側面板出現（官方多分享）', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ipadListsPreviewEmpty), findsOneWidget);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.text(l.ipadListsPreviewEmpty), findsNothing);
      expect(find.text(l.ipadListsReferenceView), findsOneWidget);
      expect(find.text(l.commonShare), findsOneWidget);
      expect(find.text(l.albumSetCover), findsOneWidget);
      expect(find.byType(ImagePreviewPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('同人圖面板：作者、沒有分享鈕；參考檢視入口開參考圖檢視（不是手機預覽）', (tester) async {
      await show(tester, FanArtListPage(pitId: pitId), big);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(firstThumb());
      await settle(tester);
      // 面板上的作者（列表下方也有作者字，所以至少兩處）。
      expect(find.text('@作者甲'), findsAtLeastNWidgets(2));
      expect(find.text(l.commonShare), findsNothing);
      await tester.tap(find.text(l.ipadListsReferenceView));
      await settle(tester);
      expect(find.byType(ReferenceViewerPage), findsOneWidget);
      expect(find.byType(FanArtPreviewPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('拉窗：選中的圖在窄視窗保留，拉回來面板還原', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.text(l.ipadListsReferenceView), findsOneWidget);
      await resize(tester, phone);
      expect(find.text(l.ipadListsReferenceView), findsNothing);
      await resize(tester, land);
      expect(find.text(l.ipadListsReferenceView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('834 寬（medium）：點圖彈出底部 sheet，不進全螢幕預覽', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), portrait);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text(l.ipadListsReferenceView), findsOneWidget);
      expect(find.byType(ImagePreviewPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('手機：點圖照舊進全螢幕預覽', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), phone);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.byType(ImagePreviewPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('寬版：多選鈕進入多選，點圖切換選取，面板收起', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.bySemanticsLabel(l.ipadListsMultiSelect));
      await settle(tester);
      expect(find.text(l.commonDownload), findsOneWidget);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.text(l.commonSelectedCount(1)), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('寬版：長按拖曳多選仍可用', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.longPress(firstThumb());
      await settle(tester);
      expect(find.text(l.commonSelectedCount(1)), findsOneWidget);
      await unmount(tester);
    });
  });

  group('我的腦洞', () {
    testWidgets('寬版：並排，點卡片右側出現詳情與「從這個腦洞開摸魚」', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ipadListsIdeaEmpty), findsOneWidget);
      await tester.tap(find.text('天台看煙花'));
      await settle(tester);
      expect(find.text(l.ipadListsStartDraftFromIdea), findsOneWidget);
      expect(find.text(l.ipadListsIdeaFlow), findsOneWidget);
      expect(find.byType(IdeaDetailPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('寬版有狀態篩選；手機沒有', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ideaStatusOpen), findsWidgets);
      await tester.tap(find.text(l.ideaStatusOpen).first);
      await settle(tester);
      expect(find.text('天台看煙花'), findsNothing);
      expect(find.text('貓咪擬人'), findsOneWidget);
      await resize(tester, phone);
      // 篩選只在並排時套用：窄視窗回到完整列表。
      expect(find.text('天台看煙花'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('選中後拉窄＝停在詳情頁；拉回寬＝退回並排且仍選中', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.text('天台看煙花'));
      await settle(tester);
      await resize(tester, phone);
      expect(find.byType(IdeaDetailPage), findsOneWidget);
      await resize(tester, land);
      await settle(tester);
      expect(find.byType(IdeaDetailPage), findsNothing);
      expect(find.text(l.ipadListsStartDraftFromIdea), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('沒有選中就拉窄：維持列表', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      await resize(tester, phone);
      expect(find.byType(IdeaDetailPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('手機：點卡片照舊進詳情頁', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), phone);
      await tester.tap(find.text('天台看煙花'));
      await settle(tester);
      expect(find.byType(IdeaDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('834 寬（medium）：分兩頁', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), portrait);
      await tester.tap(find.text('天台看煙花'));
      await settle(tester);
      expect(find.byType(IdeaDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('寬版長按仍可多選', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      await tester.longPress(find.text('天台看煙花'));
      await settle(tester);
      expect(navBarHiddenCount.value, 1);
      await unmount(tester);
    });
  });

  group('我的摸魚', () {
    testWidgets('寬版：並排；點列後詳情顯示標題、頁碼與縮圖欄', (tester) async {
      await show(tester, DraftListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ipadListsDraftEmpty), findsOneWidget);
      await tester.tap(find.text('構圖草稿').first);
      await settle(tester);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.bySemanticsLabel(l.ipadListsDraftImageN(2)), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(l.ipadListsDraftImageN(2)));
      await settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.byType(DraftDetailPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('選中後拉窄＝詳情頁；拉回寬＝還原', (tester) async {
      await show(tester, DraftListPage(pitId: pitId), land);
      await tester.tap(find.text('構圖草稿').first);
      await settle(tester);
      await resize(tester, phone);
      expect(find.byType(DraftDetailPage), findsOneWidget);
      await resize(tester, big);
      await settle(tester);
      expect(find.byType(DraftDetailPage), findsNothing);
      expect(find.text('1 / 2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機：九宮格切換仍在；寬版沒有', (tester) async {
      await show(tester, DraftListPage(pitId: pitId), phone);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.bySemanticsLabel(l.pieceViewNine), findsOneWidget);
      await resize(tester, land);
      expect(find.bySemanticsLabel(l.pieceViewNine), findsNothing);
      await unmount(tester);
    });
  });

  group('我的成圖', () {
    testWidgets('寬版：欄數 3，點成圖右側詳情面板出現互動量與關聯腦洞', (tester) async {
      await show(tester, FinishedListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(masonryCols(tester), 3);
      expect(find.text(l.ipadListsPieceEmpty), findsOneWidget);
      await tester.tap(find.text('成圖0').first);
      await settle(tester);
      expect(find.text(l.pieceFormSocialLinks), findsOneWidget);
      expect(find.text(l.ideaLinkedHeading), findsOneWidget);
      expect(find.text('天台看煙花'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機：2 欄；寬版切九宮格＝5 欄', (tester) async {
      await show(tester, FinishedListPage(pitId: pitId), phone);
      expect(masonryCols(tester), 2);
      await unmount(tester);
      await show(tester, FinishedListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.bySemanticsLabel(l.pieceViewNine));
      await settle(tester);
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      final d = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(d.crossAxisCount, 5);
      await unmount(tester);
    });

    testWidgets('拉窗：選中的成圖與版面模式保留', (tester) async {
      await show(tester, FinishedListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.bySemanticsLabel(l.pieceViewNine));
      await settle(tester);
      await tester.tap(find.byType(GridView).first.hitTestable());
      await resize(tester, phone);
      await resize(tester, land);
      expect(find.byType(GridView), findsWidgets);
      await unmount(tester);
    });
  });

  group('推活', () {
    testWidgets('寬版：右側篩選面板（搜尋、分組、跳到月份）', (tester) async {
      await show(tester, OshiListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ipadListsOshiJumpToMonth), findsOneWidget);
      expect(find.text(l.albumGroupLabel), findsOneWidget);
      expect(find.text(l.commonManage), findsOneWidget);
      // 有分組也有沒分組的紀錄：「無分組」列出現（既有規則）。
      expect(find.text(l.oshiPillUngrouped), findsOneWidget);
      await resize(tester, phone);
      expect(find.text(l.ipadListsOshiJumpToMonth), findsNothing);
      await unmount(tester);
    });

    testWidgets('寬版搜尋篩掉不符合的紀錄；窄視窗保留輸入', (tester) async {
      await show(tester, OshiListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text('紀錄11'), findsOneWidget);
      await tester.enterText(
        find.bySemanticsLabel(l.ipadListsOshiSearchLabel).hitTestable(),
        '紀錄0',
      );
      await settle(tester);
      Finder rec(String t) =>
          find.byWidgetPredicate((w) => w is Text && w.data == t);
      expect(find.text('紀錄11'), findsNothing);
      expect(rec('紀錄0'), findsOneWidget);
      // 窄視窗：篩選暫停（面板不在），拉回寬版仍套用。
      await resize(tester, phone);
      expect(rec('紀錄11'), findsOneWidget);
      await resize(tester, land);
      expect(find.text('紀錄11'), findsNothing);
      expect(rec('紀錄0'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('寬版：點分組列篩選', (tester) async {
      await show(tester, OshiListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.text(l.oshiPillUngrouped));
      await settle(tester);
      expect(find.text('紀錄11'), findsOneWidget);
      expect(find.text('紀錄0'), findsNothing);
      await unmount(tester);
    });

    testWidgets('跳到月份：時間軸捲到該月標題', (tester) async {
      await show(tester, OshiListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.oshiMonthHeader(2026, 8)), findsNothing);
      await tester.tap(find.text(l.ipadListsMonthShort(8)));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.oshiMonthHeader(2026, 8)), findsWidgets);
      await unmount(tester);
    });

    testWidgets('手機：沒有面板，分組 pills 照舊', (tester) async {
      await show(tester, OshiListPage(pitId: pitId), phone);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.text(l.ipadListsOshiJumpToMonth), findsNothing);
      expect(find.text(l.oshiPillUngrouped), findsOneWidget);
      await unmount(tester);
    });
  });

  group('雜物', () {
    testWidgets('九宮格：手機 3 欄，平板逐格增加', (tester) async {
      int cols() {
        final g = tester.widget<GridView>(find.byType(GridView));
        return (g.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;
      }

      await show(tester, JunkListPage(pitId: pitId), phone);
      expect(cols(), 3);
      await unmount(tester);
      await show(tester, JunkListPage(pitId: pitId), land);
      expect(cols(), greaterThan(4));
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
