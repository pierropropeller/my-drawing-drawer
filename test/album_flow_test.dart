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
    // 空白頁（OfficialEmpty）：沒有篩選列，只有「加圖」按鈕。
    expect(find.text('0 張'), findsOneWidget);

    // 新增：先打開相簿選圖（測試中由假的選圖器回傳一張），再進入新增頁。
    await tester.tap(find.text('加圖'));
    await settle(tester);
    expect(find.text('新增官方圖'), findsOneWidget);
    expect(find.text('管理'), findsOneWidget); // 分組右上的管理按鈕
    await tester.tap(find.text('加入官方圖冊')); // 圖片已經帶入，不用再選
    await settle(tester);
    await settle(tester);

    final rows = await tester.runAsync(() => db.watchOfficial(pitId).first);
    expect(rows!.length, 1);
    expect(
      File('${tmp.path}/images/${rows.single.imageFile}').existsSync(),
      isTrue,
    );
    expect(find.text('還沒有官方圖'), findsNothing);
    // 有圖後出現分組 chips 與「管理分組」。
    expect(find.text('設定圖'), findsWidgets);
    expect(find.byTooltip('管理分組'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('預覽頁隱藏底部導覽；設為封面＝官方圖冊的封面（不是主頁坑封面）；同人圖列表顯示作者與分組', (tester) async {
    await tester.runAsync(() async {
      final groups = await db.watchGroups(pitId).first;
      await db.addOfficial(pitId, groups.first.id, const [
        NewImage(file: 'a.png', width: 10, height: 10),
      ]);
      final fan = await db.watchGroups(pitId, kind: 'fan').first;
      await db.addFanArts(
        pitId,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        author: '@illust',
        groupId: fan.first.id,
      );
      await db.addFanArts(pitId, const [
        NewImage(file: 'a.png', width: 10, height: 10),
      ], author: '');
    });
    Directory('${tmp.path}/images').createSync(recursive: true);
    File('${tmp.path}/images/a.png').writeAsBytesSync(_png1x1);

    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);

    // 官方圖冊 → 預覽
    await tester.tap(find.text('官方圖冊'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget); // 列表頁底部導覽還在
    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.text('設為封面'), findsOneWidget);
    expect(find.text('目標'), findsNothing); // 預覽頁蓋住底部導覽
    await tester.tap(find.text('設為封面'));
    await settle(tester);
    var pit = (await tester.runAsync(() => db.watchPit(pitId).first))!;
    expect(pit.officialCoverId, isNotNull);
    expect(pit.coverImageId, isNull);
    expect(find.text('已設為官方圖冊封面'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    expect(find.text('目標'), findsOneWidget); // 回來後導覽列又出現

    // 好看同人圖：有作者／分組才顯示那一行
    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    await tester.tap(find.text('好看同人圖'));
    await settle(tester);
    expect(find.text('@illust'), findsOneWidget);
    expect(find.text('推特'), findsWidgets); // chips 與圖下方的分組名
    expect(find.text('還沒有同人圖'), findsNothing);

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
