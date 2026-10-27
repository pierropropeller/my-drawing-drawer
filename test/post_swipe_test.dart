import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-122 詳情頁左右滑換上／下篇：大圖以下左右滑換篇、端點只回彈、刪除後顯示下一篇。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('post_swipe');
    await Directory('${tmp.path}/images').create(recursive: true);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<String>> seed(WidgetTester tester) async {
    final ids = <String>[];
    await tester.runAsync(() async {
      final pit = await db.createPit(name: '坑A');
      for (final title in ['甲篇', '乙篇', '丙篇']) {
        ids.add(
          await db.saveDraft(
            pitId: pit,
            title: title,
            body: '$title的內文',
            images: const [NewImage(file: 'x.png', width: 10, height: 10)],
            tagIds: const [],
            ideaIds: const [],
          ),
        );
      }
      ids.insert(0, pit);
    });
    return ids;
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
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
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  bool visible(WidgetTester tester, String text) {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return false;
    final r = tester.getRect(f.first);
    return r.left >= 0 && r.right <= 360;
  }

  testWidgets('內文區左右滑換篇；第一篇再往右拉只回彈；刪除後顯示下一篇', (tester) async {
    final ids = await seed(tester);
    final pit = ids.first;
    final order = ids.sublist(1);
    await show(
      tester,
      DraftDetailPage(draftId: order[0], pitId: pit, order: order),
    );
    expect(visible(tester, '甲篇'), isTrue);

    // 第一篇往右拉：只回彈。
    await tester.drag(find.text('甲篇的內文'), const Offset(200, 0));
    await settle(tester);
    expect(visible(tester, '甲篇'), isTrue);

    // 往左拉過 30%：換到下一篇。
    await tester.drag(find.text('甲篇的內文'), const Offset(-200, 0));
    await settle(tester);
    expect(visible(tester, '乙篇'), isTrue);
    expect(visible(tester, '甲篇'), isFalse);

    // 拉不夠（< 30%）：彈回。
    await tester.drag(find.text('乙篇的內文'), const Offset(-60, 0));
    await settle(tester);
    expect(visible(tester, '乙篇'), isTrue);

    // 刪除乙篇 → 顯示丙篇（標題列的刪除對應目前這篇）。
    await tester.tap(find.bySemanticsLabel('刪除').first);
    await settle(tester);
    await tester.tap(find.text('刪除').last);
    await settle(tester);
    expect(visible(tester, '丙篇'), isTrue);
    final rows = await tester.runAsync(() => db.select(db.drafts).get());
    final deleted = rows!.where((d) => d.deletedAt != null).single;
    expect(deleted.id, order[1]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
