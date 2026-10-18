import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/theme/font_fallback.dart';

/// D-090：真實字型渲染驗證（不是檢查 style／cmap）。
///
/// 背景：Flutter 切字型時，「底字＋組合字元」若分屬不同 family 會整個 cluster 變豆腐或不畫，
/// 所以 fallback 必須是單一合併 family（DrawerSymbols）。
///
/// 方法：主字型用 test/fixtures/MainProxy.ttf（Noto Sans 的 ASCII＋ω＋• 子集，代替執行期
/// 下載的 Noto Sans TC；它的字形和 DrawerSymbols 裡的 Noto Sans 完全相同）。
/// 「參考圖」＝直接用 DrawerSymbols 當主字型渲染（整個 cluster 一定在同一個字型內）。
/// 「實際圖」＝主字型 MainProxy＋app 的 kFontFamilyFallback。兩者逐像素必須相同；
/// 豆腐、空白、組合字元錯位都會造成差異。
/// 另外要求參考圖本身有畫出東西（與單獨「(」不同），確保字型真的有這些字形。
/// 負向對照：fallback 清空時，實際圖必須與參考圖不同，證明比對方法有效。
/// 設環境變數 KAOMOJI_PNG_DIR 可把渲染結果輸出成 PNG 目視檢查。

const _size = 36.0;

Future<void> _load(String family, String path) async {
  final l = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await l.load();
}

/// CJK／全形字元由主字型 Noto Sans TC 負責，測試環境沒有，先拿掉（ω 也拿掉：它屬於主字型，
/// 且字距在兩種字型下有 1px 級差異，與 fallback 無關）。
String _stripPrimary(String s) => String.fromCharCodes(
  s.runes.where(
    (c) =>
        c != 0x03C9 &&
        !(c >= 0x4E00 && c <= 0x9FFF ||
            c >= 0x3130 && c <= 0x318F ||
            c >= 0xFE30 && c <= 0xFE4F),
  ),
);

var _pngCount = 0;

/// 回傳每個像素是否為深色（1／0）。
Future<Uint8List> _render(
  WidgetTester tester,
  List<String> rows, {
  required String family,
  required List<String> fallback,
  bool field = false,
  String tag = '',
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final style = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: _size,
    color: Colors.black,
    height: 1.5,
  );
  const strut = StrutStyle(
    fontFamily: 'MainProxy',
    fontSize: _size,
    height: 1.5,
    forceStrutHeight: true,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Material(
          color: Colors.white,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: field
                  ? SizedBox(
                      width: 800,
                      child: TextField(
                        maxLines: null,
                        style: style,
                        strutStyle: strut,
                        decoration: null,
                        controller: TextEditingController(
                          text: rows.join('\n'),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in rows)
                          Text(r, style: style, strutStyle: strut),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  late Uint8List dark;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage();
    final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    dark = Uint8List(img.width * img.height);
    for (var i = 0; i < dark.length; i++) {
      dark[i] = d.getUint8(i * 4) < 128 ? 1 : 0;
    }
    final dir = Platform.environment['KAOMOJI_PNG_DIR'];
    if (dir != null && tag.isNotEmpty) {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$dir/${_pngCount++}_$tag.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
  return dark;
}

int _diff(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) n++;
  }
  return n;
}

bool _isMark(int c) =>
    (c >= 0x0300 && c <= 0x036F) ||
    (c >= 0x1DC0 && c <= 0x1DFF) ||
    (c >= 0x0E31 && c <= 0x0E3A && c != 0x0E32 && c != 0x0E33) ||
    (c >= 0x0E47 && c <= 0x0E4E) ||
    (c >= 0x17B4 && c <= 0x17D3 && c != 0x17D4) ||
    (c >= 0x1BE6 && c <= 0x1BF3) ||
    c == 0x1CD0 ||
    c == 0xFF9E ||
    c == 0xFF9F;

void main() {
  final samples = File('tool/kaomoji_samples.txt')
      .readAsLinesSync()
      .where((l) => l.isNotEmpty)
      .map(_stripPrimary)
      .toList();

  // 所有「非 ASCII 底字＋後面接的組合字元」cluster。
  final clusters = <String>{};
  for (final s in samples) {
    final chars = s.runes.map(String.fromCharCode).toList();
    for (var i = 0; i < chars.length; i++) {
      if (chars[i].codeUnitAt(0) < 0x80 || _isMark(chars[i].runes.first)) {
        continue;
      }
      var j = i + 1;
      while (j < chars.length && _isMark(chars[j].runes.first)) {
        j++;
      }
      clusters.add(chars.sublist(i, j).join());
      i = j - 1;
    }
  }

  Future<void> setup() async {
    await _load('MainProxy', 'test/fixtures/MainProxy.ttf');
    await _load('DrawerSymbols', 'assets/fonts/DrawerSymbols-Regular.ttf');
  }

  testWidgets('Text 與 TextField 整串顏文字：實際渲染等於「整串在同一字型」的參考圖', (tester) async {
    await setup();
    for (final field in [false, true]) {
      final name = field ? 'field' : 'text';
      final ref = await _render(
        tester,
        samples,
        family: 'DrawerSymbols',
        fallback: const [],
        field: field,
        tag: '${name}_reference',
      );
      final actual = await _render(
        tester,
        samples,
        family: 'MainProxy',
        fallback: kFontFamilyFallback,
        field: field,
        tag: '${name}_actual',
      );
      expect(_diff(actual, ref), 0, reason: '$name：與參考圖有差異（豆腐／空白／錯位）');

      // 負向對照：沒有 fallback 時一定不同。
      final none = await _render(
        tester,
        samples,
        family: 'MainProxy',
        fallback: const [],
        field: field,
        tag: '${name}_nofallback',
      );
      expect(_diff(none, ref), greaterThan(1000), reason: '比對方法無效');
    }
  });

  testWidgets('每個 cluster 逐一渲染：有畫出來，且與參考圖相同', (tester) async {
    await setup();
    final base = await _render(
      tester,
      ['('],
      family: 'DrawerSymbols',
      fallback: const [],
    );
    final bad = <String>[];
    for (final c in clusters) {
      final ref = await _render(
        tester,
        ['($c'],
        family: 'DrawerSymbols',
        fallback: const [],
      );
      final actual = await _render(
        tester,
        ['($c'],
        family: 'MainProxy',
        fallback: kFontFamilyFallback,
      );
      // 字型真的有這個 cluster 的字形（有畫出與單獨「(」不同的東西），且實際渲染相同。
      if (_diff(ref, base) == 0 || _diff(actual, ref) != 0) bad.add(c);
    }
    expect(bad, isEmpty, reason: '缺字形或 cluster 被拆到不同 family：${bad.join(' ')}');
  });
}
