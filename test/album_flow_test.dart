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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_test');
    pitId = await db.createPit(name: '測試坑');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final src = File('${tmp.path}/pick.png')..writeAsBytesSync(_png1x1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imagePickerProvider.overrideWithValue(() async => [XFile(src.path)]),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('官方圖冊：進入 → 新增圖片 → 存入資料庫', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('官方圖冊'));
    await settle(tester);
    expect(find.text('還沒有官方圖'), findsOneWidget);
    // 分組 chips 與「管理分組」
    expect(find.text('設定圖'), findsOneWidget);
    expect(find.byTooltip('管理分組'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.tap(find.text('新增圖片'));
    await settle(tester);
    await tester.tap(find.text('儲存'));
    await settle(tester);
    await settle(tester);

    final rows = await tester.runAsync(() => db.watchOfficial(pitId).first);
    expect(rows!.length, 1);
    expect(
      File('${tmp.path}/images/${rows.single.imageFile}').existsSync(),
      isTrue,
    );
    expect(find.text('還沒有官方圖'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
