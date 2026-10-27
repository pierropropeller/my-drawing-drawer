import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitId;
  var n = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('huakeng_fresh');
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '測試坑');
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('官方圖冊：連加三張，每次存完列表立刻出現新圖（真檔案 IO，不重建 provider／DB）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imagePickerProvider.overrideWithValue((_) async {
            final f = File('${tmp.path}/pick${n++}.png')
              ..writeAsBytesSync(_png1x1);
            return [XFile(f.path)];
          }),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('官方圖冊'));
    await settle(tester);
    for (var round = 1; round <= 3; round++) {
      await tester.tap(
        round == 1 ? find.text('加圖') : find.byType(FloatingActionButton),
      );
      await settle(tester);
      await tester.tap(find.text('加入官方圖冊'));
      await settle(tester);
      await settle(tester);
      final rows = await tester.runAsync(() => db.watchOfficial(pitId).first);
      expect(rows!.length, round);
      expect(find.byType(Image), findsNWidgets(round), reason: 'round $round');
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      expect(
        find.byType(RawImage),
        findsNWidgets(round),
        reason: 'decoded $round',
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04,
  0x08, 0x06, 0x00, 0x00, 0x00, 0xa9, 0xf1, 0x9e, 0x7e, 0x00, 0x00, 0x00,
  0x12, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xdf, 0xc0, 0xf0,
  0x1f, 0x19, 0x33, 0x90, 0x2e, 0x00, 0x00, 0x50, 0x4f, 0x27, 0xe1, 0xeb,
  0x00, 0xf8, 0xa5, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
];
