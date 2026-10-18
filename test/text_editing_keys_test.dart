import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_actions.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/search/pit_search_page.dart';

/// Gboard 文本編輯面板（方向鍵／選擇／全選）在 Android 上透過 InputConnection 送
/// DPAD 按鍵與 setSelection；這裡在 Dart 端模擬同樣的輸入，確認 App 沒有攔截或吞掉：
/// 方向鍵移動游標、Shift＋方向鍵選取、全選、以及 IME 送來的 selection 更新。
/// 頁面放在和真實 App 一樣的外層（Scaffold＋Navigator＋removeViewInsets，鍵盤開啟）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_text_keys');
    pitId = await db.createPit(name: '測試坑');
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 800) * 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 320 * 3);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: Navigator(
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => page),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 對畫面上第一個輸入框跑完整的游標／選取操作。
  Future<void> exercise(WidgetTester tester) async {
    final field = find.byType(EditableText).first;
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'hello world');
    await tester.pump();
    EditableTextState st() => tester.state<EditableTextState>(field);
    TextSelection sel() => st().textEditingValue.selection;
    expect(sel(), const TextSelection.collapsed(offset: 11));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(sel(), const TextSelection.collapsed(offset: 10));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(sel(), const TextSelection.collapsed(offset: 11));

    // Shift＋左：向左擴選。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(sel().baseOffset, 11);
    expect(sel().extentOffset, 9);

    // 全選。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(sel(), const TextSelection(baseOffset: 0, extentOffset: 11));

    // IME（Gboard 面板）直接送 selection 更新。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();
    expect(sel(), const TextSelection.collapsed(offset: 3));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 0, extentOffset: 11),
      ),
    );
    await tester.pump();
    expect(sel(), const TextSelection(baseOffset: 0, extentOffset: 11));

    // IME 回報 selection 之後，方向鍵仍以新位置為準。
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(sel(), const TextSelection.collapsed(offset: 6));

    // 整個過程中內容不能被改寫。
    expect(st().textEditingValue.text, 'hello world');
    await unmount(tester);
  }

  testWidgets('腦洞編輯', (tester) async {
    await pumpPage(tester, IdeaFormPage(pitId: pitId));
    await exercise(tester);
  });

  testWidgets('摸魚新增', (tester) async {
    await pumpPage(tester, DraftFormPage(pitId: pitId));
    await exercise(tester);
  });

  testWidgets('坑新增', (tester) async {
    await pumpPage(tester, const PitNewPage());
    await exercise(tester);
  });

  testWidgets('搜尋', (tester) async {
    await pumpPage(tester, PitSearchPage(pitId: pitId));
    await exercise(tester);
  });

  testWidgets('腦洞內文（多行）', (tester) async {
    await pumpPage(tester, IdeaFormPage(pitId: pitId));
    final multi = find.byWidgetPredicate(
      (w) => w is EditableText && w.maxLines != 1,
    );
    expect(multi, findsWidgets);
    final field = multi.first;
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'ab\ncd');
    await tester.pump();
    final st = tester.state<EditableTextState>(field);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(st.textEditingValue.selection.isCollapsed, isTrue);
    expect(st.textEditingValue.selection.baseOffset, lessThan(3));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(st.textEditingValue.selection.baseOffset, greaterThan(2));
    await unmount(tester);
  });

  testWidgets('模態對話框內的輸入框', (tester) async {
    await pumpPage(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => promptText(context, title: 't'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await exercise(tester);
  });
}
