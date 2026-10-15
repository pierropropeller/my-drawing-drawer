import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/junk/junk_list_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/state/settings.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_pits_ui');
    pitId = await db.createPit(name: '坑A', description: '描述');
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
    bool online = true,
  }) async {
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
          onlineProvider.overrideWith((ref) => Stream.value(online)),
          ...overrides,
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> seedOshi(int n) async {
    for (var i = 0; i < n; i++) {
      await db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 5, 1 + i),
        images: const [NewImage(file: 'o.png')],
      );
    }
  }

  Future<void> pumpPitPage(WidgetTester tester, Brightness b) async {
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
          theme: buildTheme(b, useGoogleFonts: false),
          home: PitPage(pitId: pitId),
        ),
      ),
    );
    await settle(tester);
  }

  Offset at(WidgetTester tester, String label) =>
      tester.getTopLeft(find.text(label));

  testWidgets('D-058：六格 2 欄 3 列，數量單位各自正確，推活 N 筆', (tester) async {
    await tester.runAsync(() => seedOshi(2));
    await pumpPitPage(tester, Brightness.light);
    final o = at(tester, '官方圖冊');
    final f = at(tester, '好看同人圖');
    final d = at(tester, '我的草稿');
    final i = at(tester, '我的腦洞');
    final p = at(tester, '我的成圖');
    final h = at(tester, '推活');
    expect(o.dy, f.dy);
    expect(d.dy, i.dy);
    expect(p.dy, h.dy);
    expect(o.dy < d.dy && d.dy < p.dy, isTrue);
    // D-074：第二列腦洞在左、草稿在右。
    expect(o.dx, i.dx);
    expect(i.dx, p.dx);
    expect(f.dx, d.dx);
    expect(d.dx, h.dx);
    expect(o.dx < f.dx, isTrue);
    // 列距相同＝格子是正方形（寬格已不存在）。
    expect((d.dy - o.dy), closeTo(p.dy - d.dy, 0.01));
    expect(find.text('0 張'), findsNWidgets(3)); // 官方、同人、成圖
    expect(find.text('0 份'), findsOneWidget);
    expect(find.text('0 個'), findsOneWidget);
    expect(find.text('2 筆'), findsOneWidget);
    expect(find.text('還沒有成圖・開始你的第一張'), findsNothing);
    expect(find.text('雜物'), findsNothing);
    await unmount(tester);
  });

  testWidgets('D-058：成圖格有成圖時用封面圖鋪滿，沒有成圖是 icon 格', (tester) async {
    await pumpPitPage(tester, Brightness.light);
    expect(find.byType(StoredImage), findsNothing);
    await unmount(tester);

    await tester.runAsync(
      () => db.savePiece(
        pitId: pitId,
        title: '成圖甲',
        body: '',
        images: const [NewImage(file: 'p.png')],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 5, 1),
        ideaIds: const [],
        draftIds: const [],
      ),
    );
    await pumpPitPage(tester, Brightness.light);
    expect(find.byType(StoredImage), findsOneWidget);
    expect(find.text('1 張'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('D-058：點推活格進推活列表；推活格長按開選擇封面（推活格自己的封面）', (tester) async {
    await tester.runAsync(() => seedOshi(1));
    await pumpPitPage(tester, Brightness.light);
    await tester.longPress(find.text('推活'));
    await settle(tester);
    expect(find.text('長按中：推活 封面'), findsOneWidget);
    await unmount(tester);

    await pumpPitPage(tester, Brightness.light);
    await tester.tap(find.text('推活'));
    await settle(tester);
    expect(find.text('官方圖冊'), findsNothing); // 已進入推活列表頁
    expect(find.byType(OshiListPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('PitDark：深色推活格 #312B3A，淺色 #ECE6F3', (tester) async {
    Color tileColor() {
      final box = tester.widgetList<Container>(find.byType(Container)).where((
        c,
      ) {
        final d = c.decoration;
        return d is BoxDecoration &&
            (d.color == const Color(0xFF312B3A) ||
                d.color == const Color(0xFFECE6F3));
      });
      expect(box.length, 1);
      return (box.single.decoration! as BoxDecoration).color!;
    }

    await pumpPitPage(tester, Brightness.dark);
    expect(tileColor(), const Color(0xFF312B3A));
    await unmount(tester);
    await pumpPitPage(tester, Brightness.light);
    expect(tileColor(), const Color(0xFFECE6F3));
    await unmount(tester);
  });

  testWidgets('雜物入口只在雜物開關開啟時出現在六格最底', (tester) async {
    await tester.runAsync(
      () => (db.update(db.pits)..where((x) => x.id.equals(pitId))).write(
        const PitsCompanion(junkEnabled: Value(true)),
      ),
    );
    await pumpPitPage(tester, Brightness.light);
    expect(find.text('雜物'), findsOneWidget);
    expect(at(tester, '雜物').dy > at(tester, '推活').dy, isTrue);
    await unmount(tester);
  });

  testWidgets('導覽列：坑內頁有，編輯坑／開新坑沒有', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.text('開新坑').last);
    await settle(tester);
    expect(find.text('目標'), findsNothing);
    await tester.tap(find.bySemanticsLabel('返回'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.text('坑A'));
    await settle(tester);
    expect(find.text('官方圖冊'), findsOneWidget);
    expect(find.text('目標'), findsOneWidget);

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    expect(find.text('編輯坑'), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    await tester.tap(find.bySemanticsLabel('返回'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);
    await unmount(tester);
  });

  Future<void> openEdit(WidgetTester tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('坑A'));
    await settle(tester);
    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
  }

  testWidgets('PitEdit-ntnf：坑內還沒有圖片，沒有封面區', (tester) async {
    await openEdit(tester);
    expect(find.text('編輯坑'), findsOneWidget);
    expect(find.text('封面'), findsNothing);
    await unmount(tester);
  });

  testWidgets('PitEditNoCover：有圖沒封面 → 虛線＋號，點了進選擇封面', (tester) async {
    await tester.runAsync(() => addImageAsync(db, pitId, 'a.png'));
    await openEdit(tester);
    expect(find.text('封面'), findsOneWidget);
    expect(find.bySemanticsLabel('選擇封面'), findsOneWidget);
    expect(find.text('更換封面'), findsNothing);
    await tester.tap(find.bySemanticsLabel('選擇封面'));
    await settle(tester);
    expect(find.text('編輯坑'), findsNothing); // 已進入選擇封面頁
    await unmount(tester);
  });

  testWidgets('PitEdit：有封面 → 縮圖＋更換封面', (tester) async {
    await tester.runAsync(() async {
      final id = await addImageAsync(db, pitId, 'a.png');
      await db.setCover(pitId, id);
    });
    await openEdit(tester);
    expect(find.text('更換封面'), findsOneWidget);
    expect(find.bySemanticsLabel('選擇封面'), findsNothing);
    await unmount(tester);
  });

  testWidgets('雜物開關：儲存後坑內頁最底出現雜物入口', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('坑A'));
    await settle(tester);
    expect(find.text('雜物'), findsNothing);

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    await tester.tap(find.byType(AppSwitch).first);
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await settle(tester);
    final pit = await tester.runAsync(() => db.watchPit(pitId).first);
    expect(pit!.junkEnabled, isTrue);

    expect(find.text('雜物'), findsOneWidget);
    await tester.ensureVisible(find.text('雜物'));
    await tester.tap(find.text('雜物'));
    await settle(tester);
    // 進入雜物列表頁（坑內頁被蓋住，五格不再可見）。
    expect(find.byType(JunkListPage), findsOneWidget);
    expect(find.text('官方圖冊'), findsNothing);
    await unmount(tester);
  });

  testWidgets('離線橫條', (tester) async {
    await pumpApp(tester, online: false);
    await settle(tester);
    expect(find.text('離線中・恢復網絡後將自動上傳'), findsOneWidget);
    expect(find.textContaining('同步中'), findsNothing);
    await unmount(tester);
  });

  testWidgets('封面還沒下載：蓋淡色＋下載 icon；檔案存在時沒有', (tester) async {
    await tester.runAsync(() async {
      final id = await addImageAsync(db, pitId, 'cover.png');
      await db.setCover(pitId, id);
    });
    await pumpApp(tester);
    await settle(tester);
    expect(find.bySemanticsLabel('尚未下載'), findsOneWidget);

    Directory('${tmp.path}/images').createSync(recursive: true);
    File('${tmp.path}/images/cover.png').writeAsBytesSync(const [0]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await unmount(tester);

    // 檔案已經在本機：重新進入主頁不再有遮罩。
    await pumpApp(tester);
    await settle(tester);
    expect(find.bySemanticsLabel('尚未下載'), findsNothing);
    await unmount(tester);
  });
}

Future<String> addImageAsync(AppDatabase db, String pitId, String file) async {
  final groups = await db.select(db.officialGroups).get();
  await db.addOfficial(pitId, groups[0].id, [NewImage(file: file)]);
  return (await db.select(db.officialImages).get()).first.id;
}
