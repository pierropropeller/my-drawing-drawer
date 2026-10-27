import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart' show StoredImage;
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:huakeng/ui/material/material_library_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeShareChannel extends ShareChannel {
  _FakeShareChannel({this.initial = const []});
  final List<String> initial;

  @override
  Future<List<String>> getInitialShare() async => initial;

  @override
  void setOnShare(void Function(List<String> paths)? cb) {}
}

/// 素材庫 UI（D-071）：列表／九宮格、分類 pills、多選（移動／刪除／全選）、加圖、
/// 導覽列規則、「我的」的素材庫卡、分享進來的「坑｜素材庫」。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('material_ui');
    await Directory('${tmp.path}/images').create(recursive: true);
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  List<Override> overrides({List<XFile> pick = const []}) => [
    databaseProvider.overrideWithValue(db),
    sharedPrefsProvider.overrideWithValue(prefs),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${tmp.path}/images')),
    ),
    imagePickerProvider.overrideWithValue((_) async => pick),
    // 素材庫自己的加圖直接開相簿（不經加圖來源選單）。
    photoPickerProvider.overrideWithValue((_) async => pick),
  ];

  Future<void> showPage(
    WidgetTester tester,
    Widget page, {
    Map<String, Object> initialPrefs = const {},
    List<XFile> pick = const [],
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      ...initialPrefs,
    });
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(pick: pick),
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
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<List<String>> seed(
    MaterialCategory c,
    int n, {
    String prefix = 'm',
  }) async {
    return db.addMaterials(c, [
      for (var i = 0; i < n; i++)
        NewImage(file: '$prefix-${c.name}-$i.png', width: 30, height: 40 + i),
    ]);
  }

  Future<List<MaterialImage>> rows() => db.select(db.materialImages).get();

  /// 掛在 Scaffold 底下才看得到導覽列行為：用 navBarHiddenCount 觀察。
  Finder tiles() => find.byType(StoredImage);

  testWidgets('空狀態：沒有素材時沒有 pills 與右下加號，有「加圖」按鈕', (tester) async {
    await showPage(tester, const MaterialLibraryPage());
    expect(find.text('素材庫'), findsOneWidget);
    expect(find.text('還沒有素材'), findsOneWidget);
    expect(find.text('加圖'), findsOneWidget);
    expect(find.text('服裝'), findsNothing);
    expect(find.bySemanticsLabel('加素材'), findsNothing);
    await unmount(tester);
  });

  testWidgets('列表：標題、張數、全部＋7 個分類 pills，點分類只剩該分類', (tester) async {
    await tester.runAsync(() async {
      await seed(MaterialCategory.clothing, 3);
      await seed(MaterialCategory.pose, 2);
    });
    await showPage(tester, const MaterialLibraryPage());
    expect(find.text('5 張'), findsOneWidget);
    for (final c in ['全部', '服裝', '姿勢', '人體', '色盤', '場景', '畫風', '貼圖']) {
      expect(find.text(c), findsOneWidget);
    }
    expect(tiles(), findsNWidgets(5));

    await tester.tap(find.text('姿勢'));
    await settle(tester);
    expect(find.text('2 張'), findsOneWidget);
    expect(tiles(), findsNWidgets(2));

    await tester.tap(find.text('人體'));
    await settle(tester);
    expect(find.text('還沒有素材'), findsOneWidget);
    // 瀏覽時導覽列不被隱藏。
    expect(navBarHiddenCount.value, 0);
    await unmount(tester);
  });

  testWidgets('initialCategory：直接停在該分類', (tester) async {
    await tester.runAsync(() async {
      await seed(MaterialCategory.clothing, 1);
      await seed(MaterialCategory.style, 2);
    });
    await showPage(
      tester,
      const MaterialLibraryPage(initialCategory: MaterialCategory.style),
    );
    expect(find.text('2 張'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('版面切換：瀑布｜九宮格，記住上次選擇', (tester) async {
    await tester.runAsync(() => seed(MaterialCategory.pose, 4));
    await showPage(tester, const MaterialLibraryPage());
    expect(find.byType(GridView), findsNothing);
    await tester.tap(find.bySemanticsLabel('九宮格'));
    await settle(tester);
    expect(find.byType(GridView), findsOneWidget);
    expect(prefs.getString('materialLayout'), 'grid');
    await unmount(tester);

    // 下次進來停在九宮格。
    await showPage(
      tester,
      const MaterialLibraryPage(),
      initialPrefs: {'materialLayout': 'grid'},
    );
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('瀑布'));
    await settle(tester);
    expect(find.byType(GridView), findsNothing);
    expect(prefs.getString('materialLayout'), 'waterfall');
    await unmount(tester);
  });

  testWidgets('點圖開預覽（ImageGalleryPage）', (tester) async {
    await tester.runAsync(() => seed(MaterialCategory.pose, 3));
    await showPage(tester, const MaterialLibraryPage());
    await tester.tap(tiles().first);
    await settle(tester);
    expect(find.byType(ImageGalleryPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('多選：長按進入、導覽列隱藏；全選、取消全選、關閉退出', (tester) async {
    await tester.runAsync(() => seed(MaterialCategory.pose, 3));
    await showPage(tester, const MaterialLibraryPage());
    expect(navBarHiddenCount.value, 0);

    await tester.longPress(tiles().first);
    await settle(tester);
    expect(find.text('已選 1 張'), findsOneWidget);
    expect(navBarHiddenCount.value, 1);
    // 底部四個動作。
    for (final a in ['分享', '下載', '移動', '刪除']) {
      expect(find.text(a), findsOneWidget);
    }
    // 沒有右下加號。
    expect(find.bySemanticsLabel('加素材'), findsNothing);

    await tester.tap(tiles().at(1));
    await settle(tester);
    expect(find.text('已選 2 張'), findsOneWidget);

    await tester.tap(find.text('全選'));
    await settle(tester);
    expect(find.text('已選 3 張'), findsOneWidget);
    expect(find.text('取消全選'), findsOneWidget);

    await tester.tap(find.byTooltip('取消選擇'));
    await settle(tester);
    expect(find.text('素材庫'), findsOneWidget);
    expect(navBarHiddenCount.value, 0);
    await unmount(tester);
  });

  testWidgets('多選「移動」：sheet 列出 7 個分類與張數，改分類', (tester) async {
    await tester.runAsync(() async {
      await seed(MaterialCategory.pose, 3);
      await seed(MaterialCategory.clothing, 2);
    });
    await showPage(tester, const MaterialLibraryPage());
    await tester.tap(find.text('姿勢'));
    await settle(tester);
    await tester.longPress(tiles().first);
    await settle(tester);
    await tester.tap(find.text('全選'));
    await settle(tester);
    await tester.tap(find.text('移動'));
    await settle(tester);

    expect(find.text('移動到'), findsOneWidget);
    expect(find.text('3 張'), findsWidgets);
    for (final c in MaterialCategory.values) {
      expect(find.byKey(ValueKey('materialCat-${c.name}')), findsOneWidget);
    }
    // 服裝 2 張、姿勢 3 張。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('materialCat-clothing')),
        matching: find.text('2 張'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('materialCat-scene')));
    await settle(tester);
    // 按鈕「移動」（sheet 內）。
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('移動')),
    );
    await settle(tester);

    final all = (await tester.runAsync(rows))!;
    expect(all.where((r) => r.category == MaterialCategory.scene).length, 3);
    expect(all.where((r) => r.category == MaterialCategory.clothing).length, 2);
    // 退出多選。
    expect(find.text('素材庫'), findsOneWidget);
    expect(navBarHiddenCount.value, 0);
    await unmount(tester);
  });

  testWidgets('多選「刪除」：要確認，確認後軟刪除', (tester) async {
    await tester.runAsync(() => seed(MaterialCategory.body, 3));
    await showPage(tester, const MaterialLibraryPage());
    await tester.longPress(tiles().first);
    await settle(tester);
    await tester.tap(find.text('刪除'));
    await settle(tester);
    expect(find.text('刪除 1 項？'), findsOneWidget);
    // 取消＝不刪。
    await tester.tap(find.text('取消'));
    await settle(tester);
    expect(
      (await tester.runAsync(rows))!.every((r) => r.deletedAt == null),
      isTrue,
    );

    await tester.tap(find.text('刪除'));
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('刪除')),
    );
    await settle(tester);
    final live = (await tester.runAsync(rows))!
        .where((r) => r.deletedAt == null);
    expect(live.length, 2);
    expect(find.text('2 張'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('在分類下加圖：直接歸該分類', (tester) async {
    final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png1x1);
    await tester.runAsync(() => seed(MaterialCategory.palette, 1));
    await showPage(
      tester,
      const MaterialLibraryPage(initialCategory: MaterialCategory.palette),
      pick: [XFile(f.path)],
    );
    await tester.tap(find.bySemanticsLabel('加素材'));
    await settle(tester, rounds: 30);
    expect(find.text('加入到'), findsNothing);
    final all = (await tester.runAsync(rows))!;
    expect(all.length, 2);
    expect(all.every((r) => r.category == MaterialCategory.palette), isTrue);
    final added = all.firstWhere((r) => !r.imageFile.startsWith('m-'));
    expect(added.width, 1);
    expect(added.height, 1);
    await unmount(tester);
  });

  testWidgets('在「全部」下加圖：先彈出選分類，選了才存；取消不存', (tester) async {
    final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png1x1);
    await tester.runAsync(() => seed(MaterialCategory.palette, 1));
    await showPage(tester, const MaterialLibraryPage(), pick: [XFile(f.path)]);
    await tester.tap(find.bySemanticsLabel('加素材'));
    await settle(tester);
    expect(find.text('加入到'), findsOneWidget);
    // 沒選分類時按鈕不能按。
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('加入')),
    );
    await settle(tester);
    expect(find.text('加入到'), findsOneWidget);

    // 取消（點遮罩外）：沒有存。
    await tester.tapAt(const Offset(20, 100));
    await settle(tester);
    expect((await tester.runAsync(rows))!.length, 1);

    await tester.tap(find.bySemanticsLabel('加素材'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('materialCat-sticker')));
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('加入')),
    );
    await settle(tester, rounds: 30);
    final all = (await tester.runAsync(rows))!;
    expect(all.length, 2);
    expect(all.where((r) => r.category == MaterialCategory.sticker).length, 1);
    await unmount(tester);
  });

  testWidgets('深色模式：列表、九宮格、多選都能畫出來', (tester) async {
    await tester.runAsync(() => seed(MaterialCategory.pose, 4));
    await showPage(
      tester,
      const MaterialLibraryPage(),
      dark: true,
      initialPrefs: {'materialLayout': 'grid'},
    );
    await tester.longPress(tiles().first);
    await settle(tester);
    expect(find.text('已選 1 張'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  group('整個 App', () {
    Future<void> pumpApp(
      WidgetTester tester, {
      List<String> initialShare = const [],
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'onboarded': true});
      prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            shareChannelProvider.overrideWithValue(
              _FakeShareChannel(initial: initialShare),
            ),
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
    }

    testWidgets('「我的」的素材庫卡：顯示總張數，點了開素材庫（導覽列仍在）', (tester) async {
      await tester.runAsync(() async {
        await seed(MaterialCategory.pose, 3);
        await seed(MaterialCategory.scene, 2);
      });
      await pumpApp(tester);
      await tester.tap(find.text('我的').last);
      await settle(tester);
      expect(find.text('素材庫'), findsOneWidget);
      expect(find.text('5 張'), findsOneWidget);

      await tester.tap(find.text('素材庫'));
      await settle(tester);
      expect(find.byType(MaterialLibraryPage), findsOneWidget);
      expect(navBarHiddenCount.value, 0);
      expect(find.text('時間軸'), findsOneWidget); // 導覽列還在

      // 返回「我的」。
      await tester.tap(find.byTooltip('返回'));
      await settle(tester);
      expect(find.byType(MaterialLibraryPage), findsNothing);
      await unmount(tester);
    });

    Finder inSheet(Finder f) =>
        find.descendant(of: find.byType(ShareSheet), matching: f);

    testWidgets('分享進來：切到「素材庫」段，選分類、加入，停在該分類的素材庫頁', (tester) async {
      final f = File('${tmp.path}/in0.png')..writeAsBytesSync(_png1x1);
      final g = File('${tmp.path}/in1.png')..writeAsBytesSync(_png1x1);
      await pumpApp(tester, initialShare: [f.path, g.path]);
      expect(find.byType(ShareSheet), findsOneWidget);
      // 預設「坑」段；切換在最上面。
      expect(inSheet(find.text('位置')), findsOneWidget);
      expect(inSheet(find.text('分類')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('shareDestMaterial')));
      await settle(tester);
      expect(inSheet(find.text('位置')), findsNothing);
      expect(inSheet(find.text('分類')), findsOneWidget);
      for (final c in ['服裝', '姿勢', '人體', '色盤', '場景', '畫風', '貼圖']) {
        expect(inSheet(find.text(c)), findsOneWidget);
      }
      // 素材庫段按鈕一律是「加入」。
      expect(inSheet(find.text('加入')), findsOneWidget);
      expect(inSheet(find.text('下一步')), findsNothing);

      await tester.tap(inSheet(find.text('畫風')));
      await settle(tester);
      await tester.tap(inSheet(find.text('加入')));
      await settle(tester, rounds: 40);

      final all = (await tester.runAsync(rows))!;
      expect(all.length, 2);
      expect(all.every((r) => r.category == MaterialCategory.style), isTrue);
      expect(all.every((r) => r.width == 1 && r.height == 1), isTrue);
      expect(File(f.path).existsSync(), isFalse);
      expect(find.byType(ShareSheet), findsNothing);
      expect(find.text('已加入'), findsOneWidget);
      // 停在「我的」分頁的素材庫頁，分類是畫風。
      expect(find.byType(MaterialLibraryPage), findsOneWidget);
      expect(find.text('2 張'), findsOneWidget);
      expect(prefs.getString('shareLastDest'), 'material');
      await unmount(tester);
    });

    testWidgets('下次分享預設停在上次用的那段與分類', (tester) async {
      final f = File('${tmp.path}/in0.png')..writeAsBytesSync(_png1x1);
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'shareLastDest': 'material',
        'shareLastMaterial': 'body',
      });
      prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            shareChannelProvider.overrideWithValue(
              _FakeShareChannel(initial: [f.path]),
            ),
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
      expect(inSheet(find.text('分類')), findsOneWidget);
      await tester.tap(inSheet(find.text('加入')));
      await settle(tester, rounds: 40);
      final all = (await tester.runAsync(rows))!;
      expect(all.single.category, MaterialCategory.body);
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
