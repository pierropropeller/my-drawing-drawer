import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/debug/dev_options_section.dart';
import 'package:huakeng/debug/layout_bounds.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('開關切換：旗標立即翻轉、整棵樹重繪不報錯、並存進偏好', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: const Scaffold(
            body: SingleChildScrollView(child: DevOptionsSection()),
          ),
        ),
      ),
    );
    expect(find.text('開發者選項'), findsOneWidget);
    expect(find.text('顯示版面邊界'), findsOneWidget);
    expect(find.text('顯示文字基線'), findsOneWidget);
    expect(find.text('顯示點擊區域'), findsOneWidget);
    expect(debugPaintSizeEnabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('devOpt_sizes')));
    await tester.pump();
    expect(debugPaintSizeEnabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('devOpt_baselines')));
    await tester.pump();
    expect(debugPaintBaselinesEnabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('devOpt_pointers')));
    await tester.pump();
    expect(debugPaintPointersEnabled, isTrue);
    expect(tester.takeException(), isNull);

    await tester.runAsync(
      () => LayoutBoundsDebug.set(DebugPaintOption.sizes, true),
    );
    final saved = await tester.runAsync(SharedPreferences.getInstance);
    expect(saved!.getBool('debug_paint_sizes'), isTrue);

    // 還原：旗標清掉後，從偏好讀回。
    debugPaintSizeEnabled = false;
    await tester.runAsync(() => LayoutBoundsDebug.restore(prefs));
    expect(debugPaintSizeEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('devOpt_sizes')));
    await tester.pump();
    expect(debugPaintSizeEnabled, isFalse);
    expect(tester.takeException(), isNull);

    // 測試框架要求結束時所有繪製除錯旗標都已關閉。
    for (final o in DebugPaintOption.values) {
      await tester.runAsync(() => LayoutBoundsDebug.set(o, false));
    }
    await tester.pump();
    expect(debugPaintBaselinesEnabled, isFalse);
    expect(debugPaintPointersEnabled, isFalse);
  });
}
