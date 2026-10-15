import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/common/timeline.dart';
import 'package:huakeng/ui/oshi/oshi_date_guess.dart';
import 'package:huakeng/ui/oshi/oshi_detail_page.dart';
import 'package:huakeng/ui/oshi/oshi_form_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/search/tag_filter_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 推活 UI（D-057／D-062／D-063／D-065／D-066）：預設日期推測、共用時間軸、列表（時間軸／網格／分組／
/// tag 篩選）、新增與編輯、詳情與刪除、導覽列規則。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late List<OfficialGroup> groups;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('oshi_ui');
    pitId = await db.createPit(name: '坑A');
    groups = await db.watchGroups(pitId, kind: 'oshi').first;
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
    Map<String, Object> initialPrefs = const {},
    List<XFile> pick = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      ...initialPrefs,
    });
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
          imagePickerProvider.overrideWithValue(() async => pick),
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

  Future<String> rec({
    required DateTime date,
    String? groupId,
    String? title,
    String? description,
    List<String> files = const ['a.png'],
    List<String> tagIds = const [],
  }) => db.saveOshiRecord(
    pitId: pitId,
    date: date,
    groupId: groupId,
    title: title,
    description: description,
    images: [for (final f in files) NewImage(file: f, width: 30, height: 40)],
    tagIds: tagIds,
  );

  // 最小的 JPEG：只有 APP1 Exif，內含 DateTimeOriginal。
  Uint8List jpegWithExif(String stamp) {
    final b = BytesBuilder();
    final tiff = BytesBuilder();
    void tu16(int v) => tiff.add([v & 0xff, (v >> 8) & 0xff]);
    void tu32(int v) => tiff.add([
      v & 0xff,
      (v >> 8) & 0xff,
      (v >> 16) & 0xff,
      (v >> 24) & 0xff,
    ]);
    tiff.add('II'.codeUnits);
    tu16(0x2a);
    tu32(8);
    // IFD0：一筆 ExifIFD 指標（偏移 26）。
    tu16(1);
    tu16(0x8769);
    tu16(4);
    tu32(1);
    tu32(26);
    tu32(0);
    // ExifIFD：一筆 DateTimeOriginal（20 bytes，資料在偏移 44）。
    tu16(1);
    tu16(0x9003);
    tu16(2);
    tu32(20);
    tu32(44);
    tu32(0);
    tiff.add([...stamp.codeUnits, 0]);
    final body = tiff.toBytes();
    b.add([0xff, 0xd8, 0xff, 0xe1]);
    b.add([(2 + 6 + body.length) >> 8, (2 + 6 + body.length) & 0xff]);
    b.add('Exif'.codeUnits);
    b.add([0, 0]);
    b.add(body);
    b.add([0xff, 0xd9]);
    return b.toBytes();
  }

  group('預設日期（EXIF → 檔案時間 → 今天）', () {
    test('parseExifDateTime', () {
      expect(
        parseExifDateTime('2026:10:05 14:03:22'),
        DateTime(2026, 10, 5, 14, 3, 22),
      );
      expect(
        parseExifDateTime('2026-10-05 14:03:22\u0000'),
        DateTime(2026, 10, 5, 14, 3, 22),
      );
      expect(parseExifDateTime('2026:10:05'), DateTime(2026, 10, 5));
      expect(parseExifDateTime('0000:00:00 00:00:00'), isNull);
      expect(parseExifDateTime('abc'), isNull);
      expect(parseExifDateTime(null), isNull);
    });

    test('pickOshiDate 的優先順序，且只取年月日', () {
      final now = DateTime(2026, 10, 11, 9, 30);
      expect(
        pickOshiDate(
          exif: DateTime(2026, 5, 3, 22),
          modified: DateTime(2026, 6, 1),
          now: now,
        ),
        DateTime(2026, 5, 3),
      );
      expect(
        pickOshiDate(modified: DateTime(2026, 6, 1, 8), now: now),
        DateTime(2026, 6, 1),
      );
      expect(pickOshiDate(now: now), DateTime(2026, 10, 11));
    });

    test('guessOshiDate：有 EXIF 用 EXIF，沒有就用檔案修改時間，讀不到用今天', () async {
      final withExif = File('${dir.path}/exif.jpg')
        ..writeAsBytesSync(jpegWithExif('2025:12:24 18:00:00'));
      expect(await guessOshiDate(withExif.path), DateTime(2025, 12, 24));

      final plain = File('${dir.path}/plain.png')..writeAsBytesSync([1, 2, 3]);
      plain.setLastModifiedSync(DateTime(2024, 2, 29, 23, 59));
      expect(await guessOshiDate(plain.path), DateTime(2024, 2, 29));

      expect(
        await guessOshiDate(
          '${dir.path}/missing.png',
          now: DateTime(2026, 1, 2, 3),
        ),
        DateTime(2026, 1, 2),
      );
    });
  });

  group('共用時間軸元件（D-063）', () {
    testWidgets('月份分段、同一天的第二筆起是灰點、月份最後一筆不畫線', (tester) async {
      TimelineEntry e(String id, DateTime d) =>
          TimelineEntry(id: id, date: d, onTap: () {}, title: id);
      await show(
        tester,
        Scaffold(
          body: TimelineView(
            entries: [
              e('a', DateTime(2026, 10, 8)),
              e('b', DateTime(2026, 10, 5)),
              e('c', DateTime(2026, 10, 5)),
              e('d', DateTime(2026, 9, 22)),
            ],
            countLabel: (n) => '$n 筆',
          ),
        ),
      );
      expect(find.text('2026 年 10 月'), findsOneWidget);
      expect(find.text('2026 年 9 月'), findsOneWidget);
      expect(find.text('3 筆'), findsOneWidget);
      expect(find.text('1 筆'), findsOneWidget);
      // 日期大字：10/8、10/5（只一次）、9/22；同天第二筆是灰點。
      expect(find.text('08'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-dot')), findsOneWidget);
      // 線：10 月的 a、b 之後有（c 是月底沒有），9 月只有一筆沒有 → 共 2 條。
      expect(find.byKey(const ValueKey('timeline-line')), findsNWidgets(2));
      // 2026-10-08 是週四。
      expect(find.text('週四'), findsOneWidget);
      expect(find.text('週一'), findsOneWidget);
      expect(find.text('週二'), findsOneWidget);
      await unmount(tester);
    });

    test('groupTimelineByMonth 保持順序並合併同月', () {
      TimelineEntry e(DateTime d) =>
          TimelineEntry(id: '$d', date: d, onTap: () {});
      final s = groupTimelineByMonth([
        e(DateTime(2026, 10, 8)),
        e(DateTime(2026, 10, 1)),
        e(DateTime(2026, 9, 30)),
        e(DateTime(2025, 9, 30)),
      ]);
      expect(s.map((x) => (x.year, x.month, x.entries.length)), [
        (2026, 10, 2),
        (2026, 9, 1),
        (2025, 9, 1),
      ]);
    });
  });

  group('列表', () {
    testWidgets('空狀態：沒有導覽列隱藏、沒有 FAB／篩選列、可新增', (tester) async {
      await show(tester, OshiListPage(pitId: pitId));
      expect(find.text('坑A · 推活'), findsOneWidget);
      expect(find.text('0 筆'), findsOneWidget);
      expect(find.text('還沒有推活紀錄'), findsOneWidget);
      expect(find.text('新增紀錄'), findsOneWidget);
      expect(find.text('全部'), findsNothing);
      expect(navBarHiddenCount.value, 0); // 瀏覽頁有導覽列
      await unmount(tester);
    });

    testWidgets('時間軸：月份分段、日期、標題、描述、tag、多張圓形數字；分組 pills 篩選', (tester) async {
      final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
      await tester.runAsync(() async {
        await rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[0].id,
          title: '一週年展・現場',
          description: '排了兩小時隊',
          files: ['a.png', 'b.png'],
          tagIds: [tag!],
        );
        await rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[1].id,
          title: '十連出貨',
        );
        await rec(date: DateTime(2026, 9, 22), title: '痛包完成');
      });
      await show(tester, OshiListPage(pitId: pitId));
      expect(find.text('3 筆'), findsWidgets); // 標題列總數＋10 月的 2 筆…
      expect(find.text('2026 年 10 月'), findsOneWidget);
      expect(find.text('2026 年 9 月'), findsOneWidget);
      expect(find.text('一週年展・現場'), findsOneWidget);
      expect(find.text('排了兩小時隊'), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 兩張圖的圓形數字
      expect(
        find.byKey(const ValueKey('timeline-dot')),
        findsOneWidget,
      ); // 同日第二筆
      // 分組 pills
      for (final n in ['全部', '線下照片', '遊戲截圖', '對話記錄']) {
        expect(find.text(n), findsOneWidget);
      }
      await tester.tap(find.text('遊戲截圖'));
      await settle(tester);
      expect(find.text('十連出貨'), findsOneWidget);
      expect(find.text('一週年展・現場'), findsNothing);
      expect(find.text('痛包完成'), findsNothing);
      await tester.tap(find.text('全部'));
      await settle(tester);
      expect(find.text('痛包完成'), findsOneWidget);
      expect(navBarHiddenCount.value, 0);
      await unmount(tester);
    });

    testWidgets('九宮格：沒有任何文字、貼邊 3 欄、間距 2px、切換並記住選擇', (tester) async {
      await tester.runAsync(() async {
        await rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[0].id,
          files: ['a.png', 'b.png'],
        );
        await rec(date: DateTime(2026, 9, 3));
      });
      await show(tester, OshiListPage(pitId: pitId));
      await tester.tap(find.bySemanticsLabel('九宮格'));
      await settle(tester);
      // 圖下沒有日期、分組標籤（D-066 的標籤在九宮格不顯示）；「線下照片」只剩 pills 一個。
      expect(find.text('10/05'), findsNothing);
      expect(find.text('09/03'), findsNothing);
      expect(find.text('線下照片'), findsOneWidget);
      // 多張圖的那格右下角有張數。
      expect(find.text('2'), findsOneWidget);
      // 一排 3 格正方形、貼邊、間距 2px。
      final cells = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('oshi-grid-'),
      );
      expect(cells, findsNWidgets(2));
      final r0 = tester.getRect(cells.at(0)), r1 = tester.getRect(cells.at(1));
      expect(r0.width, closeTo(r0.height, 0.01));
      expect(r0.left, 0);
      expect(r1.left - r0.right, 2);
      expect(r0.width, closeTo((360 - 4) / 3, 0.5));
      expect(prefs.getString('oshiLayout'), 'grid');
      await unmount(tester);

      // 重開：記住網格。
      await show(
        tester,
        OshiListPage(pitId: pitId),
        initialPrefs: {'oshiLayout': 'grid'},
      );
      expect(find.text('2026 年 10 月'), findsNothing);
      await tester.tap(find.bySemanticsLabel('時間軸'));
      await settle(tester);
      expect(find.text('2026 年 10 月'), findsOneWidget);
      expect(prefs.getString('oshiLayout'), 'timeline');
      await unmount(tester);
    });

    testWidgets('tag 篩選：頂部「#tag ×」篩選列＋符合筆數，按 × 回完整列表', (tester) async {
      final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
      await tester.runAsync(() async {
        await rec(date: DateTime(2026, 10, 5), title: '有 tag', tagIds: [tag!]);
        await rec(date: DateTime(2026, 10, 4), title: '沒 tag');
      });
      await show(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => OshiListPage(pitId: pitId, tagId: tag),
          ),
        ),
      );
      expect(find.byType(TagFilterBar), findsOneWidget);
      expect(find.text('有 tag'), findsOneWidget);
      expect(find.text('沒 tag'), findsNothing);
      expect(find.text('2 筆'), findsWidgets); // 標題列＝全部 2 筆
      await tester.tap(find.bySemanticsLabel('移除篩選'));
      await settle(tester);
      expect(find.byType(TagFilterBar), findsNothing);
      expect(find.text('沒 tag'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('管理分組：開推活分組管理頁（沒有導覽列），顯示各組筆數', (tester) async {
      await tester.runAsync(
        () => rec(date: DateTime(2026, 10, 5), groupId: groups[0].id),
      );
      await show(tester, OshiListPage(pitId: pitId));
      await tester.tap(find.byTooltip('管理分組'));
      await settle(tester);
      expect(find.text('分組只用於推活，拖曳可調整次序'), findsOneWidget);
      expect(find.text('1 筆'), findsOneWidget);
      expect(navBarHiddenCount.value, greaterThan(0));
      await unmount(tester);
    });

    testWidgets('深色模式沒有 layout 例外', (tester) async {
      await tester.runAsync(() async {
        await rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[0].id,
          title: 'x',
        );
      });
      await show(tester, OshiListPage(pitId: pitId), dark: true);
      await tester.tap(find.bySemanticsLabel('九宮格'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('新增與編輯', () {
    File png(String name) {
      final f = File('${dir.path}/$name');
      f.writeAsBytesSync(Uint8List.fromList(_png1x1));
      return f;
    }

    testWidgets('新增：欄位順序、沒有導覽列、儲存日期／分組／tag', (tester) async {
      final tag = await tester.runAsync(() => db.createTag(pitId, '夏日企劃'));
      final img = png('one.png')
        ..setLastModifiedSync(DateTime(2026, 3, 14, 12));
      await show(tester, OshiFormPage(pitId: pitId, initialImages: [img.path]));
      expect(navBarHiddenCount.value, greaterThan(0));
      expect(find.text('新增推活紀錄'), findsOneWidget);
      expect(find.text('建立紀錄'), findsOneWidget);
      // 欄位次序：圖片 < 標題 < 描述 < 分組 < tag < 日期
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      final order = [y('圖片'), y('標題'), y('描述'), y('分組'), y('tag'), y('日期')];
      expect(order, [...order]..sort());
      // 預設日期＝第一張圖的檔案時間（沒有 EXIF）
      expect(find.text('2026 / 03 / 14'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), '  一週年展  ');
      await tester.enterText(find.byType(TextField).at(1), '排了兩小時隊');
      await tester.tap(find.text('遊戲截圖'));
      await tester.pump();
      await tester.ensureVisible(find.text('#夏日企劃'));
      await tester.tap(find.text('#夏日企劃'));
      await tester.pump();

      // 手動改日期（改過之後不再被圖片猜測覆蓋）
      await tester.ensureVisible(find.text('2026 / 03 / 14'));
      await tester.tap(find.text('2026 / 03 / 14'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('20'));
      await tester.pump();
      await tester.tap(
        find.text(
          MaterialLocalizations.of(tester.element(find.byType(Scaffold).first))
              .okButtonLabel,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('2026 / 03 / 20'), findsOneWidget);

      await tester.ensureVisible(find.text('建立紀錄'));
      await tester.tap(find.text('建立紀錄'));
      await settle(tester);
      await settle(tester);
      final rows = await tester.runAsync(
        () => db.watchOshiRecords(pitId).first,
      );
      expect(rows, hasLength(1));
      final v = rows!.single;
      expect(v.record.title, '一週年展');
      expect(v.record.description, '排了兩小時隊');
      expect(v.date, DateTime(2026, 3, 20));
      expect(v.group!.name, '遊戲截圖');
      expect(v.tags.map((e) => e.id), [tag]);
      expect(v.images, hasLength(1));
      await unmount(tester);
    });

    testWidgets('沒有圖片時不能建立；× 移除圖片後按建立會提示', (tester) async {
      final img = png('two.png');
      await show(tester, OshiFormPage(pitId: pitId, initialImages: [img.path]));
      await tester.tap(find.bySemanticsLabel('移除圖片'));
      await tester.pump();
      await tester.ensureVisible(find.text('建立紀錄'));
      await tester.tap(find.text('建立紀錄'));
      await tester.pump();
      expect(find.text('請先選擇圖片'), findsOneWidget);
      expect(await db.watchOshiRecords(pitId).first, isEmpty);
      await unmount(tester);
    });

    testWidgets('分組可再點取消、也可「新增」分組並選取', (tester) async {
      final img = png('three.png');
      await show(tester, OshiFormPage(pitId: pitId, initialImages: [img.path]));
      await tester.ensureVisible(find.text('線下照片'));
      await tester.tap(find.text('線下照片'));
      await tester.pump();
      await tester.tap(find.text('線下照片')); // 再點取消
      await tester.pump();
      // 分組欄在 tag 欄之前，第一個「新增」是分組的。
      await tester.ensureVisible(find.text('新增').first);
      await tester.tap(find.text('新增').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField).last, '週邊');
      await tester.tap(find.text('確定'));
      await settle(tester);
      expect(find.text('週邊'), findsOneWidget);
      await tester.ensureVisible(find.text('建立紀錄'));
      await tester.tap(find.text('建立紀錄'));
      await settle(tester);
      await settle(tester);
      final v = (await tester.runAsync(() => db.watchOshiRecords(pitId).first))!
          .single;
      expect(v.group!.name, '週邊');
      await unmount(tester);
    });

    testWidgets('編輯：載入既有資料、按鈕是「儲存」、日期不被覆蓋、可取消分組', (tester) async {
      final id = (await tester.runAsync(
        () => rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[0].id,
          title: '舊標題',
          description: '舊描述',
        ),
      ))!;
      await show(tester, OshiFormPage(pitId: pitId, recordId: id));
      expect(find.text('編輯推活紀錄'), findsOneWidget);
      expect(find.text('儲存'), findsOneWidget);
      expect(find.text('建立紀錄'), findsNothing);
      expect(find.text('舊標題'), findsOneWidget);
      expect(find.text('2026 / 10 / 05'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '新標題');
      await tester.ensureVisible(find.text('線下照片'));
      await tester.tap(find.text('線下照片')); // 取消分組
      await tester.pump();
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final v = (await tester.runAsync(() => db.getOshiRecord(id)))!;
      expect(v.record.title, '新標題');
      expect(v.record.description, '舊描述');
      expect(v.record.groupId, isNull);
      expect(v.date, DateTime(2026, 10, 5));
      expect(v.images.single.file, 'a.png'); // 沿用原圖
      await unmount(tester);
    });
  });

  group('詳情', () {
    testWidgets('輪播「1 / N」、日期含星期、分組 chip、標題、描述、tag；沒有導覽列', (tester) async {
      final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
      final id = (await tester.runAsync(
        () => rec(
          date: DateTime(2026, 10, 5),
          groupId: groups[0].id,
          title: '一週年展・現場',
          description: '排了兩小時隊，終於拿到限定立牌。',
          files: ['a.png', 'b.png', 'c.png', 'd.png'],
          tagIds: [tag!],
        ),
      ))!;
      await show(tester, OshiDetailPage(pitId: pitId, recordId: id));
      expect(navBarHiddenCount.value, greaterThan(0));
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('2026 / 10 / 05（週一）'), findsOneWidget);
      expect(find.text('線下照片'), findsOneWidget);
      expect(find.text('一週年展・現場'), findsOneWidget);
      expect(find.text('排了兩小時隊，終於拿到限定立牌。'), findsOneWidget);
      expect(find.text('#角色1'), findsOneWidget);
      expect(find.bySemanticsLabel('編輯'), findsOneWidget);
      expect(find.bySemanticsLabel('刪除'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 / 4'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('點 tag 回推活列表並套用 tag 篩選', (tester) async {
      final tag = await tester.runAsync(() => db.createTag(pitId, '角色1'));
      final id = (await tester.runAsync(
        () => rec(date: DateTime(2026, 10, 5), title: '有 tag', tagIds: [tag!]),
      ))!;
      await tester.runAsync(
        () => rec(date: DateTime(2026, 10, 4), title: '沒 tag'),
      );
      await show(tester, OshiListPage(pitId: pitId));
      await tester.tap(find.text('有 tag'));
      await settle(tester);
      expect(find.byType(OshiDetailPage), findsOneWidget);
      await tester.tap(find.text('#角色1'));
      await settle(tester);
      expect(find.byType(OshiDetailPage), findsNothing);
      expect(find.byType(TagFilterBar), findsOneWidget);
      expect(find.text('沒 tag'), findsNothing);
      expect(id, isNotEmpty);
      await unmount(tester);
    });

    testWidgets('刪除要確認：取消不刪、確認後軟刪除並返回', (tester) async {
      final id = (await tester.runAsync(
        () => rec(date: DateTime(2026, 10, 5), title: '要刪的'),
      ))!;
      await show(tester, OshiListPage(pitId: pitId));
      await tester.tap(find.text('要刪的'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('刪除'));
      await settle(tester);
      expect(find.text('刪除這筆紀錄？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await settle(tester);
      expect(await tester.runAsync(() => db.getOshiRecord(id)), isNotNull);
      await tester.tap(find.bySemanticsLabel('刪除'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('刪除'),
        ),
      );
      await settle(tester);
      expect(await tester.runAsync(() => db.getOshiRecord(id)), isNull);
      expect(find.byType(OshiDetailPage), findsNothing);
      expect(find.text('還沒有推活紀錄'), findsOneWidget);
      await unmount(tester);
    });
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
