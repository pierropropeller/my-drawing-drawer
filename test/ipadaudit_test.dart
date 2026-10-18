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
import 'package:huakeng/ui/album/fan_art_new_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/goals/goal_new_page.dart';
import 'package:huakeng/ui/oshi/oshi_form_page.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/device_class.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/media_source/media_source_menu.dart';
import 'package:huakeng/ui/media_source/media_source_services.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 稽核＋補齊（iPad 設計稿 design-ipad2）：預覽頁、新增頁（form sheet／page sheet）、加圖選單、分享匯入。
/// 窄視窗（約 400）的 iPad 用 400 版（page sheet、參考圖檢視 RespRef400）；手機版面不變。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const phone = Size(390, 844);
  const split = Size(400, 900); // iPad 分屏窄視窗
  const medium = Size(700, 1000);
  const portrait = Size(834, 1194);
  const land = Size(1194, 834);
  const big = Size(1366, 1024);

  late AppDatabase db;
  late Directory dir;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipadaudit');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png']) {
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
    await db.saveDraft(
      pitId: pitId,
      title: '構圖草稿',
      images: const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
      ],
      tagIds: const [],
      ideaIds: const [],
    );
    await db.addFanArts(
      pitId,
      const [
        NewImage(file: 'a.png', width: 100, height: 200),
        NewImage(file: 'b.png', width: 300, height: 100),
      ],
      author: '@作者甲',
      groupId: fan.first.id,
    );
  });

  tearDown(() async {
    debugTabletDeviceOverride = null;
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

  Future<void> show(
    WidgetTester tester,
    Widget page,
    Size size, {
    MediaSourceServices? services,
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
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
          if (services != null)
            mediaSourceServicesProvider.overrideWithValue(services),
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
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    navBarHiddenCount.value = 0;
  }

  Finder firstThumb() => find
      .descendant(
        of: find.byType(MasonryGridView),
        matching: find.byType(GestureDetector),
      )
      .first;

  group('預覽頁：iPad 窄視窗（RespRef400）用參考圖檢視，手機維持原預覽', () {
    testWidgets('iPad 400：同人圖點圖＝參考圖檢視（底部縮圖列＋icon 工具列），沒有手機預覽', (tester) async {
      debugTabletDeviceOverride = true;
      await show(tester, FanArtListPage(pitId: pitId), split);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.byType(FanArtPreviewPage), findsOneWidget);
      expect(find.byType(AlbumReferenceScreen), findsOneWidget);
      expect(find.byType(ReferenceViewer), findsOneWidget);
      // 標題「坑A · 好看同人圖」、頁碼；窄版不可出現寬版的右側資料面板。
      expect(find.text('坑A · 好看同人圖'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      expect(find.bySemanticsLabel(l.refviewPanel), findsNothing);
      // 返回回到列表。
      await tester.tap(find.bySemanticsLabel(l.commonBack));
      await settle(tester);
      expect(find.byType(ReferenceViewer), findsNothing);
      expect(find.byType(MasonryGridView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('iPad 400：官方圖冊同樣', (tester) async {
      debugTabletDeviceOverride = true;
      await show(tester, OfficialListPage(pitId: pitId), split);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.byType(ImagePreviewPage), findsOneWidget);
      expect(find.byType(ReferenceViewer), findsOneWidget);
      expect(find.text('坑A · 官方圖冊'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機 390：照舊手機預覽（沒有參考圖檢視）', (tester) async {
      await show(tester, FanArtListPage(pitId: pitId), phone);
      await tester.tap(firstThumb());
      await settle(tester);
      expect(find.byType(FanArtPreviewPage), findsOneWidget);
      expect(find.byType(ReferenceViewer), findsNothing);
      await unmount(tester);
    });

    testWidgets('寬版面板的「參考檢視」開參考圖檢視，不是手機預覽', (tester) async {
      await show(tester, OfficialListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(firstThumb());
      await settle(tester);
      await tester.tap(find.text(l.ipadListsReferenceView));
      await settle(tester);
      expect(find.byType(ReferenceViewerPage), findsOneWidget);
      expect(find.byType(ImagePreviewPage), findsNothing);
      // 1194 寬＝RefFull：有資料面板開關。
      expect(find.bySemanticsLabel(l.refviewPanel), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('參考圖檢視拉窗：1194 ↔ 400 不丟張數與選中', (tester) async {
      debugTabletDeviceOverride = true;
      await show(tester, FanArtListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(firstThumb());
      await settle(tester);
      await tester.tap(find.text(l.ipadListsReferenceView));
      await settle(tester);
      expect(find.byType(ReferenceViewer), findsOneWidget);
      await resize(tester, split);
      expect(find.byType(ReferenceViewer), findsOneWidget);
      expect(find.bySemanticsLabel(l.refviewPanel), findsNothing);
      await resize(tester, land);
      expect(find.bySemanticsLabel(l.refviewPanel), findsOneWidget);
      await unmount(tester);
    });
  });

  group('摸魚詳情面板的「參考檢視」', () {
    testWidgets('1194：開參考圖檢視（標題「坑A · 我的摸魚」、2 張），不是舊的全螢幕看圖', (tester) async {
      await show(tester, DraftListPage(pitId: pitId), land);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.tap(find.text('構圖草稿').first);
      await settle(tester);
      await tester.tap(find.text(l.ipadListsReferenceView));
      await settle(tester);
      expect(find.byType(ReferenceViewerPage), findsOneWidget);
      expect(find.text('坑A · 我的摸魚'), findsOneWidget);
      expect(find.text('1 / 2'), findsWidgets);
      await unmount(tester);
    });
  });

  group('加圖來源選單', () {
    Future<AddSource?> openMenu(WidgetTester tester, Size size) async {
      AddSource? picked;
      var done = false;
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showMediaSourceMenu(
                  context,
                  options: const AddSourceOptions(
                    clipboard: ClipboardProbe.image,
                  ),
                );
                done = true;
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
        size,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
      expect(done, false);
      return picked;
    }

    testWidgets('400：底部 action sheet，另有獨立的取消鈕', (tester) async {
      await openMenu(tester, split);
      expect(find.byType(MediaSourceActionSheet), findsOneWidget);
      expect(find.byType(MediaSourcePopover), findsNothing);
      expect(find.text('加圖來源'), findsOneWidget);
      expect(find.byKey(const Key('media-source-photos')), findsOneWidget);
      expect(find.byKey(const Key('media-source-paste')), findsOneWidget);
      // 取消關閉選單。
      await tester.tap(find.byKey(const Key('media-source-cancel')));
      await settle(tester);
      expect(find.byType(MediaSourceActionSheet), findsNothing);
      await unmount(tester);
    });

    testWidgets('700：popover（有箭頭／沒有取消鈕）', (tester) async {
      await openMenu(tester, medium);
      expect(find.byType(MediaSourcePopover), findsOneWidget);
      expect(find.byType(MediaSourceActionSheet), findsNothing);
      expect(find.byKey(const Key('media-source-cancel')), findsNothing);
      await unmount(tester);
    });
  });

  group('彈出表單 ↔ 視窗闊度', () {
    testWidgets('開新坑：1194 輸入後拉到 400 變 page sheet（短按鈕「建立」），內容不丟', (
      tester,
    ) async {
      debugTabletDeviceOverride = true;
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNewPit(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
        land,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pit-name')), '新坑名');
      await resize(tester, split);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('form-sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('form-sheet-peek')), findsOneWidget);
      expect(find.text('新坑名'), findsOneWidget);
      // 窄：標題列 52 高。
      final header = find.ancestor(
        of: find.text('取消'),
        matching: find.byType(Container),
      );
      expect(
        tester.getSize(header.first).height,
        52,
        reason: 'page sheet 標題列 52 高',
      );
      await resize(tester, portrait);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('新坑名'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機 390：開新坑仍是整頁', (tester) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openNewPit(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
        phone,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('form-sheet')), findsNothing);
      expect(find.byType(PitNewPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('分享匯入（ShareImport／ShareImport400）', () {
    Future<void> openShare(WidgetTester tester, Size size) async {
      final file = File('${dir.path}/images/a.png');
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showShareSheet(context, paths: [file.path]),
              child: const Text('OPEN'),
            ),
          ),
        ),
        size,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
    }

    double cellWidth(WidgetTester tester) =>
        tester.getSize(find.text('官方圖冊').last).width;

    testWidgets('1194：置中 720×760 對話框', (tester) async {
      await openShare(tester, land);
      expect(find.byType(Dialog), findsOneWidget);
      final size = tester.getSize(find.byType(ShareSheet));
      expect(size.width, 720);
      expect(size.height, 760);
      await unmount(tester);
    });

    testWidgets('700：仍是置中對話框（≥600）', (tester) async {
      debugTabletDeviceOverride = true;
      await openShare(tester, medium);
      expect(find.byType(Dialog), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('iPad 400：全闊 page sheet，位置 4 欄一排', (tester) async {
      debugTabletDeviceOverride = true;
      await openShare(tester, split);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('form-sheet')), findsOneWidget);
      // 分享頁沒有抓握條與露出底層的灰條（ShareImport400）。
      expect(find.byKey(const ValueKey('form-sheet-peek')), findsNothing);
      expect(find.text('加入到畫匣'), findsOneWidget);
      // 4 欄：第一格和第五格不同一排。
      final first = tester.getTopLeft(find.text('官方圖冊').last);
      expect(cellWidth(tester), greaterThan(0));
      expect(first.dx, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('手機 390：維持 bottom sheet', (tester) async {
      await openShare(tester, phone);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('form-sheet')), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      await unmount(tester);
    });
  });

  group('所有新增頁在各視窗尺寸：不溢位、主按鈕在', () {
    final forms =
        <String, (Future<Object?> Function(BuildContext), String, String)>{
          '開新坑': ((c) => openNewPit(c), '建立', '建立'),
          '新增腦洞': ((c) => openIdeaForm(c, pitId: pitId), '建立腦洞', '建立'),
          '新增摸魚': ((c) => openDraftForm(c, pitId: pitId), '建立摸魚', '建立'),
          '新增成圖': ((c) => openPieceForm(c, pitId: pitId), '建立成圖', '建立'),
          '新增推活紀錄': ((c) => openOshiFormPage(c, pitId: pitId), '建立紀錄', '建立'),
          '新增官方圖': ((c) => openOfficialNew(c, pitId: pitId), '加入官方圖冊', '加入'),
          '加收藏': ((c) => openFanArtNew(c, pitId: pitId), '加入同人圖', '加入'),
          '新增年度目標': (
            (c) => GoalNewPage.open(
              c,
              period: GoalPeriod.year,
              year: 2026,
            ).then((_) => null),
            '建立目標',
            '建立',
          ),
        };
    final sizes = {
      '390×844（手機）': (phone, false),
      '400×900（iPad 分屏）': (split, true),
      '700×1000': (medium, true),
      '834×1194': (portrait, true),
      '1194×834': (land, true),
      '1366×1024': (big, true),
    };
    for (final f in forms.entries) {
      for (final sz in sizes.entries) {
        testWidgets('${f.key} @ ${sz.key}', (tester) async {
          final (size, tablet) = sz.value;
          debugTabletDeviceOverride = tablet;
          await show(
            tester,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => f.value.$1(context),
                  child: const Text('OPEN'),
                ),
              ),
            ),
            size,
          );
          await tester.tap(find.text('OPEN'));
          await settle(tester);
          expect(tester.takeException(), isNull);
          final narrow = size.width < 600;
          if (tablet) {
            // 手機整頁的主按鈕在 ListView 底部（惰性建立），不查；彈出頁的標題列主按鈕一定在。
            final label = narrow ? f.value.$3 : f.value.$2;
            expect(
              find.text(label),
              findsOneWidget,
              reason: '${f.key} 的主按鈕「$label」',
            );
          }
          expect(
            find.byKey(const ValueKey('form-sheet')),
            narrow && tablet ? findsOneWidget : findsNothing,
          );
          await unmount(tester);
        });
      }
    }
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
