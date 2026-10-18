import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/image_picker_field.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/common/dashed_box.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/media_source/drop_target_service.dart';
import 'package:huakeng/ui/media_source/drop_zone.dart';
import 'package:huakeng/ui/media_source/media_menu_anchor.dart';
import 'package:huakeng/ui/media_source/media_source_menu.dart';
import 'package:huakeng/ui/media_source/media_source_services.dart';
import 'package:huakeng/ui/media_source/pick_images_for.dart';
import 'package:image_picker/image_picker.dart';

class _FakeFiles implements FileSourceService {
  _FakeFiles(this.result, {this.fail = false});
  final List<XFile> result;
  final bool fail;
  int calls = 0;

  @override
  Future<List<XFile>> pick() async {
    calls++;
    if (fail) throw StateError('boom');
    return result;
  }
}

class _FakeCamera implements CameraSourceService {
  _FakeCamera({this.available = true, this.shot, this.fail = false});
  final bool available;
  final XFile? shot;
  final bool fail;
  int captures = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<XFile?> capture() async {
    captures++;
    if (fail) throw StateError('no permission');
    return shot;
  }
}

class _FakeClipboard implements ClipboardImageService {
  _FakeClipboard(this.state, {this.image});
  final ClipboardProbe state;
  final XFile? image;
  int reads = 0;

  @override
  Future<ClipboardProbe> probe() async => state;

  @override
  Future<XFile?> read(Directory dir) async {
    reads++;
    return image;
  }
}

/// 測試用的「加圖」入口：一個按鈕（包在加圖格錨點裡），按了走 [pickImagesFor]。
class _Host extends ConsumerStatefulWidget {
  const _Host({required this.onResult});
  final void Function(List<XFile>) onResult;

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: const Alignment(-0.6, -0.4),
      child: MediaMenuAnchorTarget(
        child: GestureDetector(
          key: const Key('host-add'),
          onTap: () async => widget.onResult(await pickImagesFor(context, ref)),
          child: const SizedBox(width: 84, height: 84, child: Text('加圖')),
        ),
      ),
    ),
  );
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

/// iPad 加圖來源選單（MediaMenu）、拖放接收（MediaDrop）。
/// 原生行為（相機、剪貼簿、檔案 App、真正的拖放）不在這裡驗證，全部用假服務。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    MediaMenuAnchor.clear();
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('ipadmedia');
    await Directory('${tmp.path}/images').create(recursive: true);
    await Directory('${tmp.path}/tmp').create(recursive: true);
    for (final n in ['a.png', 'b.png']) {
      File('${tmp.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    File('${tmp.path}/pick.png').writeAsBytesSync(_png1x1);
    pitId = await db.createPit(name: '測試坑');
  });
  tearDown(() async => db.close());

  void size(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w * 2, h * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          ...overrides,
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

  MediaSourceServices services({
    FileSourceService? files,
    CameraSourceService? camera,
    ClipboardImageService? clipboard,
  }) => MediaSourceServices(
    files: files ?? _FakeFiles(const []),
    camera: camera ?? _FakeCamera(),
    clipboard: clipboard ?? _FakeClipboard(ClipboardProbe.none),
    tempDir: () async => Directory('${tmp.path}/tmp'),
  );

  group('popover 位置', () {
    const screen = Size(1194, 834);
    const menu = Size(320, 360);

    test('預設放在加圖格右側，箭頭對齊格子中心', () {
      final p = computePopoverPlacement(
        anchor: const Rect.fromLTWH(300, 200, 84, 84),
        screen: screen,
        menu: menu,
      );
      expect(p.side, PopoverSide.right);
      expect(p.offset.dx, 300 + 84 + 12);
      expect(p.arrow, 242);
      expect(p.offset.dy + menu.height, lessThanOrEqualTo(screen.height - 16));
    });

    test('右邊放不下改左邊；左右都放不下改下方，再不行上方；沒有錨點置中', () {
      final left = computePopoverPlacement(
        anchor: const Rect.fromLTWH(1000, 200, 84, 84),
        screen: screen,
        menu: menu,
      );
      expect(left.side, PopoverSide.left);
      expect(left.offset.dx, 1000 - 12 - 320);

      const narrow = Size(400, 900);
      final below = computePopoverPlacement(
        anchor: const Rect.fromLTWH(160, 100, 84, 84),
        screen: narrow,
        menu: menu,
      );
      expect(below.side, PopoverSide.below);
      expect(below.offset.dx, greaterThanOrEqualTo(16));
      expect(below.offset.dx + 320, lessThanOrEqualTo(400 - 16));

      final above = computePopoverPlacement(
        anchor: const Rect.fromLTWH(160, 780, 84, 84),
        screen: narrow,
        menu: menu,
      );
      expect(above.side, PopoverSide.above);

      final none = computePopoverPlacement(
        anchor: null,
        screen: screen,
        menu: menu,
      );
      expect(none.side, PopoverSide.center);
    });
  });

  group('AddSourceOptions：依能力顯示項目', () {
    test('一律有 照片／檔案／素材庫', () {
      expect(const AddSourceOptions(camera: false).sources, [
        AddSource.photos,
        AddSource.files,
        AddSource.materials,
      ]);
    });
    test('有相機才有拍照；剪貼簿有圖或不確定才有貼上', () {
      expect(
        const AddSourceOptions(
          camera: true,
          clipboard: ClipboardProbe.image,
        ).sources,
        [
          AddSource.photos,
          AddSource.files,
          AddSource.materials,
          AddSource.camera,
          AddSource.paste,
        ],
      );
      expect(
        const AddSourceOptions(
          camera: false,
          clipboard: ClipboardProbe.unknown,
        ).sources.last,
        AddSource.paste,
      );
      expect(
        const AddSourceOptions(camera: true).sources,
        isNot(contains(AddSource.paste)),
      );
    });
  });

  group('加圖入口 pickImagesFor', () {
    testWidgets('手機（390 寬）：直接開選擇器，不出現選單', (tester) async {
      size(tester, 390, 844);
      var direct = 0;
      List<XFile>? got;
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          photoPickerProvider.overrideWithValue((_) async {
            direct++;
            return [XFile('${tmp.path}/pick.png')];
          }),
          mediaSourceServicesProvider.overrideWithValue(services()),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      expect(direct, 1);
      expect(got, hasLength(1));
      expect(find.byKey(const Key('media-source-photos')), findsNothing);
    });

    testWidgets('寬窗（834）：彈出五項選單，順序與文字照稿；點外面關閉回傳空', (tester) async {
      size(tester, 834, 1194);
      List<XFile>? got;
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(clipboard: _FakeClipboard(ClipboardProbe.image)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      for (final k in ['photos', 'files', 'materials', 'camera', 'paste']) {
        expect(find.byKey(Key('media-source-$k')), findsOneWidget, reason: k);
      }
      expect(find.text('從「照片」選取'), findsOneWidget);
      expect(find.text('從「檔案」選取'), findsOneWidget);
      expect(find.text('從素材庫選取'), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('貼上'), findsOneWidget);
      expect(find.text('剪貼簿有 1 張圖'), findsOneWidget);
      // 錨在加圖格右側，有箭頭，寬 320。
      final menu = tester.getRect(find.byType(MediaSourceMenu));
      final tile = tester.getRect(find.byKey(const Key('host-add')));
      expect(menu.width, 320);
      expect(menu.left, greaterThan(tile.right));
      expect(find.byKey(const Key('media-source-arrow')), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(got, isEmpty);
      expect(find.byType(MediaSourceMenu), findsNothing);
    });

    testWidgets('窄分屏（400 寬）仍是手機版：直接開選擇器', (tester) async {
      size(tester, 400, 900);
      var direct = 0;
      await pump(
        tester,
        _Host(onResult: (_) {}),
        overrides: [
          photoPickerProvider.overrideWithValue((_) async {
            direct++;
            return const [];
          }),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      expect(direct, 1);
    });

    testWidgets('沒有相機不顯示拍照；剪貼簿沒圖不顯示貼上；不確定（iOS）顯示貼上但沒有副標', (tester) async {
      size(tester, 834, 1194);
      await pump(
        tester,
        _Host(onResult: (_) {}),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(camera: _FakeCamera(available: false)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      expect(find.byKey(const Key('media-source-camera')), findsNothing);
      expect(find.byKey(const Key('media-source-paste')), findsNothing);
      expect(find.byKey(const Key('media-source-photos')), findsOneWidget);
    });

    testWidgets('剪貼簿不確定：有貼上、沒有「剪貼簿有 1 張圖」', (tester) async {
      size(tester, 834, 1194);
      await pump(
        tester,
        _Host(onResult: (_) {}),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(clipboard: _FakeClipboard(ClipboardProbe.unknown)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      expect(find.byKey(const Key('media-source-paste')), findsOneWidget);
      expect(find.text('剪貼簿有 1 張圖'), findsNothing);
    });

    testWidgets('照片：走原本的自家選擇器，保持它回傳的次序', (tester) async {
      size(tester, 834, 1194);
      List<XFile>? got;
      final order = [
        XFile('${tmp.path}/pick.png'),
        XFile('${tmp.path}/images/b.png'),
        XFile('${tmp.path}/images/a.png'),
      ];
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          photoPickerProvider.overrideWithValue((_) async => order),
          mediaSourceServicesProvider.overrideWithValue(services()),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-photos')));
      await settle(tester);
      expect(got!.map((f) => f.path), order.map((f) => f.path));
    });

    testWidgets('檔案：回傳檔案 App 選到的檔；失敗提示並回傳空', (tester) async {
      size(tester, 834, 1194);
      List<XFile>? got;
      final files = _FakeFiles([XFile('${tmp.path}/pick.png')]);
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(services(files: files)),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-files')));
      await settle(tester);
      expect(files.calls, 1);
      expect(got, hasLength(1));

      // 失敗
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(files: _FakeFiles(const [], fail: true)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-files')));
      await settle(tester);
      expect(got, isEmpty);
      expect(find.text('無法讀取所選檔案'), findsOneWidget);
    });

    testWidgets('拍照：回傳照片；被拒絕提示無法開啟相機', (tester) async {
      size(tester, 834, 1194);
      List<XFile>? got;
      final cam = _FakeCamera(shot: XFile('${tmp.path}/pick.png'));
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(services(camera: cam)),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-camera')));
      await settle(tester);
      expect(cam.captures, 1);
      expect(got, hasLength(1));

      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(camera: _FakeCamera(fail: true)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-camera')));
      await settle(tester);
      expect(got, isEmpty);
      expect(find.text('無法開啟相機'), findsOneWidget);
    });

    testWidgets('貼上：有圖回傳；實際沒圖（不確定時）提示剪貼簿裡沒有圖片', (tester) async {
      size(tester, 834, 1194);
      List<XFile>? got;
      final clip = _FakeClipboard(
        ClipboardProbe.image,
        image: XFile('${tmp.path}/pick.png'),
      );
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(clipboard: clip),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      expect(clip.reads, 0); // 打開選單不可以讀內容（iOS 會跳允許貼上）
      await tester.tap(find.byKey(const Key('media-source-paste')));
      await settle(tester);
      expect(clip.reads, 1);
      expect(got, hasLength(1));

      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [
          mediaSourceServicesProvider.overrideWithValue(
            services(clipboard: _FakeClipboard(ClipboardProbe.unknown)),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-paste')));
      await settle(tester);
      expect(got, isEmpty);
      expect(find.text('剪貼簿裡沒有圖片'), findsOneWidget);
    });

    testWidgets('素材庫：依點選次序複製成暫存檔，保留副檔名', (tester) async {
      size(tester, 834, 1194);
      await tester.runAsync(
        () => db.addMaterials(MaterialCategory.pose, [
          const NewImage(file: 'a.png', width: 1, height: 1),
          const NewImage(file: 'b.png', width: 1, height: 1),
        ]),
      );
      List<XFile>? got;
      await pump(
        tester,
        _Host(onResult: (r) => got = r),
        overrides: [mediaSourceServicesProvider.overrideWithValue(services())],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-materials')));
      await settle(tester);

      // 確認按鈕一開始停用
      FilledButton confirm() => tester.widget<FilledButton>(
        find.byKey(const Key('material-pick-confirm')),
      );
      expect(confirm().onPressed, isNull);

      final tiles = find.byWidgetPredicate(
        (w) =>
            w is GestureDetector &&
            w.key is ValueKey &&
            (w.key as ValueKey).value.toString().startsWith('material-pick-'),
      );
      expect(tiles, findsNWidgets(2));
      // 最新加入的 b.png（列表上排前面）先點，再點另一張。
      await tester.tap(tiles.at(1));
      await tester.pump();
      await tester.tap(tiles.at(0));
      await tester.pump();
      expect(find.text('加入 2 張'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('material-pick-confirm')));
      await settle(tester);

      expect(got, hasLength(2));
      expect(got!.every((f) => f.path.startsWith('${tmp.path}/tmp/')), isTrue);
      expect(got!.every((f) => f.path.endsWith('.png')), isTrue);
      expect(got!.every((f) => File(f.path).existsSync()), isTrue);
      expect(got![0].path, isNot(got![1].path));
      await unmount(tester);
    });

    testWidgets('素材庫是空的：顯示空狀態，無法加入', (tester) async {
      size(tester, 834, 1194);
      await pump(
        tester,
        _Host(onResult: (_) {}),
        overrides: [mediaSourceServicesProvider.overrideWithValue(services())],
      );
      await tester.tap(find.byKey(const Key('host-add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('media-source-materials')));
      await settle(tester);
      expect(find.byKey(const Key('material-pick-empty')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('material-pick-confirm')),
            )
            .onPressed,
        isNull,
      );
      await unmount(tester);
    });

    test('copyMaterialsToTemp：略過本機沒有的檔案', () async {
      final store = ImageStore(Directory('${tmp.path}/images'));
      await db.addMaterials(MaterialCategory.pose, [
        const NewImage(file: 'a.png'),
        const NewImage(file: 'missing.png'),
      ]);
      final rows = await db.watchMaterials().first;
      final out = await copyMaterialsToTemp(
        store,
        rows,
        Directory('${tmp.path}/tmp'),
      );
      expect(out, hasLength(1));
    });
  });

  group('官方圖冊表單的加圖格（整合）', () {
    testWidgets('寬窗：點新增官方圖的「＋」格彈出選單；選照片後圖片加進格子', (tester) async {
      size(tester, 834, 1194);
      await pump(
        tester,
        OfficialNewPage(pitId: pitId),
        overrides: [
          photoPickerProvider.overrideWithValue(
            (_) async => [XFile('${tmp.path}/pick.png')],
          ),
          mediaSourceServicesProvider.overrideWithValue(services()),
          dropTargetServiceProvider.overrideWithValue(
            FakeDropTargetService(supported: false),
          ),
        ],
      );
      await tester.tap(find.byType(DashedBox).first);
      await settle(tester);
      expect(find.byType(MediaSourceMenu), findsOneWidget);
      // 錨在「＋」格旁（有箭頭）。
      expect(find.byKey(const Key('media-source-arrow')), findsOneWidget);
      await tester.tap(find.byKey(const Key('media-source-photos')));
      await settle(tester);
      expect(find.byType(ImageItemThumb), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('手機：點「＋」格直接開選擇器，沒有選單', (tester) async {
      size(tester, 390, 844);
      var direct = 0;
      await pump(
        tester,
        OfficialNewPage(pitId: pitId),
        overrides: [
          photoPickerProvider.overrideWithValue((_) async {
            direct++;
            return const [];
          }),
          dropTargetServiceProvider.overrideWithValue(
            FakeDropTargetService(supported: false),
          ),
        ],
      );
      await tester.tap(find.byType(DashedBox).first);
      await settle(tester);
      expect(direct, 1);
      expect(find.byType(MediaSourceMenu), findsNothing);
      await unmount(tester);
    });
  });

  group('DropZone', () {
    DropItem item(String id, {Future<XFile?> Function()? load}) => DropItem(
      id: id,
      load: load ?? () async => XFile('${tmp.path}/pick.png'),
    );

    Future<FakeDropTargetService> pumpZone(
      WidgetTester tester, {
      required List<List<XFile>> received,
      bool supported = true,
    }) async {
      size(tester, 834, 1194);
      final fake = FakeDropTargetService(supported: supported);
      await pump(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              height: 400,
              child: DropZone(
                title: '放開即可加入「官方圖冊」',
                subtitleFor: (n) => '$n 張 · 放開後選擇分組',
                onFiles: received.add,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
        overrides: [dropTargetServiceProvider.overrideWithValue(fake)],
      );
      return fake;
    }

    testWidgets('拖進範圍顯示提示條與張數；移出或離開就消失', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      expect(find.byKey(const Key('drop-banner')), findsNothing);

      fake.enter(3, const Offset(100, 100));
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsOneWidget);
      expect(find.text('放開即可加入「官方圖冊」'), findsOneWidget);
      expect(find.text('3 張 · 放開後選擇分組'), findsOneWidget);

      fake.move(const Offset(700, 700)); // 範圍外
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsNothing);

      fake.move(const Offset(50, 50));
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsOneWidget);

      fake.leave();
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsNothing);
      expect(received, isEmpty);
    });

    testWidgets('放開：逐項載入，顯示 n／N，全部完成後依序交給 onFiles', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      final c1 = Completer<XFile?>();
      final c2 = Completer<XFile?>();
      fake.enter(2, const Offset(10, 10));
      fake.drop([
        item('a', load: () => c1.future),
        item('b', load: () => c2.future),
      ], const Offset(10, 10));
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsNothing);
      expect(find.text('正在載入 0／2 張'), findsOneWidget);

      c2.complete(XFile('${tmp.path}/images/b.png')); // 後面的先好
      await tester.pump();
      await tester.pump();
      expect(find.text('正在載入 1／2 張'), findsOneWidget);
      expect(received, isEmpty);

      c1.complete(XFile('${tmp.path}/images/a.png'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('drop-loading')), findsNothing);
      expect(received, hasLength(1));
      // 順序是放開時的順序，不是載入完成的順序。
      expect(received.single.map((f) => f.name), ['a.png', 'b.png']);
    });

    testWidgets('單項載入失敗（iCloud 下載不到）：其餘照常加入，提示 N 張無法載入', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      fake.drop([
        item('a'),
        item('b', load: () async => throw StateError('icloud')),
        item('c', load: () async => null),
      ], const Offset(10, 10));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(received, hasLength(1));
      expect(received.single, hasLength(1));
      expect(find.text('2 張無法載入'), findsOneWidget);
    });

    testWidgets('全部失敗：不呼叫 onFiles', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      fake.drop([item('a', load: () async => null)], const Offset(10, 10));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(received, isEmpty);
      expect(find.text('1 張無法載入'), findsOneWidget);
    });

    testWidgets('放在範圍外：忽略', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      fake.drop([item('a')], const Offset(900, 900));
      await tester.pump();
      await tester.pump();
      expect(received, isEmpty);
      expect(find.byKey(const Key('drop-loading')), findsNothing);
    });

    testWidgets('平台不支援：不訂閱事件，什麼都不顯示', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received, supported: false);
      expect(fake.startCalls, 1);
      fake.enter(1, const Offset(10, 10));
      await tester.pump();
      expect(find.byKey(const Key('drop-banner')), findsNothing);
    });

    testWidgets('上面壓著別的頁面時，下面的落點不回應', (tester) async {
      final received = <List<XFile>>[];
      final fake = await pumpZone(tester, received: received);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())),
      );
      await settle(tester);
      fake.enter(1, const Offset(10, 10));
      fake.drop([item('a')], const Offset(10, 10));
      await tester.pump();
      await tester.pump();
      expect(received, isEmpty);
    });
  });

  group('ChannelDropTargetService（Dart 側契約）', () {
    const name = 'test/media_drop';
    late MethodChannel channel;

    setUp(() => channel = const MethodChannel(name));

    test('沒有原生實作＝不支援', () async {
      final s = ChannelDropTargetService(channel: channel);
      expect(await s.start(), isFalse);
    });

    test('原生送來的事件轉成 DropEvent；load 轉成檔案', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'start') return true;
            if (call.method == 'load') {
              return '/tmp/${call.arguments['id']}.jpg';
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final s = ChannelDropTargetService(channel: channel);
      expect(await s.start(), isTrue);
      final events = <DropEvent>[];
      s.events.listen(events.add);

      Future<void> fromNative(String method, Object? args) async {
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall(method, args),
              ),
              (_) {},
            );
      }

      await fromNative('enter', {'count': 2, 'x': 10.0, 'y': 20.0});
      await fromNative('move', {'x': 11.0, 'y': 21.0});
      await fromNative('drop', {
        'x': 12.0,
        'y': 22.0,
        'items': [
          {'id': 'p1', 'name': 'IMG_1.HEIC'},
          {'id': 'p2'},
        ],
      });
      await fromNative('leave', {});
      await Future<void>.delayed(Duration.zero);

      expect(events[0], isA<DropEnter>());
      expect((events[0] as DropEnter).count, 2);
      expect((events[1] as DropMove).position, const Offset(11, 21));
      final drop = events[2] as DropPerform;
      expect(drop.items.map((i) => i.id), ['p1', 'p2']);
      expect(drop.items.first.name, 'IMG_1.HEIC');
      expect((await drop.items.first.load())!.path, '/tmp/p1.jpg');
      expect(events[3], isA<DropLeave>());
    });
  });

  group('官方圖冊的落點', () {
    testWidgets('新增官方圖：支援拖放時顯示提示文字；不支援時不顯示', (tester) async {
      size(tester, 834, 1194);
      await pump(
        tester,
        OfficialNewPage(pitId: pitId),
        overrides: [
          dropTargetServiceProvider.overrideWithValue(FakeDropTargetService()),
        ],
      );
      expect(find.text('分屏時可直接從「照片」或「檔案」拖曳圖片至此'), findsOneWidget);

      await pump(
        tester,
        OfficialNewPage(pitId: pitId),
        overrides: [
          dropTargetServiceProvider.overrideWithValue(
            FakeDropTargetService(supported: false),
          ),
        ],
      );
      expect(find.text('分屏時可直接從「照片」或「檔案」拖曳圖片至此'), findsNothing);
      await unmount(tester);
    });

    testWidgets('新增官方圖：拖放進來的圖加到圖片格', (tester) async {
      size(tester, 834, 1194);
      final fake = FakeDropTargetService();
      await pump(
        tester,
        OfficialNewPage(pitId: pitId),
        overrides: [dropTargetServiceProvider.overrideWithValue(fake)],
      );
      expect(find.byType(ImageItemThumb), findsNothing);
      fake.enter(2, const Offset(300, 300));
      await tester.pump();
      expect(find.text('放開即可加入「官方圖冊」'), findsOneWidget);
      expect(find.text('2 張'), findsOneWidget);
      fake.drop([
        DropItem(id: '1', load: () async => XFile('${tmp.path}/pick.png')),
        DropItem(id: '2', load: () async => XFile('${tmp.path}/images/a.png')),
      ], const Offset(300, 300));
      await settle(tester);
      expect(find.byType(ImageItemThumb), findsNWidgets(2));
      await unmount(tester);
    });

    testWidgets('官方圖冊列表：提示條寫明張數與「放開後選擇分組」；放開後進入選分組的新增頁', (tester) async {
      size(tester, 834, 1194);
      final fake = FakeDropTargetService();
      await pump(
        tester,
        OfficialListPage(pitId: pitId),
        overrides: [dropTargetServiceProvider.overrideWithValue(fake)],
      );
      fake.enter(3, const Offset(400, 600));
      await tester.pump();
      expect(find.text('放開即可加入「官方圖冊」'), findsOneWidget);
      expect(find.text('3 張 · 放開後選擇分組'), findsOneWidget);

      fake.drop([
        DropItem(id: '1', load: () async => XFile('${tmp.path}/pick.png')),
      ], const Offset(400, 600));
      await settle(tester, rounds: 10);
      expect(find.byType(OfficialNewPage), findsOneWidget);
      expect(find.byType(ImageItemThumb), findsOneWidget);
      // 新增頁本身就是選分組那一步。
      expect(find.text('加入官方圖冊'), findsOneWidget);
      await unmount(tester);
    });
  });
}
