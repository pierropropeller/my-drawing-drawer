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

  Future<void> pumpApp(WidgetTester tester) async {
    // 手機尺寸（預設 800x600 太矮，卡片會被導覽列蓋住）。
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await tester.pump();
  }

  /// drift 的 stream 需要真實的 async，這裡等它們推送一輪。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  /// 不用 pumpAndSettle：載入中的轉圈動畫永遠不會 settle。
  /// 卸載畫面並讓 drift 取消 stream 時排的 timer 跑完，否則測試結尾會報 pending timer。
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('底部導覽可切換 坑／目標／我的', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('目標'));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pump();
    await tester.tap(find.text('坑'));
    await tester.pump();
    await settle(tester);
    expect(find.text('我的坑'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('開新坑 → 主頁出現卡片 → 進坑內頁', (tester) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('還沒有坑'), findsOneWidget);

    await tester.tap(find.text('開新坑'));
    await frames(tester);
    await tester.enterText(find.byType(TextFormField).first, '測試坑');
    await tester.tap(find.text('建立'));
    await settle(tester);
    await frames(tester);

    expect(find.text('測試坑'), findsOneWidget);
    expect(find.text('0 成圖 · 0 腦洞未孵'), findsOneWidget);

    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await frames(tester);
    for (final label in ['官方圖冊', '好看同人圖', '我的草稿', '我的腦洞', '我的成圖']) {
      expect(find.text(label), findsOneWidget);
    }
    // 新坑沒有圖，編輯頁不顯示「更換封面」。
    await tester.tap(find.byTooltip('編輯'));
    await frames(tester);
    expect(find.text('更換封面'), findsNothing);
    await unmount(tester);
  });
}
