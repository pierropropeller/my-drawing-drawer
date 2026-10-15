import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
import 'package:huakeng/ui/common/dashed_box.dart';
import 'package:huakeng/ui/common/reorder_tile.dart';
import 'package:image_picker/image_picker.dart';

const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

void main() {
  test('moveListItem 把第 from 項插到 to 的位置', () {
    final l = [1, 2, 3, 4];
    moveListItem(l, 0, 2);
    expect(l, [2, 3, 1, 4]);
    moveListItem(l, 3, 0);
    expect(l, [4, 2, 3, 1]);
    moveListItem(l, 1, 1);
    moveListItem(l, 9, 0);
    expect(l, [4, 2, 3, 1]);
  });

  Finder removeButtons() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.button == true,
  );

  Future<(List<ImageItem>, List<String>, Directory)> pumpField(
    WidgetTester tester, {
    int n = 3,
  }) async {
    final tmp = Directory.systemTemp.createTempSync('reorder');
    final items = [
      for (var i = 0; i < n; i++)
        ImageItem.picked(
          XFile((File('${tmp.path}/$i.png')..writeAsBytesSync(_png1x1)).path),
        ),
    ];
    final paths = [for (final i in items) i.picked!.path];
    await tester.pumpWidget(
      ProviderScope(
        child: StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ImagePickerField(
                    items: items,
                    onAdd: () {},
                    onRemove: (_) {},
                    onReorder: (a, b) =>
                        setState(() => moveListItem(items, a, b)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (items, paths, tmp);
  }

  // 第 i 格的中心（84px 格、間距 8、左邊距 20；一排塞得下就都在第一排）。
  Offset cell(WidgetTester tester, int i) {
    final origin = tester.getTopLeft(find.byType(ReorderableImageGrid));
    return origin + Offset((i % 4) * 92 + 42, (i ~/ 4) * 92 + 42);
  }

  testWidgets('長按浮起：× 全隱藏、原位變虛線空位，放手後 × 回來', (tester) async {
    final (items, paths, tmp) = await pumpField(tester);
    expect(removeButtons(), findsNWidgets(3));
    final dashedBefore = find.byType(DashedBox).evaluate().length;
    final g = await tester.startGesture(cell(tester, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(removeButtons(), findsNothing);
    expect(find.byType(DashedBox).evaluate().length, dashedBefore + 1);
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(removeButtons(), findsNWidgets(3));
    expect([for (final i in items) i.picked!.path], paths);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('拖到另一格：其他圖讓位，放手後順序改變', (tester) async {
    final (items, paths, tmp) = await pumpField(tester);
    final g = await tester.startGesture(cell(tester, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(cell(tester, 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 讓位完成：原本第 2、3 張往前滑一格。
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tile1'))).dx,
      tester.getTopLeft(find.byType(ReorderableImageGrid)).dx,
    );
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    tmp.deleteSync(recursive: true);
  });

  testWidgets('拖到「＋」格＝排到最後；＋ 不可拖', (tester) async {
    final (items, paths, tmp) = await pumpField(tester);
    final g = await tester.startGesture(cell(tester, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(cell(tester, 3)); // ＋ 在第 4 格
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    // 長按「＋」：什麼都不會發生。
    final p = await tester.startGesture(cell(tester, 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DashedBox).evaluate().length, 1);
    await p.up();
    await tester.pump();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('拖到格子範圍外＝排到最後；原地放手順序不變', (tester) async {
    final (items, paths, tmp) = await pumpField(tester);
    var g = await tester.startGesture(cell(tester, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(cell(tester, 0) + const Offset(0, 160));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    g = await tester.startGesture(cell(tester, 1));
    await tester.pump(const Duration(milliseconds: 400));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    tmp.deleteSync(recursive: true);
  });

  testWidgets('點 × 仍可移除、不會觸發拖曳', (tester) async {
    final (_, _, tmp) = await pumpField(tester);
    await tester.tap(removeButtons().first);
    await tester.pump();
    expect(find.byType(DashedBox).evaluate().length, 1);
    tmp.deleteSync(recursive: true);
  });
}
