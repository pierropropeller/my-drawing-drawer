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
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/move_sheet.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/goals/review_edit_page.dart';
import 'package:huakeng/ui/goals/review_pick_sheet.dart';
import 'package:huakeng/ui/goals/year_view.dart';

/// 跨坑移動 sheet（D-054）、圖片比例（D-055）、年度回顧月份挑圖（D-056）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String a;
  late String b;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('movereview_ui');
    await Directory('${tmp.path}/images').create(recursive: true);
    for (final n in ['a.png', 'b.png', 'c.png', 'd.png', 'e.png']) {
      File('${tmp.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    a = await db.createPit(name: '坑甲');
    b = await db.createPit(name: '坑乙');
  });

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${tmp.path}/images')),
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

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(MoveSheet), matching: find.text(text));

  testWidgets('跨坑移動：tag 按名稱對應到目標坑，移動後在目標坑的同人圖列表看得到', (tester) async {
    await tester.runAsync(() async {
      final t = await db.createTag(a, '夏日');
      await db.addFanArts(
        a,
        [NewImage(file: 'a.png', width: 10, height: 10)],
        author: 'au',
        tagIds: [t],
      );
    });
    phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('坑甲'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    await tester.tap(find.text('移動'));
    await settle(tester);

    // 「坑」「位置」小標；坑 chips 列出所有未封存的坑。
    expect(find.byType(MoveSheet), findsOneWidget);
    expect(inSheet('坑'), findsOneWidget);
    expect(inSheet('位置'), findsOneWidget);
    expect(inSheet('坑甲'), findsOneWidget);
    expect(inSheet('坑乙'), findsOneWidget);
    await tester.tap(inSheet('坑乙'));
    await settle(tester);
    await tester.tap(inSheet('好看同人圖'));
    await settle(tester);
    await tester.tap(find.text('完成').last);
    await settle(tester);

    final inA = await tester.runAsync(() => db.watchFanArts(a).first);
    final inB = await tester.runAsync(() => db.watchFanArts(b).first);
    expect(inA, isEmpty);
    expect(inB!.single.pitId, b);
    final tagsB = await tester.runAsync(() => db.watchTags(b).first);
    final summer = tagsB!.firstWhere((t) => t.name == '夏日');
    final ids = await tester.runAsync(
      () => db.watchTagIds(TagTarget.fanArt, inB.single.id).first,
    );
    expect(ids, [summer.id]);
    // 結束多選＋提示（帶目標坑名）。
    expect(find.text('已選 1 張'), findsNothing);
    expect(find.textContaining('「坑乙」'), findsOneWidget);

    // 坑乙的好看同人圖列表（套用 #夏日 篩選）：看得到這張圖與 tag。
    await unmount(tester);
    await pumpPage(tester, FanArtListPage(pitId: b, tagId: summer.id));
    expect(find.byType(Image), findsWidgets);
    expect(find.textContaining('夏日'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('移動 sheet：換坑後官方分組是目標坑的；目標坑沒開雜物就沒有雜物', (tester) async {
    await tester.runAsync(() async {
      final bGroup = (await db.watchGroups(b).first).first;
      await db.renameGroup(bGroup.id, '乙專屬分組');
      await db.updatePit(a, name: '坑甲', archived: false, junkEnabled: true);
    });
    await pumpPage(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMoveSheet(
              context,
              pitId: a,
              from: AlbumCell.junk,
              count: 2,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(inSheet('雜物'), findsOneWidget); // 本坑開了雜物
    await tester.tap(inSheet('官方圖冊'));
    await settle(tester);
    expect(inSheet('乙專屬分組'), findsNothing);
    await tester.tap(inSheet('坑乙'));
    await settle(tester);
    expect(inSheet('乙專屬分組'), findsOneWidget);
    expect(inSheet('雜物'), findsNothing); // 坑乙沒開雜物
    await tester.tap(inSheet('坑甲'));
    await settle(tester);
    expect(inSheet('乙專屬分組'), findsNothing);
    expect(inSheet('雜物'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> piece(String title, String file, DateTime at, int likes) async {
    final id = await db.savePiece(
      pitId: a,
      title: title,
      body: '',
      images: [NewImage(file: file)],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: at,
      ideaIds: const [],
      draftIds: const [],
      isPublished: true,
      isCommission: false,
    );
    await db.setActualLikes(id, likes);
  }

  testWidgets('年度回顧：多於一張的月份長按打開選圖 sheet，預選目前圖，完成後套用；一張時沒反應', (tester) async {
    await tester.runAsync(() async {
      await piece('春天', 'a.png', DateTime(2026, 3, 1), 5);
      await piece('夏天', 'b.png', DateTime(2026, 3, 2), 9);
      await piece('秋天', 'c.png', DateTime(2026, 3, 3), 1);
      await piece('四月唯一', 'e.png', DateTime(2026, 4, 2), 0);
    });
    await pumpPage(tester, const Scaffold(body: YearView(year: 2026)));
    // 只有一張的 4 月：長按沒反應。
    await tester.longPress(find.text('4月'));
    await settle(tester);
    expect(find.byType(ReviewPickSheet), findsNothing);
    // 沒有成圖的 5 月：一樣沒反應。
    await tester.longPress(find.text('5月'));
    await settle(tester);
    expect(find.byType(ReviewPickSheet), findsNothing);

    // 3 月（3 張）：打開 sheet。
    await tester.longPress(find.text('3月'));
    await settle(tester);
    expect(find.byType(ReviewPickSheet), findsOneWidget);
    expect(find.text('選擇 3 月的圖片'), findsOneWidget);
    expect(find.text('3 張成圖'), findsOneWidget);
    String? selectedTitle() {
      for (final t in ['春天', '夏天', '秋天']) {
        final s = tester.widget<Semantics>(
          find
              .ancestor(of: find.text(t), matching: find.byType(Semantics))
              .first,
        );
        if (s.properties.selected == true) return t;
      }
      return null;
    }

    expect(selectedTitle(), '夏天'); // 預設＝互動量最高
    await tester.tap(find.text('秋天'));
    await settle(tester);
    expect(selectedTitle(), '秋天');
    await tester.tap(find.text('完成'));
    await settle(tester);
    expect(find.byType(ReviewPickSheet), findsNothing);
    final months = await tester.runAsync(
      () => db.watchReviewMonths(2026).first,
    );
    expect(months![3], 'c.png');

    // 再開一次：預選的是目前顯示的「秋天」。
    await tester.longPress(find.text('3月'));
    await settle(tester);
    expect(selectedTitle(), '秋天');
    await unmount(tester);
  });

  testWidgets('年度回顧排版：標題是「圖片比例」，沒有「正方格比例」', (tester) async {
    await pumpPage(tester, ReviewEditPage(year: 2026));
    expect(find.text('圖片比例'), findsOneWidget);
    expect(find.text('正方格比例'), findsNothing);
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
