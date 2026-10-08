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
import 'package:huakeng/ui/tags/tag_manage_page.dart';

/// 腦洞／草稿／tag 畫面的互動與規則（D-001～D-005、D-015～D-018、D-037、D-043）。
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
  }) => db.saveDraft(
    pitId: pitId,
    title: title,
    body: body,
    images: [
      for (var i = 0; i < images; i++)
        NewImage(file: ['a.png', 'b.png', 'c.png'][i % 3]),
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
      final draftId = await newDraft(title: '草稿');
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
      expect(find.text('還沒有草稿'), findsOneWidget);
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
    testWidgets('腦洞編輯頁：選擇草稿面板列標題／無標題、多選、完成後存成關聯', (tester) async {
      final titled = await newDraft(title: '天台煙花 · 構圖', images: 2);
      final blank = await newDraft();
      final ideaId = await newIdea('天台');
      await show(tester, IdeaFormPage(pitId: pitId, ideaId: ideaId));
      expect(find.text('關聯草稿'), findsOneWidget);
      expect(find.text('關聯成圖'), findsOneWidget);
      expect(find.textContaining('連接'), findsNothing);

      await tester.ensureVisible(find.text('選擇').first);
      await tester.tap(find.text('選擇').first); // 第一顆是關聯草稿
      await settle(tester);
      expect(find.text('選擇草稿'), findsWidgets);
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

    testWidgets('草稿表單：關聯腦洞的面板用同一款，量詞是「個」', (tester) async {
      await newIdea('腦洞甲');
      await show(tester, DraftFormPage(pitId: pitId));
      expect(find.text('關聯腦洞'), findsOneWidget);
      await tester.ensureVisible(find.text('選擇'));
      await tester.tap(find.text('選擇'));
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

  group('表單圖片 ×（D-018）', () {
    testWidgets('草稿編輯：移除一張後儲存只剩一張', (tester) async {
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

  group('草稿詳情三種情況（D-017）', () {
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
      expect(find.text('刪除這份草稿？'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('腦洞詳情不能新增關聯（D-037）', () {
    testWidgets('沒有關聯時整段不顯示、也沒有「＋」格', (tester) async {
      final id = await newIdea('孤單腦洞');
      await show(tester, IdeaDetailPage(ideaId: id, pitId: pitId));
      expect(find.text('孤單腦洞'), findsOneWidget);
      expect(find.text('關聯的草稿'), findsNothing);
      expect(find.text('關聯的成圖'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇草稿')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇成圖')), findsNothing);
      await unmount(tester);
    });

    testWidgets('有關聯草稿才顯示該段，且沒有「＋」格；tag 可點', (tester) async {
      final d = await newDraft(title: '線稿');
      final id = await newIdea('腦洞', tagIds: [tagA], draftIds: [d]);
      String? tapped;
      await show(
        tester,
        IdeaDetailPage(ideaId: id, pitId: pitId, onTagTap: (t) => tapped = t),
      );
      expect(find.text('關聯的草稿'), findsOneWidget);
      expect(find.text('關聯的成圖'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('選擇草稿')), findsNothing);
      expect(find.textContaining('連接'), findsNothing);
      await tester.tap(find.text('#角色1'));
      expect(tapped, tagA);
      await unmount(tester);
    });
  });

  group('tag 顯示規則與篩選（D-043）', () {
    testWidgets('腦洞卡片顯示 tag，草稿卡片不顯示', (tester) async {
      await newIdea('有 tag 的腦洞', tagIds: [tagA]);
      await newDraft(title: '有 tag 的草稿', tagIds: [tagA]);
      await show(tester, IdeaListPage(pitId: pitId));
      expect(find.text('#角色1'), findsOneWidget);
      await unmount(tester);

      await show(tester, DraftListPage(pitId: pitId));
      expect(find.text('有 tag 的草稿'), findsOneWidget);
      expect(find.text('#角色1'), findsNothing);
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

  group('草稿列表卡片', () {
    testWidgets('有字卡、純圖單張、純圖多張（+N）、九宮格切換', (tester) async {
      await newDraft(title: '有字', images: 3);
      await newDraft(); // 純圖單張
      await newDraft(images: 3); // 純圖多張
      await newDraft(images: 5); // 純圖 +2
      await show(tester, DraftListPage(pitId: pitId));
      expect(find.text('有字'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('4 份'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('九宮格'));
      await settle(tester);
      expect(find.text('3'), findsWidgets); // 多圖格右下角張數
      expect(tester.takeException(), isNull);
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
