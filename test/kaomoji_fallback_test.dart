import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/theme/font_fallback.dart';

const _kaomoji = ['(≖ᴗ≖)✧', '(๑•̀ㅂ•́)و✧', 'ಠ_ಠ', 'ᐛ', '꒰ ꒱'];

void main() {
  test('fallback 次序符合 D-090', () {
    expect(kFontFamilyFallback, [
      'NotoSansTC',
      'NotoSans',
      'NotoSansSymbols',
      'NotoSansSymbols2',
      'NotoSansMath',
      'NotoSansThai',
      'NotoSansKannada',
      'NotoSansCanadianAboriginal',
      'NotoSansYi',
    ]);
  });

  test('pubspec 有註冊 fallback 字型，且檔案存在', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in kFontFamilyFallback.skip(1)) {
      expect(pubspec, contains('family: $f'));
      expect(File('assets/fonts/$f-Regular.ttf').existsSync(), isTrue);
    }
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
      expect(theme.textTheme.headlineSmall!.fontFamilyFallback,
          kFontFamilyFallback);
      expect(
          theme.textTheme.titleLarge!.fontFamilyFallback, kFontFamilyFallback);
    });
  }
}
