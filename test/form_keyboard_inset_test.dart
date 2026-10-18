import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_new_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';

/// 鍵盤（viewInsets.bottom）開啟時，表單頁要能捲動、聚焦的欄位在鍵盤上方、沒有 overflow，
/// 也不能出現一大塊空白（底部 inset 被扣兩次）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // 手機 360×800 邏輯像素；鍵盤 320 高。
  const kb = 320.0;
  const screenH = 800.0;

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_kb_inset');
  });

  void phone(WidgetTester tester, {Size logical = const Size(360, screenH)}) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = logical * 3;
    addTearDown(tester.view.reset);
  }

  void keyboard(WidgetTester tester, bool open) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: open ? kb * tester.view.devicePixelRatio : 0,
    );
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    imageStoreProvider.overrideWith(
      (ref) async => ImageStore(Directory('${tmp.path}/images')),
    ),
    onlineProvider.overrideWith((ref) => Stream.value(true)),
  ];

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Brightness brightness = Brightness.dark,
    bool underShell = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(brightness, useGoogleFonts: false),
          // 真實 App 的頁面是疊在外層 Scaffold（底部導覽）裡的 Navigator 上。
          home: underShell
              ? Scaffold(
                  body: Navigator(
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => page),
                  ),
                  bottomNavigationBar: const SizedBox.shrink(),
                )
              : page,
        ),
      ),
    );
    await settle(tester);
  }

  /// 驗證：沒有 overflow 例外、可捲動、聚焦欄位在鍵盤上方、捲動視窗吃滿鍵盤上方的空間（沒有空白塊）。
  Future<void> expectKeyboardOk(
    WidgetTester tester,
    Finder field, {
    double screenH = screenH,
  }) async {
    keyboard(tester, true);
    await settle(tester);
    expect(tester.takeException(), isNull);
    // 把欄位捲進來（真機 focus 時會自動 ensureVisible）。
    await tester.ensureVisible(field);
    await settle(tester);
    final scrollable = find
        .descendant(
          of: find.byType(PitNewPage),
          matching: find.byType(Scrollable),
        )
        .first;
    final vp = tester.getRect(scrollable);
    // 捲動視窗的底邊貼著鍵盤上緣（更高＝多扣了一次 inset＝空白塊）。
    expect(vp.bottom, closeTo(screenH - kb, 1.0), reason: '捲動區底邊應貼著鍵盤上緣');
    final f = tester.getRect(field);
    expect(f.bottom, lessThanOrEqualTo(screenH - kb + 0.5));
    expect(f.top, greaterThanOrEqualTo(vp.top - 0.5));
  }

  for (final dark in [true, false]) {
    final b = dark ? Brightness.dark : Brightness.light;
    final tag = dark ? '深色' : '淺色';

    testWidgets('開新坑（淺坑）手機版 $tag：描述聚焦、鍵盤開啟', (tester) async {
      phone(tester);
      await pumpPage(
        tester,
        const PitNewPage(initialStatus: PitStatus.shallow),
        brightness: b,
      );
      await tester.tap(find.byKey(const ValueKey('pit-desc')));
      await settle(tester);
      await expectKeyboardOk(tester, find.byKey(const ValueKey('pit-desc')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('開新坑（坑）手機版 $tag：坑名聚焦、鍵盤開啟', (tester) async {
      phone(tester, logical: const Size(360, 560));
      await pumpPage(tester, const PitNewPage(), brightness: b);
      await expectKeyboardOk(
        tester,
        find.byKey(const ValueKey('pit-name')),
        screenH: 560,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  }

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('真實 App：主頁→開新淺坑→描述聚焦、鍵盤開啟（$mode）', (tester) async {
      phone(tester);
      await tester.runAsync(() async {
        await db.createPit(name: '坑A');
        await db.createPit(name: '淺B', status: PitStatus.shallow);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            themeModeProvider.overrideWithValue(mode),
          ],
          child: const HuaKengApp(useGoogleFonts: false),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      await tester.tap(find.text('開新淺坑'));
      await settle(tester);
      expect(find.byType(PitNewPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pit-desc')));
      await settle(tester);
      await expectKeyboardOk(tester, find.byKey(const ValueKey('pit-desc')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
    });
  }

  /// 開著真實 App（有一個現坑），回傳那個坑的 id；[open] 在分頁 Navigator 的 context 上開表單。
  Future<void> openInApp(
    WidgetTester tester,
    Future<void> Function(BuildContext ctx, String pitId) open,
  ) async {
    final id = (await tester.runAsync(() => db.createPit(name: '坑A')))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(),
          themeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    final ctx = tester.element(find.byType(PitsPage));
    // ignore: unawaited_futures
    open(ctx, id);
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 第一個文字欄（[within] 之內）：點它、開鍵盤後必須整個在鍵盤上方、沒有 overflow。
  Future<void> expectFieldAboveKeyboard(
    WidgetTester tester,
    Finder within,
    double screenH,
  ) async {
    final fields = find.descendant(
      of: within,
      matching: find.byType(TextField),
    );
    keyboard(tester, true);
    await settle(tester);
    expect(tester.takeException(), isNull);
    // 有些表單（官方圖）沒有文字欄，只驗證版面。
    if (fields.evaluate().isEmpty) return;
    final field = fields.first;
    await tester.ensureVisible(field);
    await tester.tap(field);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(field);
    await settle(tester);
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(screenH - kb + 0.5));
    expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
  }

  final phoneForms =
      <String, (Future<void> Function(BuildContext, String), Type)>{
        '編輯坑': (
          (c, id) async => Navigator.of(c).push(
            MaterialPageRoute<void>(builder: (_) => PitEditPage(pit: _pit!)),
          ),
          PitEditPage,
        ),
        '新增官方圖': ((c, id) => openOfficialNew(c, pitId: id), OfficialNewPage),
        '新增同人圖': ((c, id) => openFanArtNew(c, pitId: id), FanArtNewPage),
      };

  for (final e in phoneForms.entries) {
    testWidgets('手機真實 App：${e.key}鍵盤開啟，欄位在鍵盤上方、捲動區吃滿鍵盤上方空間', (tester) async {
      phone(tester);
      _pit = null;
      await openInApp(tester, (c, id) async {
        _pit = await db.watchPit(id).first;
        await e.value.$1(c, id);
      });
      expect(find.byType(e.value.$2), findsOneWidget);
      final page = find.byType(e.value.$2);
      await expectFieldAboveKeyboard(tester, page, screenH);
      final vp = tester.getRect(
        find.descendant(of: page, matching: find.byType(Scrollable)).first,
      );
      expect(vp.bottom, closeTo(screenH - kb, 1.0));
      await close(tester);
    });
  }

  // iPad（1194×834）置中 modal：對話框縮在鍵盤上方，欄位可見。
  final padModals =
      <String, (Future<void> Function(BuildContext, String), Type)>{
        '開新坑': ((c, id) => openNewPit(c), PitNewPage),
        '編輯坑': ((c, id) => openPitEdit(c, _pit!), PitEditPage),
        '新增官方圖': ((c, id) => openOfficialNew(c, pitId: id), OfficialNewPage),
        '新增同人圖': ((c, id) => openFanArtNew(c, pitId: id), FanArtNewPage),
      };
  for (final e in padModals.entries) {
    testWidgets('iPad modal：${e.key}鍵盤開啟，沒有 overflow、對話框在鍵盤上方', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1194, 834);
      addTearDown(tester.view.reset);
      _pit = null;
      await openInApp(tester, (c, id) async {
        _pit = await db.watchPit(id).first;
        await e.value.$1(c, id);
      });
      expect(find.byType(e.value.$2), findsOneWidget);
      final page = find.byType(e.value.$2);
      await expectFieldAboveKeyboard(tester, page, 834);
      final dialog = tester.getRect(page);
      expect(dialog.bottom, lessThanOrEqualTo(834 - kb + 0.5));
      await close(tester);
    });
  }
}

Pit? _pit;
