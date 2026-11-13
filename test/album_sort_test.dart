import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_order_queries.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_kinds.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/image_masonry.dart';
import 'package:huakeng/ui/common/media_widgets.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/material/material_library_page.dart';

/// 圖冊手動排序（D-134）：順序套用規則、存取與同步、多選頁的排序鍵與瀑布流拖動。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('applyAlbumOrder', () {
    String id(String s) => s;
    test('沒排過＝原本次序', () {
      expect(applyAlbumOrder(['a', 'b', 'c'], null, id), ['a', 'b', 'c']);
    });
    test('排過的照存的順序；沒排過的（新加的）放最前面、照原本次序', () {
      expect(
        applyAlbumOrder(['n1', 'a', 'n2', 'b', 'c'], ['c', 'a', 'b'], id),
        ['n1', 'n2', 'c', 'a', 'b'],
      );
    });
    test('存的順序裡已刪除的 id 略過', () {
      expect(applyAlbumOrder(['a', 'b'], ['x', 'b', 'a'], id), ['b', 'a']);
    });
  });

  group('資料層', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('schemaVersion 18；各頁範圍字串', () {
      expect(db.schemaVersion, 18);
      expect(AlbumOrderScope.official('p', null), 'official:p:all');
      expect(AlbumOrderScope.fan('p', 'g'), 'fan:p:g');
      expect(AlbumOrderScope.inspo(null), 'inspo:all');
    });

    test('「全部」和分組各存一套，互不影響；排序不動圖本身的更新時間', () async {
      final pit = await db.createPit(name: '坑');
      final ids = await db.addFanArts(pit, const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
      ], author: '');
      final before = {
        for (final r in await db.select(db.fanArts).get()) r.id: r.updatedAt,
      };
      await db.saveAlbumOrder(
        AlbumOrderScope.fan(pit, null),
        ids.reversed.toList(),
      );
      await db.saveAlbumOrder(AlbumOrderScope.fan(pit, 'g1'), ids);
      expect(
        await db.watchAlbumOrder(AlbumOrderScope.fan(pit, null)).first,
        ids.reversed.toList(),
      );
      expect(
        await db.watchAlbumOrder(AlbumOrderScope.fan(pit, 'g1')).first,
        ids,
      );
      expect(
        await db.watchAlbumOrder(AlbumOrderScope.fan(pit, 'g2')).first,
        isNull,
      );
      for (final r in await db.select(db.fanArts).get()) {
        expect(r.updatedAt, before[r.id]);
      }
    });

    test('同步：一頁一份文件，來回一致', () async {
      const kind = AlbumOrderKind();
      expect(allSyncKinds.whereType<AlbumOrderKind>(), hasLength(1));
      await db.saveAlbumOrder('inspo:all', ['x', 'y']);
      final versions = await kind.versions(db);
      expect(versions.keys, ['inspo:all']);
      final doc = await kind.encode(db, 'inspo:all');
      await db.saveAlbumOrder('inspo:all', ['y']);
      await kind.apply(db, doc);
      expect(await db.watchAlbumOrder('inspo:all').first, ['x', 'y']);
    });
  });

  group('UI', () {
    late AppDatabase db;
    late Directory tmp;
    late String pitId;

    setUp(() async {
      navBarHiddenCount.value = 0;
      navLocked.value = false;
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('album_sort');
      await Directory('${tmp.path}/images').create(recursive: true);
      for (final n in ['a.png', 'b.png', 'c.png', 'd.png']) {
        File('${tmp.path}/images/$n').writeAsBytesSync(_png1x1);
      }
      pitId = await db.createPit(name: '測試坑');
    });
    tearDown(() => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
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
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    List<String> shownIds(WidgetTester tester) => [
      for (final t in tester.widgetList<AlbumMasonryTile>(
        find.byType(AlbumMasonryTile),
      ))
        t.image.id,
    ];

    testWidgets('多選頁右上排序鍵 → 編輯排序（瀑布流）；拖動放手存「全部」的順序；完成回列表', (tester) async {
      await tester.runAsync(
        () => db.addFanArts(pitId, const [
          NewImage(file: 'a.png', width: 10, height: 14),
          NewImage(file: 'b.png', width: 10, height: 10),
          NewImage(file: 'c.png', width: 10, height: 12),
          NewImage(file: 'd.png', width: 10, height: 10),
        ], author: '@someone'),
      );
      await pumpPage(tester, FanArtListPage(pitId: pitId));
      // 列表本身沒有排序鍵。
      expect(find.byKey(const ValueKey('albumSortButton')), findsNothing);

      await tester.longPress(find.byType(AlbumMasonryTile).first);
      await settle(tester);
      expect(find.text('已選 1 份'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('albumSortButton')));
      await settle(tester);
      expect(find.text('編輯排序'), findsOneWidget);
      expect(find.text('長按拖動可自訂順序'), findsOneWidget);
      expect(find.text('已選 1 份'), findsNothing);
      expect(find.text('下載'), findsNothing); // 沒有多選動作列
      expect(find.byKey(const ValueKey('albumSortGrid')), findsOneWidget);
      expect(navLocked.value, isTrue);

      final before = shownIds(tester);
      expect(before, hasLength(4));
      final tiles = find.byType(AlbumMasonryTile);
      // 拖起來後格子會變（原位變虛線、多一張浮起的），位置先記下。
      final start = tester.getCenter(tiles.at(0));
      final target = tester.getCenter(tiles.at(3));
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(start, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      final saved = await tester.runAsync(
        () => db.watchAlbumOrder(AlbumOrderScope.fan(pitId, null)).first,
      );
      expect(saved, isNotNull);
      expect(saved!.toSet(), before.toSet());
      expect(saved.first, before[1]); // 第一張被拖走了
      expect(saved, isNot(before));
      expect(shownIds(tester), saved);

      await tester.tap(find.byKey(const ValueKey('albumSortDone')));
      await settle(tester);
      expect(find.text('編輯排序'), findsNothing);
      expect(navLocked.value, isFalse);
      // 回到列表也照新順序。
      expect(shownIds(tester), saved);
      await unmount(tester);
    });
    testWidgets('靈感廣場：多選頁排序鍵 → 編輯排序；拖動放手存「全部」的順序', (tester) async {
      await tester.runAsync(
        () => db.addMaterials(
          materialCategoryIdOf(MaterialCategory.values.first),
          const [
            NewImage(file: 'a.png', width: 10, height: 14),
            NewImage(file: 'b.png', width: 10, height: 10),
            NewImage(file: 'c.png', width: 10, height: 12),
          ],
        ),
      );
      await pumpPage(tester, const MaterialLibraryPage());
      expect(find.byKey(const ValueKey('albumSortButton')), findsNothing);
      await tester.longPress(find.byType(MediaThumb).first);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('albumSortButton')));
      await settle(tester);
      expect(find.text('編輯排序'), findsOneWidget);
      expect(find.byKey(const ValueKey('albumSortGrid')), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      final thumbs = find.byType(MediaThumb);
      final start = tester.getCenter(thumbs.at(0));
      final target = tester.getCenter(thumbs.at(2));
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(start, target, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      final saved = await tester.runAsync(
        () => db.watchAlbumOrder(AlbumOrderScope.inspo(null)).first,
      );
      expect(saved, hasLength(3));

      await tester.tap(find.byKey(const ValueKey('albumSortDone')));
      await settle(tester);
      expect(find.text('編輯排序'), findsNothing);
      expect(navLocked.value, isFalse);
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
