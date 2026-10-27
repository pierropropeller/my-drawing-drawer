import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/theme/font_fallback.dart';

final _kaomoji = File('tool/kaomoji_samples.txt')
    .readAsLinesSync()
    .where((l) => l.isNotEmpty)
    .toList();

void main() {
  test('fallback 只有單一合併 family，且 pubspec 有註冊、檔案存在', () {
    expect(kFontFamilyFallback, ['DrawerSymbols']);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: DrawerSymbols'));
    expect(pubspec, contains('assets/fonts/DrawerSymbols-Regular.ttf'));
    expect(File('assets/fonts/DrawerSymbols-Regular.ttf').existsSync(), isTrue);
  });

  testWidgets('FontManifest 有 DrawerSymbols，且字型檔真的被打包', (tester) async {
    await tester.runAsync(() async {
      final manifest = await rootBundle.loadString('FontManifest.json');
      expect(manifest, contains('"family":"DrawerSymbols"'));
      final data = await rootBundle.load(
        'assets/fonts/DrawerSymbols-Regular.ttf',
      );
      expect(data.lengthInBytes, greaterThan(100000));
    });
  });

  for (final b in Brightness.values) {
    testWidgets('輸入框與列表的 effective style 帶 fallback（${b.name}）', (
      tester,
    ) async {
      final theme = buildTheme(b, useGoogleFonts: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: TextEditingController(text: _kaomoji[0])),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in _kaomoji) ListTile(title: Text(s)),
                      // 帶自訂 TextStyle（只改字級）的 Text 也要繼承
                      const Text('ಠ_ಠ', style: TextStyle(fontSize: 20)),
                      Text('ᐛ', style: theme.textTheme.headlineSmall),
                      Text('꒰ ꒱', style: theme.textTheme.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.style.fontFamilyFallback, kFontFamilyFallback);

      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        // 還原 effective style：DefaultTextStyle 合併 Text.style。
        final ctx = tester.element(find.byWidget(text));
        final eff = DefaultTextStyle.of(ctx).style.merge(text.style);
        expect(
          eff.fontFamilyFallback,
          kFontFamilyFallback,
          reason: 'Text "${text.data}" 缺 fontFamilyFallback',
        );
      }

      // Serif 標題也要有同樣 fallback。
      expect(
        theme.textTheme.headlineSmall!.fontFamilyFallback,
        kFontFamilyFallback,
      );
      expect(
        theme.textTheme.titleLarge!.fontFamilyFallback,
        kFontFamilyFallback,
      );
    });
  }
}
