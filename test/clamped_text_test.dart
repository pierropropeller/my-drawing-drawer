import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/clamped_text.dart';

/// 測試環境的字型是 Ahem：每個字都是 fontSize×fontSize 的方塊，所以 fontSize 10、寬 100 ＝ 一行 10 字。
void main() {
  const style = TextStyle(fontSize: 10, height: 1);

  String? clamp(String s, {double width = 100, int lines = 2}) =>
      clampTextToLines(s, style: style, maxWidth: width, maxLines: lines);

  group('clampTextToLines', () {
    test('放得下：原樣（不加省略號）', () {
      expect(clamp('abc'), 'abc');
      expect(clamp('a\nb'), 'a\nb');
    });

    test('剛好填滿 maxLines 也不加省略號', () {
      expect(clamp('0123456789' * 2), '0123456789' * 2);
      expect(clamp('a\nb'), 'a\nb');
    });

    test('空字串、只有空白／換行', () {
      expect(clamp(''), '');
      expect(clamp('  \n\n '), '');
    });

    test('結尾的空行不算內容：不會因此出現省略號', () {
      expect(clamp('a\nb\n\n\n'), 'a\nb');
    });

    test('三行文字只顯示兩行（硬換行截斷）：省略號接在最後可見字後', () {
      expect(clamp('a\nb\nc'), 'a\nb…');
    });

    test('截斷點落在空行：退到前一個非空行的行尾', () {
      expect(clamp('a\nb\n\nc'), 'a\nb…');
      expect(clamp('a\n\nc'), 'a…');
      expect(clamp('a\n\n\n\nc', lines: 3), 'a…');
    });

    test('maxLines 1，多行文字', () {
      expect(clamp('第一行\n第二行', lines: 1), '第一行…');
    });

    test('軟換行：太長自動折行，被截斷後最後一行接省略號且塞得進', () {
      final out = clamp('0123456789' * 3)!; // 30 字，一行 10 字，只顯示 2 行
      expect(out.endsWith('…'), isTrue);
      expect(out.length, lessThanOrEqualTo(20));
      expect(out, '0123456789012345678…');
    });

    test('軟換行加硬換行混合', () {
      // 第 1 行 10 字、第 2 行 3 字，第 3 行被截。
      expect(clamp('0123456789\nabc\ndef'), '0123456789\nabc…');
    });

    test('CJK：不用空白也能逐字折行', () {
      final out = clamp('一二三四五六七八九十甲乙丙丁戊己庚辛壬癸子丑寅卯')!;
      expect(out, '一二三四五六七八九十甲乙丙丁戊己庚辛壬…');
    });

    test('emoji（含 ZWJ 組合）不會被切成半個', () {
      const family = '👨‍👩‍👧'; // 一個 grapheme，多個 code unit
      final out = clamp('${'a' * 19}$family${'b' * 10}')!;
      expect(out.endsWith('…'), isTrue);
      // 去掉省略號後，不能留下孤立的 ZWJ／surrogate。
      final body = out.substring(0, out.length - 1);
      expect(body.endsWith('‍'), isFalse);
      for (final r in body.runes) {
        expect(r >= 0xD800 && r <= 0xDFFF, isFalse);
      }
    });

    test('窄寬度也塞得進：省略號不會多折出第三行', () {
      final out = clamp('abcdefghij' * 5, width: 30)!;
      expect(out.endsWith('…'), isTrue);
      expect(out.length, lessThanOrEqualTo(6));
    });

    test('量不出來（寬度無限）→ null', () {
      expect(clamp('a\nb\nc', width: double.infinity), isNull);
    });
  });

  group('ClampedText', () {
    Future<void> pump(WidgetTester t, String s, {double width = 100}) {
      return t.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ClampedText(s, maxLines: 2, style: style),
            ),
          ),
        ),
      );
    }

    String shown(WidgetTester t) => t
        .renderObject<RenderClampedText>(find.byType(ClampedParagraph))
        .shownText;

    testWidgets('三行文字顯示兩行加省略號', (t) async {
      await pump(t, 'a\nb\nc');
      expect(shown(t), 'a\nb…');
      expect(t.getSize(find.byType(ClampedText)).height, 20);
    });

    testWidgets('放得下就是原文', (t) async {
      await pump(t, 'a\nb');
      expect(shown(t), 'a\nb');
    });

    testWidgets('可以放進 IntrinsicHeight（時間軸列的用法）', (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: ClampedText('a\nb\nc', maxLines: 2, style: style),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      expect(shown(t), 'a\nb…');
    });
  });
}
