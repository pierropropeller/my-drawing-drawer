import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/form_image_preview_page.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
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
  Finder removeButtons() => find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.button == true &&
        w.properties.label == '移除圖片',
  );
  Finder thumbs() => find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.button == true &&
        w.properties.label == '預覽圖片',
  );

  Future<(List<ImageItem>, Directory)> pumpField(
    WidgetTester tester, {
    int n = 3,
    void Function(int)? onRemove,
  }) async {
    final tmp = Directory.systemTemp.createTempSync('formprev');
    final items = [
      for (var i = 0; i < n; i++)
        ImageItem.picked(
          XFile((File('${tmp.path}/$i.png')..writeAsBytesSync(_png1x1)).path),
        ),
    ];
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
                    onRemove: (i) {
                      onRemove?.call(i);
                      setState(() => items.removeAt(i));
                    },
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
    return (items, tmp);
  }

  Offset cell(WidgetTester tester, int i) {
    final grid = find.byType(ReorderableImageGrid);
    final origin = tester.getTopLeft(grid);
    final w = tester.getSize(grid).width;
    final size = ((w - 32) / 5).floorToDouble();
    final pitch = size + 8;
    return origin + Offset(i * pitch + size / 2, size / 2);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('點小圖開預覽：顯示 × 與「1 / N」，沒有底部動作列', (tester) async {
    final (_, tmp) = await pumpField(tester);
    await tester.tapAt(cell(tester, 0));
    await settle(tester);
    expect(find.byType(FormImagePreviewPage), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.bySemanticsLabel('關閉'), findsOneWidget);
    expect(find.text('分享'), findsNothing);
    expect(find.text('下載'), findsNothing);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('點第 2 張從第 2 張開始；左右滑換圖、頁碼跟著變', (tester) async {
    final (_, tmp) = await pumpField(tester);
    await tester.tapAt(cell(tester, 1));
    await settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await settle(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(300, 0), 1500);
    await settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('點 × 關閉預覽、回到表單', (tester) async {
    final (_, tmp) = await pumpField(tester);
    await tester.tapAt(cell(tester, 0));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('關閉'));
    await settle(tester);
    expect(find.byType(FormImagePreviewPage), findsNothing);
    expect(find.byType(ImagePickerField), findsOneWidget);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('長按仍是拖曳排序，不會開預覽', (tester) async {
    final (items, tmp) = await pumpField(tester);
    final paths = [for (final i in items) i.picked!.path];
    final g = await tester.startGesture(cell(tester, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(cell(tester, 2));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(FormImagePreviewPage), findsNothing);
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    tmp.deleteSync(recursive: true);
  });

  testWidgets('點小圖右上的 × 仍是移除，不會開預覽', (tester) async {
    final removed = <int>[];
    final (items, tmp) = await pumpField(tester, onRemove: removed.add);
    await tester.tap(removeButtons().at(1));
    await settle(tester);
    expect(removed, [1]);
    expect(items.length, 2);
    expect(find.byType(FormImagePreviewPage), findsNothing);
    expect(thumbs(), findsNWidgets(2));
    tmp.deleteSync(recursive: true);
  });
}
