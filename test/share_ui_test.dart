import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/share/share_host.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假的 channel：不碰原生，測試用 [push] 模擬熱啟動時新的分享。
class FakeShareChannel extends ShareChannel {
  FakeShareChannel({this.initial = const []});
  final List<String> initial;
  void Function(List<String>)? onShare;
  int backCalls = 0;

  @override
  Future<List<String>> getInitialShare() async => initial;

  @override
  void setOnShare(void Function(List<String> paths)? cb) => onShare = cb;

  @override
  Future<void> moveTaskToBack() async => backCalls++;

  void push(List<String> paths) => onShare!(paths);
}

/// 分享進來的「加入到」sheet（D-053）。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitA;
  late String pitB;
  late FakeShareChannel channel;

  setUp(() async {
    navBarHiddenCount.value = 0;
    shareBackDelay = Duration.zero;
    SharedPreferences.setMockInitialValues({'onboarded': true});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('share_ui');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitA = await db.createPit(name: '坑A');
    pitB = await db.createPit(name: '坑B');
  });

  List<String> sharedFiles(int n) {
    return [
      for (var i = 0; i < n; i++)
        (File('${tmp.path}/in$i.png')..writeAsBytesSync(_png1x1)).path,
    ];
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 匯入圖片要靠真實的 async（解碼尺寸），每張圖要多輪 runAsync＋pump。
  Future<void> settleLong(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester, FakeShareChannel ch) async {
    channel = ch;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final List<Override> overrides = [
      databaseProvider.overrideWithValue(db),
      imageStoreProvider.overrideWith(
        (ref) async => ImageStore(Directory('${tmp.path}/images')),
      ),
      shareChannelProvider.overrideWithValue(ch),
      sharedPrefsProvider.overrideWithValue(prefs),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(ShareSheet), matching: f);

  Future<void> tapIn(WidgetTester tester, String text) async {
    await tester.tap(inSheet(find.text(text)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('冷啟動：顯示縮圖與張數，預設官方圖冊，「加入」存進該坑選的分組', (tester) async {
    final files = sharedFiles(3);
    await pumpApp(tester, FakeShareChannel(initial: files));

    expect(find.byType(ShareSheet), findsOneWidget);
    expect(inSheet(find.text('加入到')), findsOneWidget);
    expect(inSheet(find.text('3 張')), findsOneWidget);
    expect(find.byKey(const ValueKey('shareThumb0')), findsOneWidget);
    expect(find.byKey(const ValueKey('shareThumb2')), findsOneWidget);
    // 坑 chips ＋「開新坑」，位置格（雜物沒開啟時隱藏）。
    expect(inSheet(find.text('坑A')), findsOneWidget);
    expect(inSheet(find.text('開新坑')), findsOneWidget);
    expect(inSheet(find.text('官方圖冊')), findsOneWidget);
    expect(inSheet(find.text('好看同人圖')), findsOneWidget);
    expect(inSheet(find.text('草稿')), findsOneWidget);
    expect(inSheet(find.text('腦洞')), findsOneWidget);
    expect(inSheet(find.text('成圖')), findsOneWidget);
    // 官方圖冊選中時展開分組。
    expect(inSheet(find.text('分組')), findsOneWidget);
    expect(inSheet(find.text('設定圖')), findsOneWidget);

    await tapIn(tester, '素材');
    await tapIn(tester, '加入');
    await settleLong(tester);

    final rows = (await tester.runAsync(
      () => db.select(db.officialImages).get(),
    ))!;
    expect(rows.length, 3);
    final groups = (await tester.runAsync(
      () => db.select(db.officialGroups).get(),
    ))!;
    final material = groups.firstWhere(
      (g) => g.name == '素材' && g.pitId == pitA,
    );
    expect(
      rows.every((r) => r.pitId == pitA && r.groupId == material.id),
      isTrue,
    );
    // 檔案已複製進 App 儲存空間，暫存檔已清掉。
    expect(Directory('${tmp.path}/images').listSync().length, 3);
    expect(File(files.first).existsSync(), isFalse);
    // 顯示「已加入」並回到原本的 App。
    expect(find.text('已加入'), findsOneWidget);
    expect(channel.backCalls, 1);
    expect(find.byType(ShareSheet), findsNothing);
    await unmount(tester);
  });

  testWidgets('熱啟動：App 已在執行時收到新的分享', (tester) async {
    await pumpApp(tester, FakeShareChannel());
    expect(find.byType(ShareSheet), findsNothing);

    channel.push(sharedFiles(1));
    await settle(tester);
    expect(find.byType(ShareSheet), findsOneWidget);
    expect(inSheet(find.text('1 張')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('好看同人圖：作者留空、沒有出處', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
    await tapIn(tester, '坑B');
    await tapIn(tester, '好看同人圖');
    // 同人圖沒有分組 chips。
    expect(inSheet(find.text('分組')), findsNothing);
    await tapIn(tester, '加入');
    await settleLong(tester);

    final rows = (await tester.runAsync(() => db.select(db.fanArts).get()))!;
    expect(rows.length, 2);
    expect(
      rows.every((r) => r.pitId == pitB && r.author == '' && r.groupId == null),
      isTrue,
    );
    expect(find.text('已加入'), findsOneWidget);
    expect(channel.backCalls, 1);
    await unmount(tester);
  });

  for (final c in [
    ('草稿', DraftFormPage),
    ('腦洞', IdeaFormPage),
    ('成圖', PieceFormPage),
  ]) {
    testWidgets('「下一步」：${c.$1} 打開新增表單並預先放好圖片', (tester) async {
      await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
      await tapIn(tester, '坑B');
      await tapIn(tester, c.$1);
      expect(inSheet(find.text('下一步')), findsOneWidget);
      await tapIn(tester, '下一步');
      await settle(tester);

      expect(find.byType(ShareSheet), findsNothing);
      final page = tester.widget(find.byType(c.$2));
      final images = switch (page) {
        DraftFormPage p => (p.pitId, p.initialImages.length),
        IdeaFormPage p => (p.pitId, p.initialImages.length),
        PieceFormPage p => (p.pitId, p.initialImages.length),
        _ => throw StateError('unexpected'),
      };
      expect(images, (pitB, 2));
      // 還沒儲存，也不會回到原本的 App。
      expect(channel.backCalls, 0);
      expect(
        (await tester.runAsync(() => db.select(db.officialImages).get()))!,
        isEmpty,
      );
      await unmount(tester);
    });
  }

  testWidgets('記住上次用的坑和位置，下次預選', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(1)));
    await tapIn(tester, '坑B');
    await tapIn(tester, '腦洞');
    await tapIn(tester, '下一步');
    await settle(tester);
    expect(
      (await SharedPreferences.getInstance()).getString('shareLastPit'),
      pitB,
    );

    // 再分享一次：預選坑B＋腦洞（按鈕是「下一步」，沒有分組 chips）。
    channel.push(sharedFiles(1));
    await settle(tester);
    expect(inSheet(find.text('下一步')), findsOneWidget);
    expect(inSheet(find.text('分組')), findsNothing);
    await tapIn(tester, '下一步');
    await settle(tester);
    expect(
      tester.widget<IdeaFormPage>(find.byType(IdeaFormPage).last).pitId,
      pitB,
    );
    await unmount(tester);
  });

  testWidgets('雜物：坑沒開啟時隱藏；開啟後可加入；換到沒開啟的坑退回官方圖冊', (tester) async {
    await db.updatePit(pitA, name: '坑A', archived: false, junkEnabled: true);
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
    // 坑A 開啟雜物：有第六格。
    expect(inSheet(find.text('雜物')), findsOneWidget);
    // 切到沒開啟的坑B：雜物消失。
    await tapIn(tester, '坑B');
    expect(inSheet(find.text('雜物')), findsNothing);
    await tapIn(tester, '坑A');
    await tapIn(tester, '雜物');
    expect(inSheet(find.text('分組')), findsNothing);
    await tapIn(tester, '加入');
    await settleLong(tester);
    final junk = (await tester.runAsync(() => db.select(db.junkImages).get()))!;
    expect(junk.length, 2);
    expect(junk.every((j) => j.pitId == pitA), isTrue);

    // 上次是 坑A＋雜物；切到坑B 時退回官方圖冊。
    channel.push(sharedFiles(1));
    await settle(tester);
    expect(inSheet(find.text('雜物')), findsOneWidget);
    await tapIn(tester, '坑B');
    expect(inSheet(find.text('分組')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('開新坑：回來後選中新坑並保留位置', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(1)));
    await tapIn(tester, '好看同人圖');
    await tapIn(tester, '開新坑');
    await settle(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(find.byType(PitNewPage), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '新坑');
    await tester.tap(find.text(l10nStatic.pitsCreate));
    await settle(tester);
    expect(find.byType(PitNewPage), findsNothing);
    expect(find.byType(ShareSheet), findsOneWidget);

    await tapIn(tester, '加入');
    await settleLong(tester);
    final newPit = ((await tester.runAsync(() => db.select(db.pits).get()))!)
        .firstWhere((p) => p.name == '新坑');
    final rows = (await tester.runAsync(() => db.select(db.fanArts).get()))!;
    expect(rows.length, 1);
    expect(rows.single.pitId, newPit.id);
    await unmount(tester);
  });

  testWidgets('取消 sheet 不會存任何東西，暫存檔被清掉', (tester) async {
    final files = sharedFiles(1);
    await pumpApp(tester, FakeShareChannel(initial: files));
    await tester.tapAt(const Offset(200, 100)); // 點遮罩關閉
    await settle(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(
      (await tester.runAsync(() => db.select(db.officialImages).get()))!,
      isEmpty,
    );
    expect(File(files.first).existsSync(), isFalse);
    expect(channel.backCalls, 0);
    await unmount(tester);
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
