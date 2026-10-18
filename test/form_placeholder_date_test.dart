import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/entity/piece_widgets.dart';

/// D-094：成圖表單不放 placeholder。
/// D-096：腦洞、摸魚、成圖的「日期」選擇器上限是今天（交稿、發佈日期維持可選未來）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;
  late String pieceId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_formdate_test');
    Directory('${tmp.path}/images').createSync(recursive: true);
    pitId = await db.createPit(name: '測試坑');
    pieceId = await db.savePiece(
      pitId: pitId,
      title: '商稿',
      body: '內文',
      images: const [],
      tagIds: const [],
      links: const [SocialLink('推特', 'https://x.com/a/status/1')],
      targetLikes: 100,
      // 舊資料已有未來的日期：開選擇器不能炸，也不改資料。
      finishedAt: DateTime.now().add(const Duration(days: 30)),
      ideaIds: const [],
      draftIds: const [],
      isPublished: true,
      publishedAt: DateTime.now().add(const Duration(days: 5)),
      isCommission: true,
      client: '@某某老師',
      amount: 800,
      currency: 'HKD',
      receivedAmount: 300,
      dueAt: DateTime.now().add(const Duration(days: 20)),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    bool wide = false,
  }) async {
    // modal 版是 iPad 用的，給寬一點的畫面。
    tester.view.physicalSize = wide
        ? const Size(2400, 6000)
        : const Size(1080, 6000);
    tester.view.devicePixelRatio = wide ? 2 : 3;
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
          home: Scaffold(body: page),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// 點開指定語意標籤的日期欄，回傳彈出的日曆。
  Future<CalendarDatePicker> openPicker(
    WidgetTester tester,
    String label,
  ) async {
    final f = find.byWidgetPredicate(
      (w) => w is PieceDateField && w.semanticLabel == label,
    );
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(f);
    await tester.pump(const Duration(milliseconds: 400));
    return tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
  }

  Future<void> closePicker(WidgetTester tester) async {
    await tester.tap(find.text('取消').last);
    await tester.pump(const Duration(milliseconds: 400));
  }

  final today = DateUtils.dateOnly(DateTime.now());

  group('D-096 日期上限是今天', () {
    for (final modal in [false, true]) {
      final tag = modal ? '（modal）' : '';
      testWidgets('腦洞新增$tag', (tester) async {
        await pumpPage(
          tester,
          IdeaFormPage(pitId: pitId, asModal: modal),
          wide: modal,
        );
        final cal = await openPicker(tester, '日期');
        expect(cal.lastDate, today);
        await closePicker(tester);
        await unmount(tester);
      });
      testWidgets('摸魚新增$tag', (tester) async {
        await pumpPage(
          tester,
          DraftFormPage(pitId: pitId, asModal: modal),
          wide: modal,
        );
        final cal = await openPicker(tester, '日期');
        expect(cal.lastDate, today);
        expect(cal.initialDate!.isAfter(today), isFalse);
        await closePicker(tester);
        await unmount(tester);
      });
      testWidgets('成圖新增$tag：完成時間上限今天', (tester) async {
        await pumpPage(
          tester,
          PieceFormPage(pitId: pitId, asModal: modal),
          wide: modal,
        );
        final cal = await openPicker(tester, '完成時間');
        expect(cal.lastDate, today);
        await closePicker(tester);
        await unmount(tester);
      });
    }

    testWidgets('成圖編輯：舊資料有未來日期也能開；完成時間上限今天，交稿／發佈日期仍可選未來', (tester) async {
      await pumpPage(tester, PieceFormPage(pitId: pitId, pieceId: pieceId));
      var cal = await openPicker(tester, '完成時間');
      expect(cal.lastDate, today);
      expect(cal.initialDate, today); // 未來的舊值夾到今天，不炸
      await closePicker(tester);
      cal = await openPicker(tester, '交稿日期');
      expect(cal.lastDate.isAfter(today), isTrue);
      await closePicker(tester);
      cal = await openPicker(tester, '發佈日期');
      expect(cal.lastDate.isAfter(today), isTrue);
      await closePicker(tester);
      // 資料沒被動到
      final v = (await tester.runAsync(() => db.watchPieceViews(pitId).first))!;
      expect(v.single.piece.finishedAt.isAfter(DateTime.now()), isTrue);
      await unmount(tester);
    });
  });

  group('D-094 成圖表單沒有 placeholder', () {
    for (final edit in [false, true]) {
      testWidgets('成圖${edit ? '編輯' : '新增'}：所有輸入框沒有 hint／label／helper', (
        tester,
      ) async {
        await pumpPage(
          tester,
          PieceFormPage(pitId: pitId, pieceId: edit ? pieceId : null),
        );
        if (!edit) {
          // 新增：把兩個開關打開，露出發佈與委託欄位
          for (final i in [0, 1]) {
            await tester.tap(find.byType(AppSwitch).at(i));
            await tester.pump(const Duration(milliseconds: 300));
          }
          // 加一行社交連結，檢查連結輸入框
          await tester.ensureVisible(find.text('加社交連結'));
          await tester.tap(find.text('加社交連結'));
          await tester.pump(const Duration(milliseconds: 200));
        }
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.length, greaterThan(3));
        for (final f in fields) {
          final d = f.decoration;
          expect(d?.hintText ?? '', isEmpty);
          expect(d?.labelText ?? '', isEmpty);
          expect(d?.helperText ?? '', isEmpty);
        }
        expect(find.text('貼上連結網址'), findsNothing);
        expect(find.text('為這張成圖命名'), findsNothing);
        expect(find.text('想說的話、創作筆記…'), findsNothing);
        await unmount(tester);
      });
    }
  });
}
