import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_actions.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/album/fan_art_edit_page.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/group_manage_page.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/ui/album/move_sheet.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/album/tag_batch_sheet.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/search/filter_pills.dart';
import 'package:huakeng/ui/search/pit_search_result_page.dart';
import 'package:huakeng/ui/junk/junk_list_page.dart';
import 'package:image_picker/image_picker.dart';

/// 圖冊區塊的 UI 行為：導覽列顯示規則、移動 sheet、雜物、同人圖預覽、表單的「×」。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('album_ui');
    pitId = await db.createPit(name: '測試坑');
    await Directory('${tmp.path}/images').create(recursive: true);
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${tmp.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    File('${tmp.path}/pick.png').writeAsBytesSync(_png1x1);
  });

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${tmp.path}/images')),
    ),
    imagePickerProvider.overrideWithValue(
      (_) async => [XFile('${tmp.path}/pick.png')],
    ),
  ];

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
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

  /// 直接顯示某個頁面（用在還沒有入口的頁面，或不需要整個 App 的情況）。
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.light,
  }) async {
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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

  Future<void> seedOfficial(int n) async {
    final g = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(pitId, g.id, [
      for (var i = 0; i < n; i++)
        NewImage(
          file: ['a.png', 'b.png', 'c.png'][i % 3],
          width: 10,
          height: 10,
        ),
    ]);
  }

  testWidgets('下載存到固定英文名稱的相簿 Drawer', (tester) async {
    expect(downloadAlbumName, 'Drawer');
  });

  testWidgets('官方圖冊：多選隱藏導覽列，底部是 下載／移動／tag／刪除；移動到好看同人圖', (tester) async {
    await tester.runAsync(() => seedOfficial(2));
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('官方圖冊'));
    await settle(tester);
    expect(find.text('時間軸'), findsOneWidget); // 瀏覽時有導覽列

    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    expect(find.text('已選 1 張'), findsOneWidget);
    expect(find.text('時間軸'), findsNothing); // 多選沒有導覽列
    expect(find.text('下載'), findsOneWidget);
    expect(find.text('移動'), findsOneWidget);
    expect(find.text('tag'), findsOneWidget);
    expect(find.text('刪除'), findsOneWidget);
    expect(find.text('分組'), findsNothing);
    expect(find.text('分享'), findsNothing); // 分享只有雜物

    await tester.tap(find.text('移動'));
    await settle(tester);
    expect(find.text('移動到'), findsOneWidget);
    expect(find.text('好看同人圖'), findsWidgets);
    // 雜物沒開啟就不列出。
    expect(
      find.descendant(of: find.byType(MoveSheet), matching: find.text('雜物')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(of: find.byType(MoveSheet), matching: find.text('好看同人圖')),
    );
    await settle(tester);
    await tester.tap(find.text('完成'));
    await settle(tester);

    final official = await tester.runAsync(() => db.watchOfficial(pitId).first);
    final fan = await tester.runAsync(() => db.watchFanArts(pitId).first);
    expect(official!.length, 1);
    expect(fan!.length, 1);
    expect(find.text('時間軸'), findsOneWidget); // 結束多選後導覽列回來
    await unmount(tester);
  });

  testWidgets('移動 sheet：官方圖冊內換分組（展開分組 chips）', (tester) async {
    await tester.runAsync(() => seedOfficial(1));
    final groups = await tester.runAsync(() => db.watchGroups(pitId).first);
    await pumpApp(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('官方圖冊'));
    await settle(tester);
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.text('移動'));
    await settle(tester);

    final second = groups![1];
    await tester.tap(
      find.descendant(
        of: find.byType(MoveSheet),
        matching: find.text(second.name),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('完成'));
    await settle(tester);
    final rows = await tester.runAsync(() => db.watchOfficial(pitId).first);
    expect(rows!.single.groupId, second.id);
    await unmount(tester);
  });

  testWidgets('雜物：3 欄純圖、長按多選 分享／下載／移動／刪除、移動到官方圖冊', (tester) async {
    await tester.runAsync(() async {
      await db.updatePit(
        pitId,
        name: '測試坑',
        archived: false,
        junkEnabled: true,
      );
      await db.addJunk(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
        NewImage(file: 'b.png', width: 10, height: 10),
        NewImage(file: 'c.png', width: 10, height: 10),
      ]);
    });
    await pumpPage(tester, JunkListPage(pitId: pitId));
    expect(find.text('測試坑 · 雜物'), findsOneWidget);
    expect(find.text('3 張'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(navBarHiddenCount.value, 0); // 瀏覽時有導覽列

    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    expect(find.text('已選 1 張'), findsOneWidget);
    expect(navBarHiddenCount.value, 1); // 多選隱藏導覽列
    for (final s in ['分享', '下載', '移動', '刪除']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('移動'));
    await settle(tester);
    // 從雜物移動：三格都列出，目前所在的雜物預選。
    for (final s in ['官方圖冊', '好看同人圖', '雜物']) {
      expect(
        find.descendant(of: find.byType(MoveSheet), matching: find.text(s)),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(of: find.byType(MoveSheet), matching: find.text('官方圖冊')),
    );
    await settle(tester);
    await tester.tap(find.text('完成'));
    await settle(tester);

    final junk = await tester.runAsync(() => db.watchJunk(pitId).first);
    final official = await tester.runAsync(() => db.watchOfficial(pitId).first);
    expect(junk!.length, 2);
    expect(official!.length, 1);
    expect(navBarHiddenCount.value, 0);
    await unmount(tester);
  });

  testWidgets('雜物：空白頁；刪除要確認', (tester) async {
    await pumpPage(tester, JunkListPage(pitId: pitId));
    expect(find.text('還沒有雜物'), findsOneWidget);
    await unmount(tester);

    await tester.runAsync(
      () => db.addJunk(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
      ]),
    );
    await pumpPage(tester, JunkListPage(pitId: pitId));
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.text('刪除'));
    await settle(tester);
    expect(find.text('刪除 1 張圖？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '刪除'));
    await settle(tester);
    final junk = await tester.runAsync(() => db.watchJunk(pitId).first);
    expect(junk, isEmpty);
    await unmount(tester);
  });

  testWidgets('同人圖預覽：作者、出處、全部 tag（可點）、加入日期；沒有導覽列', (tester) async {
    final tagA = await tester.runAsync(() => db.createTag(pitId, '角色1'));
    final tagB = await tester.runAsync(() => db.createTag(pitId, '夏日企劃'));
    final fanGroup = await tester.runAsync(
      () async => (await db.watchGroups(pitId, kind: 'fan').first).first,
    );
    await tester.runAsync(
      () => db.addFanArts(
        pitId,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        author: '@illust_ka',
        groupId: fanGroup!.id,
        tagIds: [tagA!, tagB!],
      ),
    );
    final row = (await tester.runAsync(() => db.watchFanArts(pitId).first))!
        .single;
    final tapped = <String>[];
    await pumpPage(
      tester,
      FanArtPreviewPage(
        pitId: pitId,
        images: [
          AlbumImage(
            id: row.id,
            file: row.imageFile,
            width: 10,
            height: 10,
            kind: AlbumKind.fanArt,
            author: row.author,
            groupName: fanGroup!.name,
            groupId: row.groupId,
            createdAt: DateTime(2026, 9, 21),
          ),
        ],
        initialIndex: 0,
        onTagTap: tapped.add,
      ),
    );
    expect(find.text('測試坑 · 好看同人圖'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('@illust_ka'), findsOneWidget);
    expect(find.text(fanGroup.name), findsOneWidget);
    expect(find.text('#角色1'), findsOneWidget);
    expect(find.text('#夏日企劃'), findsOneWidget);
    expect(find.text('2026 / 09 / 21 加入'), findsOneWidget);
    for (final s in ['分享', '下載', '設為封面', '編輯', '刪除']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(navBarHiddenCount.value, 1);

    await tester.tap(find.text('#夏日企劃'));
    expect(tapped, [tagB]);

    // 設為封面＝同人圖這一格的封面。
    await tester.tap(find.text('設為封面'));
    await settle(tester);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.fanArtCoverId, row.id);
    await unmount(tester);
    expect(navBarHiddenCount.value, 0);
  });

  testWidgets('同人圖列表：卡片開啟同人圖預覽；預覽裡點 tag 進坑內搜尋結果頁（D-107）', (tester) async {
    final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
    await tester.runAsync(() async {
      await db.addFanArts(
        pitId,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        author: '有 tag',
        tagIds: [tag!],
      );
    });
    await pumpPage(tester, FanArtListPage(pitId: pitId));
    expect(find.text('有 tag'), findsOneWidget);
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.byType(FanArtPreviewPage), findsOneWidget);
    expect(find.text('#角色1'), findsOneWidget);
    expect(navBarHiddenCount.value, 1);
    await tester.tap(find.text('#角色1'));
    await settle(tester);
    expect(find.byType(PitSearchResultPage), findsOneWidget);
    expect(find.byType(TagFilterPill), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('同人圖列表：有出處也有沒出處的圖時，「無出處」pill 出現在最後並可篩選', (tester) async {
    final src = (await tester.runAsync(
      () async => (await db.watchGroups(pitId, kind: 'fan').first).first,
    ))!;
    await tester.runAsync(() async {
      await db.addFanArts(
        pitId,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        author: '有出處',
        groupId: src.id,
      );
      await db.addFanArts(pitId, const [
        NewImage(file: 'b.png', width: 10, height: 10),
      ], author: '沒出處');
    });
    await pumpPage(tester, FanArtListPage(pitId: pitId));
    expect(find.text('無出處'), findsOneWidget);
    await tester.ensureVisible(find.text('無出處'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('無出處')).dx,
      greaterThan(tester.getTopLeft(find.text(src.name).first).dx),
    );
    await tester.tap(find.text('無出處'));
    await settle(tester);
    expect(find.text('沒出處'), findsOneWidget);
    expect(find.text('有出處'), findsNothing);
    await unmount(tester);
  });

  testWidgets('同人圖列表：全都有出處（或全都沒出處）時不顯示「無出處」', (tester) async {
    await tester.runAsync(() async {
      await db.addFanArts(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
      ], author: '沒出處');
    });
    await pumpPage(tester, FanArtListPage(pitId: pitId));
    expect(find.text('無出處'), findsNothing);
    await unmount(tester);
  });

  testWidgets('同人圖列表：無篩選時列出全部；多選一樣是 下載／移動／tag／刪除', (tester) async {
    await tester.runAsync(() async {
      await db.addFanArts(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
        NewImage(file: 'b.png', width: 10, height: 10),
      ], author: '@x');
    });
    await pumpPage(tester, FanArtListPage(pitId: pitId));
    expect(find.text('@x'), findsNWidgets(2));
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    expect(navBarHiddenCount.value, 1);
    for (final s in ['下載', '移動', 'tag', '刪除']) {
      expect(find.text(s), findsOneWidget);
    }
    // 同人圖移到官方圖冊：兩邊的數量都對。
    await tester.tap(find.text('移動'));
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(MoveSheet), matching: find.text('官方圖冊')),
    );
    await settle(tester);
    await tester.tap(find.text('完成'));
    await settle(tester);
    final fan = await tester.runAsync(() => db.watchFanArts(pitId).first);
    final official = await tester.runAsync(() => db.watchOfficial(pitId).first);
    expect(fan!.length, 1);
    expect(official!.length, 1);
    await unmount(tester);
  });

  /// 批次 tag sheet 的 chip（key 帶名稱與狀態）。
  Finder tagChip(String name, TagCoverage state) =>
      find.byKey(ValueKey('batchTag-$name-${state.name}'));

  /// 官方圖冊兩張圖：T1 兩張都有、T2 只有第一張、T3 都沒有。回傳圖片 id 與 tag id。
  Future<({List<String> images, Map<String, String> tags})> seedTagged() async {
    await seedOfficial(2);
    final rows = await db.watchOfficial(pitId).first;
    final t1 = await db.createTag(pitId, 'T1');
    final t2 = await db.createTag(pitId, 'T2');
    final t3 = await db.createTag(pitId, 'T3');
    await db.setOfficialTags(rows[0].id, [t1, t2]);
    await db.setOfficialTags(rows[1].id, [t1]);
    return (
      images: [rows[0].id, rows[1].id],
      tags: {'T1': t1, 'T2': t2, 'T3': t3},
    );
  }

  Future<void> openTagSheet(WidgetTester tester) async {
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.text('全選'));
    await settle(tester);
    await tester.tap(find.text('tag'));
    await settle(tester);
  }

  testWidgets('官方圖冊多選 tag：三種狀態，點一下部分/沒有→全加、全有→全移除，完成才套用', (tester) async {
    final seeded = (await tester.runAsync(seedTagged))!;
    await pumpPage(tester, OfficialListPage(pitId: pitId));
    await openTagSheet(tester);

    expect(find.byType(BatchTagSheet), findsOneWidget);
    expect(find.text('2 張'), findsWidgets);
    // 實色＋勾／虛線框＋橫線／白底。
    expect(tagChip('T1', TagCoverage.all), findsOneWidget);
    expect(tagChip('T2', TagCoverage.some), findsOneWidget);
    expect(tagChip('T3', TagCoverage.none), findsOneWidget);

    await tester.tap(tagChip('T2', TagCoverage.some)); // 部分 → 全加
    await tester.tap(tagChip('T1', TagCoverage.all)); // 全有 → 全移除
    await tester.tap(tagChip('T3', TagCoverage.none)); // 沒有 → 全加
    await settle(tester);
    expect(tagChip('T2', TagCoverage.all), findsOneWidget);
    expect(tagChip('T1', TagCoverage.none), findsOneWidget);
    expect(tagChip('T3', TagCoverage.all), findsOneWidget);
    // 還沒按完成：資料沒有動。
    final before = await tester.runAsync(
      () => db.tagCoverage(AlbumCell.official, seeded.images),
    );
    expect(
      {for (final e in before!) e.tag.name: e.coverage},
      {'T1': TagCoverage.all, 'T2': TagCoverage.some, 'T3': TagCoverage.none},
    );

    await tester.tap(
      find.descendant(
        of: find.byType(BatchTagSheet),
        matching: find.text('完成'),
      ),
    );
    await settle(tester);
    expect(find.byType(BatchTagSheet), findsNothing);
    final after = await tester.runAsync(
      () => db.tagCoverage(AlbumCell.official, seeded.images),
    );
    expect(
      {for (final e in after!) e.tag.name: e.coverage},
      {'T1': TagCoverage.none, 'T2': TagCoverage.all, 'T3': TagCoverage.all},
    );
    // 套用後結束多選，導覽列的規則回到瀏覽狀態。
    expect(navBarHiddenCount.value, 0);
    await unmount(tester);
  });

  testWidgets('批次 tag sheet：點兩下回到原狀；可在 sheet 裡新增 tag；點外面關閉不套用', (tester) async {
    final seeded = (await tester.runAsync(seedTagged))!;
    await pumpPage(tester, OfficialListPage(pitId: pitId));
    await openTagSheet(tester);

    // 部分有 → 全加 → 全移除。
    await tester.tap(tagChip('T2', TagCoverage.some));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(tagChip('T2', TagCoverage.all));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tagChip('T2', TagCoverage.none), findsOneWidget);

    // 就地新增：新 tag 直接是「全部加上」。
    await tester.tap(
      find.descendant(
        of: find.byType(BatchTagSheet),
        matching: find.text('新增'),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField), '#新tag');
    await tester.tap(find.text(l10nStatic.albumConfirm));
    await settle(tester);
    expect(tagChip('新tag', TagCoverage.all), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BatchTagSheet),
        matching: find.text('完成'),
      ),
    );
    await settle(tester);
    final cov = (await tester.runAsync(
      () => db.tagCoverage(AlbumCell.official, seeded.images),
    ))!;
    expect(
      {for (final e in cov) e.tag.name: e.coverage},
      {
        'T1': TagCoverage.all,
        'T2': TagCoverage.none,
        'T3': TagCoverage.none,
        '新tag': TagCoverage.all,
      },
    );

    // 再開一次，改了但點遮罩關閉＝不套用。
    await openTagSheet(tester);
    await tester.tap(tagChip('T3', TagCoverage.none));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(180, 20));
    await settle(tester);
    expect(find.byType(BatchTagSheet), findsNothing);
    final cov2 = (await tester.runAsync(
      () => db.tagCoverage(AlbumCell.official, seeded.images),
    ))!;
    expect(
      cov2.firstWhere((e) => e.tag.name == 'T3').coverage,
      TagCoverage.none,
    );
    await unmount(tester);
  });

  testWidgets('好看同人圖多選也有 tag 按鈕並可批次套用；雜物沒有 tag', (tester) async {
    final tag = (await tester.runAsync(() async {
      await db.addFanArts(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
        NewImage(file: 'b.png', width: 10, height: 10),
      ], author: '@x');
      return db.createTag(pitId, '夏日');
    }))!;
    await pumpPage(tester, FanArtListPage(pitId: pitId));
    await openTagSheet(tester);
    expect(tagChip('夏日', TagCoverage.none), findsOneWidget);
    await tester.tap(tagChip('夏日', TagCoverage.none));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(
      find.descendant(
        of: find.byType(BatchTagSheet),
        matching: find.text('完成'),
      ),
    );
    await settle(tester);
    final rows = (await tester.runAsync(() => db.watchFanArts(pitId).first))!;
    for (final r in rows) {
      final ids = (await tester.runAsync(
        () => db.watchTagIds(TagTarget.fanArt, r.id).first,
      ))!;
      expect(ids, [tag]);
    }
    await unmount(tester);

    await tester.runAsync(
      () => db.addJunk(pitId, const [
        NewImage(file: 'c.png', width: 10, height: 10),
      ]),
    );
    await pumpPage(tester, JunkListPage(pitId: pitId));
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    expect(find.text('tag'), findsNothing);
    for (final s in ['分享', '下載', '移動', '刪除']) {
      expect(find.text(s), findsOneWidget);
    }
    await unmount(tester);
  });

  testWidgets('新增官方圖：已加入的圖片右上角有「×」可移除；表單沒有導覽列', (tester) async {
    await pumpPage(
      tester,
      OfficialNewPage(
        pitId: pitId,
        initialImages: [
          XFile('${tmp.path}/pick.png'),
          XFile('${tmp.path}/pick.png'),
        ],
      ),
    );
    expect(navBarHiddenCount.value, 1);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.bySemanticsLabel('移除圖片'), findsNWidgets(2));
    await tester.tap(find.bySemanticsLabel('移除圖片').first, warnIfMissed: false);
    await settle(tester);
    expect(find.byType(Image), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('編輯同人圖：顯示圖片與「×」，按 × 確認後刪除', (tester) async {
    await tester.runAsync(
      () => db.addFanArts(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
      ], author: '@x'),
    );
    final row = (await tester.runAsync(() => db.watchFanArts(pitId).first))!
        .single;
    await pumpPage(tester, FanArtEditPage(pitId: pitId, imageId: row.id));
    expect(navBarHiddenCount.value, 1);
    expect(find.text('編輯同人圖'), findsOneWidget);
    expect(find.text('出處'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('加圖'), findsNothing); // 單張不能再加
    await tester.tap(find.bySemanticsLabel('移除圖片'), warnIfMissed: false);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, '刪除'));
    await settle(tester);
    final fan = await tester.runAsync(() => db.watchFanArts(pitId).first);
    expect(fan, isEmpty);
    await unmount(tester);
  });

  testWidgets('選擇封面：沒有說明小字、沒有導覽列', (tester) async {
    await tester.runAsync(() => seedOfficial(1));
    await pumpPage(tester, CoverPickPage(pitId: pitId, kind: 'official'));
    expect(find.text('長按中：官方圖冊 封面'), findsOneWidget);
    expect(find.text('選擇封面圖'), findsOneWidget);
    expect(find.textContaining('點選即設為封面'), findsNothing);
    expect(navBarHiddenCount.value, 1);
    await unmount(tester);
  });

  testWidgets('管理分組沒有導覽列；預設沒有「自定義」分組', (tester) async {
    await pumpPage(tester, GroupManagePage(pitId: pitId));
    expect(navBarHiddenCount.value, 1);
    expect(find.text('自定義'), findsNothing);
    expect(find.text('設定圖'), findsOneWidget);
    await unmount(tester);
    expect(navBarHiddenCount.value, 0);
  });

  testWidgets('深色模式與平板寬度：雜物多選、移動 sheet 沒有 layout 例外', (tester) async {
    await tester.runAsync(() async {
      await db.updatePit(
        pitId,
        name: '測試坑',
        archived: false,
        junkEnabled: true,
      );
      await db.addJunk(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
        NewImage(file: 'b.png', width: 10, height: 10),
      ]);
    });
    await pumpPage(
      tester,
      JunkListPage(pitId: pitId),
      brightness: Brightness.dark,
    );
    tester.view.physicalSize = const Size(2400, 1600);
    await tester.pump();
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.text('移動'));
    await settle(tester);
    expect(find.text('移動到'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  /// 從按鈕開啟表單（要有上一頁才能 pop）；results 收 pop 的結果。
  Future<void> openFromHost(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) open,
    List<Object?> results,
  ) async {
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(await open(context)),
          child: const Text('開'),
        ),
      ),
    );
    await tester.tap(find.text('開'));
    await settle(tester);
  }

  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
  }

  testWidgets('D-089 新增官方圖：分組下面有 tag 區（管理、新增），選了 tag 存進圖片', (tester) async {
    final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
    await tester.runAsync(() => db.createTag(pitId, '夏日'));
    await openFromHost(
      tester,
      (c) => openOfficialNew(
        c,
        pitId: pitId,
        initialImages: [XFile('${tmp.path}/pick.png')],
      ),
      [],
    );
    expect(find.text('tag'), findsOneWidget);
    expect(find.text('#角色1'), findsOneWidget);
    expect(find.text('#夏日'), findsOneWidget);
    expect(find.text('管理'), findsNWidgets(2)); // 分組、tag
    // 分組在 tag 之上。
    expect(
      tester.getTopLeft(find.text('分組')).dy <
          tester.getTopLeft(find.text('tag')).dy,
      isTrue,
    );
    await tester.tap(find.text('#角色1'));
    await tester.pump();
    await tester.tap(find.text('加入官方圖冊'));
    await settleLong(tester);
    final rows = (await tester.runAsync(
      () => db.watchOfficial(pitId, tagId: tag).first,
    ))!;
    expect(rows.length, 1);
    await unmount(tester);
  });

  testWidgets('D-089 編輯官方圖：載入分組與 tag，存檔後更新；沒有導覽列', (tester) async {
    final tagA = await tester.runAsync(() => db.createTag(pitId, '角色1'));
    final tagB = await tester.runAsync(() => db.createTag(pitId, '夏日'));
    await tester.runAsync(() => seedOfficial(1));
    final row = (await tester.runAsync(() => db.watchOfficial(pitId).first))!
        .single;
    await tester.runAsync(() => db.setOfficialTags(row.id, [tagA!]));
    await openFromHost(
      tester,
      (c) => openOfficialEdit(c, pitId: pitId, imageId: row.id),
      [],
    );
    expect(navBarHiddenCount.value, 1);
    expect(find.text('編輯官方圖'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('加圖'), findsNothing);
    await tester.tap(find.text('#角色1')); // 取消
    await tester.pump();
    await tester.tap(find.text('#夏日'));
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await settleLong(tester);
    final ids = (await tester.runAsync(
      () => db.watchTagIds(TagTarget.official, row.id).first,
    ))!;
    expect(ids, [tagB]);
    await unmount(tester);
  });

  testWidgets('D-089 編輯官方圖：按 × 確認後刪除並回傳 true', (tester) async {
    await tester.runAsync(() => seedOfficial(1));
    final row = (await tester.runAsync(() => db.watchOfficial(pitId).first))!
        .single;
    bool? result;
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await openOfficialEdit(
            context,
            pitId: pitId,
            imageId: row.id,
          ),
          child: const Text('開'),
        ),
      ),
    );
    await tester.tap(find.text('開'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('移除圖片'), warnIfMissed: false);
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, '刪除'));
    await settle(tester);
    expect(await tester.runAsync(() => db.watchOfficial(pitId).first), isEmpty);
    expect(result, isTrue);
    await unmount(tester);
  });

  testWidgets('D-089 官方圖預覽：分組標籤下是 tag chips，日期在 tag 下面；點 tag 回呼', (
    tester,
  ) async {
    final tagA = await tester.runAsync(() => db.createTag(pitId, '角色1'));
    final tagB = await tester.runAsync(() => db.createTag(pitId, '夏日企劃'));
    await tester.runAsync(() async {
      final g = (await db.watchGroups(pitId).first).first;
      await db.addOfficial(
        pitId,
        g.id,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        tagIds: [tagA!, tagB!],
      );
    });
    final row = (await tester.runAsync(() => db.watchOfficial(pitId).first))!
        .single;
    final group = (await tester.runAsync(
      () async => (await db.watchGroups(pitId).first).first,
    ))!;
    final tapped = <String>[];
    await pumpPage(
      tester,
      ImagePreviewPage(
        pitId: pitId,
        images: [
          AlbumImage(
            id: row.id,
            file: row.imageFile,
            width: 10,
            height: 10,
            kind: AlbumKind.official,
            groupName: group.name,
            groupId: row.groupId,
            createdAt: DateTime(2026, 9, 21),
          ),
        ],
        initialIndex: 0,
        onTagTap: tapped.add,
      ),
    );
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y(group.name) < y('#角色1'), isTrue);
    expect(y('#角色1') < y('2026 / 09 / 21 加入'), isTrue);
    expect(find.text('#夏日企劃'), findsOneWidget);
    await tester.tap(find.text('#夏日企劃'));
    expect(tapped, [tagB]);
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
