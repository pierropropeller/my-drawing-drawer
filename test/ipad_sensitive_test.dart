import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
import 'package:huakeng/ui/album/wide_layout.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/sensitive_dialogs.dart';
import 'package:huakeng/ui/common/sensitive_gate.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
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
      expect(inPanel(find.byKey(badge)), findsOneWidget);
      expect(inPanel(find.byKey(blur)), findsNothing);
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
