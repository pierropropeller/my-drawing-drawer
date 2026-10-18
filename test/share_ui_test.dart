import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/junk/junk_list_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/oshi/oshi_form_page.dart';
import 'package:huakeng/ui/oshi/oshi_list_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 假的 channel：不碰原生，測試用 [push] 模擬熱啟動時新的分享。
class FakeShareChannel extends ShareChannel {
  FakeShareChannel({this.initial = const []});
  final List<String> initial;
  void Function(List<String>)? onShare;

  @override
  Future<List<String>> getInitialShare() async => initial;

  @override
  void setOnShare(void Function(List<String> paths)? cb) => onShare = cb;

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

  Future<void> pumpApp(
    WidgetTester tester,
    FakeShareChannel ch, {
    Size size = const Size(1080, 2400),
  }) async {
    channel = ch;
    tester.view.physicalSize = size;
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
    // 中間內容可捲動，先捲到看得見再點。
    await tester.ensureVisible(inSheet(find.text(text)));
    await tester.pump(const Duration(milliseconds: 50));
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
    expect(inSheet(find.text('摸魚')), findsOneWidget);
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
    // 顯示「已加入」，留在 App 裡，停在坑A 的官方圖冊列表。
    expect(find.text('已加入'), findsOneWidget);
    expect(find.byType(ShareSheet), findsNothing);
    expect(find.byType(OfficialListPage), findsOneWidget);
    expect(find.byType(PitPage, skipOffstage: false), findsOneWidget);
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

  testWidgets('App 裡已開著 bottom sheet（如選圖器）時收到分享：先關掉它，再顯示「加入到」', (tester) async {
    await pumpApp(tester, FakeShareChannel());
    final ctx = tester.element(find.byType(Scaffold).first);
    // ignore: unawaited_futures
    showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: true,
      builder: (_) => const SizedBox(height: 300, child: Text('假選圖器')),
    );
    await settle(tester);
    expect(find.text('假選圖器'), findsOneWidget);

    channel.push(sharedFiles(1));
    await settle(tester);
    expect(find.text('假選圖器'), findsNothing);
    expect(find.byType(ShareSheet), findsOneWidget);
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
    expect(find.byType(FanArtListPage), findsOneWidget);
    await unmount(tester);
  });

  for (final c in [
    ('摸魚', DraftFormPage),
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
    expect(find.byType(JunkListPage), findsOneWidget);

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

  Future<List<String>> tagNamesOf(
    WidgetTester tester,
    TagTarget target,
    String id,
  ) async {
    final ids = (await tester.runAsync(
      () => db.watchTagIds(target, id).first,
    ))!;
    final tags = (await tester.runAsync(() => db.select(db.tags).get()))!;
    return [
      for (final t in tags)
        if (ids.contains(t.id)) t.name,
    ]..sort();
  }

  testWidgets('官方圖冊：分組單選＋tag 多選（可就地新增），加入後存進資料庫', (tester) async {
    await tester.runAsync(() async {
      await db.createTag(pitA, '角色1');
      await db.createTag(pitA, '角色2');
    });
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
    expect(inSheet(find.text('tag')), findsOneWidget);
    await tapIn(tester, '#角色1');
    await tapIn(tester, '#角色2');
    await tapIn(tester, '#角色2'); // 再點一次＝取消
    await tapIn(tester, '海報宣傳');
    // 就地新增 tag：新 tag 自動選上。
    await tapIn(tester, '新增');
    await tester.enterText(find.byType(TextField).last, '夏日');
    await tester.tap(find.text(l10nStatic.albumConfirm));
    await settle(tester);
    expect(inSheet(find.text('#夏日')), findsOneWidget);
    await tapIn(tester, '加入');
    await settleLong(tester);

    final rows = (await tester.runAsync(
      () => db.select(db.officialImages).get(),
    ))!;
    expect(rows.length, 2);
    final groups = (await tester.runAsync(
      () => db.select(db.officialGroups).get(),
    ))!;
    final poster = groups.firstWhere(
      (g) => g.name == '海報宣傳' && g.pitId == pitA,
    );
    for (final r in rows) {
      expect(r.groupId, poster.id);
      expect(await tagNamesOf(tester, TagTarget.official, r.id), ['夏日', '角色1']);
    }
    await unmount(tester);
  });

  testWidgets('好看同人圖：作者＋出處（單選、可取消）＋tag，加入後存進資料庫', (tester) async {
    await tester.runAsync(() => db.createTag(pitB, '夏日企劃'));
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
    await tapIn(tester, '坑B');
    await tapIn(tester, '好看同人圖');
    await settle(tester);
    expect(inSheet(find.text('作者')), findsOneWidget);
    expect(inSheet(find.text('出處')), findsOneWidget);
    expect(inSheet(find.text('推特')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('shareAuthor')),
      ' @illust_ka ',
    );
    await tapIn(tester, '小紅書');
    await tapIn(tester, 'lofter');
    await tapIn(tester, 'lofter'); // 再點一次＝取消
    await tapIn(tester, '小紅書');
    await tapIn(tester, '#夏日企劃');
    await tapIn(tester, '加入');
    await settleLong(tester);

    final rows = (await tester.runAsync(() => db.select(db.fanArts).get()))!;
    expect(rows.length, 2);
    final groups = (await tester.runAsync(
      () => db.select(db.officialGroups).get(),
    ))!;
    final xhs = groups.firstWhere((g) => g.name == '小紅書' && g.pitId == pitB);
    for (final r in rows) {
      expect(r.pitId, pitB);
      expect(r.author, '@illust_ka');
      expect(r.groupId, xhs.id);
      expect(await tagNamesOf(tester, TagTarget.fanArt, r.id), ['夏日企劃']);
    }
    // 留在 App 裡，停在坑B 的好看同人圖列表。
    expect(find.byType(FanArtListPage), findsOneWidget);
    expect(
      tester.widget<FanArtListPage>(find.byType(FanArtListPage)).pitId,
      pitB,
    );
    await unmount(tester);
  });

  testWidgets('加入後不再回到其他 App；列表返回是坑內頁、再返回是坑列表', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(1)));
    await tapIn(tester, '加入');
    await settleLong(tester);
    expect(find.byType(OfficialListPage), findsOneWidget);
    await tester.tap(find.byTooltip(l10nStatic.commonBack));
    await settle(tester);
    expect(find.byType(OfficialListPage), findsNothing);
    expect(find.byType(PitPage, skipOffstage: false), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('位置是 4 欄 7 格：官方圖冊、好看同人圖、推活、雜物／腦洞、摸魚、成圖（D-091）', (tester) async {
    await db.updatePit(pitA, name: '坑A', archived: false, junkEnabled: true);
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(1)));
    Offset c(String text) => tester.getCenter(inSheet(find.text(text)));
    final first = [c('官方圖冊'), c('好看同人圖'), c('推活'), c('雜物')];
    final second = [c('腦洞'), c('摸魚'), c('成圖')];
    // 第一列 4 格由左到右，同一水平線。
    for (var i = 1; i < 4; i++) {
      expect(first[i].dx, greaterThan(first[i - 1].dx));
      expect(first[i].dy, closeTo(first[0].dy, 2));
    }
    // 第二列 3 格，對齊前三欄。
    for (var i = 0; i < 3; i++) {
      expect(second[i].dx, closeTo(first[i].dx, 0.5));
      expect(second[i].dy, closeTo(second[0].dy, 2));
    }
    expect(second[0].dy, greaterThan(first[0].dy));
    // 坑沒開雜物時只有 6 格，腦洞接在推活後面（第一列第四欄）。
    await tapIn(tester, '坑B');
    expect(inSheet(find.text('雜物')), findsNothing);
    expect(c('腦洞').dx, closeTo(first[3].dx, 0.5));
    expect(c('腦洞').dy, closeTo(c('官方圖冊').dy, 2));
    await unmount(tester);
  });

  testWidgets('坑 chips 用文件夾 icon ＋坑名，沒有彩色圓點／封面圓', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(1)));
    final chip = find.ancestor(
      of: inSheet(find.text('坑B')),
      matching: find.byType(Row),
    );
    expect(
      find.descendant(of: chip.first, matching: find.byType(SvgPicture)),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('D-064：最高 88% 螢幕，中間可捲動、按鈕固定；縮圖單排橫向捲動', (tester) async {
    await db.updatePit(pitA, name: '坑A', archived: false, junkEnabled: true);
    // 360×500 的小螢幕，12 張以上縮圖。
    await pumpApp(
      tester,
      FakeShareChannel(initial: sharedFiles(14)),
      size: const Size(1080, 1500),
    );
    await tapIn(tester, '好看同人圖'); // 欄位最多的一格
    final sheetSize = tester.getSize(find.byType(ShareSheet));
    expect(sheetSize.height, lessThanOrEqualTo(500 * 0.88 + 0.5));
    // 底部按鈕固定在畫面內。
    final addBottom = tester.getBottomLeft(inSheet(find.text('加入'))).dy;
    expect(addBottom, lessThanOrEqualTo(500));
    // 中間內容超出時可捲動。
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('shareScroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    // 縮圖列：高度 60，單排橫向捲動，後面的縮圖要捲過去才看得到。
    expect(
      tester.getSize(find.byKey(const ValueKey('shareThumbs'))).height,
      60,
    );
    expect(find.byKey(const ValueKey('shareThumb13')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('shareThumbs')),
      const Offset(-1500, 0),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('shareThumb13')), findsOneWidget);
    // 仍然是同一排：縮圖的 y 一樣。
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('shareThumb12'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('shareThumb13'))).dy,
    );
    await unmount(tester);
  });

  testWidgets('「下一步」：推活打開推活新增頁，圖片已放好', (tester) async {
    await pumpApp(tester, FakeShareChannel(initial: sharedFiles(2)));
    await tapIn(tester, '坑B');
    await tapIn(tester, '推活');
    expect(inSheet(find.text('下一步')), findsOneWidget);
    expect(inSheet(find.text('分組')), findsNothing);
    await tapIn(tester, '下一步');
    await settle(tester);
    expect(find.byType(ShareSheet), findsNothing);
    // 打開推活新增頁，分享進來的圖片已放好。
    expect(find.byType(OshiFormPage), findsOneWidget);
    // 表單關閉後停在推活列表（不是掉回主頁），再返回是坑內頁。
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(OshiFormPage), findsNothing);
    expect(find.byType(OshiListPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(OshiListPage), findsNothing);
    expect(find.byType(PitPage), findsOneWidget);
    expect(
      (await tester.runAsync(() => db.select(db.officialImages).get()))!,
      isEmpty,
    );
    expect(
      (await SharedPreferences.getInstance()).getString('shareLastSection'),
      'oshi',
    );
    await unmount(tester);
  });

  testWidgets('取消 sheet 不會存任何東西，暫存檔被清掉', (tester) async {
    final files = sharedFiles(1);
    await pumpApp(tester, FakeShareChannel(initial: files));
    await tester.tapAt(const Offset(200, 10)); // 點遮罩關閉
    await settle(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(
      (await tester.runAsync(() => db.select(db.officialImages).get()))!,
      isEmpty,
    );
    expect(File(files.first).existsSync(), isFalse);
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
