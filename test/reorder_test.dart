import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/theme/app_theme.dart';
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

  testWidgets('表單圖片格：長按拖到另一張上可改順序', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('reorder');
    final items = [
      for (var i = 0; i < 3; i++)
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
              body: ImagePickerField(
                items: items,
                onAdd: null,
                onRemove: (_) {},
                onReorder: (a, b) => setState(() => moveListItem(items, a, b)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final tiles = find.byType(ReorderTile);
    expect(tiles, findsNWidgets(3));
    final from = tester.getCenter(tiles.at(0));
    final to = tester.getCenter(tiles.at(2));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveTo(to, timeStamp: const Duration(milliseconds: 700));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(
      [for (final i in items) i.picked!.path],
      [paths[1], paths[2], paths[0]],
    );
    tmp.deleteSync(recursive: true);
  });
}
