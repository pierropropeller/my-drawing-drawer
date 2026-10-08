import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('目標分頁：年／月／日分段控制，新增目標後顯示進度', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('目標').last);
    await settle(tester);
    expect(find.text('年度回顧'), findsOneWidget);
    expect(find.text('還沒有年度目標'), findsOneWidget);

    await tester.ensureVisible(find.text('新增目標').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('新增目標').first);
    await settle(tester);
    expect(find.text('選擇坑之後才能選 tag'), findsOneWidget); // 未選坑不能選 tag
    await tester.ensureVisible(find.text('建立目標'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('建立目標'));
    await settle(tester);
    expect(find.text('完成 1 張成圖'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);

    await tester.tap(find.text('月'));
    await settle(tester);
    expect(find.text('日'), findsNWidgets(2)); // 分段控制「日」＋月曆週標題
    expect(find.text('月度小目標'), findsOneWidget);
    await tester.tap(find.text('日').first);
    await settle(tester);
    expect(find.text('這天沒有紀錄'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
