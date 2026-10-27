import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/trash_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/profile_page.dart';
import 'package:huakeng/ui/trash/trash_page.dart';
import 'package:huakeng/ui/trash/trash_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-120 最近刪除 UI：我的入口（沒有內容時不顯示）、坑卡、分段、多選還原／清空、坑卡對話框、預覽。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('trash_ui');
    await Directory('${tmp.path}/images').create(recursive: true);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
        ],
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
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 坑C（刪除，坑內 2 張雜物）＋坑A 裡刪掉的腦洞（沒有圖）和 1 張雜物。
  Future<({String pitA, String pitC})> seed(WidgetTester tester) async {
    late String a, c;
    await tester.runAsync(() async {
      c = await db.createPit(name: '坑C', junkEnabled: true);
      await db.addJunk(c, const [
        NewImage(file: 'c1.png', width: 10, height: 10),
        NewImage(file: 'c2.png', width: 10, height: 10),
      ]);
      await db.deletePit(c);
      a = await db.createPit(name: '坑A', junkEnabled: true);
      final idea = await db.saveIdea(
        pitId: a,
        title: '天台看煙花',
        body: '',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      await db.deleteIdeas([idea]);
      await db.addJunk(a, const [
        NewImage(file: 'a1.png', width: 10, height: 10),
      ]);
      final j = await (db.select(
        db.junkImages,
      )..where((x) => x.imageFile.equals('a1.png'))).getSingle();
      await db.deleteJunk([j.id]);
    });
    return (pitA: a, pitC: c);
  }

  testWidgets('我的：沒有刪除內容時沒有「最近刪除」；有內容時顯示項目數', (tester) async {
    await show(tester, const ProfilePage());
    expect(find.text('最近刪除'), findsNothing);
    await seed(tester);
    await settle(tester);
    expect(find.text('最近刪除'), findsOneWidget);
    expect(find.text('3 項'), findsOneWidget);
    await tester.tap(find.text('最近刪除'));
    await settle(tester);
    expect(find.byType(TrashPage), findsOneWidget);
    expect(navBarHiddenCount.value, 1);
    await unmount(tester);
  });

  testWidgets('頁面：坑卡「2 項・剩 30 天」，內容按剩餘天數分段，腦洞顯示文字格', (tester) async {
    await seed(tester);
    await show(tester, const TrashPage());
    expect(find.text('坑'), findsOneWidget);
    expect(find.text('坑C'), findsOneWidget);
    expect(find.text('2 項・剩 30 天'), findsOneWidget);
    expect(find.text('剩 30 天'), findsOneWidget);
    expect(find.text('天台看煙花'), findsOneWidget);
    expect(find.text('選擇'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('多選：沒選時底部是全部還原／全部清空；選了變還原／永久刪除；還原後回到原處', (tester) async {
    await seed(tester);
    await show(tester, const TrashPage());
    await tester.tap(find.text('選擇'));
    await settle(tester);
    expect(find.text('選擇項目'), findsOneWidget);
    expect(find.text('全部還原'), findsOneWidget);
    expect(find.text('全部清空'), findsOneWidget);

    await tester.tap(find.text('天台看煙花'));
    await settle(tester);
    expect(find.text('已選 1 項'), findsOneWidget);
    expect(find.text('還原'), findsOneWidget);
    expect(find.text('永久刪除'), findsOneWidget);
    await tester.tap(find.text('還原'));
    await settle(tester);
    expect(find.text('天台看煙花'), findsNothing);
    final idea = await tester.runAsync(() => db.select(db.ideas).getSingle());
    expect(idea!.deletedAt, isNull);

    // 全部清空要確認，寫明坑數和項目數。
    await tester.tap(find.text('選擇'));
    await settle(tester);
    await tester.tap(find.text('全部清空'));
    await settle(tester);
    expect(find.text('清空最近刪除？'), findsOneWidget);
    expect(find.text('1 個坑和 1 項內容會永久刪除，無法復原。'), findsOneWidget);
    await tester.tap(find.text('永久刪除').last);
    await settle(tester);
    final left = await tester.runAsync(() => db.loadTrash());
    expect(left!.isEmpty, isTrue);
    await unmount(tester);
  });

  testWidgets('點坑卡：對話框 永久刪除／取消／還原，還原連坑內內容', (tester) async {
    final ids = await seed(tester);
    await show(tester, const TrashPage());
    await tester.tap(find.text('坑C'));
    await settle(tester);
    expect(find.text('「坑C」'), findsOneWidget);
    expect(find.text('坑內 2 項會跟坑一起還原。'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('還原'));
    await settle(tester);
    expect(find.text('坑C'), findsNothing);
    final pit = await tester.runAsync(
      () =>
          (db.select(db.pits)..where((p) => p.id.equals(ids.pitC))).getSingle(),
    );
    expect(pit!.deletedAt, isNull);
    await unmount(tester);
  });

  testWidgets('預覽：位置、剩餘天數、刪除日期，只有還原／永久刪除', (tester) async {
    await seed(tester);
    final t = await tester.runAsync(() => db.loadTrash());
    final idea = t!.items.firstWhere((i) => i.kind == TrashKind.idea);
    await show(tester, TrashPreviewPage(item: idea));
    expect(find.text('坑A · 我的腦洞'), findsOneWidget);
    expect(find.text('剩 30 天'), findsOneWidget);
    expect(find.textContaining(' 刪除'), findsOneWidget);
    expect(find.text('還原'), findsOneWidget);
    expect(find.text('永久刪除'), findsOneWidget);
    expect(find.text('分享'), findsNothing);
    await unmount(tester);
  });

  testWidgets('iPad 右欄：標題帶項目數、一排 6 格，多選底部置中動作列', (tester) async {
    await seed(tester);
    await show(tester, const Scaffold(body: TrashPage(embedded: true)));
    tester.view.physicalSize = const Size(2388, 1668);
    tester.view.devicePixelRatio = 2;
    await settle(tester);
    expect(find.text('最近刪除 3 項', findRichText: true), findsOneWidget);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid).first);
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      6,
    );
    await tester.tap(find.text('選擇'));
    await settle(tester);
    expect(find.text('全部還原'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
