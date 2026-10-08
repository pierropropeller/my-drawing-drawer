import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/payment.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/ui/common/app_switch.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/entity/entity_widgets.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/piece_detail_page.dart';
import 'package:huakeng/ui/entity/piece_platform.dart';
import 'package:huakeng/ui/entity/piece_widgets.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_piece_test');
    Directory('${tmp.path}/images').createSync(recursive: true);
    File('${tmp.path}/images/a.png').writeAsBytesSync(_png1x1);
    pitId = await db.createPit(name: '測試坑');
  });

  Future<String> seed({
    String title = '月下的約定',
    bool published = false,
    bool commission = false,
  }) => db.savePiece(
    pitId: pitId,
    title: title,
    body: '',
    images: const [NewImage(file: 'a.png', width: 10, height: 10)],
    tagIds: const [],
    links: const [SocialLink('推特', 'https://x.com/a/status/1')],
    targetLikes: 100,
    finishedAt: DateTime(2026, 9, 12),
    ideaIds: const [],
    draftIds: const [],
    isPublished: published,
    publishedAt: DateTime(2026, 10, 6),
    isCommission: commission,
    client: commission ? '@某某老師' : '',
    amount: commission ? 800 : null,
    currency: 'HKD',
    receivedAmount: commission ? 300 : 0,
    dueAt: commission ? DateTime(2026, 10, 20) : null,
  );

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final src = File('${tmp.path}/pick.png')..writeAsBytesSync(_png1x1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imagePickerProvider.overrideWithValue(() async => [XFile(src.path)]),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
  }

  /// 單獨 pump 一個頁面（不經過坑內頁）。
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: page,
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openFinished(WidgetTester tester) async {
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('測試坑'));
    await settle(tester);
    await tester.tap(find.text('我的成圖'));
    await settle(tester);
  }

  Future<void> show(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(Key(key));
    await show(tester, f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await show(tester, f.first);
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// 標題列左上的返回鍵（最上層那一頁的）。
  Future<void> back(WidgetTester tester) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(SubPageHeader).last,
            matching: find.byType(InkResponse),
          )
          .first,
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  bool chipOn(WidgetTester tester, String label) => tester
      .widget<PieceChipButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(PieceChipButton),
        ),
      )
      .on;

  test('依網址自動判斷社交平台', () {
    expect(
      detectSocialPlatform('https://x.com/a/status/1'),
      PieceSocialPlatform.twitter,
    );
    expect(detectSocialPlatform('twitter.com/a'), PieceSocialPlatform.twitter);
    expect(
      detectSocialPlatform('https://www.xiaohongshu.com/explore/1'),
      PieceSocialPlatform.xiaohongshu,
    );
    expect(
      detectSocialPlatform('https://a.lofter.com/post/1'),
      PieceSocialPlatform.lofter,
    );
    expect(
      detectSocialPlatform('https://www.pixiv.net/artworks/1'),
      PieceSocialPlatform.pixiv,
    );
    expect(
      detectSocialPlatform('https://weibo.com/1/abc'),
      PieceSocialPlatform.weibo,
    );
    expect(
      detectSocialPlatform('https://www.instagram.com/p/1'),
      PieceSocialPlatform.instagram,
    );
    expect(
      detectSocialPlatform('https://example.com'),
      PieceSocialPlatform.other,
    );
    expect(detectSocialPlatform(''), PieceSocialPlatform.other);
    // 不能只是主機名稱結尾相似
    expect(
      detectSocialPlatform('https://notx.com/a'),
      PieceSocialPlatform.other,
    );
  });

  testWidgets('成圖列表有導覽列；詳情、編輯沒有；列表頂部沒有 tag chips', (tester) async {
    await tester.runAsync(() async {
      final tag = await db.createTag(pitId, '角色1');
      await db.savePiece(
        pitId: pitId,
        title: '有 tag',
        body: '',
        images: const [NewImage(file: 'a.png', width: 10, height: 10)],
        tagIds: [tag],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 9, 12),
        ideaIds: const [],
        draftIds: const [],
        isPublished: true,
      );
    });
    await openFinished(tester);
    expect(find.text('目標'), findsOneWidget);
    expect(find.text('#角色1'), findsNothing);
    expect(find.text('全部'), findsNothing);

    await tester.tap(find.text('有 tag'));
    await settle(tester);
    expect(find.text('目標'), findsNothing); // 詳情沒有導覽列
    expect(find.text('#角色1'), findsOneWidget); // 詳情列出全部 tag

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    expect(find.text('編輯成圖'), findsOneWidget);
    expect(find.text('目標'), findsNothing);
    await back(tester);
    await settle(tester);
    await back(tester);
    await settle(tester);
    expect(find.text('目標'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('FinishedListPage(tagId) 只列出有該 tag 的成圖', (tester) async {
    late String tag;
    await tester.runAsync(() async {
      tag = await db.createTag(pitId, '角色1');
      for (final (title, tags) in [
        ('甲', [tag]),
        ('乙', <String>[]),
      ]) {
        await db.savePiece(
          pitId: pitId,
          title: title,
          body: '',
          images: const [NewImage(file: 'a.png', width: 10, height: 10)],
          tagIds: tags,
          links: const [],
          targetLikes: 0,
          finishedAt: DateTime(2026, 9, 12),
          ideaIds: const [],
          draftIds: const [],
          isPublished: true,
        );
      }
    });
    await pumpPage(tester, FinishedListPage(pitId: pitId, tagId: tag));
    await settle(tester);
    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsNothing);
    await unmount(tester);
  });

  testWidgets('新增：兩個開關都關＝私稿；整組欄位保留', (tester) async {
    await openFinished(tester);
    await tester.tap(find.text('新增'));
    await settle(tester);
    expect(find.text('新增成圖'), findsWidgets);
    expect(find.text('目標'), findsNothing);
    expect(find.text('發佈日期'), findsNothing);
    expect(find.text('委託人'), findsNothing);
    await enter(tester, 'piece-title', '私稿');
    await tapText(tester, '建立成圖');
    await settle(tester);
    await settle(tester);
    final rows = await tester.runAsync(() => db.watchPieceViews(pitId).first);
    expect(rows!.single.piece.title, '私稿');
    expect(rows.single.piece.isPublished, isFalse);
    expect(rows.single.piece.isCommission, isFalse);
    expect(rows.single.piece.currency, 'CNY'); // 設定的預設幣種
    await unmount(tester);
  });

  testWidgets('新增：公開發佈＋商稿，社交連結依網址顯示平台，已收齊按鈕跟著數字走', (tester) async {
    await openFinished(tester);
    await tester.tap(find.text('新增'));
    await settle(tester);
    await enter(tester, 'piece-title', '商稿');

    await tester.tap(find.byType(AppSwitch).at(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('發佈日期'), findsOneWidget);
    expect(find.text('社交媒體連結'), findsOneWidget);
    expect(find.text('目標互動量'), findsOneWidget);
    expect(find.text('實際互動量'), findsNothing); // 新增頁沒有
    expect(find.text('委託人'), findsNothing);

    // 社交連結：直接多一行輸入，沒有 bottom sheet
    await tapText(tester, '加社交連結');
    expect(find.byKey(const Key('piece-link-0')), findsOneWidget);
    expect(find.text('X'), findsNothing);
    await enter(tester, 'piece-link-0', 'https://x.com/a/status/1');
    expect(find.text('X'), findsOneWidget); // 平台簡寫
    await tapText(tester, '加社交連結');
    await enter(tester, 'piece-link-1', 'https://example.com/p');
    expect(find.text('X'), findsOneWidget);
    await enter(tester, 'piece-target', '100');

    await tester.tap(find.byType(AppSwitch).at(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('委託人'), findsOneWidget);
    expect(find.text('已收金額'), findsOneWidget);
    expect(find.text('交稿日期'), findsOneWidget);
    await enter(tester, 'piece-client', '@某某老師');
    await enter(tester, 'piece-amount', '800');
    expect(chipOn(tester, '已收齊'), isFalse);

    // 按「已收齊」＝填滿；再按＝歸零
    await tapText(tester, '已收齊');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('piece-received')))
          .controller!
          .text,
      '800',
    );
    expect(chipOn(tester, '已收齊'), isTrue);
    // 手動改小 → 變回外框
    await enter(tester, 'piece-received', '300');
    expect(chipOn(tester, '已收齊'), isFalse);
    // 金額改大也一樣：先收齊，再把金額加大
    await tapText(tester, '已收齊');
    expect(chipOn(tester, '已收齊'), isTrue);
    await enter(tester, 'piece-amount', '900');
    expect(chipOn(tester, '已收齊'), isFalse);
    await tapText(tester, '已收齊');
    expect(chipOn(tester, '已收齊'), isTrue);
    await tapText(tester, '已收齊');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('piece-received')))
          .controller!
          .text,
      '0',
    );
    await enter(tester, 'piece-received', '300');

    await tapText(tester, '建立成圖');
    await settle(tester);
    await settle(tester);
    final v = (await tester.runAsync(() => db.watchPieceViews(pitId).first))!
        .single;
    expect(v.piece.title, '商稿');
    expect(v.piece.isPublished, isTrue);
    expect(v.piece.isCommission, isTrue);
    expect(v.piece.targetLikes, 100);
    expect(v.piece.client, '@某某老師');
    expect(v.piece.amount, 900);
    expect(v.piece.receivedAmount, 300);
    expect(v.payment.status, PaymentStatus.partial);
    expect(v.links.map((e) => e.platform), ['推特', '其他']);
    expect(v.links.map((e) => e.url), [
      'https://x.com/a/status/1',
      'https://example.com/p',
    ]);
    await unmount(tester);
  });

  testWidgets('編輯：帶入資料、多「實際互動量」、按鈕「儲存」；開關關閉時資料保留', (tester) async {
    late String id;
    await tester.runAsync(() async {
      id = await seed(published: true, commission: true);
    });
    await openFinished(tester);
    await tester.tap(find.text('月下的約定'));
    await settle(tester);
    // 詳情：公開與商稿資訊
    expect(find.text('@某某老師'), findsOneWidget);
    expect(find.text('HK\$ 800'), findsOneWidget);
    expect(find.text('已收 HK\$ 300'), findsOneWidget);
    expect(find.text('2026 / 10 / 06'), findsOneWidget);
    expect(find.text('2026 / 10 / 20'), findsOneWidget);

    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    expect(find.text('編輯成圖'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.text('實際互動量'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('piece-amount')))
          .controller!
          .text,
      '800',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('piece-received')))
          .controller!
          .text,
      '300',
    );
    expect(chipOn(tester, '已收齊'), isFalse);
    await enter(tester, 'piece-actual', '86');
    // 關掉公開發佈：資料保留
    await tester.tap(find.byType(AppSwitch).at(0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('發佈日期'), findsNothing);
    await tapText(tester, '已收齊');
    await tapText(tester, '儲存');
    await settle(tester);
    await settle(tester);

    final v = (await tester.runAsync(() => db.watchPieceView(id).first))!;
    expect(v.piece.actualLikes, 86);
    expect(v.piece.isPublished, isFalse);
    expect(v.piece.publishedAt, DateTime(2026, 10, 6));
    expect(v.links.single.url, 'https://x.com/a/status/1');
    expect(v.piece.isCommission, isTrue);
    expect(v.piece.client, '@某某老師');
    expect(v.piece.currency, 'HKD');
    expect(v.piece.receivedAmount, 800);
    expect(v.payment.isPaid, isTrue);
    expect(v.piece.dueAt, DateTime(2026, 10, 20));
    await unmount(tester);
  });

  testWidgets('編輯：圖片右上角有 × 可移除已上傳的圖', (tester) async {
    await tester.runAsync(seed);
    await openFinished(tester);
    await tester.tap(find.text('月下的約定'));
    await settle(tester);
    await tester.tap(find.byTooltip('編輯'));
    await settle(tester);
    expect(find.bySemanticsLabel('移除圖片'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('移除圖片'));
    await tester.pump();
    expect(find.bySemanticsLabel('移除圖片'), findsNothing);
    await unmount(tester);
  });

  testWidgets('詳情：點 tag 觸發 onTagTap；刪除要確認；私稿不顯示互動量與連結', (tester) async {
    late String tag;
    late String id;
    await tester.runAsync(() async {
      tag = await db.createTag(pitId, '角色1');
      id = await db.savePiece(
        pitId: pitId,
        title: '私稿',
        body: '',
        images: const [NewImage(file: 'a.png', width: 10, height: 10)],
        tagIds: [tag],
        links: const [SocialLink('推特', 'https://x.com/a')],
        targetLikes: 10,
        finishedAt: DateTime(2026, 9, 12),
        ideaIds: const [],
        draftIds: const [],
        isPublished: false,
        isCommission: false,
      );
    });
    final tapped = <String>[];
    await pumpPage(
      tester,
      PieceDetailPage(pieceId: id, pitId: pitId, onTagTap: tapped.add),
    );
    await settle(tester);
    expect(find.text('社交媒體連結'), findsNothing);
    expect(find.textContaining('實際互動量'), findsNothing);
    await tester.tap(find.text('#角色1'));
    expect(tapped, [tag]);
    await tester.tap(find.byTooltip('刪除'));
    await settle(tester);
    expect(find.text('刪除這張成圖？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await settle(tester);
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
