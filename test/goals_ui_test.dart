import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/entity_widgets.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/goals/day_page.dart';
import 'package:huakeng/ui/goals/goal_new_page.dart';
import 'package:huakeng/ui/goals/goal_widgets.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/goals/income_year_page.dart';
import 'package:huakeng/ui/goals/money_format.dart';
import 'package:huakeng/ui/goals/pit_pill.dart';
import 'package:huakeng/ui/goals/review_canvas.dart';
import 'package:huakeng/ui/goals/review_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 目標區塊 UI：坑 pill（D-004）、商稿收入（D-047/049/050）、時間軸 ＋（D-038）、
/// 年度回顧排版（D-039/D-007）、新增目標（D-023）、導覽列規則（D-005）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('goals_ui');
    pitId = await db.createPit(name: '坑A');
    navBarHiddenCount.value = 0;
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
  }) async {
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
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: page,
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<String> commission(
    String title,
    DateTime at, {
    String client = '',
    double? amount,
    String currency = 'CNY',
    double received = 0,
  }) => db.savePiece(
    pitId: pitId,
    title: title,
    body: '',
    images: const [],
    tagIds: const [],
    links: const [],
    targetLikes: 0,
    finishedAt: at,
    ideaIds: const [],
    draftIds: const [],
    isCommission: true,
    client: client,
    amount: amount,
    currency: currency,
    receivedAmount: received,
  );

  test('金額格式：符號＋千分位', () {
    expect(formatMoney('CNY', 12800), '¥ 12,800');
    expect(formatMoney('HKD', 3600), 'HK\$ 3,600');
    expect(formatMoney('CNY', 1234.5), '¥ 1,234.5');
    expect(formatMoney('XYZ', 5), 'XYZ 5');
    expect(reviewAlbumName, 'Drawer');
  });

  testWidgets('坑 pill 是資料夾 icon，沒有迷你封面（D-004）', (tester) async {
    await show(
      tester,
      const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: GoalCardBody(
            label: '夏日企劃',
            progress: 3,
            target: 5,
            pitName: '坑A',
            tags: ['#夏日企劃'],
          ),
        ),
      ),
    );
    expect(find.text('坑A'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PitPill),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
    expect(find.byType(StoredImage), findsNothing);
    await unmount(tester);
  });

  testWidgets('新增目標：沒有導覽列、需要達成互動量開啟預設 100、自動命名（D-023）', (tester) async {
    await show(
      tester,
      GoalNewPage(period: GoalPeriod.year, year: 2026),
      dark: true,
    );
    expect(navBarHiddenCount.value, greaterThan(0));
    expect(find.text('完成 1 張成圖'), findsOneWidget);
    await tester.ensureVisible(find.text('需要達成互動量'));
    // AppSwitch 不是 Material Switch：用語意標籤點。
    await tester.tap(find.byType(AppSwitch));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('互動量過 100 的成圖 1 張'), findsOneWidget);
    // 切到腦洞／草稿：動詞與量詞
    await tester.tap(find.text('腦洞'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('生產 1 個腦洞'), findsOneWidget);
    await tester.tap(find.text('草稿'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('畫 1 份草稿'), findsOneWidget);
    await unmount(tester);
    await tester.pump(const Duration(milliseconds: 10));
    expect(navBarHiddenCount.value, 0);
  });

  testWidgets('目標分頁：年度頁有商稿收入卡，點進收入頁（沒有導覽列）', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      await commission(
        '天台的煙花',
        DateTime(now.year, 1, 5),
        client: '某某老師',
        amount: 800,
        received: 300,
      );
      await commission(
        '制服 paro',
        DateTime(now.year, 1, 6),
        amount: 1800,
        currency: 'HKD',
        received: 1800,
      );
      await commission(
        '雙人頭像',
        DateTime(now.year, 2, 1),
        client: '@aozora',
        amount: 2000,
      );
    });
    await show(tester, const GoalsPage());
    expect(find.text('商稿收入'), findsOneWidget);
    expect(find.text('3 張'), findsOneWidget);
    expect(find.textContaining('HK\$ 1,800'), findsOneWidget);
    await tester.tap(find.text('商稿收入'));
    await settle(tester);
    expect(find.text('${now.year} 商稿收入'), findsOneWidget);
    expect(navBarHiddenCount.value, greaterThan(0));
    // 卡片：每幣種合計＋已收＋張數
    expect(find.text('人民幣'), findsOneWidget);
    expect(find.text('港幣'), findsOneWidget);
    expect(find.text('¥ 2,800'), findsOneWidget);
    expect(find.text('已收 ¥ 300 · 2 張'), findsOneWidget);
    expect(find.text('已收 HK\$ 1,800 · 1 張'), findsOneWidget);
    // 紅色提示：未收齊 2 張，尚欠 ¥ 2,500
    expect(find.text('未收齊 2 張'), findsOneWidget);
    expect(find.text('尚欠 ¥ 2,500'), findsOneWidget);
    // 月份列與收款狀態
    expect(find.text('2月'), findsOneWidget);
    expect(find.text('1月'), findsWidgets);
    expect(find.text('已收 ¥ 300'), findsOneWidget);
    expect(find.text('已收齊'), findsOneWidget);
    expect(find.text('未收'), findsOneWidget);
    expect(find.text('@aozora'), findsOneWidget);
    expect(find.text('@某某老師'), findsOneWidget);
    // D-049：月份小計右緣與列內金額右緣同一條線（卡片 padding 14 ＋ 邊框 1）
    final subtotal = tester.getTopRight(find.text('¥ 2,000').first);
    final rowAmount = tester.getTopRight(find.text('¥ 2,000').last);
    expect(subtotal.dx, rowAmount.dx);
    final monthLeft = tester.getTopLeft(find.text('2月')).dx;
    final titleCard = tester.getTopLeft(find.text('雙人頭像'));
    expect(titleCard.dx - monthLeft, greaterThan(40)); // 縮圖在左邊，標題不在同線
    await unmount(tester);
  });

  testWidgets('收入頁：沒有商稿時年度頁不出現商稿收入卡', (tester) async {
    await show(tester, const GoalsPage());
    expect(find.text('商稿收入'), findsNothing);
    expect(find.text('1月'), findsOneWidget); // GoalEmpty：中文月份（D-025）
    expect(find.text('Jan'), findsNothing);
    await unmount(tester);
  });

  testWidgets('空白的收入頁不會出錯', (tester) async {
    await show(tester, IncomeYearPage(year: 2026));
    expect(find.text('2026 商稿收入'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('年度目標依進度排序，已達成的沉底（D-022）', (tester) async {
    final year = DateTime.now().year;
    await tester.runAsync(() async {
      // 已達成：腦洞目標 1，建立 1 個腦洞
      await db.saveGoal(
        period: GoalPeriod.year,
        year: year,
        name: '目標甲',
        kind: GoalKind.idea,
        count: 1,
        tagIds: const [],
      );
      await db.saveGoal(
        period: GoalPeriod.year,
        year: year,
        name: '目標乙',
        kind: GoalKind.piece,
        count: 2,
        tagIds: const [],
      );
      await db.saveIdea(
        pitId: pitId,
        title: 'i',
        body: '',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
        createdAt: DateTime(year, 1, 1),
      );
      await db.savePiece(
        pitId: pitId,
        title: 'p',
        body: '',
        images: const [],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(year, 1, 1),
        ideaIds: const [],
        draftIds: const [],
      );
    });
    await show(tester, const GoalsPage());
    await tester.ensureVisible(find.text('目標甲'));
    final yJia = tester.getTopLeft(find.text('目標甲')).dy;
    final yYi = tester.getTopLeft(find.text('目標乙')).dy;
    expect(yYi, lessThan(yJia)); // 乙 50%、甲 100% → 甲在下
    await unmount(tester);
  });

  testWidgets('時間軸 ＋：只有腦洞／草稿／成圖，時間不可改，進對應表單（D-038）', (tester) async {
    await show(tester, DayPage(day: DateTime.now()));
    await tester.tap(find.byType(EntityFab));
    await settle(tester);
    expect(find.text('新增'), findsWidgets);
    expect(find.text('腦洞'), findsOneWidget);
    expect(find.text('草稿'), findsOneWidget);
    expect(find.text('成圖'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing); // 沒有時間按鈕
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('草稿'));
    await settle(tester);
    expect(find.byType(DraftFormPage), findsOneWidget);
    await unmount(tester);

    await show(tester, DayPage(day: DateTime.now()));
    await tester.tap(find.byType(EntityFab));
    await settle(tester);
    await tester.tap(find.text('腦洞'));
    await settle(tester);
    expect(find.byType(IdeaFormPage), findsOneWidget);
    await unmount(tester);

    await show(tester, DayPage(day: DateTime.now()));
    await tester.tap(find.byType(EntityFab));
    await settle(tester);
    await tester.tap(find.text('成圖'));
    await settle(tester);
    expect(find.byType(PieceFormPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('時間軸 ＋：有多個坑時選完類型再選坑', (tester) async {
    await tester.runAsync(() => db.createPit(name: '坑B'));
    await show(tester, DayPage(day: DateTime.now()));
    await tester.tap(find.byType(EntityFab));
    await settle(tester);
    await tester.tap(find.text('腦洞'));
    await settle(tester);
    expect(find.text('選擇坑'), findsOneWidget);
    await tester.tap(find.text('坑B'));
    await settle(tester);
    expect(find.byType(IdeaFormPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('年度回顧排版：月份對齊三選一、預設跟著月份位置、沒有導覽列', (tester) async {
    await show(tester, ReviewEditPage(year: 2026));
    expect(navBarHiddenCount.value, greaterThan(0));
    for (final l in ['月份對齊', '靠左', '置中', '靠右']) {
      expect(find.text(l), findsOneWidget);
    }
    // 預設在圖上＝靠左
    ReviewCanvas canvas() => tester.widget(find.byType(ReviewCanvas));
    expect(canvas().monthAlign, 'start');
    await tester.tap(find.text('空白位置'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas().monthAlign, 'center'); // 空白位置預設置中
    await tester.ensureVisible(find.text('靠右'));
    await tester.tap(find.text('靠右'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas().monthAlign, 'end');
    await tester.tap(find.text('圖上'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(canvas().monthAlign, 'end'); // 明確選過就不再跟著位置變
    await unmount(tester);
  });

  testWidgets('回顧畫布：外圍白框無圓角，月份文字依對齊靠右', (tester) async {
    await show(
      tester,
      Scaffold(
        body: ReviewCanvas(
          files: const {},
          columns: 4,
          ratio: '1:1',
          monthFormat: '1月',
          monthOnImage: true,
          monthAlign: 'end',
        ),
      ),
    );
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ReviewCanvas),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(box.color, Colors.white);
    expect(box.decoration, isNull); // 沒有圓角
    expect(box.padding, const EdgeInsets.all(12));
    final fitted = tester.widget<FittedBox>(find.byType(FittedBox).first);
    expect(fitted.alignment, Alignment.centerRight);
    await unmount(tester);
  });
}
