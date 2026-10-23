import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/pits/pit_page.dart';

/// 手機版坑頁標題列：圖示對「標題＋描述」整塊垂直置中（沒有描述時就是對標題置中）；點擊區 48。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_pithdr');
  });

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pump(WidgetTester tester, String? desc) async {
    final id = await tester.runAsync(
      () => db.createPit(name: '空洞騎士', description: desc),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: PitPage(pitId: id!),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('沒有描述：標題與返回、編輯圖示垂直置中', (tester) async {
    await pump(tester, null);
    final title = tester.getRect(find.text('空洞騎士'));
    final back = tester.getRect(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '返回'),
    );
    final edit = tester.getRect(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '編輯'),
    );
    expect(title.center.dy, closeTo(back.center.dy, 0.5));
    expect(title.center.dy, closeTo(edit.center.dy, 0.5));
    await unmount(tester);
  });

  testWidgets('有描述：返回、編輯圖示對「標題＋描述」整塊垂直置中；描述左緣與標題對齊', (tester) async {
    await pump(tester, '原作動畫');
    final title = tester.getRect(find.text('空洞騎士'));
    final desc = tester.getRect(find.text('原作動畫'));
    final back = tester.getRect(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '返回'),
    );
    final edit = tester.getRect(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '編輯'),
    );
    // 標題框 40px 高、與描述之間 2px；整塊 = 標題框頂到描述底。
    final blockCenter = ((title.center.dy - 20) + desc.bottom) / 2;
    expect(back.center.dy, closeTo(blockCenter, 1));
    expect(edit.center.dy, closeTo(blockCenter, 1));
    expect(desc.left, closeTo(title.left, 0.5));
    // 點擊區維持 48，比圖示大。
    expect(back.height, greaterThanOrEqualTo(48));
    await unmount(tester);
  });
}
