import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_edit_page.dart';
import 'package:huakeng/ui/album/fan_art_new_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/common/device_class.dart';
import 'package:huakeng/ui/common/adaptive_modal.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/oshi/oshi_form_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:image_picker/image_picker.dart';

/// iPad：所有新增／編輯表單在視窗 ≥600 是置中 form sheet；＜600 的 iPad（分屏約 400 寬）是
/// page sheet（NewXxx400）；＜600 的手機是整頁。三種模式存檔結果一致、結果回到呼叫端。
enum _Mode { page, dialog, sheet }

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late File png;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('ipadforms');
    await Directory('${dir.path}/images').create();
    png = File('${dir.path}/one.png')
      ..writeAsBytesSync(Uint8List.fromList(_png));
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 存檔會匯入圖片（真的檔案 IO），機器忙時要多等一下。
  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await settle(tester);
    }
  }

  void setView(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// 一個有「打開」按鈕的宿主頁；[open] 的回傳值會被記下來。
  Future<void> pumpHost(
    WidgetTester tester,
    Size size,
    Future<Object?> Function(BuildContext context) open,
    List<Object?> results,
  ) async {
    setView(tester, size);
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => results.add(await open(context)),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await settle(tester);
  }

  /// 同 testWidgets，結束時卸載整棵樹（讓 drift 的 stream 計時器收掉）。
  void tw(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 10));
        // HidesNavBar 的計數是在 microtask 裡減的，先讓它跑完再歸零。
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        navBarHiddenCount.value = 0;
      }
    });
  }

  /// 整頁的 ListView 是惰性建立的：先捲到看得見。
  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
  }

  const phone = Size(390, 844);
  const portrait = Size(834, 1194);
  const landscape = Size(1194, 834);

  /// 開啟後在對話框（dialog）、page sheet（sheet）或整頁（page）。
  void expectMode(_Mode mode) {
    switch (mode) {
      case _Mode.dialog:
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byKey(const ValueKey('form-sheet')), findsNothing);
        expect(navBarHiddenCount.value, 0, reason: 'modal 不藏導覽列');
      case _Mode.sheet:
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(const ValueKey('form-sheet')), findsOneWidget);
        expect(navBarHiddenCount.value, 0, reason: 'sheet 不藏導覽列');
      case _Mode.page:
        expect(find.byType(Dialog), findsNothing);
        expect(find.byKey(const ValueKey('form-sheet')), findsNothing);
        expect(navBarHiddenCount.value, greaterThan(0), reason: '整頁要藏導覽列');
    }
  }

  const sheetSize = Size(400, 900);

  for (final (name, size, mode) in [
    ('手機 390×844', phone, _Mode.page),
    ('分屏 400×900（iPad）', sheetSize, _Mode.sheet),
    ('直向 834×1194', portrait, _Mode.dialog),
    ('橫向 1194×834', landscape, _Mode.dialog),
  ]) {
    final modal = mode != _Mode.page;

    /// page sheet 的主按鈕縮短成「建立」／「加入」。
    String label(String long, String short) =>
        mode == _Mode.sheet ? short : long;
    group(name, () {
      setUp(
        () => debugTabletDeviceOverride = mode == _Mode.sheet ? true : null,
      );
      tearDown(() => debugTabletDeviceOverride = null);
      tw('新增腦洞：存檔並關閉', (tester) async {
        final r = <Object?>[];
        await pumpHost(tester, size, (c) => openIdeaForm(c, pitId: pitId), r);
        expectMode(mode);
        expect(find.text('新增腦洞'), findsOneWidget);
        expect(find.text(label('建立腦洞', '建立')), findsOneWidget);
        // 沒填標題：按鈕變灰不能按、不關閉（D-121 ①）
        await tester.tap(find.text(label('建立腦洞', '建立')));
        await settle(tester);
        expect(find.text('新增腦洞'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, '天台看煙花');
        await tester.pump();
        await tester.tap(find.text(label('建立腦洞', '建立')));
        await settle(tester);
        expect(find.text('新增腦洞'), findsNothing);
        expect(r, hasLength(1));
        final rows = await tester.runAsync(() => db.select(db.ideas).get());
        expect(rows!.single.title, '天台看煙花');
      });

      tw('取消不存', (tester) async {
        final r = <Object?>[];
        await pumpHost(tester, size, (c) => openDraftForm(c, pitId: pitId), r);
        expectMode(mode);
        if (modal) {
          await tester.tap(find.text('取消'));
        } else {
          await tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .maybePop();
        }
        await settle(tester);
        expect(find.text('新增摸魚'), findsNothing);
        final rows = await tester.runAsync(() => db.select(db.drafts).get());
        expect(rows, isEmpty);
      });

      tw('新增摸魚（帶圖）：存檔', (tester) async {
        final r = <Object?>[];
        await pumpHost(
          tester,
          size,
          (c) =>
              openDraftForm(c, pitId: pitId, initialImages: [XFile(png.path)]),
          r,
        );
        expectMode(mode);
        await tester.enterText(find.byType(TextField).first, '構圖');
        await tester.pump();
        await tester.tap(find.text(label('建立摸魚', '建立')));
        await settleLong(tester);
        final rows = await tester.runAsync(() => db.select(db.drafts).get());
        expect(rows!.single.title, '構圖');
        expect(find.text('新增摸魚'), findsNothing);
      });

      tw('新增成圖：商稿欄位、存檔', (tester) async {
        final r = <Object?>[];
        await pumpHost(
          tester,
          size,
          (c) =>
              openPieceForm(c, pitId: pitId, initialImages: [XFile(png.path)]),
          r,
        );
        expectMode(mode);
        await tester.enterText(find.byKey(const Key('piece-title')), '夏日');
        // 開商稿：出現委託人欄
        await reveal(tester, find.text('商稿'));
        await tester.tap(find.byType(AppSwitch).at(1));
        await settle(tester);
        expect(find.byKey(const Key('piece-client')), findsOneWidget);
        await tester.enterText(find.byKey(const Key('piece-client')), '某某');
        await tester.enterText(find.byKey(const Key('piece-amount')), '800');
        await reveal(tester, find.text(label('建立成圖', '建立')));
        await tester.tap(find.text(label('建立成圖', '建立')));
        await settleLong(tester);
        final rows = await tester.runAsync(() => db.select(db.pieces).get());
        expect(rows!.single.title, '夏日');
        expect(rows.single.isCommission, true);
        expect(rows.single.client, '某某');
        expect(rows.single.amount, 800);
      });

      tw('新增推活紀錄：存檔', (tester) async {
        final r = <Object?>[];
        await pumpHost(
          tester,
          size,
          (c) => openOshiFormPage(c, pitId: pitId, initialImages: [png.path]),
          r,
        );
        expectMode(mode);
        await tester.enterText(find.byType(TextField).first, '一週年展');
        await reveal(tester, find.text(label('建立紀錄', '建立')));
        await tester.tap(find.text(label('建立紀錄', '建立')));
        await settleLong(tester);
        final rows = await tester.runAsync(
          () => db.select(db.oshiRecords).get(),
        );
        expect(rows!.single.title, '一週年展');
      });

      tw('新增官方圖：選分組、加入', (tester) async {
        final r = <Object?>[];
        await pumpHost(
          tester,
          size,
          (c) => openOfficialNew(
            c,
            pitId: pitId,
            initialImages: [XFile(png.path)],
          ),
          r,
        );
        expectMode(mode);
        expect(find.text('新增官方圖'), findsOneWidget);
        if (modal) {
          expect(find.textContaining('一併加入'), findsOneWidget);
        }
        await tester.tap(find.text(label('加入官方圖冊', '加入')));
        await settleLong(tester);
        final rows = await tester.runAsync(
          () => db.select(db.officialImages).get(),
        );
        expect(rows, hasLength(1));
        expect(find.text('新增官方圖'), findsNothing);
      });

      tw('加收藏／編輯同人圖：存檔與回傳', (tester) async {
        final r = <Object?>[];
        await pumpHost(
          tester,
          size,
          (c) =>
              openFanArtNew(c, pitId: pitId, initialImages: [XFile(png.path)]),
          r,
        );
        expectMode(mode);
        expect(find.text(modal ? '加收藏' : '新增同人圖'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '@ka');
        await tester.pump();
        await tester.tap(find.text(modal ? label('加入同人圖', '加入') : '加入好看同人圖'));
        await settleLong(tester);
        final rows = await tester.runAsync(() => db.select(db.fanArts).get());
        expect(rows!.single.author, '@ka');
        final id = rows.single.id;

        // 編輯
        final r2 = <Object?>[];
        await tester.pumpWidget(const SizedBox());
        navBarHiddenCount.value = 0;
        await pumpHost(
          tester,
          size,
          (c) => openFanArtEdit(c, pitId: pitId, imageId: id),
          r2,
        );
        expectMode(mode);
        await tester.enterText(find.byType(TextField).first, '@ka2');
        await tester.pump();
        await tester.tap(find.text('儲存'));
        await settle(tester);
        final rows2 = await tester.runAsync(() => db.select(db.fanArts).get());
        expect(rows2!.single.author, '@ka2');
        expect(find.byType(FanArtEditPage), findsNothing);
      });
    });
  }

  group('modal 內開出的面板會疊在對話框上', () {
    tw('腦洞 modal：關聯摸魚的選擇面板可開可關，表單狀態保留', (tester) async {
      await db.saveDraft(
        pitId: pitId,
        title: '草圖一',
        body: '',
        ideaIds: const [],
        pieceIds: const [],
        tagIds: const [],
        images: [const NewImage(file: 'a.png')],
      );
      await pumpHost(
        tester,
        landscape,
        (c) => openIdeaForm(c, pitId: pitId),
        [],
      );
      expect(find.byType(Dialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '標題X');
      final choose = find.text('選擇');
      await tester.ensureVisible(choose.first);
      await tester.tap(choose.first);
      await settle(tester);
      expect(find.text('草圖一'), findsWidgets);
      await tester.tapAt(const Offset(20, 20));
      await settle(tester);
      // 面板關了，對話框與輸入的內容還在
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('標題X'), findsOneWidget);
    });

    tw('AdaptiveModalScope：modal 內為 true，整頁為 false', (tester) async {
      bool? seen;
      await pumpHost(
        tester,
        landscape,
        (c) => showAdaptiveModal<void>(
          c,
          builder: (ctx, asModal) => Builder(
            builder: (ctx) {
              seen = AdaptiveModalScope.of(ctx);
              return const SizedBox();
            },
          ),
        ),
        [],
      );
      expect(seen, true);
    });
  });

  group('840 寬（最窄的 modal）', () {
    tw('成圖：對話框縮到 792 寬時併成兩欄，商稿卡仍可用', (tester) async {
      await pumpHost(
        tester,
        const Size(840, 900),
        (c) => openPieceForm(c, pitId: pitId, initialImages: [XFile(png.path)]),
        [],
      );
      expect(find.byType(Dialog), findsOneWidget);
      await tester.enterText(find.byKey(const Key('piece-title')), '窄');
      await reveal(tester, find.text('商稿'));
      await tester.tap(find.byType(AppSwitch).at(1));
      await settle(tester);
      expect(find.byKey(const Key('piece-client')), findsOneWidget);
      await tester.tap(find.text('建立成圖'));
      await settleLong(tester);
      final rows = await tester.runAsync(() => db.select(db.pieces).get());
      expect(rows!.single.title, '窄');
    });

    tw('編輯腦洞（modal）會載入既有內容', (tester) async {
      final id = await db.saveIdea(
        pitId: pitId,
        title: '舊標題',
        body: '舊內文',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
        date: DateTime(2026, 1, 2),
      );
      await pumpHost(
        tester,
        landscape,
        (c) => openIdeaForm(c, pitId: pitId, ideaId: id),
        [],
      );
      expect(find.text('編輯腦洞'), findsOneWidget);
      expect(find.text('舊標題'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '新標題');
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final rows = await tester.runAsync(() => db.select(db.ideas).get());
      expect(rows!.single.title, '新標題');
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('分享「加入到」', () {
    tw('≥840：720×760 置中對話框，7 欄位置、取消回傳 null', (tester) async {
      final r = <Object?>[];
      await pumpHost(
        tester,
        landscape,
        (c) => showShareSheet(c, paths: [png.path, png.path]),
        r,
      );
      expect(find.byType(Dialog), findsOneWidget);
      final box = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.width, 720);
      expect(box.height, 760);
      expect(find.text('加入到畫匣'), findsOneWidget);
      expect(find.text('2 張'), findsOneWidget);
      // 位置 7 欄：官方圖冊與推活在同一排
      final y1 = tester.getTopLeft(find.text('官方圖冊')).dy;
      final y2 = tester.getTopLeft(find.text('推活').last).dy;
      expect(y1, closeTo(y2, 4));
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(r, [null]);
    });

    tw('手機：維持 bottom sheet', (tester) async {
      await pumpHost(
        tester,
        phone,
        (c) => showShareSheet(c, paths: [png.path]),
        [],
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('加入到'), findsOneWidget);
    });
  });

  group('分區 tab bar', () {
    Future<void> pumpList(WidgetTester tester, Size size) async {
      setView(tester, size);
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
            home: OfficialListPage(pitId: pitId),
          ),
        ),
      );
      await settle(tester);
    }

    tw('≥600 有 tab，切換到好看同人圖；手機沒有', (tester) async {
      await pumpList(tester, portrait);
      expect(find.text('我的腦洞'), findsOneWidget);
      await tester.tap(find.text('好看同人圖'));
      await settle(tester);
      expect(find.text('我的腦洞'), findsOneWidget);
      // 現在在同人圖頁：標題列也是「好看同人圖」，tab 為選中
      await tester.tap(find.text('我的摸魚'));
      await settle(tester);
      await tester.tap(find.text('我的成圖'));
      await settle(tester);
      await tester.tap(find.text('推活').first);
      await settle(tester);
      await tester.tap(find.text('官方圖冊').first);
      await settle(tester);
      expect(find.text('我的腦洞'), findsOneWidget);
    });

    tw('手機 390 不畫 tab', (tester) async {
      await pumpList(tester, phone);
      expect(find.text('我的腦洞'), findsNothing);
    });
  });
}

const _png = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
