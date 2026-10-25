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
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/adaptive_modal.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/device_class.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/me/app_icon_page.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/me/language_page.dart';
import 'package:huakeng/ui/me/personalize_page.dart';
import 'package:huakeng/ui/me/profile_page.dart';
import 'package:huakeng/ui/me/sensitive_settings_page.dart';
import 'package:huakeng/ui/me/theme_page.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPad 批次 4（P-031／P-032／P-033／P-035）：我的 → 個人化右欄子頁、敏感內容設定、
/// 備份儲存空間卡與 Drive 已滿、開新坑／編輯坑的類型。
/// Artboard：Profile、ProfileSensitive、ProfileBackup、BackupFull、NewPit、NewPitShallow、
/// PitEdit、PitEditShallow、NewPit400。
const _gb = 1024 * 1024 * 1024;

class _Accounts implements AccountService {
  @override
  Future<Map<String, String>> headers() async => {'Authorization': 'Bearer t'};
  @override
  Future<String?> restore() async => null;
  @override
  Future<String> signIn() async => 'molly@example.com';
  @override
  Future<void> signOut() async {}
}

/// 固定在某個 [SyncState]，不真的同步。
class _FixedSync extends SyncController {
  _FixedSync(this.fixed);
  final SyncState fixed;
  @override
  SyncState build() => fixed;
  @override
  Future<bool> syncNow() async => false;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;

  setUp(() {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('ipad_batch4');
  });
  tearDown(() async {
    debugTabletDeviceOverride = null;
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    navBarHiddenCount.value = 0;
  }

  Future<void> show(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(1194, 834),
    Map<String, Object> prefs = const {},
    List<dynamic> extra = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true, ...prefs});
    final p = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(p),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          for (final o in extra) o,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: home,
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  /// 左欄那一列是否選中（`_SplitRow` 的 Semantics selected）。
  bool leftSelected(WidgetTester tester, String title) => tester
      .widgetList<Semantics>(
        find.ancestor(
          of: find.text(title).first,
          matching: find.byType(Semantics),
        ),
      )
      .any((s) => s.properties.selected == true);

  group('P-031 我的 → 個人化（Profile）', () {
    testWidgets('左欄只有四列；右欄個人化列出四行', (tester) async {
      await show(tester, const ProfilePage());
      for (final t in ['素材庫', '個人化', '備份與同步', '關於 App']) {
        expect(find.text(t), findsWidgets);
      }
      // 左欄沒有主題色／語言／敏感內容；它們只在右欄的列表裡各出現一次。
      for (final t in ['主題色', 'App 圖示', '語言', '敏感內容']) {
        expect(find.text(t), findsOneWidget, reason: t);
        expect(tester.getTopLeft(find.text(t)).dx, greaterThan(360), reason: t);
      }
      expect(find.byType(PersonalizePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('點進主題色：右欄換成該頁，頂部「‹ 個人化」；左欄仍亮個人化；返回回列表', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('主題色'));
      await settle(tester);
      expect(find.byType(ThemePage), findsOneWidget);
      expect(find.byType(PersonalizePage), findsNothing);
      // 沒有 push 頁面、沒有藏導覽。
      expect(navBarHiddenCount.value, 0);
      final back = find.byKey(const ValueKey('meEmbeddedBack'));
      expect(back, findsOneWidget);
      expect(
        find.descendant(of: back, matching: find.text('個人化')),
        findsOneWidget,
      );
      // 返回鍵在標題上面。
      expect(
        tester.getTopLeft(back).dy,
        lessThan(tester.getTopLeft(find.text('主題色').last).dy),
      );
      expect(leftSelected(tester, '個人化'), isTrue);

      await tester.tap(back);
      await settle(tester);
      expect(find.byType(ThemePage), findsNothing);
      expect(find.byType(PersonalizePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('主題色順序：玫瑰、霧藍、珊瑚、抹茶（沒有橄欖）', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('主題色'));
      await settle(tester);
      final xs = [
        for (final n in ['玫瑰', '霧藍', '珊瑚', '抹茶'])
          tester.getTopLeft(find.text(n)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(xs.toSet().length, 4);
      expect(find.text('橄欖'), findsNothing);
      await unmount(tester);
    });

    testWidgets('App 圖示、語言也在右欄開啟並可返回；左欄點個人化回到列表', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('App 圖示'));
      await settle(tester);
      expect(find.byType(AppIconPickPage), findsOneWidget);
      expect(find.byKey(const ValueKey('meEmbeddedBack')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('meEmbeddedBack')));
      await settle(tester);
      await tester.tap(find.text('語言'));
      await settle(tester);
      expect(find.byType(LanguagePage), findsOneWidget);
      // 點左欄的「個人化」＝回到列表。
      await tester.tap(find.text('個人化').first);
      await settle(tester);
      expect(find.byType(LanguagePage), findsNothing);
      expect(find.byType(PersonalizePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機（390）仍是 push 整頁，不受影響', (tester) async {
      await show(tester, const ProfilePage(), size: const Size(390, 844));
      await tester.tap(find.text('個人化'));
      await settle(tester);
      await tester.tap(find.text('主題色'));
      await settle(tester);
      expect(find.byType(ThemePage), findsOneWidget);
      expect(find.byKey(const ValueKey('meEmbeddedBack')), findsNothing);
      await unmount(tester);
    });
  });

  group('P-032 敏感內容設定（ProfileSensitive）', () {
    testWidgets('右欄：總開關；安全模式只在開著時出現；關總開關彈置中確認框', (tester) async {
      await show(tester, const ProfilePage());
      await tester.tap(find.text('敏感內容'));
      await settle(tester);
      expect(find.byType(SensitiveSettingsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('meEmbeddedBack')), findsOneWidget);
      expect(find.text('敏感內容標記'), findsOneWidget);
      expect(find.text('安全模式'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      expect(find.text('安全模式'), findsOneWidget);
      expect(find.text('開啟後會模糊顯示已標記的圖片，關閉則正常顯示'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      final dialog = find.byKey(const ValueKey('sensitiveConfirm'));
      expect(dialog, findsOneWidget);
      expect(find.text('關閉敏感內容標記？'), findsOneWidget);
      expect(
        find.text('已標記的圖片會照常顯示，不再模糊，所有敏感內容選項也會隱藏。重新開啟後，標記會自動恢復。'),
        findsOneWidget,
      );
      // 置中、不超過 360。
      final box = find
          .descendant(of: dialog, matching: find.byType(Material))
          .first;
      final c = tester.getCenter(box);
      expect((c.dx - 597).abs() < 1 && (c.dy - 417).abs() < 40, isTrue);
      expect(tester.getSize(box).width, lessThanOrEqualTo(360));

      // 取消：維持開啟。
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(find.text('安全模式'), findsOneWidget);
      // 關閉：總開關關、安全模式消失。
      await tester.tap(find.byKey(const ValueKey('sensitiveMasterSwitch')));
      await settle(tester);
      await tester.tap(find.text('關閉'));
      await settle(tester);
      expect(find.text('安全模式'), findsNothing);
      expect(
        tester
            .widget<AppSwitch>(
              find.byKey(const ValueKey('sensitiveMasterSwitch')),
            )
            .value,
        isFalse,
      );
      await unmount(tester);
    });
  });

  group('P-033 備份與同步（ProfileBackup、BackupFull）', () {
    Future<void> pumpBackup(
      WidgetTester tester, {
      required StorageQuota quota,
      SyncState? sync,
    }) async {
      final remote = MemoryRemote()..quota = quota;
      await show(
        tester,
        const ProfilePage(),
        prefs: {
          'accountEmail': 'molly@example.com',
          'syncedAccount': 'molly@example.com',
        },
        extra: [
          accountServiceProvider.overrideWithValue(_Accounts()),
          syncRemoteProvider.overrideWithValue(remote),
          if (sync != null)
            syncControllerProvider.overrideWith(() => _FixedSync(sync)),
        ],
      );
      await tester.tap(find.text('備份與同步').first);
      await settle(tester);
      expect(find.byType(BackupPage), findsOneWidget);
    }

    testWidgets('儲存空間卡放在 Google Drive 卡下面（8.3 GB / 15 GB）', (tester) async {
      await tester.runAsync(
        () => db
            .into(db.remoteFileSizes)
            .insert(
              RemoteFileSizesCompanion.insert(
                name: 'images__x',
                size: (1.2 * _gb).round(),
              ),
            ),
      );
      await pumpBackup(
        tester,
        quota: const StorageQuota(
          usage: 8 * _gb + 300 * 1024 * 1024,
          limit: 15 * _gb,
        ),
      );
      expect(find.text('儲存空間'), findsOneWidget);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('儲存空間')).dy,
        greaterThan(tester.getTopLeft(find.text('Google Drive')).dy),
      );
      expect(
        tester.getTopLeft(find.text('自動同步')).dy,
        greaterThan(tester.getTopLeft(find.text('儲存空間')).dy),
      );
      expect(find.text('Drive 已滿'), findsNothing);
      expect(find.textContaining('上次備份'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Drive 已滿：紅框、12 張未上傳、管理連結、紅色小字、左欄副標「Drive 已滿」', (tester) async {
      await pumpBackup(
        tester,
        quota: const StorageQuota(usage: 15 * _gb, limit: 15 * _gb),
        sync: SyncState(
          phase: SyncPhase.idle,
          lastSyncAt: DateTime.now(),
          quotaFull: true,
          lastResult: SyncResult()
            ..quotaFull = true
            ..transfers = [
              for (var i = 0; i < 12; i++)
                SyncTransfer(
                  file: 'u$i.png',
                  direction: TransferDirection.upload,
                  state: TransferState.waiting,
                ),
            ],
        ),
      );
      // 卡片標題＋左欄副標＝兩處「Drive 已滿」。
      expect(find.text('Drive 已滿'), findsNWidgets(2));
      expect(tester.getTopLeft(find.text('Drive 已滿').first).dx, lessThan(360));
      expect(find.text('12 張未上傳', findRichText: true), findsOneWidget);
      expect(find.text('管理 Google 儲存空間'), findsOneWidget);
      final sub = tester.widget<Text>(find.text('上傳暫停　下載正常'));
      expect(sub.style!.color, const Color(0xFFC0392B));
      // 紅框（1.5）。
      final frames = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('15 GB / 15 GB', findRichText: true),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) => d.border != null && (d.border! as Border).top.width == 1.5,
          );
      expect(frames, isNotEmpty);
      expect(
        (frames.first.border! as Border).top.color,
        const Color(0xFFE7B9AE),
      );
      await unmount(tester);
    });
  });

  group('P-035 開新坑／編輯坑的類型', () {
    Future<void> openNew(WidgetTester tester, Size size) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openNewPit(context),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
        size: size,
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
    }

    /// 對話框本體的寬（Dialog 外殼之內第一個 SizedBox＝[AdaptiveModalDialog] 的 w×h）。
    double dialogWidth(WidgetTester tester) => tester
        .getSize(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(SizedBox),
              )
              .first,
        )
        .width;

    testWidgets('NewPit：頂部類型 坑｜淺坑；坑名沒有 placeholder；600 寬單欄', (tester) async {
      await openNew(tester, const Size(1194, 834));
      expect(find.text('類型'), findsOneWidget);
      expect(find.text('坑'), findsOneWidget);
      expect(find.text('淺坑'), findsOneWidget);
      expect(find.text('封存'), findsNothing);
      final name = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('pit-name')),
          matching: find.byType(TextField),
        ),
      );
      expect(name.decoration?.hintText, isNull);
      expect(find.text('封面'), findsNothing);
      expect(find.text('開啟的格子'), findsNothing);
      expect(dialogWidth(tester), 600);
      await unmount(tester);
    });

    testWidgets('NewPitShallow：選淺坑 → 880 兩欄；左 類型＋坑名＋描述（沒有封面）；右 7 個開關預設只開官方圖冊與好看同人圖', (
      tester,
    ) async {
      await openNew(tester, const Size(1194, 834));
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      expect(dialogWidth(tester), 880);
      // 淺坑不要封面（Molly 10/23）。
      expect(find.text('封面'), findsNothing);
      expect(find.bySemanticsLabel('選擇封面'), findsNothing);
      expect(find.text('開啟的格子'), findsOneWidget);
      // 左右兩欄：開啟的格子在右邊。
      expect(
        tester.getTopLeft(find.text('開啟的格子')).dx,
        greaterThan(tester.getTopLeft(find.text('坑名')).dx + 380),
      );
      final switches = tester
          .widgetList<AppSwitch>(find.byType(AppSwitch))
          .map((s) => s.value)
          .toList();
      expect(switches, [true, true, false, false, false, false, false]);

      // 建立：淺坑、只開官方圖冊＋同人圖。
      await tester.enterText(find.byType(TextFormField).first, '新淺坑');
      await tester.tap(find.text('建立'));
      await settle(tester);
      final pits = await tester.runAsync(() => db.select(db.pits).get());
      final pit = pits!.single;
      expect(pit.status, PitStatus.shallow);
      expect(pit.enabledSections, {PitSectionKey.official, PitSectionKey.fan});
      await unmount(tester);
    });

    testWidgets('切回「坑」縮回 600 單欄', (tester) async {
      await openNew(tester, const Size(1194, 834));
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      await tester.tap(find.text('坑').first);
      await settle(tester);
      expect(dialogWidth(tester), 600);
      expect(find.text('開啟的格子'), findsNothing);
      await unmount(tester);
    });

    testWidgets('NewPit400：窄 iPad 的 page sheet 也有類型，並保留「封面可於建立後…」', (
      tester,
    ) async {
      debugTabletDeviceOverride = true;
      await openNew(tester, const Size(400, 834));
      expect(
        AdaptiveModalScope.sheetOf(tester.element(find.text('開新坑'))),
        isTrue,
      );
      expect(find.text('類型'), findsOneWidget);
      expect(find.text('坑'), findsOneWidget);
      expect(find.text('淺坑'), findsOneWidget);
      expect(find.text('封面可於建立後在「編輯坑」中選擇。'), findsOneWidget);
      await tester.tap(find.text('淺坑'));
      await settle(tester);
      expect(find.text('開啟的格子'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    Future<Pit> mkPit(PitStatus status, {Set<PitSectionKey>? sections}) async {
      final id = await db.createPit(
        name: '坑A',
        description: '原作動畫',
        status: status == PitStatus.shallow
            ? PitStatus.shallow
            : PitStatus.active,
        enabledSections: sections ?? const {},
      );
      if (status == PitStatus.archived) {
        await db.updatePit(id, name: '坑A', status: PitStatus.archived);
      }
      return (await (db.select(
        db.pits,
      )..where((p) => p.id.equals(id))).getSingle());
    }

    Future<void> openEdit(
      WidgetTester tester,
      Pit pit, {
      bool master = true,
    }) async {
      await show(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => openPitEdit(context, pit),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
        prefs: {'sensitiveEnabled': master},
      );
      await tester.tap(find.text('OPEN'));
      await settle(tester);
    }

    List<String> switchLabels(WidgetTester tester) => tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Semantics),
          ),
        )
        .where(
          (s) => s.properties.toggled != null && s.properties.label != null,
        )
        .map((s) => s.properties.label!)
        .toList();

    testWidgets('PitEdit（坑）：類型 坑｜淺坑｜封存；只有 雜物＋敏感內容 兩個開關', (tester) async {
      final pit = await tester.runAsync(() => mkPit(PitStatus.active));
      await openEdit(tester, pit!);
      expect(find.text('類型'), findsOneWidget);
      expect(find.text('封存'), findsOneWidget);
      expect(switchLabels(tester), ['雜物', '敏感內容']);
      // P-041：三種類型都可以從相簿選封面。
      expect(find.text('從相簿選擇'), findsOneWidget);
      expect(find.text('開啟的格子'), findsNothing);
      await unmount(tester);
    });

    testWidgets('PitEdit（封存）：同樣是 雜物＋敏感內容', (tester) async {
      final pit = await tester.runAsync(() => mkPit(PitStatus.archived));
      expect(pit!.status, PitStatus.archived);
      await openEdit(tester, pit);
      expect(switchLabels(tester), ['雜物', '敏感內容']);
      await unmount(tester);
    });

    testWidgets('PitEdit：敏感內容總開關關著＝沒有「敏感內容」開關', (tester) async {
      final pit = await tester.runAsync(() => mkPit(PitStatus.active));
      await openEdit(tester, pit!, master: false);
      expect(switchLabels(tester), ['雜物']);
      await unmount(tester);
    });

    testWidgets('PitEditShallow：開啟的格子 7 個＋敏感內容；「從相簿選擇」；右欄可捲動', (tester) async {
      final pit = await tester.runAsync(
        () => mkPit(
          PitStatus.shallow,
          sections: {PitSectionKey.official, PitSectionKey.fan},
        ),
      );
      await openEdit(tester, pit!);
      expect(find.text('開啟的格子'), findsOneWidget);
      expect(switchLabels(tester), [
        '官方圖冊',
        '好看同人圖',
        '我的腦洞',
        '我的摸魚',
        '我的成圖',
        '推活',
        '雜物',
        '敏感內容',
      ]);
      expect(find.text('從相簿選擇'), findsOneWidget);
      expect(find.text('從相簿上載'), findsNothing);
      // 右欄放得下不了的內容會捲動：沒有 overflow，且有垂直 Scrollable。
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(CustomScrollView),
        ),
        findsWidgets,
      );
      await unmount(tester);
    });
  });
}
