import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/adaptive_modal.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/junk/junk_list_page.dart';
import 'package:huakeng/ui/media_source/drop_zone.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/media_source/media_source_menu.dart';
import 'package:huakeng/ui/media_source/media_source_services.dart';
import 'package:huakeng/ui/common/dashed_box.dart';
import 'package:huakeng/ui/nav/nav_rail.dart';
import 'package:huakeng/ui/nav/nav_sidebar.dart';
import 'package:huakeng/ui/shell.dart';
import 'package:huakeng/ui/sync/sync_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// P-022：iPad 先有的元件在深色主題下取自深色 token（不寫死淺色值）。
/// 設 `DARK_SHOTS=<資料夾>` 會把每個情境輸出成 PNG，方便人工對照 `*Dark` 設計稿。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const phone = Size(390, 844);
  const split = Size(400, 900);
  const portrait = Size(834, 1194);
  const land = Size(1194, 834);

  /// 目前主題（預設玫瑰）的深色 token。
  final d = buildTheme(
    Brightness.dark,
    useGoogleFonts: false,
  ).extension<AppTokens>()!;

  late AppDatabase db;
  late Directory dir;
  late String pitId;
  final shotKey = GlobalKey();

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipaddark');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '坑A');
    await db.createPit(name: '坑B');
    final official = await db.watchGroups(pitId).first;
    await db.addOfficial(pitId, official.first.id, const [
      NewImage(file: 'a.png', width: 100, height: 200),
      NewImage(file: 'b.png', width: 300, height: 100),
    ]);
    final fan = await db.watchGroups(pitId, kind: 'fan').first;
    await db.addFanArts(
      pitId,
      const [
        NewImage(file: 'a.png', width: 100, height: 200),
        NewImage(file: 'b.png', width: 300, height: 100),
      ],
      author: '@作者甲',
      groupId: fan.first.id,
    );
    await db.saveIdea(
      pitId: pitId,
      title: '天台看煙花',
      body: '兩人在夏日祭典結束後偷偷溜上天台',
      images: const [NewImage(file: 'a.png')],
      tagIds: const [],
      draftIds: const [],
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

  Future<void> shot(WidgetTester tester, String name) async {
    final out = Platform.environment['DARK_SHOTS'];
    if (out == null) return;
    await tester.runAsync(() async {
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> show(
    WidgetTester tester,
    Widget page,
    Size size, {
    bool dark = true,
  }) async {
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
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
        ],
        child: RepaintBoundary(
          key: shotKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
            home: page,
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

  /// 找 [f]（含其子孫）範圍內所有 Container／DecoratedBox／Material 的背景色，依樹的順序。
  Iterable<Color> backgrounds(Finder f) sync* {
    final widgets = <Widget>[
      ...f.evaluate().map((e) => e.widget),
      ...find
          .descendant(of: f, matching: find.byWidgetPredicate((_) => true))
          .evaluate()
          .map((e) => e.widget),
    ];
    for (final w in widgets) {
      Color? c;
      if (w is Container) {
        c =
            w.color ??
            (w.decoration is BoxDecoration
                ? (w.decoration! as BoxDecoration).color
                : null);
      } else if (w is DecoratedBox && w.decoration is BoxDecoration) {
        c = (w.decoration as BoxDecoration).color;
      } else if (w is Material) {
        c = w.color;
      }
      if (c != null) yield c;
    }
  }

  /// 目前畫面上所有「大面積」背景色（Container／DecoratedBox／ColoredBox／Material）。
  Set<Color> lightBackgrounds(WidgetTester tester) {
    final out = <Color>{};
    void add(Color? c) {
      if (c == null || c.a < .5) return;
      if (c.computeLuminance() > .45) out.add(c);
    }

    for (final e in find.byWidgetPredicate((_) => true).evaluate()) {
      final w = e.widget;
      if (w is Container) {
        add(w.color);
        final dec = w.decoration;
        if (dec is BoxDecoration) add(dec.color);
      } else if (w is DecoratedBox) {
        final dec = w.decoration;
        if (dec is BoxDecoration) add(dec.color);
      } else if (w is AnimatedContainer) {
        final dec = w.decoration;
        if (dec is BoxDecoration) add(dec.color);
      } else if (w is Ink) {
        final dec = w.decoration;
        if (dec is BoxDecoration) add(dec.color);
      } else if (w is ColoredBox) {
        add(w.color);
      } else if (w is Material) {
        add(w.color);
      }
    }
    return out;
  }

  /// 深色下畫面上不可以有淺色大面積底（只有「選中」膠囊／列的米白 #F2ECE4＝ink 例外）。
  void expectDark(WidgetTester tester) {
    expect(lightBackgrounds(tester).difference({d.ink}), isEmpty);
  }

  group('Shell 深色', () {
    for (final s in {'1194': land, '834': portrait, '390': phone}.entries) {
      testWidgets('AppShell ${s.key}', (tester) async {
        await show(tester, const AppShell(), s.value);
        await shot(tester, 'shell_${s.key}');
        expectDark(tester);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(
          scaffold.backgroundColor ??
              Theme.of(tester.element(find.byType(Scaffold).first))
                  .scaffoldBackgroundColor,
          d.ground,
        );
        await unmount(tester);
      });
    }
  });

  group('列表＋詳情 深色', () {
    testWidgets('IdeaListPage 1194', (tester) async {
      await show(tester, IdeaListPage(pitId: pitId), land);
      await shot(tester, 'idea_list_1194');
      await tester.tap(find.text('天台看煙花').first);
      await settle(tester);
      await shot(tester, 'idea_detail_1194');
      expectDark(tester);
      await unmount(tester);
    });
  });

  group('視覺輸出', () {
    final pages = <String, Widget Function()>{
      'pit': () => PitPage(pitId: pitId),
      'official': () => OfficialListPage(pitId: pitId),
      'fan': () => FanArtListPage(pitId: pitId),
      'junk': () => JunkListPage(pitId: pitId),
      'draft': () => DraftListPage(pitId: pitId),
      'finished': () => FinishedListPage(pitId: pitId),
      'oshi': () => OshiListPage(pitId: pitId),
    };
    for (final e in pages.entries) {
      testWidgets('頁面 ${e.key} 1194', (tester) async {
        await show(
          tester,
          Row(
            children: [
              const SizedBox(width: 84),
              Expanded(child: e.value()),
            ],
          ),
          land,
        );
        await shot(tester, 'page_${e.key}_1194');
        expectDark(tester);
        await unmount(tester);
      });
    }
    for (final sz in {'1194': land, '400': split}.entries) {
      testWidgets('表單 ${sz.key}', (tester) async {
        await show(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showAdaptiveModal<void>(
                      context,
                      builder: (_, asModal) =>
                          DraftFormPage(pitId: pitId, asModal: asModal),
                    ),
                    child: const Text('A'),
                  ),
                  TextButton(
                    onPressed: () => showAdaptiveModal<void>(
                      context,
                      builder: (_, asModal) => PitNewPage(asModal: asModal),
                    ),
                    child: const Text('B'),
                  ),
                  TextButton(
                    onPressed: () => showAdaptiveModal<void>(
                      context,
                      builder: (_, asModal) =>
                          OfficialNewPage(pitId: pitId, asModal: asModal),
                    ),
                    child: const Text('C'),
                  ),
                ],
              ),
            ),
          ),
          sz.value,
        );
        for (final k in ['A', 'B', 'C']) {
          await tester.tap(find.text(k));
          await settle(tester);
          await shot(tester, 'form_${k}_${sz.key}');
          expectDark(tester);
          tester.state<NavigatorState>(find.byType(Navigator).first).pop();
          await settle(tester);
        }
        await unmount(tester);
      });
    }
    for (final e in {
      'official': () => OfficialListPage(pitId: pitId),
      'fan': () => FanArtListPage(pitId: pitId),
    }.entries) {
      testWidgets('圖冊選取後的預覽面板 ${e.key}', (tester) async {
        await show(tester, e.value(), land);
        await shot(tester, 'panel_${e.key}_before');
        await tester.tap(
          find
              .descendant(
                of: find.byType(MasonryGridView),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        await settle(tester);
        await shot(tester, 'panel_${e.key}');
        expectDark(tester);
        await unmount(tester);
      });
    }
    testWidgets('拖放接收區', (tester) async {
      await show(
        tester,
        Scaffold(
          body: Stack(
            children: const [
              SizedBox.expand(),
              Positioned.fill(
                child: DropHighlightBanner(
                  title: '放開即可加入「官方圖冊」',
                  subtitle: '3 張',
                ),
              ),
            ],
          ),
        ),
        land,
      );
      await shot(tester, 'dropzone');
      await unmount(tester);
    });
  });

  group('加圖', () {
    Future<void> open(
      WidgetTester tester,
      Size size, {
      bool dark = true,
      Uint8List? preview,
    }) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMediaSourceMenu(
                context,
                options: AddSourceOptions(
                  clipboard: ClipboardProbe.image,
                  clipboardPreview: preview,
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
        size,
        dark: dark,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
    }

    testWidgets('400 sheet 深色：取自深色 token', (tester) async {
      await open(tester, split);
      await shot(tester, 'media_sheet_dark');
      final sheet = find.byKey(const Key('media-source-sheet'));
      expect(backgrounds(sheet).first, d.nav);
      final clip = tester.widget<Container>(
        find.byKey(const Key('media-source-clipboard')),
      );
      expect((clip.decoration! as BoxDecoration).color, d.surface);
      await unmount(tester);
    });

    testWidgets('400 sheet 淺色', (tester) async {
      await open(tester, split, dark: false);
      await shot(tester, 'media_sheet_light');
      final sheet = find.byKey(const Key('media-source-sheet'));
      expect(backgrounds(sheet).first, AppTokens.light.ground);
      await unmount(tester);
    });

    testWidgets('popover 深色：icon 底用 soft 色系，不是淺色 pastel', (tester) async {
      await open(tester, portrait);
      await shot(tester, 'media_popover_dark');
      final menu = find.byType(MediaSourceMenu);
      expect(backgrounds(menu).first, d.surface);
      final tiles = find.descendant(
        of: menu,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 36 &&
              w.constraints?.maxHeight == 36,
        ),
      );
      expect(tiles, findsNWidgets(5));
      final colors = tiles
          .evaluate()
          .map(
            (e) =>
                ((e.widget as Container).decoration! as BoxDecoration).color!,
          )
          .toList();
      expect(colors[0], d.accentSoft); // 照片
      expect(colors[2], d.accentSoft); // 素材庫
      expect(colors[4], d.chipBg); // 貼上
      for (final c in colors) {
        expect(c.computeLuminance(), lessThan(.1));
      }
      await unmount(tester);
    });

    testWidgets('400 sheet：四格、文字色、剪貼簿膠囊取自 token', (tester) async {
      await open(tester, split);
      for (final k in ['photos', 'files', 'materials', 'camera']) {
        final tile = tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(Key('media-source-$k')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(tile.color, d.surface, reason: k);
        final shape = tile.shape! as RoundedRectangleBorder;
        expect(shape.side.color, d.border, reason: k);
      }
      final pill = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const Key('media-source-paste')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(pill.color, d.accentSoft);
      final close = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('media-source-close')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((close.decoration! as BoxDecoration).color, d.chipBg);
      await unmount(tester);
    });

    testWidgets('400 sheet：剪貼簿沒有圖片時整行不出現', (tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMediaSourceMenu(
                context,
                options: const AddSourceOptions(),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
        split,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
      expect(find.byKey(const Key('media-source-sheet')), findsOneWidget);
      expect(find.byKey(const Key('media-source-clipboard')), findsNothing);
      expect(find.byKey(const Key('media-source-paste')), findsNothing);
      await unmount(tester);
    });

    testWidgets('400 sheet：往下拉關閉、點外面關閉', (tester) async {
      await open(tester, split);
      await tester.drag(
        find.byKey(const Key('media-source-sheet')),
        const Offset(0, 300),
      );
      await settle(tester);
      expect(find.byKey(const Key('media-source-sheet')), findsNothing);
      await open(tester, split);
      await tester.tapAt(const Offset(200, 40));
      await settle(tester);
      expect(find.byKey(const Key('media-source-sheet')), findsNothing);
      await unmount(tester);
    });
  });

  group('同步／拖放／導覽 深色 token', () {
    testWidgets('SyncColors 深色＝稿的同步藍', (tester) async {
      await show(tester, const SizedBox(), land);
      final c = SyncColors.of(tester.element(find.byType(SizedBox).first));
      expect(c.progress, const Color(0xFF7F9DBB));
      expect(c.track, const Color(0xFF2E3A46));
      expect(c.strong, const Color(0xFF93AECB));
      await unmount(tester);
    });

    testWidgets('拖放接收區：accent 虛線框＋soft 半透明底', (tester) async {
      await show(
        tester,
        const Scaffold(
          body: DropHighlightBanner(title: '放開', subtitle: '3 張'),
        ),
        land,
      );
      final box = tester.widget<DashedBox>(find.byType(DashedBox));
      expect(box.color, d.accent);
      expect(box.fill, d.accentSoft.withValues(alpha: .72));
      await unmount(tester);
    });

    testWidgets('sidebar（260）與 icon rail（84）的底是 nav 色', (tester) async {
      await show(tester, const AppShell(), land);
      final side = find.byType(NavSidebar);
      expect(side, findsOneWidget);
      expect(tester.getSize(side).width, 260);
      expect(backgrounds(side).first, d.nav);
      await unmount(tester);
      await show(tester, const AppShell(), portrait);
      final rail = find.byType(NavRail);
      expect(rail, findsOneWidget);
      expect(tester.getSize(rail).width, 84);
      expect(backgrounds(rail).first, d.nav);
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
