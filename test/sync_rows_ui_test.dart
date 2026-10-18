import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/data/sync_row_info.dart';
import 'package:huakeng/l10n/app_localizations.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/ui/common/svg_icon.dart';
import 'package:huakeng/ui/sync/sync_popover.dart';
import 'package:huakeng/ui/sync/sync_sheet.dart';
import 'package:image/image.dart' as img;

/// D-099：同步 sheet／popover 每一行——縮圖或分類占位、位置文字、傳輸中排最上、傳完淡出。

class _FakeSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  void set(SyncState s) => state = s;
}

SyncTransfer _t(
  String f, {
  bool up = false,
  TransferState s = TransferState.waiting,
  double? p,
}) => SyncTransfer(
  file: f,
  direction: up ? TransferDirection.upload : TransferDirection.download,
  state: s,
  progress: p,
);

SyncState _syncing(List<SyncTransfer> l) =>
    SyncState(phase: SyncPhase.syncing, transfersPlanned: true, transfers: l);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('pickSyncRows：傳輸中排最上（最多 3 張）、等待中接著、最多 4 行', () {
    test('順序與數量', () {
      final list = [
        _t('w1'),
        _t('a1', s: TransferState.active),
        _t('w2'),
        _t('a2', s: TransferState.active),
        _t('d', s: TransferState.done, p: 1),
        _t('a3', s: TransferState.active),
        _t('a4', s: TransferState.active),
        _t('w3'),
      ];
      expect(pickSyncRows(list).map((x) => x.file), ['a1', 'a2', 'a3', 'a4']);
      expect(
        pickSyncRows(list.where((x) => x.file != 'a4').toList())
            .map((x) => x.file),
        ['a1', 'a2', 'a3', 'w1'],
      );
      expect(
        pickSyncRows([_t('w1'), _t('a1', s: TransferState.active), _t('w2')])
            .map((x) => x.file),
        ['a1', 'w1', 'w2'],
      );
      expect(pickSyncRows(const []), isEmpty);
    });

    test('上傳與下載混在一起照同樣規則', () {
      final list = [
        _t('w', up: true),
        _t('a', s: TransferState.active),
        _t('b', up: true, s: TransferState.active),
      ];
      expect(pickSyncRows(list).map((x) => x.file), ['a', 'b', 'w']);
    });
  });

  late AppDatabase db;
  late Directory tmp;
  late ImageStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('sync_rows_ui');
    store = ImageStore(Directory('${tmp.path}/images'));
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final pitA = await db.createPit(name: '坑A', junkEnabled: true);
    final pitB = await db.createPit(name: '坑B');
    final groups = await db.select(db.officialGroups).get();
    final officialGroup = groups.firstWhere((g) => g.pitId == pitA).id;
    NewImage im(String f) => NewImage(file: f, width: 10, height: 10);
    await db.addOfficial(pitA, officialGroup, [im('official.png')]);
    await db.addFanArts(pitB, [im('fan.png')], author: 'x');
    await db.addJunk(pitA, [im('junk.png')]);
    await db.addMaterials(MaterialCategory.clothing, [im('mat.png')]);
    await db.saveDraft(
      pitId: pitA,
      title: '天台煙花',
      images: [im('draft.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await db.saveIdea(
      pitId: pitA,
      title: '腦洞標題',
      body: '',
      images: [im('idea.png')],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.savePiece(
      pitId: pitB,
      title: '成圖標題',
      body: '',
      images: [im('piece.png')],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 10, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    await db.saveOshiRecord(
      pitId: pitB,
      date: DateTime(2026, 10, 2),
      title: '一週年展',
      images: [im('oshi.png')],
    );
  });

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Size size,
    Widget body,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith((ref) async => store),
          syncControllerProvider.overrideWith(_FakeSync.new),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  _FakeSync fake(ProviderContainer c) =>
      c.read(syncControllerProvider.notifier) as _FakeSync;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // 混合清單：等待中的故意排在前面，確認傳輸中的會被提到最上面。
  List<SyncTransfer> mixed() => [
    _t('junk.png'),
    _t('fan.png', up: true, s: TransferState.active, p: .72),
    _t('official.png'),
    _t('mat.png', s: TransferState.active, p: .18),
    _t('draft.png', s: TransferState.active, p: .62),
    _t('idea.png'),
    _t('piece.png'),
    _t('oshi.png'),
  ];

  const sizes = {
    '手機 390×844': Size(390, 844),
    'iPad 窄 400×900': Size(400, 900),
  };

  for (final e in sizes.entries) {
    testWidgets('bottom sheet ${e.key}：位置文字、傳輸中排最上、最多 4 行', (tester) async {
      await seed(tester);
      final c = await pump(
        tester,
        e.value,
        const Align(alignment: Alignment.bottomCenter, child: SyncSheetBody()),
      );
      fake(c).set(_syncing(mixed()));
      await settle(tester);

      // 位置文字
      expect(find.text('坑B · 好看同人圖'), findsOneWidget);
      expect(find.text('素材庫 · 服裝'), findsOneWidget);
      expect(find.text('坑A · 摸魚 · 天台煙花'), findsOneWidget);
      // 3 張傳輸中各自顯示百分比，第 4 行是等待中
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('等待中'), findsOneWidget);
      expect(find.text('坑A · 雜物'), findsOneWidget); // 第一個等待中
      // 其餘 4 張收進「還有 N 張等待中」
      expect(find.text('還有 4 張等待中'), findsOneWidget);
      expect(find.text('坑A · 官方圖冊'), findsNothing);
      // 順序：上傳 fan(72)、下載 mat(18)、下載 draft(62) 在等待中的 junk 之前
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(y('坑B · 好看同人圖'), lessThan(y('素材庫 · 服裝')));
      expect(y('素材庫 · 服裝'), lessThan(y('坑A · 摸魚 · 天台煙花')));
      expect(y('坑A · 摸魚 · 天台煙花'), lessThan(y('坑A · 雜物')));
      // 上傳／下載標籤
      expect(find.text('上傳'), findsOneWidget);
      expect(find.text('下載'), findsNWidgets(3));
      // 每行一個 44×44 縮圖格
      expect(find.byType(SyncRowThumb), findsNWidgets(4));
      for (final el in find.byType(SyncRowThumb).evaluate()) {
        expect(el.size, const Size(44, 44));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('縮圖還沒到：該分類底色＋分類 icon，不是通用灰色圖片 icon', (tester) async {
    await seed(tester);
    final c = await pump(
      tester,
      const Size(390, 844),
      const Align(alignment: Alignment.bottomCenter, child: SyncSheetBody()),
    );
    // 分類各一，分兩輪看（一次最多 4 行）
    final cases = <String, (String, CategoryColor Function(AppTokens))>{
      'fan.png': ('fan', (t) => t.fanArt),
      'official.png': ('official', (t) => t.official),
      'draft.png': ('draft', (t) => t.draft),
      'idea.png': ('idea', (t) => t.idea),
      'piece.png': ('piece', (t) => t.piece),
      'oshi.png': ('oshi', (t) => t.oshi),
      'junk.png': ('junk', (t) => CategoryColor(t.chipBg, t.text3)),
      'mat.png': ('material', (t) => CategoryColor(t.chipBg, t.text3)),
    };
    final files = cases.keys.toList();
    final tokens = AppTokens.light;
    for (var i = 0; i < files.length; i += 4) {
      final batch = files.skip(i).take(4).toList();
      fake(c).set(_syncing([for (final f in batch) _t(f)]));
      await settle(tester);
      for (final f in batch) {
        final (key, color) = cases[f]!;
        final box = find.byKey(ValueKey('syncThumbPlaceholder:$key'));
        expect(box, findsOneWidget, reason: f);
        expect(tester.widget<ColoredBox>(box).color, color(tokens).bg);
        expect(
          find.descendant(of: box, matching: find.byType(SvgIcon)),
          findsOneWidget,
        );
      }
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    }
    // 資料庫查不到的檔案：中性底色、沒有 icon
    fake(c).set(_syncing([_t('unknown.png')]));
    await settle(tester);
    final none = find.byKey(const ValueKey('syncThumbPlaceholder:none'));
    expect(none, findsOneWidget);
    expect(
      find.descendant(of: none, matching: find.byType(SvgIcon)),
      findsNothing,
    );
  });

  testWidgets('縮圖到了就換成縮圖（本機縮圖優先），影片用 poster 的縮圖', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await store.saveThumb(
        'fan.png',
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8))),
      );
    });
    final c = await pump(
      tester,
      const Size(390, 844),
      const Align(alignment: Alignment.bottomCenter, child: SyncSheetBody()),
    );
    fake(c).set(
      _syncing([
        _t('fan.png', s: TransferState.active, p: .3),
        _t('draft.png'),
      ]),
    );
    await settle(tester);
    bool isThumbOf(Widget w, String name) {
      if (w is! Image) return false;
      final p = w.image;
      final inner = p is ResizeImage ? p.imageProvider : p;
      return inner is FileImage &&
          inner.file.path == store.thumbFileOf(name).path;
    }

    expect(
      find.byWidgetPredicate((w) => isThumbOf(w, 'fan.png')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('syncThumbPlaceholder:fan')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('syncThumbPlaceholder:draft')),
      findsOneWidget,
    );

    // 後來才到的縮圖：即時換上
    await tester.runAsync(() async {
      await store.saveThumb(
        'draft.png',
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8))),
      );
    });
    await settle(tester);
    expect(
      find.byWidgetPredicate((w) => isThumbOf(w, 'draft.png')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('syncThumbPlaceholder:draft')),
      findsNothing,
    );
  });

  testWidgets('傳完的那行淡出，下面的補上來', (tester) async {
    await seed(tester);
    final c = await pump(
      tester,
      const Size(390, 844),
      const Align(alignment: Alignment.bottomCenter, child: SyncSheetBody()),
    );
    final start = [
      _t('fan.png', s: TransferState.active, p: .5),
      _t('mat.png', s: TransferState.active, p: .2),
      _t('draft.png'),
      _t('junk.png'),
      _t('idea.png'),
    ];
    fake(c).set(_syncing(start));
    await settle(tester);
    expect(find.text('坑B · 好看同人圖'), findsOneWidget);
    expect(find.text('坑A · 雜物'), findsOneWidget);
    expect(find.text('還有 1 張等待中'), findsOneWidget);

    // fan 傳完：該行仍在、定格 100%、正在淡出；其他行補上來（idea 進到 4 行內）
    fake(c).set(
      _syncing([
        start[0].copyWith(state: TransferState.done, progress: 1),
        ...start.skip(1),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('坑B · 好看同人圖'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    final fade = find.descendant(
      of: find.byKey(const ValueKey('syncRowFade')),
      matching: find.byType(Opacity),
    );
    final mid = tester.widget<Opacity>(fade).opacity;
    expect(mid, lessThan(1));
    expect(mid, greaterThan(0));
    expect(find.text('坑A · 腦洞 · 腦洞標題'), findsOneWidget); // 補上來的一行
    expect(find.text('還有 1 張等待中'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('坑B · 好看同人圖'), findsNothing);
    expect(find.byKey(const ValueKey('syncRowFade')), findsNothing);
    expect(find.byType(SyncRowThumb), findsNWidgets(4));
  });

  testWidgets('過長的標題用省略號、不溢位', (tester) async {
    await seed(tester);
    await tester.runAsync(() async {
      await db.saveDraft(
        pitId: (await db.select(db.pits).get()).first.id,
        title: '這是一個非常非常非常非常非常非常非常長的摸魚標題用來測試省略號',
        images: [NewImage(file: 'long.png', width: 1, height: 1)],
        tagIds: const [],
        ideaIds: const [],
      );
    });
    final c = await pump(
      tester,
      const Size(390, 844),
      const Align(alignment: Alignment.bottomCenter, child: SyncSheetBody()),
    );
    fake(c).set(_syncing([_t('long.png', s: TransferState.active, p: .4)]));
    await settle(tester);
    final text = tester.widget<Text>(find.textContaining('非常非常'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  for (final e in {
    'iPad 834×1194': const Size(834, 1194),
    'iPad 橫向 1194×834': const Size(1194, 834),
  }.entries) {
    testWidgets('popover ${e.key}：同樣的行（縮圖／位置／排序）', (tester) async {
      await seed(tester);
      final c = await pump(
        tester,
        e.value,
        const SyncPopover(anchor: Rect.fromLTWH(20, 24, 40, 40)),
      );
      fake(c).set(_syncing(mixed()));
      await settle(tester);
      expect(find.text('坑B · 好看同人圖'), findsOneWidget);
      expect(find.text('素材庫 · 服裝'), findsOneWidget);
      expect(find.text('坑A · 摸魚 · 天台煙花'), findsOneWidget);
      expect(find.text('還有 4 張等待中'), findsOneWidget);
      expect(find.byType(SyncRowThumb), findsNWidgets(4));
      double y(String s) => tester.getTopLeft(find.text(s)).dy;
      expect(y('坑B · 好看同人圖'), lessThan(y('坑A · 雜物')));
      expect(tester.takeException(), isNull);
    });
  }

  group('syncRowInfos：一次批次查所屬實體', () {
    test('所有種類、標題、素材分類、poster 對應；找不到的不在結果裡', () async {
      final pitA = await db.createPit(name: '坑A');
      await db.saveDraft(
        pitId: pitA,
        title: '  ',
        images: [
          NewImage(
            file: 'v.mp4',
            kind: MediaKind.video,
            posterFile: 'v_poster.jpg',
          ),
        ],
        tagIds: const [],
        ideaIds: const [],
      );
      await db.addMaterials(MaterialCategory.pose, [NewImage(file: 'm.png')]);
      final r = await db.syncRowInfos([
        'v.mp4',
        'v_poster.jpg',
        'm.png',
        'zzz.png',
      ]);
      expect(r.keys.toSet(), {'v.mp4', 'v_poster.jpg', 'm.png'});
      expect(r['v.mp4']!.kind, SyncRowKind.draft);
      expect(r['v.mp4']!.pitName, '坑A');
      expect(r['v.mp4']!.title, isNull); // 空白標題不算
      expect(r['v.mp4']!.posterFile, 'v_poster.jpg');
      expect(r['v_poster.jpg']!.kind, SyncRowKind.draft);
      expect(r['m.png']!.kind, SyncRowKind.material);
      expect(r['m.png']!.materialCategory, MaterialCategory.pose);
      expect(r['m.png']!.pitName, isNull);
      expect(await db.syncRowInfos(const []), isEmpty);
    });

    test('已刪除、被移走而隱藏的不算；官方圖優先於其他格', () async {
      final pit = await db.createPit(name: '坑A');
      final groups = await db.select(db.officialGroups).get();
      await db.addOfficial(pit, groups.first.id, [NewImage(file: 'x.png')]);
      await db.addFanArts(pit, [NewImage(file: 'x.png')], author: 'a');
      expect(
        (await db.syncRowInfos(['x.png']))['x.png']!.kind,
        SyncRowKind.official,
      );
      await (db.update(db.officialImages))
          .write(OfficialImagesCompanion(deletedAt: Value(DateTime.now())));
      expect(
        (await db.syncRowInfos(['x.png']))['x.png']!.kind,
        SyncRowKind.fan,
      );
    });
  });
}
