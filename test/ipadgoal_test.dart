import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/adaptive_modal.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/goals/goal_new_page.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/material/material_library_page.dart';
import 'package:huakeng/ui/me/about_page.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/me/personalize_page.dart';
import 'package:huakeng/ui/me/profile_page.dart';
import 'package:huakeng/ui/me/theme_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPad／平板版面（IPADGOAL）：目標並排、新增目標對話框、我的並排面板、素材庫欄數。
/// 視窗尺寸：390×844（手機）、834×1194（直向）、1194×834、1366×1024（橫向）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('ipadgoal');
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

  void resize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1194, 834),
    Map<String, Object> prefsInit = const {},
  }) async {
    resize(tester, size);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true, ...prefsInit});
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

  Future<void> seedGoals() async {
    final now = DateTime.now();
    await db.saveGoal(
      period: GoalPeriod.year,
      year: now.year,
      name: '夏日企劃',
      kind: GoalKind.piece,
      count: 5,
      pitId: pitId,
    );
    await db.saveGoal(
      period: GoalPeriod.year,
      year: now.year,
      kind: GoalKind.idea,
      count: 20,
    );
  }

  const sizes = {
    '390×844': Size(390, 844),
    '834×1194': Size(834, 1194),
    '1194×834': Size(1194, 834),
    '1366×1024': Size(1366, 1024),
  };

  group('目標頁', () {
    for (final e in sizes.entries) {
      testWidgets('年／月／日在 ${e.key} 都能 build（沒有 overflow）', (tester) async {
        await tester.runAsync(seedGoals);
        await show(tester, const GoalsPage(), size: e.value);
        expect(find.text('年度回顧'), findsOneWidget);
        expect(find.text('夏日企劃'), findsOneWidget);
        await tester.tap(find.text('月'));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('日').first);
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('1194×834：左 430 年度回顧＋右年度目標並排，標題與年／月／日同一列', (tester) async {
      await tester.runAsync(seedGoals);
      await show(tester, const GoalsPage());
      final review = tester.getTopLeft(find.text('年度回顧'));
      final goals = tester.getTopLeft(find.text('年度目標'));
      // 並排：同一高度，右欄在左欄右邊。
      expect((review.dy - goals.dy).abs(), lessThan(2));
      expect(goals.dx, greaterThan(review.dx + 430));
      // 月份格：4 欄 → 1 月和 4 月同一列、5 月換列。
      final m1 = tester.getTopLeft(find.text('1月'));
      final m4 = tester.getTopLeft(find.text('4月'));
      final m5 = tester.getTopLeft(find.text('5月'));
      expect((m1.dy - m4.dy).abs(), lessThan(2));
      expect(m5.dy, greaterThan(m1.dy + 20));
      // 「目標」標題和「年」切換在同一列。
      final title = tester.getCenter(find.text('目標'));
      final seg = tester.getCenter(find.text('年'));
      expect((title.dy - seg.dy).abs(), lessThan(24));
      // 「新增」是實心按鈕，觸控高度 ≥44。
      final add = find.ancestor(
        of: find.text('新增'),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(add.first).height, greaterThanOrEqualTo(44));
      await unmount(tester);
    });

    testWidgets('390×844：手機版面不變（年度回顧在目標列表上方，分段控制在標題下）', (tester) async {
      await tester.runAsync(seedGoals);
      await show(tester, const GoalsPage(), size: sizes['390×844']!);
      final review = tester.getTopLeft(find.text('年度回顧'));
      final goals = tester.getTopLeft(find.text('年度目標'));
      expect(goals.dy, greaterThan(review.dy));
      final title = tester.getCenter(find.text('目標'));
      final seg = tester.getCenter(find.text('年'));
      expect(seg.dy, greaterThan(title.dy + 20));
      await unmount(tester);
    });

    testWidgets('拉窗：月視圖選擇在 1194 ↔ 390 之間保留', (tester) async {
      await tester.runAsync(seedGoals);
      await show(tester, const GoalsPage());
      await tester.tap(find.text('月'));
      await settle(tester);
      final monthTitle = find.textContaining('月').first;
      expect(monthTitle, findsWidgets);
      // 往下一個月，再縮成手機尺寸、再拉回。
      await tester.tap(find.bySemanticsLabel('下個月'));
      await settle(tester);
      final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
      resize(tester, sizes['390×844']!);
      await settle(tester);
      expect(find.text('${next.month} 月'), findsWidgets);
      resize(tester, sizes['1366×1024']!);
      await settle(tester);
      expect(find.text('${next.month} 月'), findsWidgets);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('1194×834 新增目標＝置中對話框（不藏導覽），建立後出現在列表', (tester) async {
      await show(tester, const GoalsPage());
      // 沒有目標時是空白虛線框的「新增目標」按鈕。
      await tester.tap(find.text('新增目標'));
      await settle(tester);
      expect(find.byType(AdaptiveModalDialog), findsOneWidget);
      expect(find.text('新增年度目標'), findsOneWidget);
      expect(find.text('建立目標'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      final size = tester.getSize(find.byType(AdaptiveModalScope));
      expect(size.width, lessThanOrEqualTo(880));
      expect(size.height, lessThanOrEqualTo(620));
      // 預覽和目標坑分在左右兩欄。
      final preview = tester.getTopLeft(find.text('預覽'));
      final pit = tester.getTopLeft(find.text('目標坑'));
      expect(pit.dx, greaterThan(preview.dx + 300));
      expect(navBarHiddenCount.value, 0);
      await tester.tap(find.text('建立目標'));
      await settle(tester);
      expect(find.byType(AdaptiveModalDialog), findsNothing);
      expect(find.text('完成 1 張成圖'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('取消關閉對話框；編輯既有目標也是對話框', (tester) async {
      await tester.runAsync(seedGoals);
      await show(tester, const GoalsPage());
      await tester.tap(find.text('夏日企劃'));
      await settle(tester);
      expect(find.byType(AdaptiveModalDialog), findsOneWidget);
      expect(find.text('編輯年度目標'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.byType(AdaptiveModalDialog), findsNothing);
      await unmount(tester);
    });

    testWidgets('834×1194（medium）新增目標＝置中對話框，不藏導覽', (tester) async {
      await show(tester, const GoalsPage(), size: sizes['834×1194']!);
      await tester.tap(find.text('新增目標'));
      await settle(tester);
      expect(find.byType(AdaptiveModalDialog), findsOneWidget);
      expect(find.byType(GoalNewPage), findsOneWidget);
      // 對話框縮到 786 寬仍放得下兩欄。
      final preview = tester.getTopLeft(find.text('預覽'));
      final pit = tester.getTopLeft(find.text('目標坑'));
      expect(pit.dx, greaterThan(preview.dx + 300));
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('對話框開著時視窗縮小：不 overflow、不丟內容', (tester) async {
      await show(tester, const GoalsPage());
      await tester.tap(find.text('新增目標'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '我的目標');
      resize(tester, const Size(700, 500));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('我的目標'), findsWidgets);
      resize(tester, const Size(1366, 1024));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('我的', () {
    for (final e in sizes.entries) {
      testWidgets('在 ${e.key} 能 build', (tester) async {
        await show(tester, const ProfilePage(), size: e.value);
        expect(find.text('我的'), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('390×844：一欄列表，個人化 → 主題色 push 整頁（手機行為）', (tester) async {
      await show(tester, const ProfilePage(), size: sizes['390×844']!);
      expect(find.byType(ThemePage), findsNothing);
      expect(find.text('主題色'), findsNothing); // D-106：收進個人化
      await tester.tap(find.text('個人化'));
      await settle(tester);
      await tester.tap(find.text('主題色'));
      await settle(tester);
      expect(find.byType(ThemePage), findsOneWidget);
      expect(navBarHiddenCount.value, 2);
      await unmount(tester);
    });

    testWidgets('1194×834：左列表＋右面板，點列只切換內容、不 push', (tester) async {
      await show(tester, const ProfilePage());
      // 預設個人化（D-106）：右面板是個人化頁（四列：主題色、App 圖示、語言、敏感內容）。
      final list = tester.getTopLeft(find.text('素材庫'));
      expect(find.byType(PersonalizePage), findsOneWidget);
      expect(
        tester.widget<PersonalizePage>(find.byType(PersonalizePage)).embedded,
        true,
      );
      expect(tester.getTopLeft(find.text('主題色').last).dx, greaterThan(360));
      expect(list.dx, lessThan(360));
      // 左列表只剩 素材庫、個人化、備份與同步、關於 App。
      expect(find.text('語言'), findsOneWidget);
      expect(find.text('敏感內容'), findsOneWidget);

      await tester.tap(find.text('備份與同步').first);
      await settle(tester);
      expect(find.byType(BackupPage), findsOneWidget);

      await tester.tap(find.text('關於 App').first);
      await settle(tester);
      expect(find.byType(AboutPage), findsOneWidget);

      await tester.tap(find.text('個人化').first);
      await settle(tester);
      expect(find.byType(PersonalizePage), findsOneWidget);
      // 全程沒有 push 頁面，也沒有隱藏導覽。
      expect(navBarHiddenCount.value, 0);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('拉窗：選中的項目在 1194 → 390 → 834 之間保留', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('備份與同步').first);
      await settle(tester);
      expect(find.byType(BackupPage), findsOneWidget);

      resize(tester, sizes['390×844']!);
      await settle(tester);
      expect(find.byType(BackupPage), findsNothing); // 手機＝一欄列表
      expect(tester.takeException(), isNull);

      resize(tester, sizes['834×1194']!);
      await settle(tester);
      expect(find.byType(BackupPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('個人化 → 主題色：外觀三張預覽卡可切換，返回回到個人化', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('主題色').last);
      await settle(tester);
      expect(find.byType(ThemePage), findsOneWidget);
      await tester.tap(find.text('深色'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('素材庫', () {
    Future<void> seed(int n) async {
      await db.addMaterials(MaterialCategory.clothing, [
        for (var i = 0; i < n; i++)
          NewImage(file: 'm-$i.png', width: 30, height: 40 + i),
      ]);
    }

    int gridColumns(WidgetTester tester) {
      final grid = tester.widget<GridView>(find.byType(GridView).first);
      return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount;
    }

    testWidgets('「我的」右面板：標題旁有張數、九宮格 5 欄（1194）', (tester) async {
      await tester.runAsync(() => seed(12));
      await show(
        tester,
        const ProfilePage(),
        prefsInit: const {'materialLayout': 'grid'},
      );
      await tester.tap(find.text('素材庫').first);
      await settle(tester);
      expect(find.byType(MaterialLibraryPage), findsOneWidget);
      expect(find.textContaining('12 張'), findsWidgets);
      expect(gridColumns(tester), 5);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('獨立頁：手機 3 欄（維持），平板用 gridColumnsFor', (tester) async {
      await tester.runAsync(() => seed(8));
      await show(
        tester,
        const MaterialLibraryPage(),
        size: sizes['390×844']!,
        prefsInit: const {'materialLayout': 'grid'},
      );
      expect(gridColumns(tester), 3);
      resize(tester, sizes['1366×1024']!);
      await settle(tester);
      // (1366 - 40) ÷ 180 = 7
      expect(gridColumns(tester), 7);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('面板內瀑布也跟著面板闊度', (tester) async {
      await tester.runAsync(() => seed(6));
      await show(tester, const ProfilePage());
      await tester.tap(find.text('素材庫').first);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  testWidgets('showAdaptiveModal：手機窄視窗是整頁、≥600 是對話框', (tester) async {
    Future<void> open(Size size) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdaptiveModal<void>(
                context,
                builder: (_, _) => const Text('modal-body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        size: size,
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    await open(const Size(390, 844));
    expect(find.byType(AdaptiveModalDialog), findsNothing);
    expect(find.text('modal-body'), findsOneWidget);
    await unmount(tester);

    await open(sizes['834×1194']!);
    expect(find.byType(AdaptiveModalDialog), findsOneWidget);
    expect(find.text('modal-body'), findsOneWidget);
    await unmount(tester);

    await open(sizes['1194×834']!);
    expect(find.byType(AdaptiveModalDialog), findsOneWidget);
    expect(find.text('modal-body'), findsOneWidget);
    await unmount(tester);
  });
}
