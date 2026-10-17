import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/connect_field.dart';
import 'package:huakeng/ui/entity/draft_detail_page.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/entity_widgets.dart';
import 'package:huakeng/ui/entity/idea_detail_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:huakeng/ui/entity/piece_detail_page.dart';
import 'package:huakeng/ui/entity/piece_widgets.dart';
import 'package:huakeng/ui/tags/tag_manage_page.dart';

/// 腦洞／摸魚／tag 畫面的互動與規則（D-001～D-005、D-015～D-018、D-037、D-043）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late String tagA;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('entity_ui');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '測試坑');
    tagA = await db.createTag(pitId, '角色1');
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

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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

  Future<String> newDraft({
    String? title,
    String? body,
    int images = 1,
    List<String> tagIds = const [],
    List<String> ideaIds = const [],
    List<(int, int)>? sizes,
  }) => db.saveDraft(
    pitId: pitId,
    title: title,
    body: body,
    images: [
      for (var i = 0; i < (sizes?.length ?? images); i++)
        NewImage(
          file: ['a.png', 'b.png', 'c.png'][i % 3],
          width: sizes?[i].$1 ?? 0,
          height: sizes?[i].$2 ?? 0,
        ),
    ],
    tagIds: tagIds,
    ideaIds: ideaIds,
  );

  Future<String> newIdea(
    String title, {
    List<String> tagIds = const [],
    List<String> draftIds = const [],
    List<String> pieceIds = const [],
  }) => db.saveIdea(
    pitId: pitId,
    title: title,
    body: '內文',
    images: const [],
    tagIds: tagIds,
    draftIds: draftIds,
    pieceIds: pieceIds,
  );

  Future<String> newPiece(String title) => db.savePiece(
    pitId: pitId,
    title: title,
    body: '',
    images: const [NewImage(file: 'a.png')],
    tagIds: const [],
    links: const [],
    targetLikes: 0,
    finishedAt: DateTime(2026, 5, 1),
    ideaIds: const [],
    draftIds: const [],
  );

  group('導覽列規則（D-005）', () {
    testWidgets('列表有導覽列，表單與詳情沒有', (tester) async {
      final ideaId = await newIdea('腦洞');
      final draftId = await newDraft(title: '摸魚');
      await show(tester, IdeaListPage(pitId: pitId));
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);

      await show(tester, DraftListPage(pitId: pitId));
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);

      final pages = <Widget>[
        IdeaFormPage(pitId: pitId),
        IdeaDetailPage(ideaId: ideaId, pitId: pitId),
        DraftFormPage(pitId: pitId),
        DraftDetailPage(draftId: draftId, pitId: pitId),
        TagManagePage(pitId: pitId),
        const ImageGalleryPage(images: [ImageRef('a.png', 1, 1)]),
      ];
      for (final p in pages) {
        navBarHiddenCount.value = 0;
        await show(tester, p);
        expect(
          navBarHiddenCount.value,
          greaterThan(0),
          reason: '${p.runtimeType} 應隱藏導覽列',
        );
        await unmount(tester);
        expect(navBarHiddenCount.value, 0);
      }
    });

    testWidgets('空白狀態有導覽列、沒有新增浮動按鈕', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId));
      expect(find.text('還沒有腦洞'), findsOneWidget);
      expect(find.text('記下第一個腦洞'), findsOneWidget);
      expect(find.byType(EntityFab), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);

      await show(tester, DraftListPage(pitId: pitId));
      expect(find.text('還沒有摸魚'), findsOneWidget);
      expect(find.byType(EntityFab), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('腦洞多選：進入多選隱藏導覽列，退出後恢復；只有刪除', (tester) async {
      await newIdea('甲');
      await newIdea('乙');
      await show(tester, IdeaListPage(pitId: pitId));
      expect(navBarHiddenCount.value, 0);
      await tester.longPress(find.text('甲'));
      await settle(tester);
      expect(find.text('已選 1 個'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
      expect(find.text('全選'), findsOneWidget);
      expect(navBarHiddenCount.value, greaterThan(0));
      await tester.tap(find.text('乙'));
      await settle(tester);
      expect(find.text('已選 2 個'), findsOneWidget);
      // 取消選擇：再按一次兩張都取消 → 回到瀏覽並恢復導覽列
      await tester.tap(find.text('甲'));
      await tester.tap(find.text('乙'));
      await settle(tester);
      expect(find.text('已選 1 個'), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });
  });

  group('選擇面板（D-015）與關聯用詞（D-001／D-003）', () {
    testWidgets('腦洞編輯頁：選擇摸魚面板列標題／無標題、多選、完成後存成關聯', (tester) async {
      final titled = await newDraft(title: '天台煙花 · 構圖', images: 2);
      final blank = await newDraft();
      final ideaId = await newIdea('天台');
      await show(tester, IdeaFormPage(pitId: pitId, ideaId: ideaId));
      expect(find.text('關聯摸魚'), findsOneWidget);
      expect(find.text('關聯成圖'), findsOneWidget);
      expect(find.textContaining('連接'), findsNothing);

      await tester.ensureVisible(find.text('選擇').first);
      await tester.tap(find.text('選擇').first); // 第一顆是關聯摸魚
      await settle(tester);
      expect(find.text('選擇摸魚'), findsWidgets);
      expect(find.text('已選 0 份'), findsOneWidget);
      expect(find.text('天台煙花 · 構圖'), findsOneWidget);
      expect(find.text('無標題'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);

      await tester.tap(find.text('天台煙花 · 構圖'));
      await tester.tap(find.text('無標題'));
      await settle(tester);
      expect(find.text('已選 2 份'), findsOneWidget);
      await tester.tap(find.text('無標題')); // 再按一次＝取消
      await settle(tester);
      expect(find.text('已選 1 份'), findsOneWidget);
      await tester.tap(find.text('完成'));
      await settle(tester);

      // chip 出現在表單上
      expect(find.text('天台煙花 · 構圖'), findsOneWidget);

      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final v = (await tester.runAsync(() => db.watchIdeaView(ideaId).first))!;
      expect(v.draftIds, [titled]);
      expect(v.draftIds, isNot(contains(blank)));
      await unmount(tester);
    });

    testWidgets('摸魚表單：關聯腦洞的面板用同一款，量詞是「個」', (tester) async {
      await newIdea('腦洞甲');
      await show(tester, DraftFormPage(pitId: pitId));
      expect(find.text('關聯腦洞'), findsOneWidget);
      await tester.ensureVisible(find.text('選擇').first);
      await tester.tap(find.text('選擇').first);
      await settle(tester);
      expect(find.text('選擇腦洞'), findsWidgets);
      expect(find.text('已選 0 個'), findsOneWidget);
      expect(find.text('腦洞甲'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ConnectField：成圖種類用「張」，已選 chip 可移除', (tester) async {
      final p = await newPiece('成圖甲');
      var selected = <String>[p];
      await show(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ConnectField(
              label: '關聯成圖',
              options: [ConnectOption(id: p, title: '成圖甲')],
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );
      expect(find.text('成圖甲'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('移除'));
      await settle(tester);
      expect(selected, isEmpty);
      await tester.tap(find.text('選擇'));
      await settle(tester);
      expect(find.text('已選 0 張'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('日期欄（D-070）與關聯成圖（D-069）', () {
    DateTime today() {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day);
    }

    Future<void> pickDay(WidgetTester tester, int day) async {
      await tester.tap(find.text('$day').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await settle(tester);
    }

    testWidgets('腦洞新增：日期欄在最底（關聯成圖下面、建立按鈕上面），預設今天，改日期後存成 date', (tester) async {
      await show(tester, IdeaFormPage(pitId: pitId));
      expect(find.text('日期'), findsOneWidget);
      expect(find.text(fmtSlash(today())), findsOneWidget);
      final yPiece = tester.getTopLeft(find.text('關聯成圖')).dy;
      await tester.ensureVisible(find.text('建立腦洞'));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('日期')).dy,
        greaterThan(tester.getTopLeft(find.text('關聯成圖')).dy),
      );
      expect(
        tester.getTopLeft(find.text('日期')).dy,
        lessThan(tester.getTopLeft(find.text('建立腦洞')).dy),
      );
      expect(yPiece, isNotNull);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byType(PieceDateField));
      await settle(tester);
      final day = today().day == 27 ? 26 : 27;
      await pickDay(tester, day);
      final picked = DateTime(today().year, today().month, day);
      expect(find.text(fmtSlash(picked)), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '新腦洞');
      await tester.ensureVisible(find.text('建立腦洞'));
      await tester.tap(find.text('建立腦洞'));
      await settle(tester);
      final all = await tester.runAsync(() => db.watchIdeaViews(pitId).first);
      final d = all!.single.idea.date;
      expect(DateTime(d.year, d.month, d.day), picked);
      await unmount(tester);
    });

    testWidgets('摸魚編輯：帶入原日期；不動日期儲存不變；列表與詳情顯示 date 而非建立時間', (tester) async {
      final id = await db.saveDraft(
        pitId: pitId,
        title: '舊摸魚',
        images: const [NewImage(file: 'a.png')],
        tagIds: const [],
        ideaIds: const [],
        date: DateTime(2026, 3, 5),
      );
      await show(tester, DraftFormPage(pitId: pitId, draftId: id));
      expect(find.text('2026 / 03 / 05'), findsOneWidget);
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final v = (await tester.runAsync(() => db.watchDraftView(id).first))!;
      expect(v.draft.date, DateTime(2026, 3, 5));
      await unmount(tester);

      await show(tester, DraftListPage(pitId: pitId));
      expect(find.text('3/5'), findsOneWidget);
      await unmount(tester);

      await show(tester, DraftDetailPage(draftId: id, pitId: pitId));
      expect(find.text('2026 / 03 / 05'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('腦洞列表與詳情顯示 date', (tester) async {
      final id = await db.saveIdea(
        pitId: pitId,
        title: '舊腦洞',
        body: '內文',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
        date: DateTime(2026, 2, 9),
      );
      await show(tester, IdeaListPage(pitId: pitId));
      expect(find.text('2/9'), findsOneWidget);
      await unmount(tester);
      await show(tester, IdeaDetailPage(ideaId: id, pitId: pitId));
      expect(find.text('建立於 2026 / 02 / 09'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('摸魚表單：關聯成圖在關聯腦洞下面；編輯時選擇後存成兩邊的關係，兩邊詳情都顯示', (tester) async {
      final pieceId = await newPiece('成圖甲');
      final draftId = await newDraft(title: '摸魚甲');
      await show(tester, DraftFormPage(pitId: pitId, draftId: draftId));
      expect(find.text('關聯成圖'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('關聯成圖')).dy,
        greaterThan(tester.getTopLeft(find.text('關聯腦洞')).dy),
      );
      await tester.ensureVisible(find.text('選擇').last);
      await tester.tap(find.text('選擇').last); // 第二顆＝關聯成圖
      await settle(tester);
      expect(find.text('選擇成圖'), findsWidgets);
      expect(find.text('已選 0 張'), findsOneWidget);
      await tester.tap(find.text('成圖甲'));
      await settle(tester);
      await tester.tap(find.text('完成'));
      await settle(tester);
      expect(find.text('成圖甲'), findsOneWidget); // chip
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final dv = (await tester.runAsync(
        () => db.watchDraftView(draftId).first,
      ))!;
      expect(dv.pieceIds, [pieceId]);
      await unmount(tester);

      // 摸魚詳情顯示關聯成圖（方形縮圖，沒有「＋」）
      await show(tester, DraftDetailPage(draftId: draftId, pitId: pitId));
      expect(find.text('關聯的成圖'), findsOneWidget);
      expect(find.byType(ThumbSquare), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('選擇成圖')), findsNothing);
      await unmount(tester);

      // 成圖詳情顯示關聯摸魚
      await show(tester, PieceDetailPage(pieceId: pieceId, pitId: pitId));
      expect(find.text('關聯的摸魚'), findsOneWidget);
      await unmount(tester);

      // 摸魚編輯頁帶入已選成圖，可移除並存成空
      await show(tester, DraftFormPage(pitId: pitId, draftId: draftId));
      expect(find.text('成圖甲'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('移除').first);
      await tester.tap(find.bySemanticsLabel('移除').first);
      await settle(tester);
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final v = (await tester.runAsync(
        () => db.watchDraftView(draftId).first,
      ))!;
      expect(v.pieceIds, isEmpty);
      await unmount(tester);
    });

    testWidgets('摸魚詳情沒有關聯成圖時整段不顯示', (tester) async {
      final id = await newDraft(title: '空', body: '字');
      await show(tester, DraftDetailPage(draftId: id, pitId: pitId));
      expect(find.text('關聯的成圖'), findsNothing);
      await unmount(tester);
    });
  });

  group('表單圖片 ×（D-018）', () {
    testWidgets('摸魚編輯：移除一張後儲存只剩一張', (tester) async {
      final id = await newDraft(title: '兩張', images: 2);
      await show(tester, DraftFormPage(pitId: pitId, draftId: id));
      expect(find.bySemanticsLabel('移除圖片'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('移除圖片').first);
      await settle(tester);
      expect(find.bySemanticsLabel('移除圖片'), findsOneWidget);
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final v = (await tester.runAsync(() => db.watchDraftView(id).first))!;
      expect(v.images.length, 1);
      await unmount(tester);
    });

    testWidgets('腦洞新增：沒有圖時沒有 ×，不選圖也能建立', (tester) async {
      await show(tester, IdeaFormPage(pitId: pitId));
      expect(find.bySemanticsLabel('移除圖片'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '新腦洞');
      await tester.ensureVisible(find.text('建立腦洞'));
      await tester.tap(find.text('建立腦洞'));
      await settle(tester);
      final all = await tester.runAsync(() => db.watchIdeaViews(pitId).first);
      expect(all!.single.idea.title, '新腦洞');
      await unmount(tester);
    });
  });

  group('管理 tag（D-016）', () {
    testWidgets('新增 tag：最底變輸入框（# 前綴、取消／新增），新增後出現在清單', (tester) async {
      await show(tester, TagManagePage(pitId: pitId));
      expect(find.text('#角色1'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('新增 tag'));
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('新增'), findsOneWidget);
      expect(find.text('新增 tag'), findsNothing);

      await tester.enterText(find.byType(TextField), '角色3');
      await tester.tap(find.text('新增'));
      await settle(tester);
      expect(find.text('#角色3'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('新增 tag'), findsOneWidget);
      final tags = await tester.runAsync(() => db.watchTags(pitId).first);
      expect(tags!.map((e) => e.name), containsAll(['角色1', '角色3']));
      await unmount(tester);
    });

    testWidgets('取消會收起輸入框；空白不新增', (tester) async {
      await show(tester, TagManagePage(pitId: pitId));
      await tester.tap(find.text('新增 tag'));
      await settle(tester);
      await tester.tap(find.text('新增'));
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget); // 空白不新增，輸入框還在
      await tester.enterText(find.byType(TextField), '##暫存');
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.byType(TextField), findsNothing);
      final tags = await tester.runAsync(() => db.watchTags(pitId).first);
      expect(tags!.map((e) => e.name), ['角色1']);
      await unmount(tester);
    });
  });

  group('摸魚詳情三種情況（D-017）', () {
    testWidgets('完整：標題、日期、內文、tag、關聯腦洞，多張時有 1 / N 與縮圖列', (tester) async {
      final ideaId = await newIdea('天台看煙花');
      final id = await newDraft(
        title: '天台煙花 · 構圖',
        body: '嘗試兩個側面的角度',
        images: 2,
        tagIds: [tagA],
        ideaIds: [ideaId],
      );
      String? tapped;
      await show(
        tester,
        DraftDetailPage(draftId: id, pitId: pitId, onTagTap: (t) => tapped = t),
      );
      expect(find.text('天台煙花 · 構圖'), findsOneWidget);
      expect(find.text('嘗試兩個側面的角度'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.bySemanticsLabel('第 2 張'), findsOneWidget);
      expect(find.text('關聯的腦洞'), findsOneWidget);
      expect(find.text('天台看煙花'), findsOneWidget);
      expect(find.bySemanticsLabel('編輯'), findsOneWidget);
      expect(find.bySemanticsLabel('刪除'), findsOneWidget);
      // 詳情頁不能新增關聯
      expect(find.bySemanticsLabel(RegExp('選擇腦洞')), findsNothing);
      // tag 可點
      await tester.tap(find.text('#角色1'));
      expect(tapped, tagA);
      await unmount(tester);
    });

    testWidgets('只有一張圖：只有大圖與日期，沒有 1 / N、縮圖列', (tester) async {
      final id = await newDraft();
      await show(tester, DraftDetailPage(draftId: id, pitId: pitId));
      expect(
        find.textContaining(' / '),
        findsOneWidget,
      ); // 只剩日期「2026 / 10 / 08」
      expect(find.text('1 / 1'), findsNothing);
      expect(find.bySemanticsLabel('第 1 張'), findsNothing);
      expect(find.text('關聯的腦洞'), findsNothing);
      await unmount(tester);
    });

    testWidgets('只有多張圖：1 / N，點縮圖換圖', (tester) async {
      final id = await newDraft(images: 3);
      await show(tester, DraftDetailPage(draftId: id, pitId: pitId));
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('第 3 張'));
      await settle(tester);
      expect(find.text('3 / 3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('刪除要先確認', (tester) async {
      final id = await newDraft(title: '要刪');
      await show(tester, DraftDetailPage(draftId: id, pitId: pitId));
      await tester.tap(find.bySemanticsLabel('刪除'));
      await settle(tester);
      expect(find.text('刪除這份摸魚？'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('腦洞詳情不能新增關聯（D-037）', () {
    testWidgets('沒有關聯時整段不顯示、也沒有「＋」格', (tester) async {
      final id = await newIdea('孤單腦洞');
      await show(tester, IdeaDetailPage(ideaId: id, pitId: pitId));
      expect(find.text('孤單腦洞'), findsOneWidget);
      expect(find.text('關聯的摸魚'), findsNothing);
      expect(find.text('關聯的成圖'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇摸魚')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇成圖')), findsNothing);
      await unmount(tester);
    });

    testWidgets('有關聯摸魚才顯示該段，且沒有「＋」格；tag 可點', (tester) async {
      final d = await newDraft(title: '線稿');
      final id = await newIdea('腦洞', tagIds: [tagA], draftIds: [d]);
      String? tapped;
      await show(
        tester,
        IdeaDetailPage(ideaId: id, pitId: pitId, onTagTap: (t) => tapped = t),
      );
      expect(find.text('關聯的摸魚'), findsOneWidget);
      expect(find.text('關聯的成圖'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇摸魚')), findsNothing);
      expect(find.textContaining('連接'), findsNothing);
      await tester.tap(find.text('#角色1'));
      expect(tapped, tagA);
      await unmount(tester);
    });
  });

  group('tag 顯示規則與篩選（D-043）', () {
    testWidgets('腦洞卡片與摸魚卡片都顯示 tag（D-083 統一框架）', (tester) async {
      await newIdea('有 tag 的腦洞', tagIds: [tagA]);
      await newDraft(title: '有 tag 的摸魚', tagIds: [tagA]);
      await show(tester, IdeaListPage(pitId: pitId));
      expect(find.text('#角色1'), findsOneWidget);
      await unmount(tester);

      await show(tester, DraftListPage(pitId: pitId));
      expect(find.text('有 tag 的摸魚'), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('列表的 tagId 參數只顯示有該 tag 的項目', (tester) async {
      await newIdea('甲', tagIds: [tagA]);
      await newIdea('乙');
      await newDraft(title: '丙', tagIds: [tagA]);
      await newDraft(title: '丁');
      await show(tester, IdeaListPage(pitId: pitId, tagId: tagA));
      expect(find.text('甲'), findsOneWidget);
      expect(find.text('乙'), findsNothing);
      await unmount(tester);
      await show(tester, DraftListPage(pitId: pitId, tagId: tagA));
      expect(find.text('丙'), findsOneWidget);
      expect(find.text('丁'), findsNothing);
      await unmount(tester);
    });

    testWidgets('腦洞列表點 tag 會呼叫 onTagTap', (tester) async {
      await newIdea('甲', tagIds: [tagA]);
      String? tapped;
      await show(
        tester,
        IdeaListPage(pitId: pitId, onTagTap: (t) => tapped = t),
      );
      await tester.tap(find.text('#角色1'));
      expect(tapped, tagA);
      await unmount(tester);
    });
  });

  group('摸魚列表（D-087 推特式）', () {
    testWidgets('列表與九宮格切換', (tester) async {
      await newDraft(title: '有字', images: 3);
      await newDraft();
      await newDraft(images: 3);
      await newDraft(images: 5);
      await show(tester, DraftListPage(pitId: pitId));
      expect(find.byType(DraftRow), findsWidgets);
      expect(find.text('4 份'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('九宮格'));
      await settle(tester);
      expect(find.byType(DraftRow), findsNothing);
      expect(find.text('3'), findsWidgets); // 多圖格右下角張數
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    Finder tiles() => find.descendant(
      of: find.byType(DraftRow),
      matching: find.byType(StoredImage),
    );
    Finder rich(String s) => find.text(s);

    test('版面算式', () {
      const w = 350.0;
      var l = draftImageLayout([1.5], w);
      expect(l.scrolls, isFalse);
      expect(l.sizes.single.width, w);
      expect(l.sizes.single.height, closeTo(w / 1.5, 0.001));
      // 極端比例夾在高 0.25W～1.6W。
      expect(
        draftImageLayout([20], w).sizes.single.height,
        closeTo(w / 4, .001),
      );
      expect(
        draftImageLayout([0.1], w).sizes.single.height,
        closeTo(w * 1.6, .001),
      );
      // 未知比例＝1:1。
      expect(draftImageLayout([1], w).sizes.single.height, w);
      l = draftImageLayout([0.75, 1.5], w);
      final h = (w - 4) / 2.25;
      expect(l.sizes[0], Size(h * 0.75, h));
      expect(l.sizes[1], Size(h * 1.5, h));
      expect(l.sizes[0].width + 4 + l.sizes[1].width, closeTo(w, .001));
      l = draftImageLayout([0.8, 1.0, 1.3, 0.7], w);
      expect(l.scrolls, isTrue);
      final h3 = (w - 4) / (0.8 + 0.5);
      for (final s in l.sizes) {
        expect(s.height, closeTo(h3, .001));
      }
      expect(l.sizes[0].width + 4 + l.sizes[1].width / 2, closeTo(w, .001));
    });

    testWidgets('1 張：寬 W、高依比例；標題・日期、無內文', (tester) async {
      await newDraft(title: '單張', sizes: const [(200, 100)]);
      await show(tester, DraftListPage(pitId: pitId));
      final row = tester.getRect(find.byType(DraftRow));
      expect(row.left, 0);
      final im = tester.getRect(tiles());
      expect(im.left, 20);
      expect(im.width, closeTo(row.width - 40, .01));
      expect(im.height, closeTo(im.width / 2, .01));
      expect(rich('單張'), findsOneWidget);
      expect(rich('·'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('2 張：同高拼滿 W', (tester) async {
      await newDraft(sizes: const [(300, 400), (400, 300)]);
      await show(tester, DraftListPage(pitId: pitId));
      final row = tester.getRect(find.byType(DraftRow));
      final a = tester.getRect(tiles().at(0));
      final b = tester.getRect(tiles().at(1));
      final w = row.width - 40;
      final h = (w - 4) / (0.75 + 4 / 3);
      expect(a.height, closeTo(h, .01));
      expect(b.height, closeTo(h, .01));
      expect(a.width, closeTo(h * 0.75, .01));
      expect(b.left - a.right, closeTo(4, .01));
      expect(b.right, closeTo(row.right - 20, .01));
      await unmount(tester);
    });

    testWidgets('3 張以上：同高橫捲，第 1 張完整、第 2 張露一半，延伸到右緣', (tester) async {
      await newDraft(
        title: '多張',
        sizes: const [(300, 400), (400, 400), (400, 300), (300, 400)],
      );
      await show(tester, DraftListPage(pitId: pitId));
      final row = tester.getRect(find.byType(DraftRow));
      final w = row.width - 40;
      final h = (w - 4) / (0.75 + 0.5);
      final a = tester.getRect(tiles().at(0));
      expect(a.left, 20);
      expect(a.height, closeTo(h, .01));
      final b = tester.getRect(tiles().at(1));
      // 第 2 張只露出一半：被可視區（到螢幕右緣）剪掉。
      expect(b.left, closeTo(20 + a.width + 4, .01));
      expect(
        row.right - b.left,
        closeTo(b.width / 2 + 20, .5),
      ); // 公式照 W；右邊多出的 20 留白也算可視
      final sc = tester.getRect(
        find.descendant(
          of: find.byType(DraftRow),
          matching: find.byType(ListView),
        ),
      );
      expect(sc.right, row.right);
      await tester.drag(
        find.descendant(
          of: find.byType(DraftRow),
          matching: find.byType(ListView),
        ),
        const Offset(-200, 0),
      );
      await tester.pump();
      expect(tester.getRect(tiles().at(0)).left, lessThan(20));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('無標題只有日期；有內文；已孵標記；tag 與關聯腦洞', (tester) async {
      final pieceId = await newPiece('成圖甲');
      final ideaId = await newIdea('某腦洞');
      await db.saveDraft(
        pitId: pitId,
        body: '這是內文',
        images: const [],
        tagIds: [tagA],
        ideaIds: [ideaId],
        pieceIds: [pieceId],
      );
      await show(tester, DraftListPage(pitId: pitId));
      expect(rich('·'), findsNothing);
      expect(find.text('這是內文'), findsOneWidget);
      expect(find.text('已孵 1 成圖'), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      expect(find.text('某腦洞'), findsOneWidget);
      expect(tiles(), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('沒有內文：標題後直接圖片；點整列開詳情、點圖開預覽', (tester) async {
      await newDraft(title: '甲', sizes: const [(100, 100), (100, 100)]);
      await show(tester, DraftListPage(pitId: pitId));
      await tester.tap(tiles().at(1));
      await settle(tester);
      expect(find.byType(ImageGalleryPage), findsOneWidget);
      expect(find.byType(DraftDetailPage), findsNothing);
      Navigator.of(tester.element(find.byType(ImageGalleryPage))).pop();
      await settle(tester);
      await tester.tap(rich('甲'));
      await settle(tester);
      expect(find.byType(DraftDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('深色模式沒有例外', (tester) async {
      await newDraft(title: '有字', images: 5);
      await newIdea('腦洞', tagIds: [tagA]);
      await show(tester, DraftListPage(pitId: pitId), dark: true);
      expect(tester.takeException(), isNull);
      await unmount(tester);
      await show(tester, IdeaListPage(pitId: pitId), dark: true);
      expect(tester.takeException(), isNull);
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
