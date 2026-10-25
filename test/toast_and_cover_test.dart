import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_actions.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/common/top_toast.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';

/// D-114 提示條位置／樣式／時間，D-115 編輯坑的更換封面「儲存才寫入」。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('D-114 提示條（Snackbar）', () {
    const screen = Size(390, 844);
    var undone = 0;
    setUp(() => undone = 0);

    Future<void> pumpHost(
      WidgetTester tester, {
      Widget? bottom,
      Brightness brightness = Brightness.light,
      double keyboard = 0,
    }) async {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness, useGoogleFonts: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          showSnack(context, '已刪除 3 張', success: true),
                      child: const Text('go'),
                    ),
                    TextButton(
                      onPressed: () => showSnack(
                        context,
                        '第二條',
                        actionLabel: '復原',
                        onAction: () => undone++,
                      ),
                      child: const Text('go2'),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: bottom,
          ),
        ),
      );
    }

    tearDown(hideTopToast);

    Rect toastRect(WidgetTester tester, String text) {
      final box = find.ancestor(
        of: find.text(text),
        matching: find.byType(Container),
      );
      return tester.getRect(box.first);
    }

    testWidgets('沒有固定底部元件：離螢幕底 16、左右各 16，圓角 14、內距 12×16、淺色模式深底白字', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final r = toastRect(tester, '已刪除 3 張');
      expect(screen.height - r.bottom, closeTo(16, 0.5));
      expect(r.left, 16);
      expect(screen.width - r.right, 16);
      final deco =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('已刪除 3 張'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, const Color(0xFF2B2622));
      expect(deco.borderRadius, BorderRadius.circular(14));
      expect(
        tester.widget<Text>(find.text('已刪除 3 張')).style!.color,
        Colors.white,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('已刪除 3 張'), findsNothing);
    });

    testWidgets('深色模式反白：淺底 #F2ECE4、深字 #2B2622', (tester) async {
      await pumpHost(tester, brightness: Brightness.dark);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final deco =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('已刪除 3 張'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco.color, const Color(0xFFF2ECE4));
      expect(
        tester.widget<Text>(find.text('已刪除 3 張')).style!.color,
        const Color(0xFF2B2622),
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('有底部導覽列／操作列（BottomInsetAnchor）：浮在它上方 12', (tester) async {
      await pumpHost(
        tester,
        bottom: const BottomInsetAnchor(
          child: SizedBox(height: 74, key: Key('bar')),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final bar = tester.getRect(find.byKey(const Key('bar')));
      final r = toastRect(tester, '已刪除 3 張');
      expect(bar.top - r.bottom, closeTo(12, 0.5));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('鍵盤打開：浮在鍵盤上方 12', (tester) async {
      await pumpHost(tester, keyboard: 300);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final r = toastRect(tester, '已刪除 3 張');
      expect(screen.height - 300 - r.bottom, closeTo(12, 0.5));
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('新的取代舊的（同時只有一條）；有按鈕撐 5 秒、按鈕可點並收起', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('go2'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('已刪除 3 張'), findsNothing);
      expect(find.text('第二條'), findsOneWidget);
      // 3 秒後仍在（有按鈕＝5 秒）。
      await tester.pump(const Duration(milliseconds: 3200));
      expect(find.text('第二條'), findsOneWidget);
      await tester.tap(find.text('復原'));
      await tester.pump();
      expect(undone, 1);
      expect(find.text('第二條'), findsNothing);
    });

    testWidgets('往下滑收掉', (tester) async {
      await pumpHost(tester);
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(find.text('已刪除 3 張'), const Offset(0, 80));
      await tester.pump();
      expect(find.text('已刪除 3 張'), findsNothing);
    });

    test('程式碼裡沒有人直接用 SnackBar（一律走 showSnack）', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('lib/l10n/')) continue;
        final s = f.readAsStringSync();
        if (s.contains('showSnackBar(') || s.contains('SnackBar(')) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty);
    });

    test('表單（新增／編輯頁）沒有呼叫 showSnack（D-114）', () {
      const forms = [
        'lib/ui/album/fan_art_new_page.dart',
        'lib/ui/album/official_new_page.dart',
        'lib/ui/oshi/oshi_form_page.dart',
        'lib/ui/goals/goal_new_page.dart',
        'lib/ui/entity/draft_form_page.dart',
        'lib/ui/entity/piece_form_page.dart',
        'lib/ui/entity/idea_form_page.dart',
        'lib/ui/me/profile_edit_page.dart',
        'lib/ui/pits/pit_edit_page.dart',
      ];
      for (final f in forms) {
        expect(
          File(f).readAsStringSync().contains('showSnack('),
          isFalse,
          reason: f,
        );
      }
    });
  });

  group('D-115 編輯坑：更換封面儲存才寫入', () {
    late AppDatabase db;
    late Directory tmp;
    late String pitId;
    final navKey = GlobalKey<NavigatorState>();

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('huakeng_d115');
      await Directory('${tmp.path}/images').create();
      pitId = await db.createPit(name: '坑X');
      final g = (await db.watchGroups(pitId).first).first;
      await db.addOfficial(pitId, g.id, const [
        NewImage(file: 'o1.png', width: 10, height: 10),
        NewImage(file: 'o2.png', width: 10, height: 10),
      ]);
    });
    tearDown(() async => db.close());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpEdit(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pit = (await tester.runAsync(() => db.watchPit(pitId).first))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${tmp.path}/images')),
            ),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            home: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const Text('home')),
              observers: const [],
            ),
          ),
        ),
      );
      final nav = navKey.currentState!;
      // ignore: unawaited_futures
      nav.push(MaterialPageRoute<void>(builder: (_) => PitEditPage(pit: pit)));
      await settle(tester);
    }

    Finder img(String file) =>
        find.byWidgetPredicate((w) => w is StoredImage && w.file == file);

    Future<void> pickOnCoverPage(WidgetTester tester, String file) async {
      await tester.tap(find.bySemanticsLabel('選擇封面'));
      await settle(tester);
      expect(find.byType(CoverPickPage), findsOneWidget);
      await tester.tap(img(file));
      await settle(tester);
      expect(find.byType(CoverPickPage), findsNothing);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<Pit> pit(WidgetTester tester) async =>
        (await tester.runAsync(() => db.watchPit(pitId).first))!;

    testWidgets('選封面後返回編輯頁：只更新預覽，資料庫沒變、沒有提示條；按儲存才寫入', (tester) async {
      await pumpEdit(tester);
      await pickOnCoverPage(tester, 'o2.png');
      // 預覽換成新選的那張，但資料庫還沒動。
      expect(img('o2.png'), findsOneWidget);
      expect((await pit(tester)).coverImageId, isNull);
      expect(find.text('已設為坑的封面'), findsNothing);
      expect(topToastShowing, isFalse);
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final saved = await pit(tester);
      expect(saved.coverImageId, isNotNull);
      final imgs = await tester.runAsync(() => db.watchOfficial(pitId).first);
      expect(
        imgs!.firstWhere((i) => i.id == saved.coverImageId).imageFile,
        'o2.png',
      );
      await unmount(tester);
    });

    testWidgets('選了封面但不儲存就返回：封面變更作廢', (tester) async {
      await pumpEdit(tester);
      await pickOnCoverPage(tester, 'o1.png');
      expect(img('o1.png'), findsOneWidget);
      navKey.currentState!.pop();
      await settle(tester);
      expect(find.text('home'), findsOneWidget);
      expect((await pit(tester)).coverImageId, isNull);
      expect(topToastShowing, isFalse);
      await unmount(tester);
    });
  });
}
