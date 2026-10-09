import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/goals/review_edit_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';

/// 版面回歸：坑標題與描述左緣一致、同人圖標籤貼右、年度回顧排版縮圖有畫出格子。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('layout_bugs');
    await Directory('${tmp.path}/images').create(recursive: true);
    File('${tmp.path}/images/a.png').writeAsBytesSync(_png1x1);
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
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
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: page,
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('坑內頁：標題與描述的左緣一致', (tester) async {
    final pitId = await tester.runAsync(
      () => db.createPit(name: '坑A', description: '原作動畫・角色1 × 角色2'),
    );
    await pumpPage(tester, PitPage(pitId: pitId!));
    final title = tester.getTopLeft(find.text('坑A')).dx;
    final desc = tester.getTopLeft(find.text('原作動畫・角色1 × 角色2')).dx;
    expect(desc, closeTo(title, 0.5));
    await unmount(tester);
  });

  testWidgets('好看同人圖：有作者時，出處標籤貼在卡片右緣', (tester) async {
    final pitId = await tester.runAsync(() => db.createPit(name: '坑A'));
    await tester.runAsync(() async {
      final fan = await db.watchGroups(pitId!, kind: 'fan').first;
      await db.addFanArts(
        pitId,
        const [NewImage(file: 'a.png', width: 10, height: 10)],
        author: '@illust_ka',
        groupId: fan.firstWhere((g) => g.name == '推特').id,
      );
    });
    await pumpPage(tester, FanArtListPage(pitId: pitId!));
    final tile = tester.getRect(find.byType(Image).first);
    // 篩選 chips 與卡片各有一個「推特」，卡片上的在下面。
    final tags = find.text('推特').evaluate().length;
    expect(tags, greaterThanOrEqualTo(2));
    final pill = tester.getRect(find.text('推特').last);
    // 標籤文字右緣 + 標籤內距 7 + 說明列內距 2 ＝ 圖片右緣。
    expect(pill.right + 7 + 2, closeTo(tile.right, 1));
    await unmount(tester);
  });

  testWidgets('年度回顧排版：每個排版選項的縮圖格子都有高度', (tester) async {
    await pumpPage(tester, const ReviewEditPage(year: 2026));
    for (final label in ['1 × 12', '2 × 6', '3 × 4', '4 × 3', '6 × 2']) {
      final option = find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      );
      final cells = find.descendant(
        of: option.first,
        matching: find.byType(ColoredBox),
      );
      expect(cells, findsWidgets, reason: label);
      expect(
        tester.getSize(cells.first).height,
        greaterThan(2),
        reason: '$label 的縮圖格子高度',
      );
    }
    await unmount(tester);
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
