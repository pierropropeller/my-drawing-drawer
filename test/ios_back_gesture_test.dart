import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/root_overlay_guard.dart';
import 'package:huakeng/ui/pits/pit_section_tabs.dart';
import 'package:huakeng/ui/reference/reference_viewer.dart';

/// iOS 邊緣右滑返回：主題要有 Cupertino 轉場、一般頁面不被 PopScope 攔截。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// 以指定平台跑測試；結束前（invariant 檢查之前）還原。
  void platformTest(
    String name,
    TargetPlatform platform,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  Widget app(Widget home, {GlobalKey<NavigatorState>? key}) => MaterialApp(
    navigatorKey: key,
    theme: buildTheme(Brightness.light, useGoogleFonts: false),
    home: home,
  );

  test('主題：iOS／macOS 用 Cupertino 轉場，Android 仍是返回護欄', () {
    final b = buildTheme(
      Brightness.light,
      useGoogleFonts: false,
    ).pageTransitionsTheme.builders;
    expect(b[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(b[TargetPlatform.macOS], isA<CupertinoPageTransitionsBuilder>());
    expect(
      b[TargetPlatform.android],
      isA<RootOverlayGuardTransitionsBuilder>(),
    );
  });

  platformTest('iOS：一般 push 的頁面可邊緣右滑返回', TargetPlatform.iOS, (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(const Text('home'), key: nav));
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))),
    );
    await tester.pumpAndSettle();
    final route = ModalRoute.of(tester.element(find.text('B')))!;
    expect(route.popGestureEnabled, isTrue);

    // 從左緣往右拖：手勢進行中，放開後返回。
    final g = await tester.startGesture(const Offset(2, 300));
    await g.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(route.popGestureInProgress, isTrue);
    await g.moveBy(const Offset(300, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  platformTest(
    'iOS：外層（如 Shell）的 PopScope(canPop:false) 不影響子路由的手勢',
    TargetPlatform.iOS,
    (tester) async {
      final inner = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        app(
          PopScope(
            canPop: false,
            child: Navigator(
              key: inner,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('root')),
              ),
            ),
          ),
        ),
      );
      inner.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('B')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        ModalRoute.of(tester.element(find.text('B')))!.popGestureEnabled,
        isTrue,
      );
    },
  );

  platformTest(
    'iOS：頁面有 PopScope(canPop:false)（攔截返回）時手勢停用，canPop:true 時啟用',
    TargetPlatform.iOS,
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final canPop = ValueNotifier<bool>(false);
      await tester.pumpWidget(app(const Text('home'), key: nav));
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: canPop,
            builder: (_, v, _) => PopScope(
              canPop: v,
              child: const Scaffold(body: Text('B')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('B')))!;
      expect(route.popGestureEnabled, isFalse);
      canPop.value = true;
      await tester.pump();
      expect(route.popGestureEnabled, isTrue);
    },
  );

  platformTest('iOS：坑分區換頁（pushReplacement）後的頁面仍可右滑返回', TargetPlatform.iOS, (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(const Text('home'), key: nav));
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('first')),
      ),
    );
    await tester.pumpAndSettle();
    // 與 PitSectionTabBar.replaceWith 相同的路由。
    nav.currentState!.pushReplacement(
      InstantPageRoute<void>(builder: (_) => const Scaffold(body: Text('B'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('B')))!;
    expect(route.popGestureEnabled, isTrue);
  });

  platformTest(
    'Android：主題轉場仍是返回護欄，沒有 Cupertino 邊緣手勢（行為不變）',
    TargetPlatform.android,
    (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(const Text('home'), key: nav));
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('B')),
        ),
      );
      await tester.pumpAndSettle();
      final g = await tester.startGesture(const Offset(2, 300));
      await g.moveBy(const Offset(300, 0));
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    },
  );

  group('參考圖檢視頁', () {
    late AppDatabase db;
    late Directory tmp;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('ios_back');
      await Directory('${tmp.path}/images').create(recursive: true);
      File('${tmp.path}/images/a.png').writeAsBytesSync([0, 1, 2]);
    });
    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    platformTest('iOS：ReferenceViewerPage 不攔截返回（可右滑返回）', TargetPlatform.iOS, (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext ctx;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            imageTransferProvider.overrideWith(
              (ref, file) => ImageDownloadStatus.present,
            ),
            imageStoreProvider.overrideWith(
              (ref) async => ImageStore(Directory('${tmp.path}/images')),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            theme: buildTheme(Brightness.dark, useGoogleFonts: false),
            home: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      // ignore: unawaited_futures
      openReferenceViewer(
        ctx,
        images: const [
          RefImage(id: 'a', file: 'a.png', width: 100, height: 150),
        ],
        index: 0,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final route = ModalRoute.of(
        tester.element(find.byType(ReferenceViewer)),
      )!;
      expect(route.popGestureEnabled, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
    });
  });
}
