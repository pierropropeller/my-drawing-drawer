import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/media/gallery_repository.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/picker/image_picker_sheet.dart';
import 'package:huakeng/ui/picker/picker_controller.dart';
import 'package:image_picker/image_picker.dart';

/// 假相簿：不需要外掛。
class FakeGallery extends GalleryRepository {
  FakeGallery({
    this.perm = GalleryPermission.granted,
    List<GalleryAlbum>? albums,
    Map<String, List<GalleryItem>>? items,
  }) : _albums = albums ?? const [],
       _items = items ?? const {};

  GalleryPermission perm;
  final List<GalleryAlbum> _albums;
  final Map<String, List<GalleryItem>> _items;
  int manageCalls = 0;
  int settingsCalls = 0;
  int requestCalls = 0;
  final List<String> exported = [];

  @override
  Future<GalleryPermission> permission() async => perm;

  @override
  Future<GalleryPermission> requestPermission() async {
    requestCalls++;
    return perm;
  }

  @override
  Future<List<GalleryAlbum>> albums({required bool imagesOnly}) async =>
      _albums;

  @override
  Future<List<GalleryItem>> items(
    String albumId, {
    required int start,
    required int end,
    required bool imagesOnly,
  }) async {
    final all = (_items[albumId] ?? const <GalleryItem>[])
        .where((e) => !imagesOnly || !e.isVideo)
        .toList();
    return all.sublist(start.clamp(0, all.length), end.clamp(0, all.length));
  }

  @override
  Future<Uint8List?> thumbnail(String itemId, int size) async => null;

  @override
  Future<XFile?> export(String itemId) async {
    exported.add(itemId);
    return XFile('/fake/$itemId.jpg');
  }

  @override
  Future<void> manageLimited() async => manageCalls++;

  @override
  Future<void> openSettings() async => settingsCalls++;
}

final _now = DateTime(2026, 10, 16, 12);

GalleryItem _item(
  String id,
  DateTime t, {
  GalleryItemType type = GalleryItemType.image,
  int? ms,
}) => GalleryItem(id: id, createdAt: t, type: type, durationMs: ms);

/// 今天 4 張（t1..t4）、昨天 3 張（y1..y3，y2 是影片、y3 是 GIF）、
/// 10 月 12 日 2 張（o1、o2）、去年 3 月 8 日 2 張（p1、p2）。
FakeGallery _gallery({GalleryPermission perm = GalleryPermission.granted}) {
  final all = <GalleryItem>[
    for (var i = 1; i <= 4; i++) _item('t$i', DateTime(2026, 10, 16, 12 - i)),
    _item('y1', DateTime(2026, 10, 15, 20)),
    _item(
      'y2',
      DateTime(2026, 10, 15, 19),
      type: GalleryItemType.video,
      ms: 18000,
    ),
    _item('y3', DateTime(2026, 10, 15, 18), type: GalleryItemType.gif),
    _item('o1', DateTime(2026, 10, 12, 9)),
    _item('o2', DateTime(2026, 10, 12, 8)),
    _item('p1', DateTime(2025, 3, 8, 9)),
    _item('p2', DateTime(2025, 3, 8, 8)),
  ];
  return FakeGallery(
    perm: perm,
    albums: [
      GalleryAlbum(
        id: 'dl',
        name: 'Download',
        count: 2,
        kind: GalleryAlbumKind.other,
      ),
      GalleryAlbum(id: 'x', name: 'X', count: 5, kind: GalleryAlbumKind.other),
      GalleryAlbum(
        id: 'cam',
        name: 'Camera',
        count: 4,
        kind: GalleryAlbumKind.camera,
      ),
      GalleryAlbum(
        id: 'all',
        name: 'Recent',
        count: all.length,
        kind: GalleryAlbumKind.all,
      ),
      GalleryAlbum(
        id: 'shot',
        name: 'Screenshots',
        count: 3,
        kind: GalleryAlbumKind.screenshot,
      ),
    ],
    items: {
      'all': all,
      'shot': all.where((e) => ['t1', 't2', 'y1'].contains(e.id)).toList(),
      'cam': all.where((e) => e.id.startsWith('o')).toList(),
      'x': all.where((e) => e.id.startsWith('t') || e.id == 'p1').toList(),
      'dl': all.where((e) => e.id.startsWith('p')).toList(),
    },
  );
}

Widget _app(Widget home) => MaterialApp(
  theme: buildTheme(Brightness.light, useGoogleFonts: false),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: home,
);

Future<void> _settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms / 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<FakeGallery> open(
    WidgetTester tester, {
    FakeGallery? repo,
    bool single = false,
    bool imagesOnly = false,
  }) async {
    phone(tester);
    final g = repo ?? _gallery();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ImagePickerSheet(
            repository: g,
            single: single,
            imagesOnly: imagesOnly,
            now: () => _now,
          ),
        ),
      ),
    );
    await _settle(tester);
    return g;
  }

  Finder cell(String id) => find.byKey(ValueKey('picker-cell-$id'));
  Finder circleText(String id, String n) => find.descendant(
    of: find.byKey(ValueKey('picker-circle-$id')),
    matching: find.text(n),
  );
  final bar = find.byKey(const ValueKey('picker-bottom-bar'));

  testWidgets('半開：小橫杆、沒有 ×、日期標題、pills 排序、沒有底部', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('picker-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-close')), findsNothing);
    expect(find.text('選擇圖片'), findsOneWidget);
    expect(find.textContaining('今天 · 10月16日 週五'), findsWidgets);
    expect(find.textContaining('4 張'), findsWidgets);
    expect(bar, findsNothing);
    // pills：全部、截圖、相機，其餘按張數多到少（X 5、Download 2）。
    final pills = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w.key.toString().contains('picker-pill-'),
            ),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(pills, ['全部', '截圖', '相機', 'X', 'Download']);
  });

  testWidgets('日期標題：昨天、今年、跨年', (tester) async {
    await open(tester);
    await tester.drag(cell('t1'), const Offset(0, -300));
    await _settle(tester);
    expect(find.textContaining('昨天 · 10月15日 週四'), findsWidgets);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    expect(l.pickerDate(10, 12, '週一'), '10月12日 週一');
    expect(l.pickerDateWithYear(2025, 3, 8, '週六'), '2025年3月8日 週六');
  });

  testWidgets('編號：依撳的次序、取消中間的後面往前補', (tester) async {
    await open(tester);
    await tester.tap(cell('t3'));
    await _settle(tester);
    await tester.tap(cell('t1'));
    await tester.tap(cell('t4'));
    await _settle(tester);
    expect(circleText('t3', '1'), findsOneWidget);
    expect(circleText('t1', '2'), findsOneWidget);
    expect(circleText('t4', '3'), findsOneWidget);
    expect(find.text('下一步（3）'), findsOneWidget);
    // 取消 t1：t4 補成 2。
    await tester.tap(cell('t1'));
    await _settle(tester);
    expect(circleText('t3', '1'), findsOneWidget);
    expect(circleText('t4', '2'), findsOneWidget);
    expect(circleText('t1', '2'), findsNothing);
    expect(find.text('下一步（2）'), findsOneWidget);
  });

  testWidgets('底部列：選第一張才出現、全部取消後消失；撳小圖取消', (tester) async {
    await open(tester);
    expect(bar, findsNothing);
    await tester.tap(cell('t1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(bar, findsOneWidget); // 滑上來中
    await _settle(tester);
    expect(find.byKey(const ValueKey('picker-bar-thumb-t1')), findsOneWidget);
    await tester.tap(cell('t2'));
    await _settle(tester);
    // 撳底部小圖＝取消那張。
    await tester.tap(find.byKey(const ValueKey('picker-bar-thumb-t1')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('picker-bar-thumb-t1')), findsNothing);
    expect(circleText('t2', '1'), findsOneWidget);
    await tester.tap(cell('t2'));
    await _settle(tester);
    expect(bar, findsNothing);
    expect(find.textContaining('下一步'), findsNothing);
  });

  testWidgets('整天選取：按畫面順序接在後面；再撳取消當天全部', (tester) async {
    await open(tester);
    await tester.tap(cell('t3')); // 先選今天的第 3 張
    await _settle(tester);
    final dayBtn = find.byKey(
      ValueKey('picker-day-select-${DateTime(2026, 10, 16).toIso8601String()}'),
    );
    await tester.tap(dayBtn.last);
    await _settle(tester);
    // 今天其餘依畫面順序接在 t3 後面：t3=1，t1=2，t2=3，t4=4。
    expect(circleText('t3', '1'), findsOneWidget);
    expect(circleText('t1', '2'), findsOneWidget);
    expect(circleText('t2', '3'), findsOneWidget);
    expect(circleText('t4', '4'), findsOneWidget);
    expect(find.text('下一步（4）'), findsOneWidget);
    // 全選後變實心勾，再撳＝取消當天全部。
    await tester.tap(dayBtn.last);
    await _settle(tester);
    expect(bar, findsNothing);
  });

  testWidgets('半開往上拉：彈到全螢幕（× 出現、小橫杆消失）', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('picker-close')), findsNothing);
    await tester.fling(cell('t2'), const Offset(0, -400), 1500);
    await _settle(tester, 1000);
    expect(find.byKey(const ValueKey('picker-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-handle')), findsNothing);
  });

  testWidgets('全螢幕列表在最頂再往下拉：縮回半開；半開再往下拉標題列＝關閉', (tester) async {
    phone(tester);
    final g = _gallery();
    List<XFile>? result = [XFile('/x')];
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showAppImagePicker(
                    context,
                    repository: g,
                    now: () => _now,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester, 1000);
    await tester.fling(cell('t2'), const Offset(0, -400), 1500);
    await _settle(tester, 1000);
    expect(find.byKey(const ValueKey('picker-close')), findsOneWidget);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 160),
      600,
    );
    await _settle(tester, 1000);
    expect(find.byKey(const ValueKey('picker-handle')), findsOneWidget);
    expect(find.byKey(const ValueKey('picker-close')), findsNothing);
    // 半開時往下拉標題列：關閉。
    await tester.fling(
      find.byKey(const ValueKey('picker-handle')),
      const Offset(0, 500),
      1500,
      warnIfMissed: false, // 把手本身不吃點擊，事件由外層標題列的拖曳接走
    );
    await _settle(tester, 1000);
    expect(find.byKey(const ValueKey('picker-handle')), findsNothing);
    expect(result, isNull);
  });

  testWidgets('pills 篩選：切到截圖只剩 3 張', (tester) async {
    await open(tester);
    expect(cell('o1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('picker-pill-shot')));
    await _settle(tester);
    expect(cell('t1'), findsOneWidget);
    expect(cell('t2'), findsOneWidget);
    expect(cell('y1'), findsOneWidget);
    expect(cell('o1'), findsNothing);
    expect(cell('t3'), findsNothing);
  });

  testWidgets('已選的在切換 pills 後仍保留', (tester) async {
    await open(tester);
    await tester.tap(cell('t3'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('picker-pill-cam')));
    await _settle(tester);
    expect(find.text('下一步（1）'), findsOneWidget);
    await tester.tap(cell('o1'));
    await _settle(tester);
    expect(circleText('o1', '2'), findsOneWidget);
  });

  testWidgets('影片／GIF 標記', (tester) async {
    await open(tester);
    await tester.drag(cell('t1'), const Offset(0, -300));
    await _settle(tester);
    expect(find.byKey(const ValueKey('badgeVideo')), findsOneWidget);
    expect(find.text('0:18'), findsOneWidget);
    expect(find.byKey(const ValueKey('badgeGif')), findsOneWidget);
  });

  testWidgets('拒絕權限：整頁說明＋去設定', (tester) async {
    final g = await open(
      tester,
      repo: _gallery(perm: GalleryPermission.denied),
    );
    expect(find.byKey(const ValueKey('picker-denied')), findsOneWidget);
    expect(cell('t1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('picker-open-settings')));
    expect(g.settingsCalls, 1);
  });

  testWidgets('部分權限：頂部提示＋管理權限', (tester) async {
    final g = await open(
      tester,
      repo: _gallery(perm: GalleryPermission.limited),
    );
    expect(find.byKey(const ValueKey('picker-limited-banner')), findsOneWidget);
    expect(find.text('只開放了部分相片'), findsOneWidget);
    expect(cell('t1'), findsOneWidget); // 仍列出可讀的相片
    await tester.tap(find.byKey(const ValueKey('picker-manage')));
    await _settle(tester);
    expect(g.manageCalls, 1);
  });

  testWidgets('單選＋只要圖片：撳另一張取代、沒有整天選取、不列影片', (tester) async {
    await open(tester, single: true, imagesOnly: true);
    expect(
      find.byKey(
        ValueKey(
          'picker-day-select-${DateTime(2026, 10, 16).toIso8601String()}',
        ),
      ),
      findsNothing,
    );
    await tester.tap(cell('t1'));
    await tester.tap(cell('t2'));
    await _settle(tester);
    expect(circleText('t2', '1'), findsOneWidget);
    expect(find.text('下一步（1）'), findsOneWidget);
    await tester.drag(cell('t1'), const Offset(0, -300));
    await _settle(tester);
    expect(cell('y2'), findsNothing); // 影片
  });

  testWidgets('長按拖曳連選：順序＝拖過的先後（往後、往前都對）', (tester) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(cell('t1')));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(tester.getCenter(cell('t3')));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await _settle(tester);
    expect(circleText('t1', '1'), findsOneWidget);
    expect(circleText('t2', '2'), findsOneWidget);
    expect(circleText('t3', '3'), findsOneWidget);
    // 反方向：從 t4 往 t3 拖（t3 本來就選了，所以 t4 起點是選取、拖到 t3 不改變）。
    final h = await tester.startGesture(tester.getCenter(cell('t4')));
    await tester.pump(const Duration(milliseconds: 700));
    await h.up();
    await _settle(tester);
    expect(circleText('t4', '4'), findsOneWidget);
  });

  testWidgets('下一步：按編號順序回傳檔案；✕ 回傳 null', (tester) async {
    phone(tester);
    final g = _gallery();
    List<XFile>? result;
    var done = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showAppImagePicker(
                    context,
                    repository: g,
                    now: () => _now,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester, 1000);
    await tester.tap(cell('t3'));
    await tester.tap(cell('t1'));
    await tester.tap(cell('t2'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('picker-next')));
    await _settle(tester, 1000);
    expect(done, isTrue);
    expect(result!.map((f) => f.path), [
      '/fake/t3.jpg',
      '/fake/t1.jpg',
      '/fake/t2.jpg',
    ]);

    // 再開一次，撳外面的暗位＝關閉，回傳 null。
    done = false;
    await tester.tap(find.text('open'));
    await _settle(tester, 1000);
    await tester.tapAt(const Offset(180, 40));
    await _settle(tester, 1000);
    expect(done, isTrue);
    expect(result, isNull);
  });

  testWidgets('快速捲動：拖動顯示月份泡泡，放手才跳過去', (tester) async {
    phone(tester);
    final items = <GalleryItem>[
      for (var d = 0; d < 120; d++)
        for (var k = 0; k < 4; k++)
          _item(
            'i${d}_$k',
            DateTime(2026, 10, 16).subtract(Duration(days: d, hours: k)),
          ),
    ];
    final g = FakeGallery(
      albums: [
        GalleryAlbum(
          id: 'all',
          name: 'Recent',
          count: items.length,
          kind: GalleryAlbumKind.all,
        ),
      ],
      items: {'all': items},
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ImagePickerSheet(repository: g, now: () => _now),
        ),
      ),
    );
    await _settle(tester, 1000);
    final scroller = find.byKey(const ValueKey('picker-fast-scroll'));
    expect(scroller, findsOneWidget);
    final box = tester.getRect(scroller);
    final gesture = await tester.startGesture(
      Offset(box.center.dx, box.top + 20),
    );
    await gesture.moveTo(Offset(box.center.dx, box.center.dy));
    await tester.pump();
    expect(find.byKey(const ValueKey('picker-scrub-bubble')), findsOneWidget);
    final bubble = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('picker-scrub-bubble')),
        matching: find.byType(Text),
      ),
    );
    expect(bubble.data, matches(RegExp(r'^\d{4} 年 \d{1,2} 月$')));
    // 放手前沒有跳。
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.pixels, 0);
    await gesture.up();
    await _settle(tester);
    expect(scrollable.position.pixels, greaterThan(100));
    expect(find.byKey(const ValueKey('picker-scrub-bubble')), findsNothing);
  });

  test('控制器：整天選取與拖曳順序（純邏輯）', () async {
    final g = _gallery();
    final c = PickerController(g, now: () => _now);
    await c.init();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.albums.map((a) => a.id), ['all', 'shot', 'cam', 'x', 'dl']);
    expect(c.days.length, 4);
    expect(c.days.first.items.length, 4);
    c.toggle('t2');
    c.applyDrag({0, 1, 2}, false); // 從 t1 往下拖到 t3，t2 已選
    c.applyDrag({0, 1, 2}, true);
    expect(c.selected, ['t2', 't1', 't3']);
    c.toggleDay(c.days[1]);
    expect(c.selected.sublist(3), ['y1', 'y2', 'y3']);
    expect(c.isDayFull(c.days[1]), isTrue);
    c.toggleDay(c.days[1]);
    expect(c.selected, ['t2', 't1', 't3']);
    final files = await c.exportSelected();
    expect(files.map((f) => f.path), [
      '/fake/t2.jpg',
      '/fake/t1.jpg',
      '/fake/t3.jpg',
    ]);
    c.dispose();
  });
}
