import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/src/gal_platform_interface.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/image_masonry.dart' show SelectMark;
import 'package:huakeng/ui/album/tag_batch_sheet.dart';
import 'package:huakeng/ui/common/drag_select.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/entity_select.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/ui/entity/piece_detail_page.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 摸魚、成圖列表的多選（D-095）：長按進入、拖曳連選、全選、四個動作、
/// 列表→九宮格切換、成圖三種佈局、平板版面。
class _FakeShare extends SharePlatform {
  final shared = <List<String>>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add([for (final f in params.files ?? const []) f.path]);
    return const ShareResult('', ShareResultStatus.success);
  }
}

base class _FakeGal extends GalPlatform {
  final saved = <String>[];
  final albums = <String?>[];

  @override
  Future<bool> hasAccess({bool toAlbum = false}) async => true;

  @override
  Future<bool> requestAccess({bool toAlbum = false}) async => true;

  @override
  Future<void> putImage(String path, {String? album}) async {
    saved.add(path);
    albums.add(album);
  }

  @override
  Future<void> putVideo(String path, {String? album}) async {
    saved.add(path);
    albums.add(album);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late SharedPreferences prefs;
  // SharePlus.instance 在第一次用到時就綁定平台實作，所以整個檔案共用同一個假的。
  final share = _FakeShare();
  late _FakeGal gal;

  setUpAll(() => SharePlatform.instance = share);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('entity_select');
    pitId = await db.createPit(name: '坑A');
    navBarHiddenCount.value = 0;
    share.shared.clear();
    gal = _FakeGal();
    GalPlatform.instance = gal;
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
    Size size = const Size(1080, 2400),
    double ratio = 3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    prefs = await SharedPreferences.getInstance();
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

  /// T1～T6：日期 10/1～10/6；圖片張數 2,1,3,1,1,2（橫圖，列表一列不會太高）。
  Future<List<String>> seedDrafts() async {
    const counts = [2, 1, 3, 1, 1, 2];
    final ids = <String>[];
    for (var i = 0; i < counts.length; i++) {
      ids.add(
        await db.saveDraft(
          pitId: pitId,
          title: 'T${i + 1}',
          date: DateTime(2026, 10, i + 1),
          images: [
            for (var k = 0; k < counts[i]; k++)
              NewImage(file: 'd${i + 1}_$k.png', width: 40, height: 30),
          ],
          tagIds: const [],
          ideaIds: const [],
        ),
      );
    }
    return ids;
  }

  Future<List<String>> seedPieces() async {
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      ids.add(
        await db.savePiece(
          pitId: pitId,
          title: 'P${i + 1}',
          body: '',
          images: [
            for (var k = 0; k <= i % 2; k++)
              NewImage(file: 'p${i + 1}_$k.png', width: 30, height: 40),
          ],
          tagIds: const [],
          links: const [],
          targetLikes: 0,
          finishedAt: DateTime(2026, 10, i + 1),
          ideaIds: const [],
          draftIds: const [],
        ),
      );
    }
    return ids;
  }

  Finder selectedMarks() => find.byWidgetPredicate(
    (w) => w is SelectMark && w.selected,
    description: 'selected SelectMark',
  );

  Finder bar(String key) => find.byKey(ValueKey(key));

  Future<void> longPress(WidgetTester tester, Finder f) async {
    await tester.longPress(f);
    await settle(tester);
  }

  Future<void> tapSemantic(WidgetTester tester, String label) async {
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      ),
    );
    await settle(tester);
  }

  group('摸魚', () {
    testWidgets('列表長按：換成多選九宮格、標題已選 N 份、四個動作、沒有移動、導覽列隱藏', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(tester, DraftListPage(pitId: pitId));
      expect(find.byType(DraftRow), findsWidgets);
      expect(find.byType(DragSelectItem), findsWidgets);

      await longPress(tester, find.byType(DraftRow).first);
      // 同一個多選九宮格：沒有 DraftRow，每格右上有圈，被按的那份選中。
      expect(find.byType(DraftRow), findsNothing);
      expect(find.text('已選 1 份'), findsOneWidget);
      expect(find.byType(SelectMark), findsNWidgets(6));
      expect(selectedMarks(), findsOneWidget);
      for (final s in ['分享', '下載', 'tag', '刪除']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('移動'), findsNothing);
      // 標題列換成「× 已選 N 份」＋全選；沒有分段列、沒有新增按鈕
      expect(find.text('全選'), findsOneWidget);
      expect(find.text('我的摸魚'), findsNothing);
      expect(find.text('新增摸魚'), findsNothing);
      await tester.pump();
      await tester.pump();
      expect(navBarHiddenCount.value, greaterThan(0));

      // 退出多選後回列表，導覽列回來
      await tester.tap(bar('entitySelectExit'));
      await settle(tester);
      expect(find.byType(DraftRow), findsWidgets);
      expect(find.byType(SelectMark), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('點擊切換選取；最後一份取消就離開多選；全選／取消全選', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(tester, DraftListPage(pitId: pitId));
      await longPress(tester, find.byType(DraftRow).first);

      final cells = find.byType(DragSelectItem);
      await tester.tap(cells.at(1));
      await tester.pump();
      await tester.tap(cells.at(4));
      await tester.pump();
      expect(find.text('已選 3 份'), findsOneWidget);
      await tester.tap(cells.at(1));
      await tester.pump();
      expect(find.text('已選 2 份'), findsOneWidget);

      await tester.tap(bar('entitySelectAll'));
      await tester.pump();
      expect(find.text('已選 6 份'), findsOneWidget);
      expect(find.text('取消全選'), findsOneWidget);
      // 全選後再按＝取消全選並離開多選
      await tester.tap(bar('entitySelectAll'));
      await settle(tester);
      expect(find.byType(SelectMark), findsNothing);
      expect(find.byType(DraftRow), findsWidgets);

      // 只剩一份時再點它＝離開多選
      await longPress(tester, find.byType(DraftRow).first);
      await tester.tap(find.byType(DragSelectItem).first);
      await settle(tester);
      expect(find.byType(DraftRow), findsWidgets);
      await unmount(tester);
    });

    testWidgets('列表長按後手指不放，拖曳連續多選（跨過列表→九宮格的切換）', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(tester, DraftListPage(pitId: pitId));

      final start =
          tester.getTopLeft(find.byType(DraftRow).first) + const Offset(40, 24);
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);
      expect(find.text('已選 1 份'), findsOneWidget);
      // 已換成九宮格；手指拖到第 4 格（index 3）
      final cells = find.byType(DragSelectItem);
      await g.moveTo(tester.getCenter(cells.at(1)));
      await tester.pump();
      await g.moveTo(tester.getCenter(cells.at(3)));
      await tester.pump();
      expect(find.text('已選 4 份'), findsOneWidget);
      // 拖回去 → 還原
      await g.moveTo(tester.getCenter(cells.at(2)));
      await tester.pump();
      expect(find.text('已選 3 份'), findsOneWidget);
      await g.up();
      await settle(tester);
      expect(find.text('已選 3 份'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('九宮格模式：直接在格上長按選取，退出後仍是九宮格', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(tester, DraftListPage(pitId: pitId));
      await tapSemantic(tester, '九宮格');
      expect(find.byType(DraftRow), findsNothing);
      expect(find.byType(SelectMark), findsNothing);

      await longPress(tester, find.byType(DragSelectItem).at(2));
      expect(find.text('已選 1 份'), findsOneWidget);
      expect(find.byType(SelectMark), findsNWidgets(6));
      await tester.tap(bar('entitySelectExit'));
      await settle(tester);
      expect(find.byType(SelectMark), findsNothing);
      expect(find.byType(DraftRow), findsNothing);
      expect(find.byType(DragSelectItem), findsNWidgets(6));
      await unmount(tester);
    });

    testWidgets('分享、下載：多張圖的一份，圖片一起、照圖片順序', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(tester, DraftListPage(pitId: pitId));
      // 列表由新到舊：T6(2) T5(1) T4(1) T3(3) T2(1) T1(2)；選 T6 與 T3
      await longPress(tester, find.byType(DraftRow).first);
      await tester.tap(find.byType(DragSelectItem).at(3));
      await tester.pump();
      expect(find.text('已選 2 份'), findsOneWidget);

      await tester.tap(bar('entitySelectShare'));
      await settle(tester);
      expect(share.shared, hasLength(1));
      expect(
        [for (final p in share.shared.single) p.split('/').last],
        ['d6_0.png', 'd6_1.png', 'd3_0.png', 'd3_1.png', 'd3_2.png'],
      );
      // 分享後仍在多選
      expect(find.text('已選 2 份'), findsOneWidget);

      await tester.tap(bar('entitySelectDownload'));
      await settle(tester);
      expect(
        [for (final p in gal.saved) p.split('/').last],
        ['d6_0.png', 'd6_1.png', 'd3_0.png', 'd3_1.png', 'd3_2.png'],
      );
      expect(gal.albums.toSet(), {'Drawer'});
      expect(find.text('已儲存 5 張到相簿'), findsOneWidget);
      // 下載完離開多選
      expect(find.byType(SelectMark), findsNothing);
      await unmount(tester);
    });

    testWidgets('tag：FanArtTagSheet 對摸魚批量加、移除', (tester) async {
      final ids = (await tester.runAsync(seedDrafts))!;
      final tag = (await tester.runAsync(() => db.createTag(pitId, '角色1')))!;
      await tester.runAsync(() => db.setTags(TagTarget.draft, ids[0], [tag]));
      await show(tester, DraftListPage(pitId: pitId));
      // 選 T1（最後一列）與 T2
      await longPress(tester, find.byType(DraftRow).first);
      await tester.tap(find.byType(DragSelectItem).at(4));
      await tester.pump();
      await tester.tap(find.byType(DragSelectItem).at(5));
      await tester.pump();
      await tester.tap(find.byType(DragSelectItem).first); // 取消 T6
      await tester.pump();
      expect(find.text('已選 2 份'), findsOneWidget);

      await tester.tap(bar('entitySelectTag'));
      await settle(tester);
      expect(find.byType(BatchTagSheet), findsOneWidget);
      expect(find.text('2 份'), findsOneWidget);
      // T1 有、T2 沒有 → 部分有；點一下＝全部加上
      await tester.tap(find.byKey(const ValueKey('batchTag-角色1-some')));
      await tester.pump();
      await tester.tap(find.text('完成'));
      await settle(tester);
      final after = await tester.runAsync(
        () async => [
          for (final id in ids)
            (await db.watchTagIds(TagTarget.draft, id).first),
        ],
      );
      expect(after![0], [tag]);
      expect(after[1], [tag]);
      expect(after[2], isEmpty);
      // 套用後離開多選
      expect(find.byType(SelectMark), findsNothing);
      await unmount(tester);
    });

    testWidgets('刪除：要確認；取消不刪、確認才刪', (tester) async {
      final ids = (await tester.runAsync(seedDrafts))!;
      await show(tester, DraftListPage(pitId: pitId));
      await longPress(tester, find.byType(DraftRow).first);
      await tester.tap(find.byType(DragSelectItem).at(1));
      await tester.pump();

      await tester.tap(bar('entitySelectDelete'));
      await settle(tester);
      expect(find.text('刪除 2 項？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.text('已選 2 份'), findsOneWidget);

      await tester.tap(bar('entitySelectDelete'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      final left = (await tester.runAsync(
        () => db.watchDraftViews(pitId).first,
      ))!;
      expect(
        {for (final v in left) v.draft.id},
        {ids[0], ids[1], ids[2], ids[3]},
      );
      expect(find.byType(SelectMark), findsNothing);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('平板（並排版）：長按列表換成鋪滿的多選九宮格，沒有詳情區', (tester) async {
      await tester.runAsync(seedDrafts);
      await show(
        tester,
        DraftListPage(pitId: pitId),
        size: const Size(2560, 1600),
        ratio: 2,
      );
      expect(find.byType(DraftRow), findsWidgets);
      await longPress(tester, find.byType(DraftRow).first);
      expect(find.byType(DraftRow), findsNothing);
      expect(find.text('已選 1 份'), findsOneWidget);
      expect(find.byType(SelectMark), findsNWidgets(6));
      expect(find.text('移動'), findsNothing);
      // 欄數依可用闊度（>3 欄）：6 格都在第一排
      final tops = {
        for (final e in find.byType(DragSelectItem).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      };
      expect(tops, hasLength(1));
      await tester.tap(bar('entitySelectExit'));
      await settle(tester);
      expect(find.byType(DraftRow), findsWidgets);
      await unmount(tester);
    });
  });

  group('成圖', () {
    for (final (mode, label) in [(0, '列表'), (1, '瀑布'), (2, '九宮格')]) {
      testWidgets('$label：在原佈局上選，標題已選 N 張、拖曳連選、全選、退出', (tester) async {
        await tester.runAsync(seedPieces);
        await show(tester, FinishedListPage(pitId: pitId));
        if (mode != 0) await tapSemantic(tester, label);
        expect(find.byType(SelectMark), findsNothing);
        final tiles = find.byType(DragSelectItem);
        final before = tester.getTopLeft(tiles.first);

        await longPress(tester, tiles.first);
        expect(find.text('已選 1 張'), findsOneWidget);
        // 佈局沒變（列表模式多選時換成九宮格，同摸魚列表，不比位置）
        if (mode != 0) {
          expect(tester.getTopLeft(find.byType(DragSelectItem).first), before);
        }
        expect(find.byType(SelectMark), findsWidgets);
        expect(selectedMarks(), findsOneWidget);
        for (final s in ['分享', '下載', 'tag', '刪除']) {
          expect(find.text(s), findsOneWidget, reason: s);
        }
        expect(find.text('移動'), findsNothing);
        await tester.pump();
        await tester.pump();
        expect(navBarHiddenCount.value, greaterThan(0));

        await tester.tap(find.byType(DragSelectItem).at(1));
        await tester.pump();
        expect(find.text('已選 2 張'), findsOneWidget);
        await tester.tap(bar('entitySelectAll'));
        await tester.pump();
        expect(find.text('已選 5 張'), findsOneWidget);
        await tester.tap(bar('entitySelectExit'));
        await settle(tester);
        expect(find.byType(SelectMark), findsNothing);
        expect(navBarHiddenCount.value, 0);

        // 長按後不放手拖曳：從第 1 個拖到第 3 個
        final g = await tester.startGesture(
          tester.getCenter(find.byType(DragSelectItem).first),
        );
        await tester.pump(const Duration(milliseconds: 700));
        await g.moveTo(tester.getCenter(find.byType(DragSelectItem).at(1)));
        await tester.pump();
        await g.moveTo(tester.getCenter(find.byType(DragSelectItem).at(2)));
        await tester.pump();
        expect(find.text('已選 3 張'), findsOneWidget);
        await g.up();
        await settle(tester);
        expect(find.text('已選 3 張'), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('預設是列表（D-125）：標題、日期、沒公開發佈沒有愛心；切瀑布／九宮格', (tester) async {
      await tester.runAsync(seedPieces);
      await show(tester, FinishedListPage(pitId: pitId));
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('10/1'), findsOneWidget);
      expect(find.bySemanticsLabel('田字'), findsNothing);
      await tapSemantic(tester, '瀑布');
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('10/1'), findsNothing); // 瀑布沒有日期
      await tapSemantic(tester, '列表');
      expect(find.text('10/1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('不在多選時點成圖仍開詳情；多選中點成圖是切換', (tester) async {
      await tester.runAsync(seedPieces);
      await show(tester, FinishedListPage(pitId: pitId));
      await tester.tap(find.byType(DragSelectItem).first);
      await settle(tester);
      expect(find.byType(PieceDetailPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('分享、下載、tag、刪除', (tester) async {
      final ids = (await tester.runAsync(seedPieces))!;
      final tag = (await tester.runAsync(() => db.createTag(pitId, '角色1')))!;
      await show(tester, FinishedListPage(pitId: pitId));
      await tapSemantic(tester, '九宮格');
      // 成圖列表照建立順序：P1(1) P2(2) P3(1) P4(2) P5(1)；選 P1、P2
      await longPress(tester, find.byType(DragSelectItem).first);
      await tester.tap(find.byType(DragSelectItem).at(1));
      await tester.pump();
      expect(find.text('已選 2 張'), findsOneWidget);

      await tester.tap(bar('entitySelectShare'));
      await settle(tester);
      expect(
        [for (final p in share.shared.single) p.split('/').last],
        ['p1_0.png', 'p2_0.png', 'p2_1.png'],
      );

      await tester.tap(bar('entitySelectTag'));
      await settle(tester);
      expect(find.text('2 份'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('batchTag-角色1-none')));
      await tester.pump();
      await tester.tap(find.text('完成'));
      await settle(tester);
      final tagged = await tester.runAsync(
        () async => [
          for (final id in ids) await db.watchTagIds(TagTarget.piece, id).first,
        ],
      );
      expect(tagged![0], [tag]);
      expect(tagged[1], [tag]);
      expect(tagged[2], isEmpty);
      expect(find.byType(SelectMark), findsNothing);

      // 下載：重新選 P3
      await longPress(tester, find.byType(DragSelectItem).at(2));
      await tester.tap(bar('entitySelectDownload'));
      await settle(tester);
      expect([for (final p in gal.saved) p.split('/').last], ['p3_0.png']);
      expect(find.text('已儲存 1 張到相簿'), findsOneWidget);

      // 刪除
      await longPress(tester, find.byType(DragSelectItem).at(0));
      await tester.tap(find.byType(DragSelectItem).at(1));
      await tester.pump();
      await tester.tap(bar('entitySelectDelete'));
      await settle(tester);
      expect(find.text('刪除 2 項？'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      final left = (await tester.runAsync(
        () => db.watchPieceViews(pitId).first,
      ))!;
      expect({for (final v in left) v.piece.id}, {ids[2], ids[3], ids[4]});
      await unmount(tester);
    });

    testWidgets('平板（並排版）：多選時詳情面板收起，成圖鋪滿', (tester) async {
      await tester.runAsync(seedPieces);
      await show(
        tester,
        FinishedListPage(pitId: pitId),
        size: const Size(2560, 1600),
        ratio: 2,
      );
      final w0 = tester.getSize(find.byType(DragSelectArea)).width;
      await longPress(tester, find.byType(DragSelectItem).first);
      expect(find.text('已選 1 張'), findsOneWidget);
      expect(
        tester.getSize(find.byType(DragSelectArea)).width,
        greaterThan(w0),
      );
      await unmount(tester);
    });
  });

  test('albumImagesOfAll：照份、照圖片順序攤平', () {
    final a = [const ImageRef('a1', 1, 1), const ImageRef('a2', 1, 1)];
    final b = [const ImageRef('b1', 1, 1)];
    expect(
      [
        for (final i in albumImagesOfAll([a, b])) i.file,
      ],
      ['a1', 'a2', 'b1'],
    );
    expect(albumImagesOfAll(const []), isEmpty);
  });
}
