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
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
import 'package:huakeng/ui/album/wide_layout.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/sensitive_dialogs.dart';
import 'package:huakeng/ui/common/sensitive_gate.dart';
import 'package:huakeng/ui/entity/detail_panes.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';
import 'package:huakeng/ui/pits/pit_page_tablet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P-036／P-037：敏感內容在 iPad 的顯示（FanArtSensitive／FanArtSensitiveOff／FanArtSelect／
/// NewOfficialSensitive）：左邊列表與右邊預覽面板都照安全模式處理（Molly 10/23 改：詳情也模糊）；全螢幕預覽才正常；多選時面板收起、4 欄；
/// 表單的「全部標為敏感」；坑頁的格子封面也走同一個閘門；確認框沿用手機寬度。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const land = Size(1194, 834);

  late AppDatabase db;
  late Directory dir;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipadsens');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '坑A');
    await db.setPitSensitiveEnabled(pitId, true);
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    await db.addFanArts(
      pitId,
      const [
        NewImage(file: 'a.png', width: 100, height: 200, sensitive: true),
        NewImage(file: 'b.png', width: 300, height: 100),
        NewImage(file: 'c.png', width: 100, height: 100),
      ],
      author: '@作者甲',
      groupId: fan.first.id,
    );
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
    bool safe = true,
    Size size = land,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'sensitiveEnabled': true,
      'safeMode': safe,
    });
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
          // 模擬 rail（84）。
          home: Row(
            children: [
              const SizedBox(width: 84),
              Expanded(child: page),
            ],
          ),
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

  const blur = ValueKey('sensitiveBlur');
  const circle = ValueKey('sensitiveCircle');
  const badge = ValueKey('sensitiveBadge');
  const reveal = ValueKey('sensitiveRevealButton');

  Finder inPanel(Finder f) =>
      find.descendant(of: find.byType(SidePanelFrame), matching: f);
  Finder inList(Finder f) =>
      find.descendant(of: find.byType(MasonryGridView), matching: f);

  group('好看同人圖：列表＋預覽並排', () {
    testWidgets('安全模式開：列表模糊＋34px 眼睛圓；點開後右邊預覽面板同一張也模糊（詳情照安全模式）', (tester) async {
      await show(tester, FanArtListPage(pitId: pitId));
      expect(inList(find.byKey(blur)), findsOneWidget);
      expect(tester.getSize(inList(find.byKey(circle))).width, 34);
      expect(find.byKey(badge), findsNothing);

      await tester.tap(inList(find.byKey(circle)), warnIfMissed: false);
      await settle(tester);
      // 面板出現；詳情（預覽面板）照安全模式也模糊，只有點進全螢幕預覽才正常。
      expect(find.byType(SidePanelFrame), findsOneWidget);
      expect(inPanel(find.byKey(blur)), findsOneWidget);
      expect(inPanel(find.byKey(badge)), findsNothing);
      // 列表那張仍然是模糊的。
      expect(inList(find.byKey(blur)), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('安全模式關：列表左上 22px 小標、不模糊；預覽面板同樣只有小標、不模糊', (tester) async {
      await show(tester, FanArtListPage(pitId: pitId), safe: false);
      expect(find.byKey(blur), findsNothing);
      expect(inList(find.byKey(badge)), findsOneWidget);
      expect(tester.getSize(inList(find.byKey(badge))).width, 22);

      await tester.tap(inList(find.byKey(badge)), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(SidePanelFrame), findsOneWidget);
      // P-038：預覽面板不加小標（小標只在列表類出現），也沒有眼睛鈕。
      expect(inPanel(find.byKey(badge)), findsNothing);
      expect(inPanel(find.byKey(blur)), findsNothing);
      expect(inPanel(find.byKey(reveal)), findsNothing);
      expect(inList(find.byKey(badge)), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('P-038：預覽面板左上 40px 眼睛鈕只顯示這一張（不是安全模式總開關）；換一張再回來又模糊', (
      tester,
    ) async {
      await show(tester, FanArtListPage(pitId: pitId));
      // 列表上沒有這顆鈕。
      expect(find.byKey(reveal), findsNothing);
      expect(find.byKey(const ValueKey('sensitiveSafeButton')), findsNothing);
      await tester.tap(inList(find.byKey(circle)), warnIfMissed: false);
      await settle(tester);
      // 面板的封面是 52px 圓。
      expect(tester.getSize(inPanel(find.byKey(circle))).width, 52);
      final btn = inPanel(find.byKey(reveal));
      expect(btn, findsOneWidget);
      expect(tester.getSize(btn), const Size(40, 40));
      // 在圖片左上角（離面板內緣 10），沒有另開一排。
      final img = tester.getRect(
        find
            .descendant(
              of: find.byType(SidePanelFrame),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(tester.getTopLeft(btn) - img.topLeft, const Offset(10, 10));
      expect(find.byKey(const ValueKey('sensitiveSafeButton')), findsNothing);
      expect(find.byTooltip('顯示這張'), findsOneWidget);

      await tester.tap(btn);
      await settle(tester);
      // 只有面板這張清晰；列表那張仍然模糊；安全模式沒被關掉。
      expect(inPanel(find.byKey(blur)), findsNothing);
      expect(inList(find.byKey(blur)), findsOneWidget);
      expect(find.byTooltip('重新模糊'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SidePanelFrame)),
      );
      expect(container.read(settingsProvider).safeMode, isTrue);

      await tester.tap(btn);
      await settle(tester);
      expect(inPanel(find.byKey(blur)), findsOneWidget);

      // 再撳開後換到別張（沒標記）：鈕消失；回到這張自動重新模糊。
      await tester.tap(btn);
      await settle(tester);
      expect(inPanel(find.byKey(blur)), findsNothing);
      await tester.tap(inList(find.byType(Image)).at(1), warnIfMissed: false);
      await settle(tester);
      expect(inPanel(find.byKey(reveal)), findsNothing);
      await tester.tap(inList(find.byKey(circle)), warnIfMissed: false);
      await settle(tester);
      expect(inPanel(find.byKey(blur)), findsOneWidget);
      expect(find.byTooltip('顯示這張'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('D-110：面板選到沒有標記的圖：沒有「安全模式」鈕', (tester) async {
      await show(tester, FanArtListPage(pitId: pitId));
      // 第二張（b.png，沒標記）。
      final plain = inList(find.byType(Image)).at(1);
      await tester.tap(plain, warnIfMissed: false);
      await settle(tester);
      expect(find.byType(SidePanelFrame), findsOneWidget);
      expect(find.byKey(reveal), findsNothing);
      await unmount(tester);
    });

    testWidgets('iPad 全螢幕預覽（參考圖檢視）沒有安全模式：不模糊、沒有圓／小標／鈕', (tester) async {
      await show(
        tester,
        AlbumReferenceScreen(
          images: [
            for (final f in ['a.png', 'b.png'])
              AlbumImage(
                id: f,
                file: f,
                width: 100,
                height: 100,
                kind: AlbumKind.fanArt,
              ),
          ],
          index: 0,
          pitId: pitId,
          title: '坑A · 同人圖',
        ),
      );
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(const ValueKey('sensitiveCircle')), findsNothing);
      expect(find.byKey(const ValueKey('sensitiveBadge')), findsNothing);
      expect(find.byKey(const ValueKey('sensitiveSafeButton')), findsNothing);
      await unmount(tester);
    });

    testWidgets('多選：面板收起、4 欄；列表仍照安全模式；底部動作列「下載、敏感、移動、tag、刪除」靠中間', (
      tester,
    ) async {
      await show(tester, FanArtListPage(pitId: pitId));
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.bySemanticsLabel(l.ipadListsMultiSelect));
      await settle(tester);
      expect(find.byType(SidePanelFrame), findsNothing);
      final grid = tester.widget<MasonryGridView>(find.byType(MasonryGridView));
      final d =
          grid.gridDelegate as SliverSimpleGridDelegateWithFixedCrossAxisCount;
      expect(d.crossAxisCount, 4);
      expect(inList(find.byKey(blur)), findsOneWidget);

      final xs = [
        for (final s in [
          l.commonDownload,
          l.sensitiveAction,
          l.commonMove,
          l.shareMoveTag,
          l.commonDelete,
        ])
          tester.getCenter(find.text(s)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      // 兩側各留 120（rail 84 之外）。
      expect(
        tester.getTopLeft(find.text(l.commonDownload)).dx,
        greaterThan(84 + 120),
      );
      expect(
        tester.getTopRight(find.text(l.commonDelete)).dx,
        lessThan(land.width - 120),
      );
      await unmount(tester);
    });
  });

  group('P-038 有標題列的詳情面板（摸魚／腦洞／成圖）', () {
    late String draftId;
    late String ideaId;
    late String pieceId;

    Future<void> seed(WidgetTester tester) async {
      await tester.runAsync(() async {
        draftId = await db.saveDraft(
          pitId: pitId,
          title: '構圖草稿',
          images: const [
            NewImage(file: 'a.png', width: 100, height: 100, sensitive: true),
            NewImage(file: 'b.png', width: 100, height: 100),
          ],
          tagIds: const [],
          ideaIds: const [],
        );
        ideaId = await db.saveIdea(
          pitId: pitId,
          title: '天台',
          body: '',
          images: const [
            NewImage(file: 'b.png', width: 100, height: 100),
            NewImage(file: 'a.png', width: 100, height: 100, sensitive: true),
          ],
          tagIds: const [],
          draftIds: const [],
          pieceIds: const [],
        );
        pieceId = await db.savePiece(
          pitId: pitId,
          title: '成圖一',
          body: '',
          images: const [
            NewImage(file: 'c.png', width: 100, height: 100, sensitive: true),
          ],
          tagIds: const [],
          links: const [],
          targetLikes: 0,
          finishedAt: DateTime(2026, 9, 1),
          ideaIds: const [],
          draftIds: const [],
        );
      });
    }

    testWidgets('摸魚：眼睛鈕在標題列、編輯左邊（眼睛、編輯、刪除）；只顯示這張，換圖重新模糊', (tester) async {
      await seed(tester);
      await show(
        tester,
        DraftDetailPane(pitId: pitId, draftId: draftId, onDeleted: () {}),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(DraftDetailPane)),
      );
      final btn = find.byKey(reveal);
      expect(btn, findsOneWidget);
      expect(tester.getSize(btn), const Size(44, 44));
      final eyeX = tester.getCenter(btn).dx;
      final editX = tester.getCenter(find.bySemanticsLabel(l.commonEdit)).dx;
      final delX = tester.getCenter(find.bySemanticsLabel(l.commonDelete)).dx;
      expect(eyeX, lessThan(editX));
      expect(editX, lessThan(delX));
      expect(find.byKey(circle), findsWidgets);
      // 沒有另開一排「安全模式」鈕。
      expect(find.byKey(const ValueKey('sensitiveSafeButton')), findsNothing);

      final mainBlur = find.byKey(blur);
      final before = mainBlur.evaluate().length;
      await tester.tap(btn);
      await settle(tester);
      expect(mainBlur.evaluate().length, lessThan(before));
      expect(find.byTooltip('重新模糊'), findsOneWidget);

      // 換到第二張（沒標記）：鈕消失；回來又模糊。
      await tester.tap(find.bySemanticsLabel(l.ipadListsDraftImageN(2)));
      await settle(tester);
      expect(find.byKey(reveal), findsNothing);
      await tester.tap(find.bySemanticsLabel(l.ipadListsDraftImageN(1)));
      await settle(tester);
      expect(find.byKey(reveal), findsOneWidget);
      expect(find.byTooltip('顯示這張'), findsOneWidget);
      expect(mainBlur.evaluate().length, before);
      await unmount(tester);
    });

    testWidgets('摸魚：安全模式關＝沒有眼睛鈕、沒有小標', (tester) async {
      await seed(tester);
      await show(
        tester,
        DraftDetailPane(pitId: pitId, draftId: draftId, onDeleted: () {}),
        safe: false,
      );
      expect(find.byKey(reveal), findsNothing);
      expect(find.byKey(badge), findsNothing);
      expect(find.byKey(blur), findsNothing);
      await unmount(tester);
    });

    testWidgets('腦洞：第一張沒標記→沒有鈕；翻到有標記的第二張才出現', (tester) async {
      await seed(tester);
      await show(
        tester,
        IdeaDetailPane(pitId: pitId, ideaId: ideaId, onDeleted: () {}),
      );
      expect(find.byKey(reveal), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await settle(tester);
      expect(find.byKey(reveal), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('成圖：面板沒有標題列→眼睛鈕在封面左上角 40px', (tester) async {
      await seed(tester);
      await show(
        tester,
        SizedBox(
          width: 350,
          child: PieceDetailPanel(pitId: pitId, pieceId: pieceId),
        ),
      );
      final btn = find.byKey(reveal);
      expect(btn, findsOneWidget);
      expect(tester.getSize(btn), const Size(40, 40));
      expect(find.byKey(circle), findsOneWidget);
      await tester.tap(btn);
      await settle(tester);
      expect(find.byKey(blur), findsNothing);
      await unmount(tester);
    });
  });

  group('表單（NewOfficialSensitive）', () {
    testWidgets('iPad：「全部標為敏感」離圖片格 16；手機 12', (tester) async {
      Future<EdgeInsetsGeometry> marginAt(Size size) async {
        final items = [
          ImageItem.stored(
            const NewImage(file: 'a.png', width: 10, height: 10),
          ),
          ImageItem.stored(
            const NewImage(file: 'b.png', width: 10, height: 10),
          ),
        ];
        await show(
          tester,
          Padding(
            padding: const EdgeInsets.all(20),
            child: ImagePickerField(
              pitId: pitId,
              items: items,
              onAdd: () {},
              onRemove: (_) {},
            ),
          ),
          size: size,
        );
        final c = tester.widget<Container>(
          find.byKey(const ValueKey('sensitiveMarkAll')),
        );
        return c.margin!;
      }

      expect((await marginAt(land)).vertical, 16);
      await unmount(tester);
      expect((await marginAt(const Size(390, 844))).vertical, 12);
      await unmount(tester);
    });
  });

  group('其他 iPad 畫面不繞過閘門', () {
    testWidgets('坑頁（平板）的格子封面也經過 SensitiveGate（跟手機一樣；已標記的圖本來就不會被選成封面）', (
      tester,
    ) async {
      final group = (await tester.runAsync(() => db.watchGroups(pitId).first))!
          .first;
      await tester.runAsync(
        () => db.addOfficial(pitId, group.id, const [
          NewImage(file: 'b.png', width: 100, height: 100),
          NewImage(file: 'a.png', width: 100, height: 100, sensitive: true),
        ]),
      );
      await show(tester, PitPage(pitId: pitId));
      final tile = find.descendant(
        of: find.byType(PitPageTablet),
        matching: find.byType(SensitiveGate),
      );
      expect(tile, findsWidgets);
      // 官方圖冊格子的封面是沒標記的 b.png，不是 a.png。
      expect(tester.widget<SensitiveGate>(tile.first).file, 'b.png');
      expect(find.byKey(blur), findsNothing);
      await unmount(tester);
    });

    testWidgets('確認框（P-037）：沿用手機的樣子，iPad 上不隨視窗拉寬', (tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => confirmSensitiveMasterOff(context),
              child: const Text('開'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開'));
      await settle(tester);
      final box = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('sensitiveConfirm')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(box.width, lessThanOrEqualTo(340));
      expect(box.center.dx, closeTo(land.width / 2, 1));
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
