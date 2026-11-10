import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart' show onlineProvider;
import 'package:huakeng/sync/sync_kinds.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';

/// 主頁手動排序（D-132）：資料層（排序方式、拖動、排序不算更新、轉分頁排最前、同步）與編輯排序 UI。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> names(PitStatus st) async => [
    for (final p in await db.watchPitsByStatus({st}).first) p.name,
  ];

  /// 建立時間、坑本身的更新時間都指定，結果不受執行速度影響。
  Future<String> pit(String name, int created, int updated) async {
    final id = await db.createPit(name: name);
    await (db.update(db.pits)..where((p) => p.id.equals(id))).write(
      PitsCompanion(
        createdAt: Value(DateTime.fromMillisecondsSinceEpoch(created * 1000)),
        updatedAt: Value(DateTime.fromMillisecondsSinceEpoch(updated * 1000)),
      ),
    );
    return id;
  }

  group('資料層', () {
    test('預設「更新日期新→舊」，四種自動排序都能切換', () async {
      await pit('A', 100, 400);
      await pit('B', 200, 300);
      await pit('C', 300, 500);
      expect(await names(PitStatus.active), ['C', 'A', 'B']);
      expect(
        await db.watchPitSortMode(PitStatus.active).first,
        PitSortMode.updatedDesc,
      );
      await db.setPitSortMode(PitStatus.active, PitSortMode.updatedAsc);
      expect(await names(PitStatus.active), ['B', 'A', 'C']);
      await db.setPitSortMode(PitStatus.active, PitSortMode.createdDesc);
      expect(await names(PitStatus.active), ['C', 'B', 'A']);
      await db.setPitSortMode(PitStatus.active, PitSortMode.createdAsc);
      expect(await names(PitStatus.active), ['A', 'B', 'C']);
    });

    test('每個分頁各自一套排序方式', () async {
      await db.setPitSortMode(PitStatus.shallow, PitSortMode.createdAsc);
      expect(
        await db.watchPitSortMode(PitStatus.active).first,
        PitSortMode.updatedDesc,
      );
      expect(
        await db.watchPitSortMode(PitStatus.shallow).first,
        PitSortMode.createdAsc,
      );
    });

    test('拖動＝手動排序；只改排序不算更新', () async {
      final a = await pit('A', 100, 400);
      final b = await pit('B', 200, 300);
      final c = await pit('C', 300, 500);
      await db.reorderPits(PitStatus.active, [b, c, a]);
      expect(
        await db.watchPitSortMode(PitStatus.active).first,
        PitSortMode.manual,
      );
      expect(await names(PitStatus.active), ['B', 'C', 'A']);
      // 再拖一次（連續只改排序），更新日期排序仍是原本的 C、A、B。
      await db.reorderPits(PitStatus.active, [a, b, c]);
      await db.setPitSortMode(PitStatus.active, PitSortMode.updatedDesc);
      expect(await names(PitStatus.active), ['C', 'A', 'B']);
      // 之後（隔一陣子）真的改了坑（改名）＝算更新，跳到最前面。
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      await db
          .update(db.pits)
          .write(
            PitsCompanion(sortTouchedAt: Value(past), updatedAt: Value(past)),
          );
      await db.savePit(b, name: 'B2');
      expect(await names(PitStatus.active), ['B2', 'C', 'A']);
    });

    test('手動模式：新坑、從別的分頁轉過來的坑排第一格', () async {
      final a = await pit('A', 100, 100);
      final b = await pit('B', 200, 200);
      await db.reorderPits(PitStatus.active, [a, b]);
      await pit('新', 300, 300);
      expect(await names(PitStatus.active), ['新', 'A', 'B']);

      final s = await db.createPit(name: '淺', status: PitStatus.shallow);
      await db.setPitStatus(s, PitStatus.active);
      expect((await names(PitStatus.active)).first, '淺');
      expect((await db.watchPit(s).first)!.sortOrder, isNull);
    });

    test('同步：排序方式文件來回；舊版 App 的坑文件不洗掉本機順序', () async {
      final a = await pit('A', 100, 100);
      final b = await pit('B', 200, 200);
      await db.reorderPits(PitStatus.active, [a, b]);
      const kind = PitSortKind();
      final doc = await kind.encode(db, 'active');
      await db.setPitSortMode(PitStatus.active, PitSortMode.createdAsc);
      await kind.apply(db, doc);
      expect(
        await db.watchPitSortMode(PitStatus.active).first,
        PitSortMode.manual,
      );
      expect(allSyncKinds.whereType<PitSortKind>(), hasLength(1));

      final pitDoc = await const PitsKind().encode(db, b);
      final old = Map<String, dynamic>.of(pitDoc)
        ..remove('sortOrder')
        ..remove('sortTouchedAt')
        ..remove('activityAt')
        ..['name'] = 'B 改名';
      await const PitsKind().apply(db, old);
      final local = (await db.watchPit(b).first)!;
      expect(local.name, 'B 改名');
      expect(local.sortOrder, 1);
    });
  });

  group('UI', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('huakeng_pit_sort');
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpApp(WidgetTester tester, {double w = 1080}) async {
      tester.view.physicalSize = Size(w, 2400);
      tester.view.devicePixelRatio = w > 1200 ? 1 : 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${tmp.path}/images')),
            ),
            onlineProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('長按坑卡片進入編輯排序；底部排序列；「完成」退出', (tester) async {
      await tester.runAsync(() async {
        await pit('坑A', 100, 400);
        await pit('坑B', 200, 300);
      });
      await pumpApp(tester);
      expect(find.text('時間軸'), findsOneWidget);
      expect(find.text('開新坑'), findsOneWidget);

      final g = await tester.startGesture(tester.getCenter(find.text('坑B')));
      await tester.pump(const Duration(milliseconds: 400));
      await g.up();
      await settle(tester);

      expect(find.text('編輯排序'), findsOneWidget);
      expect(find.text('長按拖動可自訂順序・點封面更換封面'), findsOneWidget);
      expect(find.text('時間軸'), findsNothing); // 沒有導覽列
      expect(find.text('開新坑'), findsNothing);
      expect(find.text('建立日期'), findsOneWidget);
      expect(find.text('新→舊'), findsOneWidget); // 預設更新日期新→舊

      // 再點亮著的「更新日期」＝舊→新
      await tester.tap(find.byKey(const ValueKey('pitSortUpdated')));
      await settle(tester);
      expect(find.text('舊→新'), findsOneWidget);
      expect(
        await tester.runAsync(
          () => db.watchPitSortMode(PitStatus.active).first,
        ),
        PitSortMode.updatedAsc,
      );

      await tester.tap(find.byKey(const ValueKey('pitSortDone')));
      await settle(tester);
      expect(find.text('編輯排序'), findsNothing);
      expect(find.text('時間軸'), findsOneWidget);
      expect(navLocked.value, isFalse);
      await unmount(tester);
    });

    testWidgets('編輯排序時點封面＝更換封面 sheet，可移除封面', (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await pit('坑A', 100, 400);
        final g = (await db.watchGroups(id).first).first;
        await db.addOfficial(id, g.id, const [NewImage(file: 'a.png')]);
        final img = (await db.watchOfficial(id).first).first;
        await db.setCover(id, img.id);
      });
      await pumpApp(tester);
      final g = await tester.startGesture(tester.getCenter(find.text('坑A')));
      await tester.pump(const Duration(milliseconds: 400));
      await g.up();
      await settle(tester);

      await tester.tap(find.byKey(ValueKey('pitCoverEdit-$id')));
      await settle(tester);
      expect(find.text('更換封面'), findsWidgets);
      expect(find.text('移除封面'), findsOneWidget);
      expect(find.text('從相簿選擇'), findsNothing); // 現坑沒有

      await tester.tap(find.text('移除封面'));
      await settle(tester);
      final p = await tester.runAsync(() => db.watchPit(id).first);
      expect(p!.coverImageId, isNull);
      expect(find.text('已移除封面'), findsOneWidget);
      expect(find.text('編輯排序'), findsOneWidget); // 仍在編輯排序
      await unmount(tester);
    });
  });
}
