import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart' show ImageRef;
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/sensitive.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/form_image_preview_page.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/ui/common/detail_carousel.dart';
import 'package:huakeng/ui/common/media_mini.dart';
import 'package:huakeng/ui/common/media_widgets.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/sensitive_gate.dart';
import 'package:huakeng/ui/entity/entity_widgets.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:huakeng/ui/entity/piece_widgets.dart';
import 'package:huakeng/ui/goals/review_canvas.dart';
import 'package:huakeng/ui/goals/year_view.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 敏感內容（D-104）的畫面：列表縮圖的模糊／小標／無、總開關關閉時什麼都不出現、
/// 表單標記、坑開關、多選動作、分享匯入、確認視窗。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('sensitive_ui');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 把 [home] 放進有真實資料庫的 App 殼。[master]／[safe] 是裝置設定。
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool master = true,
    bool safe = true,
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'sensitiveEnabled': master,
      'safeMode': safe,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
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
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  const blur = ValueKey('sensitiveBlur');
  const circle = ValueKey('sensitiveCircle');
  const badge = ValueKey('sensitiveBadge');

  Widget cell(Widget child) => SizedBox(width: 120, height: 120, child: child);

  group('SensitiveFrame（畫法本身）', () {
    testWidgets('模糊：16px 模糊＋中間 34px 灰色半透明圓；小標與圓不會同時出現', (tester) async {
      await pump(
        tester,
        cell(
          const SensitiveFrame(
            mode: SensitiveDisplay.blur,
            child: ColoredBox(color: Colors.pink),
          ),
        ),
      );
      expect(find.byKey(blur), findsOneWidget);
      final f = tester.widget<ImageFiltered>(find.byKey(blur));
      expect(
        f.imageFilter.toString(),
        contains('blur(16.0, 16.0'),
        reason: 'blur 約 16px',
      );
      expect(tester.getSize(find.byKey(circle)), const Size(34, 34));
      // 圓在格子正中央
      expect(
        tester.getCenter(find.byKey(circle)),
        tester.getCenter(find.byType(SensitiveFrame)),
      );
      final deco =
          tester.widget<Container>(find.byKey(circle)).decoration!
              as BoxDecoration;
      expect(deco.color, const Color(0x9E2B2622));
      expect(deco.shape, BoxShape.circle);
      expect(find.byKey(badge), findsNothing);
      await unmount(tester);
    });

    testWidgets('小標：不模糊，左上 22px 圓，距邊 6px', (tester) async {
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: cell(
            const SensitiveFrame(
              mode: SensitiveDisplay.badge,
              child: ColoredBox(color: Colors.pink),
            ),
          ),
        ),
      );
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(circle), findsNothing);
      expect(tester.getSize(find.byKey(badge)), const Size(22, 22));
      final frame = tester.getTopLeft(find.byType(SensitiveFrame));
      expect(tester.getTopLeft(find.byKey(badge)) - frame, const Offset(6, 6));
      await unmount(tester);
    });

    testWidgets('none：原樣；pending：模糊但還沒有圓（敏感檔案還在查）', (tester) async {
      await pump(
        tester,
        Column(
          children: [
            cell(
              const SensitiveFrame(
                key: ValueKey('n'),
                mode: SensitiveDisplay.none,
                child: ColoredBox(color: Colors.pink),
              ),
            ),
            cell(
              const SensitiveFrame(
                key: ValueKey('p'),
                mode: SensitiveDisplay.pending,
                child: ColoredBox(color: Colors.pink),
              ),
            ),
          ],
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('n')),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('p')),
          matching: find.byKey(blur),
        ),
        findsOneWidget,
      );
      expect(find.byKey(circle), findsNothing);
      await unmount(tester);
    });

    testWidgets('小縮圖：圓縮小到格子短邊的 60%，不蓋滿整張', (tester) async {
      await pump(
        tester,
        const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: SensitiveFrame(
              mode: SensitiveDisplay.blur,
              child: ColoredBox(color: Colors.pink),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(circle)).width, closeTo(24, 0.01));
      await unmount(tester);
    });
  });

  group('SensitiveGate（依總開關／安全模式／標記決定）', () {
    Future<SensitiveDisplay> modeOf(
      WidgetTester tester, {
      required bool master,
      required bool safe,
      required bool inFiles,
    }) async {
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) {
            final mode = ref.watch(sensitiveDisplayProvider('a.png'));
            return Text('mode:${mode.name}');
          },
        ),
        master: master,
        safe: safe,
      );
      return SensitiveDisplay.values.byName(
        (tester.widget<Text>(find.textContaining('mode:')).data!).substring(5),
      );
    }

    testWidgets('矩陣：總開關 × 安全模式 × 有沒有標記（坑開關關＝不在集合裡）', (tester) async {
      // 資料庫裡 a.png 是敏感的，坑開著。
      final g = ((await tester.runAsync(() => db.watchGroups(pitId).first))!)
          .first
          .id;
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await tester.runAsync(
        () => db.addOfficial(pitId, g, [
          const NewImage(file: 'a.png', sensitive: true),
          const NewImage(file: 'b.png'),
        ]),
      );
      Future<void> check(bool master, bool safe, SensitiveDisplay want) async {
        final got = await modeOf(
          tester,
          master: master,
          safe: safe,
          inFiles: true,
        );
        expect(got, want, reason: 'master=$master safe=$safe');
        await unmount(tester);
      }

      await check(true, true, SensitiveDisplay.blur);
      await check(true, false, SensitiveDisplay.badge);
      await check(false, true, SensitiveDisplay.none);
      await check(false, false, SensitiveDisplay.none);

      // 坑開關關：標記還在，但沒有模糊也沒有小標
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, false));
      await check(true, true, SensitiveDisplay.none);
      await check(true, false, SensitiveDisplay.none);
    });

    testWidgets('不是敏感的檔名：永遠 none', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Text(
            'mode:${ref.watch(sensitiveDisplayProvider('zzz.png')).name}',
          ),
        ),
      );
      expect(find.text('mode:none'), findsOneWidget);
      await unmount(tester);
    });
  });

  // P-042：時間軸第一頁（年度回顧 12 格）照安全模式；排版頁的匯出預覽畫布（與匯出的 PNG）永遠是原圖。
  group('年度回顧（P-042）', () {
    Future<void> seed(WidgetTester tester) async {
      final g = ((await tester.runAsync(() => db.watchGroups(pitId).first))!)
          .first
          .id;
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await tester.runAsync(
        () => db.addOfficial(pitId, g, [
          const NewImage(file: 'flag.png', sensitive: true),
          const NewImage(file: 'plain.png'),
        ]),
      );
    }

    final months = <int, String?>{1: 'flag.png', 2: 'plain.png'};

    Widget year() => ProviderScope(
      overrides: [
        reviewMonthsProvider(2026).overrideWith((ref) => Stream.value(months)),
      ],
      child: const Scaffold(body: YearView(year: 2026)),
    );

    Widget canvas() => Scaffold(
      body: ReviewCanvas(
        files: months,
        columns: 3,
        ratio: '1:1',
        monthFormat: 'num',
        monthOnImage: false,
      ),
    );

    testWidgets('安全模式開：已標記那格模糊＋縮小的圓（34px 以內），沒標記的正常', (tester) async {
      await seed(tester);
      await pump(tester, year());
      expect(find.byKey(blur), findsOneWidget);
      expect(find.byKey(badge), findsNothing);
      final side = tester.getSize(find.byKey(circle)).width;
      expect(side, lessThanOrEqualTo(34));
      expect(side, greaterThanOrEqualTo(14));
      await unmount(tester);
    });

    testWidgets('安全模式關：已標記那格左上角 22px 小標、不模糊', (tester) async {
      await seed(tester);
      await pump(tester, year(), safe: false);
      expect(find.byKey(blur), findsNothing);
      expect(tester.getSize(find.byKey(badge)), const Size(22, 22));
      await unmount(tester);
    });

    testWidgets('總開關關：兩格都正常', (tester) async {
      await seed(tester);
      await pump(tester, year(), master: false);
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      await unmount(tester);
    });

    for (final safe in [true, false]) {
      testWidgets('排版頁匯出預覽畫布（安全模式${safe ? '開' : '關'}）：永遠原圖，沒有模糊／小標', (
        tester,
      ) async {
        await seed(tester);
        await pump(tester, canvas(), safe: safe);
        expect(find.byKey(blur), findsNothing);
        expect(find.byKey(circle), findsNothing);
        expect(find.byKey(badge), findsNothing);
        await unmount(tester);
      });
    }
  });

  group('MediaThumb（列表縮圖共用元件）', () {
    Future<void> seed(WidgetTester tester, {bool pitOn = true}) async {
      final g = ((await tester.runAsync(() => db.watchGroups(pitId).first))!)
          .first
          .id;
      if (pitOn) {
        await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      }
      await tester.runAsync(
        () => db.addOfficial(pitId, g, [
          const NewImage(file: 'flag.png', sensitive: true),
          const NewImage(file: 'plain.png'),
          const NewImage(
            file: 'v.mp4',
            kind: MediaKind.video,
            durationMs: 5000,
            posterFile: 'v.jpg',
            sensitive: true,
          ),
          const NewImage(file: 'g.gif', kind: MediaKind.gif, sensitive: true),
        ]),
      );
    }

    Widget grid({bool protect = true}) => Wrap(
      children: [
        for (final f in const ['flag.png', 'plain.png'])
          cell(
            MediaThumb(
              MediaSource(file: f),
              protectSensitive: protect,
              key: ValueKey('t-$f'),
            ),
          ),
        cell(
          MediaThumb(
            const MediaSource(
              file: 'v.mp4',
              kind: MediaKind.video,
              durationMs: 5000,
              poster: 'v.jpg',
            ),
            count: 2,
            protectSensitive: protect,
            key: const ValueKey('t-v'),
          ),
        ),
        cell(
          MediaThumb(
            const MediaSource(file: 'g.gif', kind: MediaKind.gif),
            protectSensitive: protect,
            key: const ValueKey('t-g'),
          ),
        ),
      ],
    );

    Finder within(String key, Finder f) =>
        find.descendant(of: find.byKey(ValueKey(key)), matching: f);

    testWidgets('安全模式開：標記的圖（含影片 poster、GIF）模糊＋圓；沒標記的不動；媒體標記與張數不被模糊', (
      tester,
    ) async {
      await seed(tester);
      await pump(tester, grid());
      expect(within('t-flag.png', find.byKey(blur)), findsOneWidget);
      expect(within('t-flag.png', find.byKey(circle)), findsOneWidget);
      expect(within('t-plain.png', find.byKey(blur)), findsNothing);
      expect(within('t-plain.png', find.byKey(circle)), findsNothing);
      expect(within('t-v', find.byKey(blur)), findsOneWidget);
      expect(within('t-g', find.byKey(blur)), findsOneWidget);
      // 影片左下角「▶ 0:05」與右下角張數在模糊之外，仍然清楚。
      expect(
        within('t-v', find.byKey(const ValueKey('badgeVideo'))),
        findsOneWidget,
      );
      expect(
        within('t-v', find.byKey(const ValueKey('badgeCount'))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(blur).first,
          matching: find.byKey(const ValueKey('badgeVideo')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(blur).first,
          matching: find.byKey(const ValueKey('badgeCount')),
        ),
        findsNothing,
      );
      expect(
        within('t-g', find.byKey(const ValueKey('badgeGif'))),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('安全模式關：正常顯示＋左上小標（不模糊）；影片左下的媒體標記仍在', (tester) async {
      await seed(tester);
      await pump(tester, grid(), safe: false);
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(circle), findsNothing);
      expect(within('t-flag.png', find.byKey(badge)), findsOneWidget);
      expect(within('t-plain.png', find.byKey(badge)), findsNothing);
      expect(find.byKey(badge), findsNWidgets(3)); // 圖、影片、GIF
      expect(
        within('t-v', find.byKey(const ValueKey('badgeVideo'))),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('總開關關：什麼都沒有（標記保留）；總開關開、坑開關關：也什麼都沒有', (tester) async {
      await seed(tester);
      await pump(tester, grid(), master: false);
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      expect(find.byKey(circle), findsNothing);
      await unmount(tester);

      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, false));
      await pump(tester, grid());
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      await unmount(tester);
    });

    testWidgets('詳情／預覽用的 protectSensitive:false：永遠正常顯示', (tester) async {
      await seed(tester);
      await pump(tester, grid(protect: false));
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      await unmount(tester);
    });

    testWidgets('MiniMediaThumb 同樣處理；protectSensitive:false 就不處理', (
      tester,
    ) async {
      await seed(tester);
      await pump(
        tester,
        Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: MiniMediaThumb(
                const MediaSource(file: 'flag.png'),
                key: const ValueKey('mini'),
              ),
            ),
            SizedBox(
              width: 54,
              height: 54,
              child: MiniMediaThumb(
                const MediaSource(file: 'flag.png'),
                key: const ValueKey('mini-detail'),
                protectSensitive: false,
              ),
            ),
          ],
        ),
      );
      expect(within('mini', find.byKey(blur)), findsOneWidget);
      expect(within('mini-detail', find.byKey(blur)), findsNothing);
      // 小格子的圓縮小（54 × 0.6 ≈ 32）
      expect(
        tester.getSize(within('mini', find.byKey(circle))).width,
        lessThan(34),
      );
      await unmount(tester);
    });

    testWidgets('詳情頁主圖（52px 圓）與縮圖列（24px 圓）照安全模式模糊；點開的全螢幕預覽沒有安全模式（一律正常）', (
      tester,
    ) async {
      await seed(tester);
      await pump(
        tester,
        const Scaffold(
          body: DetailImageStage(
            images: [
              ImageRef('flag.png', 1, 1, sensitive: true),
              ImageRef('plain.png', 1, 1),
              ImageRef('flag.png', 1, 1, sensitive: true),
            ],
          ),
        ),
      );
      // 主圖（第 1 頁）＋縮圖列兩張標記的圖。
      expect(find.byKey(blur), findsNWidgets(3));
      final sizes = [
        for (final e in find.byKey(circle).evaluate())
          tester.getSize(find.byWidget(e.widget)).width,
      ]..sort();
      expect(sizes, [24, 24, 52]);
      await tester.tap(find.byType(PageView).first);
      await settle(tester);
      expect(find.byType(ImageGalleryPage), findsOneWidget);
      // 全螢幕預覽沒有安全模式：點進來就是正常的圖（沒有模糊、圓、小標）。
      for (final key in [blur, circle, badge]) {
        expect(
          find.descendant(
            of: find.byType(ImageGalleryPage),
            matching: find.byKey(key),
          ),
          findsNothing,
        );
      }
      await unmount(tester);
    });

    testWidgets('詳情頁安全模式關：主圖與縮圖列不模糊、也沒有小標（小標只在列表類）', (tester) async {
      await seed(tester);
      await pump(
        tester,
        const Scaffold(
          body: DetailImageStage(
            images: [
              ImageRef('flag.png', 1, 1, sensitive: true),
              ImageRef('plain.png', 1, 1),
            ],
          ),
        ),
        safe: false,
      );
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      await unmount(tester);
    });

    testWidgets('同步 sheet 的縮圖（SyncRowThumb）與年度回顧挑圖同樣照安全模式處理', (tester) async {
      await seed(tester);
      File('${tmp.path}/images/flag.png').writeAsBytesSync(const <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ]);
      File('${tmp.path}/images/plain.png').writeAsBytesSync(const <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ]);
      await pump(
        tester,
        const Row(
          children: [
            SyncRowThumb(file: 'flag.png', info: null, key: ValueKey('s1')),
            SyncRowThumb(file: 'plain.png', info: null, key: ValueKey('s2')),
          ],
        ),
      );
      await settle(tester);
      expect(within('s1', find.byKey(blur)), findsOneWidget);
      expect(within('s1', find.byKey(circle)), findsOneWidget);
      expect(within('s2', find.byKey(blur)), findsNothing);
      await unmount(tester);
    });

    testWidgets('標記／取消標記後縮圖即時更新（不用重開）', (tester) async {
      await seed(tester);
      await pump(
        tester,
        cell(MediaThumb(const MediaSource(file: 'plain.png'))),
      );
      expect(find.byKey(blur), findsNothing);
      final id = ((await tester.runAsync(
        () => db.select(db.officialImages).get(),
      ))!).firstWhere((r) => r.imageFile == 'plain.png').id;
      await tester.runAsync(
        () => db.setSensitive(SensitiveSource.official, [id], true),
      );
      await settle(tester);
      expect(find.byKey(blur), findsOneWidget);
      await tester.runAsync(
        () => db.setSensitive(SensitiveSource.official, [id], false),
      );
      await settle(tester);
      expect(find.byKey(blur), findsNothing);
      await unmount(tester);
    });
  });

  group('表單：全部標為敏感＋逐張標記', () {
    List<ImageItem> items() => [
      ImageItem.stored(const NewImage(file: 'a.png', width: 10, height: 10)),
      ImageItem.stored(const NewImage(file: 'b.png', width: 10, height: 10)),
    ];

    Widget field(List<ImageItem> its, {String? pit}) => Padding(
      padding: const EdgeInsets.all(20),
      child: ImagePickerField(
        pitId: pit,
        items: its,
        onAdd: () {},
        onRemove: (_) {},
      ),
    );

    testWidgets('總開關＋坑都開：出現「全部標為敏感」「0 / 2」；開＝全部標、關＝全部取消；縮圖不模糊只有小標', (
      tester,
    ) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      final its = items();
      await pump(tester, field(its, pit: pitId));
      expect(find.text('全部標為敏感'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
      final sw = find.descendant(
        of: find.byKey(const ValueKey('sensitiveMarkAll')),
        matching: find.byType(AppSwitch),
      );
      expect(tester.widget<AppSwitch>(sw).value, isFalse);
      expect(find.byKey(badge), findsNothing);

      await tester.tap(sw);
      await tester.pump();
      expect(its.every((i) => i.sensitive), isTrue);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(tester.widget<AppSwitch>(sw).value, isTrue);
      expect(find.byKey(badge), findsNWidgets(2)); // 每張小圖左下角一個
      expect(find.byKey(blur), findsNothing); // 表單裡的小圖不模糊
      expect(find.byKey(circle), findsNothing);

      await tester.tap(sw);
      await tester.pump();
      expect(its.any((i) => i.sensitive), isFalse);
      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.byKey(badge), findsNothing);

      // 只標一張：「1 / 2」，開關是關的
      its.first.sensitive = true;
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(tester.widget<AppSwitch>(sw).value, isFalse);
      // 小標在左下角（84px 縮圖，距邊 6）
      final thumb = tester.getRect(find.byType(ImageItemThumb).first);
      final b = tester.getRect(find.byKey(badge));
      expect(b.left - thumb.left, closeTo(6, 0.5));
      expect(thumb.bottom - b.bottom, closeTo(6, 0.5));
      await unmount(tester);
    });

    testWidgets('總開關關：沒有這一行、沒有小標（標記保留在資料裡）', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      final its = items()..first.sensitive = true;
      await pump(tester, field(its, pit: pitId), master: false);
      expect(find.text('全部標為敏感'), findsNothing);
      expect(find.byKey(badge), findsNothing);
      expect(its.first.sensitive, isTrue);
      await unmount(tester);
    });

    testWidgets('坑的敏感內容關：沒有這一行；沒帶 pitId 的表單也沒有', (tester) async {
      final its = items();
      await pump(tester, field(its, pit: pitId));
      expect(find.text('全部標為敏感'), findsNothing);
      await unmount(tester);
      await pump(tester, field(its));
      expect(find.text('全部標為敏感'), findsNothing);
      await unmount(tester);
    });

    testWidgets('腦洞／摸魚（FormImageGrid）和成圖（PieceImageGrid）用同樣的行為', (
      tester,
    ) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      final a = items();
      final b = items();
      await pump(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              FormImageGrid(
                pitId: pitId,
                items: a,
                onAdd: () {},
                onRemove: (_) {},
                size: 84,
              ),
              PieceImageGrid(
                pitId: pitId,
                items: b,
                onAdd: () {},
                onRemove: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(find.text('全部標為敏感'), findsNWidgets(2));
      final switches = find.descendant(
        of: find.byKey(const ValueKey('sensitiveMarkAll')),
        matching: find.byType(AppSwitch),
      );
      await tester.tap(switches.first);
      await tester.pump();
      expect(a.every((i) => i.sensitive), isTrue);
      expect(b.any((i) => i.sensitive), isFalse);
      await tester.tap(switches.last);
      await tester.pump();
      expect(b.every((i) => i.sensitive), isTrue);
      await unmount(tester);
    });

    testWidgets('點小圖開預覽：右上「標為敏感」→「已標為敏感」，切換的是目前那一張', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      final its = items();
      await pump(tester, field(its, pit: pitId));
      await tester.tap(find.byType(ImageItemThumb).last);
      await settle(tester);
      expect(find.byType(FormImagePreviewPage), findsOneWidget);
      expect(find.text('標為敏感'), findsOneWidget);
      expect(find.text('已標為敏感'), findsNothing);
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sensitivePreviewToggle')));
      await tester.pump();
      expect(find.text('已標為敏感'), findsOneWidget);
      expect(its.map((i) => i.sensitive), [false, true]);
      await tester.tap(find.byKey(const ValueKey('sensitivePreviewToggle')));
      await tester.pump();
      expect(find.text('標為敏感'), findsOneWidget);
      expect(its.map((i) => i.sensitive), [false, false]);
      await unmount(tester);
    });

    testWidgets('預覽頁：總開關或坑沒開＝沒有切換鈕', (tester) async {
      final its = items();
      await pump(tester, field(its, pit: pitId)); // 坑沒開
      await tester.tap(find.byType(ImageItemThumb).first);
      await settle(tester);
      expect(find.byType(FormImagePreviewPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sensitivePreviewToggle')),
        findsNothing,
      );
      await unmount(tester);
    });

    testWidgets('ImageItem：標記跟著存檔（resolve 帶出 sensitive）', (tester) async {
      final item = ImageItem.stored(const NewImage(file: 'a.png'));
      expect(item.sensitive, isFalse);
      item.sensitive = true;
      final store = ImageStore(Directory('${tmp.path}/images'));
      final out = await item.resolve(store);
      expect(out.sensitive, isTrue);
      expect(ImageItem.stored(out).sensitive, isTrue);
    });
  });

  group('編輯坑：敏感內容開關', () {
    Future<Pit> pitRow(WidgetTester tester) async =>
        (await tester.runAsync(() => db.watchPit(pitId).first))!;

    Finder switchOf(String key) => find.byKey(ValueKey(key));

    testWidgets('總開關關：沒有「敏感內容」這一列', (tester) async {
      await pump(tester, PitEditPage(pit: await pitRow(tester)), master: false);
      expect(find.byKey(const ValueKey('pitSensitiveRow')), findsNothing);
      await unmount(tester);
    });

    testWidgets('總開關開：雜物下面同一張卡多一列，預設關；開不用確認，存檔後寫進坑', (tester) async {
      await pump(tester, PitEditPage(pit: await pitRow(tester)));
      expect(find.byKey(const ValueKey('pitSensitiveRow')), findsOneWidget);
      expect(find.text('敏感內容'), findsOneWidget);
      final junkY = tester.getTopLeft(find.text('雜物')).dy;
      final sensY = tester.getTopLeft(find.text('敏感內容')).dy;
      expect(sensY, greaterThan(junkY));
      expect(
        tester.widget<AppSwitch>(switchOf('pitSensitiveSwitch')).value,
        false,
      );
      await tester.tap(switchOf('pitSensitiveSwitch'));
      await settle(tester);
      expect(find.byKey(const ValueKey('sensitiveConfirm')), findsNothing);
      expect(
        tester.widget<AppSwitch>(switchOf('pitSensitiveSwitch')).value,
        true,
      );
      expect((await pitRow(tester)).sensitiveEnabled, false); // 還沒存
      await tester.tap(find.text('儲存'));
      await settle(tester);
      expect((await pitRow(tester)).sensitiveEnabled, true);
      await unmount(tester);
    });

    testWidgets('開→關要確認：說明坑內已標記的張數；取消不變；確認後存檔關閉但標記保留', (tester) async {
      final g = ((await tester.runAsync(() => db.watchGroups(pitId).first))!)
          .first
          .id;
      await tester.runAsync(
        () => db.addOfficial(pitId, g, [
          const NewImage(file: 'a.png', sensitive: true),
          const NewImage(file: 'b.png', sensitive: true),
          const NewImage(file: 'c.png'),
        ]),
      );
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await pump(tester, PitEditPage(pit: await pitRow(tester)));
      expect(
        tester.widget<AppSwitch>(switchOf('pitSensitiveSwitch')).value,
        true,
      );
      await tester.tap(switchOf('pitSensitiveSwitch'));
      await settle(tester);
      expect(find.text('關閉這個坑的敏感內容？'), findsOneWidget);
      expect(find.text('坑內已標記的 2 張圖會照常顯示。重新開啟後，標記會自動恢復。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(
        tester.widget<AppSwitch>(switchOf('pitSensitiveSwitch')).value,
        true,
      );

      await tester.tap(switchOf('pitSensitiveSwitch'));
      await settle(tester);
      await tester.tap(find.text('關閉'));
      await settle(tester);
      expect(
        tester.widget<AppSwitch>(switchOf('pitSensitiveSwitch')).value,
        false,
      );
      await tester.tap(find.text('儲存'));
      await settle(tester);
      expect((await pitRow(tester)).sensitiveEnabled, false);
      expect(
        (await tester.runAsync(() => db.sensitiveCountInPit(pitId)))!,
        2,
      ); // 標記還在
      await unmount(tester);
    });

    testWidgets('淺坑（格子清單最後一列）和封存坑（單獨一張卡）一樣有這個開關', (tester) async {
      final shallow = (await tester.runAsync(
        () => db.createPit(
          name: '淺',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.fan},
        ),
      ))!;
      final archived = (await tester.runAsync(
        () => db.createPit(name: '封', status: PitStatus.archived),
      ))!;
      for (final id in [shallow, archived]) {
        final pit = (await tester.runAsync(() => db.watchPit(id).first))!;
        await pump(tester, PitEditPage(pit: pit));
        expect(
          find.byKey(const ValueKey('pitSensitiveRow')),
          findsOneWidget,
          reason: pit.name,
        );
        await tester.ensureVisible(switchOf('pitSensitiveSwitch'));
        await tester.pump();
        await tester.tap(switchOf('pitSensitiveSwitch'));
        await settle(tester);
        await tester.ensureVisible(find.text('儲存'));
        await tester.tap(find.text('儲存'));
        await settle(tester);
        expect(
          (await tester.runAsync(() => db.watchPit(id).first))!
              .sensitiveEnabled,
          true,
        );
        await unmount(tester);
      }
    });
  });

  group('多選「敏感」', () {
    Future<List<OfficialImage>> seed(
      WidgetTester tester, {
      bool pitOn = true,
    }) async {
      final g = ((await tester.runAsync(() => db.watchGroups(pitId).first))!)
          .first
          .id;
      if (pitOn) {
        await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      }
      await tester.runAsync(
        () => db.addOfficial(pitId, g, [
          const NewImage(file: 'a.png', width: 10, height: 10, sensitive: true),
          const NewImage(file: 'b.png', width: 10, height: 10),
        ]),
      );
      return (await tester.runAsync(() => db.select(db.officialImages).get()))!;
    }

    Future<void> select(WidgetTester tester) async {
      await tester.longPress(find.byType(MediaThumb).first);
      await settle(tester);
      await tester.tap(find.text('全選'));
      await settle(tester);
    }

    testWidgets('有未標的→按「敏感」全部標上；再按（全部已標）→全部取消', (tester) async {
      await seed(tester);
      await pump(tester, OfficialListPage(pitId: pitId));
      await select(tester);
      expect(find.text('敏感'), findsOneWidget);
      await tester.tap(find.text('敏感'));
      await settle(tester);
      expect(
        ((await tester.runAsync(() => db.select(db.officialImages).get()))!)
            .every((r) => r.sensitive),
        isTrue,
      );
      // 動作後離開多選；再選一次，這次全部已標 → 取消
      expect(find.text('敏感'), findsNothing);
      await select(tester);
      await tester.tap(find.text('敏感'));
      await settle(tester);
      expect(
        ((await tester.runAsync(() => db.select(db.officialImages).get()))!)
            .any((r) => r.sensitive),
        isFalse,
      );
      await unmount(tester);
    });

    testWidgets('總開關關或這個坑沒開：底部沒有「敏感」', (tester) async {
      await seed(tester);
      await pump(tester, OfficialListPage(pitId: pitId), master: false);
      await select(tester);
      expect(find.text('敏感'), findsNothing);
      expect(find.text('下載'), findsOneWidget);
      await unmount(tester);

      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, false));
      await pump(tester, OfficialListPage(pitId: pitId));
      await select(tester);
      expect(find.text('敏感'), findsNothing);
      await unmount(tester);
    });

    testWidgets('選中的有現任封面：先確認；取消＝都不動；確認後標記並移除封面、改用最新沒標記的圖', (tester) async {
      final rows = await seed(tester);
      final b = rows.firstWhere((r) => r.imageFile == 'b.png');
      await tester.runAsync(() => db.setCover(pitId, b.id));
      await pump(tester, OfficialListPage(pitId: pitId));
      await select(tester);
      await tester.tap(find.text('敏感'));
      await settle(tester);
      expect(find.text('標為敏感內容？'), findsOneWidget);
      expect(find.text('選中的圖片裡有 1 張是這個坑的封面，標記後會從封面移除。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(
        ((await tester.runAsync(() => db.select(db.officialImages).get()))!)
            .firstWhere((r) => r.id == b.id)
            .sensitive,
        isFalse,
      );
      expect(
        ((await tester.runAsync(() => db.watchPit(pitId).first))!).coverImageId,
        b.id,
      );

      await tester.tap(find.text('敏感'));
      await settle(tester);
      await tester.tap(find.text('標記並移除封面'));
      await settle(tester);
      expect(
        ((await tester.runAsync(() => db.select(db.officialImages).get()))!)
            .every((r) => r.sensitive),
        isTrue,
      );
      // 全部都標了 → 沒有可用的圖，封面清掉（顯示坑名第一個字）
      expect(
        ((await tester.runAsync(() => db.watchPit(pitId).first))!).coverImageId,
        isNull,
      );
      await unmount(tester);
    });
  });

  group('分享匯入', () {
    File png(String name) {
      final f = File('${tmp.path}/$name')
        ..writeAsBytesSync(const <int>[
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        ]);
      return f;
    }

    /// 開分享 sheet；結果（按「加入」後）放進 [choices]。
    final choices = <ShareChoice?>[];

    Future<void> openSheet(
      WidgetTester tester, {
      bool master = true,
      ShareSection? section,
    }) async {
      choices.clear();
      await pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                choices.add(
                  await showShareSheet(
                    context,
                    paths: [png('x.png').path],
                    pitId: pitId,
                    section: section,
                  ),
                );
              },
              child: const Text('開'),
            ),
          ),
        ),
        master: master,
      );
      await tester.tap(find.text('開'));
      await settle(tester);
      expect(choices, isEmpty);
    }

    Finder row() => find.byKey(const ValueKey('shareSensitiveRow'));

    testWidgets('目標坑開了敏感內容：多一行「全部標為敏感」；開著按「加入」→ 結果帶 sensitive', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await openSheet(tester);
      expect(row(), findsOneWidget);
      expect(find.text('全部標為敏感'), findsOneWidget);
      await tester.ensureVisible(row());
      final sw = find.byKey(const ValueKey('shareSensitiveSwitch'));
      expect(tester.widget<AppSwitch>(sw).value, isFalse);
      await tester.tap(sw);
      await tester.pump();
      expect(tester.widget<AppSwitch>(sw).value, isTrue);
      await tester.tap(find.text('加入'));
      await settle(tester);
      expect(choices.single!.sensitive, isTrue);
      expect(choices.single!.action, ShareAction.add);
      await unmount(tester);
    });

    testWidgets('不開關直接「加入」→ sensitive 是 false', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await openSheet(tester);
      await tester.tap(find.text('加入'));
      await settle(tester);
      expect(choices.single!.sensitive, isFalse);
      await unmount(tester);
    });

    testWidgets('「素材庫」段：只看總開關（坑沒開也有這一行）', (tester) async {
      await openSheet(tester); // 坑沒開
      expect(row(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('shareDestMaterial')));
      await settle(tester);
      expect(row(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shareSensitiveSwitch')));
      await tester.pump();
      await tester.tap(find.text('加入'));
      await settle(tester);
      expect(choices.single!.action, ShareAction.addMaterial);
      expect(choices.single!.sensitive, isTrue);
      await unmount(tester);
    });

    testWidgets('坑沒開、總開關關：沒有這一行', (tester) async {
      await openSheet(tester);
      expect(row(), findsNothing);
      await unmount(tester);
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await openSheet(tester, master: false);
      expect(row(), findsNothing);
      await unmount(tester);
    });

    testWidgets('要開表單的位置（摸魚）：這裡不放，表單裡標', (tester) async {
      await tester.runAsync(() => db.setPitSensitiveEnabled(pitId, true));
      await openSheet(tester, section: ShareSection.draft);
      expect(row(), findsNothing);
      await unmount(tester);
    });
  });
}
