import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/income_queries.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/payment.dart';
import 'package:huakeng/data/search_queries.dart';

/// 成圖新欄位（D-046／D-050）、商稿收入（D-047）、tag 篩選與坑內搜尋（D-043／D-051）、回顧月份對齊（D-039）。
void main() {
  late AppDatabase db;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: 'A');
  });
  tearDown(() => db.close());

  Future<String> piece(
    String title,
    DateTime at, {
    bool? published,
    bool? commission,
    String client = '',
    double? amount,
    String currency = 'CNY',
    double received = 0,
    List<String> tagIds = const [],
    String body = '',
    String? id,
  }) => db.savePiece(
    id: id,
    pitId: pitId,
    title: title,
    body: body,
    images: [NewImage(file: '$title.png')],
    tagIds: tagIds,
    links: const [],
    targetLikes: 0,
    finishedAt: at,
    ideaIds: const [],
    draftIds: const [],
    isPublished: published,
    isCommission: commission,
    client: client,
    amount: amount,
    currency: currency,
    receivedAmount: received,
  );

  test('收款狀態：未收／部分／已收齊（多收也算）', () {
    expect(
      paymentStateOf(amount: 800, received: 0).status,
      PaymentStatus.unpaid,
    );
    final p = paymentStateOf(amount: 800, received: 300);
    expect((p.status, p.received), (PaymentStatus.partial, 300));
    expect(paymentStateOf(amount: 800, received: 800).isPaid, isTrue);
    expect(paymentStateOf(amount: 800, received: 1000).isPaid, isTrue);
    expect(paymentStateOf(amount: null, received: 0).isUnpaid, isTrue);
    expect(paymentStateOf(amount: null, received: 5).isPaid, isTrue);
    expect(outstandingOf(amount: 800, received: 300), 500);
    expect(outstandingOf(amount: 800, received: 900), 0);
    expect(isFullyReceived(amount: 800, received: 800), isTrue);
    expect(isFullyReceived(amount: 800, received: 799), isFalse);
    expect(isFullyReceived(amount: null, received: 0), isFalse);
  });

  test('成圖新欄位：預設值、分組寫入、編輯時沒傳的組保持原樣', () async {
    final id = await piece('a', DateTime(2026, 3, 1));
    var p = (await db.watchPieceView(id).first)!;
    expect(p.piece.isPublished, isFalse);
    expect(p.piece.isCommission, isFalse);
    expect(p.piece.currency, 'CNY');
    expect(p.piece.receivedAmount, 0);
    expect(p.payment.isUnpaid, isTrue);

    await piece(
      'a',
      DateTime(2026, 3, 1),
      id: id,
      published: true,
      commission: true,
      client: ' @某某 ',
      amount: 800,
      currency: 'HKD',
      received: 300,
    );
    p = (await db.watchPieceView(id).first)!;
    expect(p.piece.isPublished, isTrue);
    expect(p.piece.publishedAt, DateTime(2026, 3, 1)); // 沒給發佈日期＝完成日期
    expect(p.piece.client, '@某某');
    expect((p.piece.amount, p.piece.currency), (800, 'HKD'));
    expect(p.payment.isPartial, isTrue);
    expect(p.payment.received, 300);

    // 編輯時兩個開關都不傳：兩組欄位都不動
    await piece('a2', DateTime(2026, 3, 2), id: id);
    p = (await db.watchPieceView(id).first)!;
    expect(p.piece.title, 'a2');
    expect(p.piece.isPublished, isTrue);
    expect(p.piece.isCommission, isTrue);
    expect(p.piece.amount, 800);

    // 關掉商稿：資料保留
    await piece('a2', DateTime(2026, 3, 2), id: id, commission: false);
    p = (await db.watchPieceView(id).first)!;
    expect(p.piece.isCommission, isFalse);

    await db.setReceivedAmount(id, 800);
    expect((await db.watchPieceView(id).first)!.payment.isPaid, isTrue);
  });

  test('目標的互動量門檻只算已公開發佈的成圖；無互動量條件的成圖目標全算', () async {
    final a = await piece('pub', DateTime(2026, 3, 1), published: true);
    final b = await piece('priv', DateTime(2026, 3, 2), published: false);
    await db.setActualLikes(a, 600);
    await db.setActualLikes(b, 900);
    await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 5,
      requireLikes: 500,
    );
    await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.piece,
      count: 4,
    );
    final views = await db.watchGoalViews(GoalPeriod.year, 2026).first;
    final byCount = {for (final v in views) v.goal.count: v.progress};
    expect(byCount[5], 1);
    expect(byCount[4], 2);
  });

  test('商稿收入：按幣種合計、尚欠、按月份（完成日期）列出', () async {
    await piece(
      '一',
      DateTime(2026, 10, 3),
      commission: true,
      amount: 800,
      received: 300,
      client: '@甲',
    );
    await piece('二', DateTime(2026, 10, 5), commission: true, amount: 800);
    await piece(
      '三',
      DateTime(2026, 9, 2),
      commission: true,
      amount: 1800,
      currency: 'HKD',
      received: 1800,
    );
    await piece(
      '四',
      DateTime(2026, 9, 9),
      commission: true,
      amount: 1200,
      received: 1500,
    ); // 多收
    await piece('五', DateTime(2026, 9, 12), commission: true, amount: 2000);
    await piece('非商稿', DateTime(2026, 9, 1), commission: false, amount: 99999);
    await piece('去年', DateTime(2025, 12, 31), commission: true, amount: 500);
    await piece('未填金額', DateTime(2026, 9, 20), commission: true);

    final y = await db.watchIncome(2026).first;
    expect(y.currencies.map((c) => c.currency), ['CNY', 'HKD']);
    final cny = y.currencies.first;
    expect(cny.total, 4800);
    expect(cny.received, 1800);
    expect(cny.count, 4);
    expect(cny.unpaidCount, 3); // 一（部分）、二、五
    expect(cny.outstanding, 500 + 800 + 2000);
    expect(cny.hasOutstanding, isTrue);
    final hkd = y.currencies.last;
    expect(
      (hkd.total, hkd.received, hkd.count, hkd.unpaidCount, hkd.outstanding),
      (1800, 1800, 1, 0, 0),
    );

    expect(y.months.map((m) => m.month), [10, 9]);
    expect(y.months.first.entries.map((e) => e.piece.title), ['二', '一']);
    expect(y.months.first.totals, {'CNY': 1600});
    final sep = y.months.last;
    expect(sep.totals, {'CNY': 3200, 'HKD': 1800});
    expect(sep.entries.length, 4); // 含沒填金額的
    expect(sep.entries.first.cover?.file, isNotNull);
    expect(
      sep.entries.firstWhere((e) => e.piece.title == '四').payment.isPaid,
      isTrue,
    );
    expect((await db.watchIncome(2024).first).isEmpty, isTrue);
  });

  test('tag 使用次數排序、tag 篩選的各種列表', () async {
    final t1 = await db.createTag(pitId, '角色1');
    final t2 = await db.createTag(pitId, '企劃');
    final t3 = await db.createTag(pitId, '零次');
    await piece('p1', DateTime(2026, 1, 1), tagIds: [t1, t2]);
    await piece('p2', DateTime(2026, 1, 2), tagIds: [t2]);
    await db.saveDraft(
      pitId: pitId,
      title: 'd1',
      images: const [NewImage(file: 'd1.png')],
      tagIds: [t2],
      ideaIds: const [],
    );
    await db.saveDraft(
      pitId: pitId,
      title: 'd2',
      images: const [NewImage(file: 'd2.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await db.saveIdea(
      pitId: pitId,
      title: 'i1',
      body: '',
      images: const [],
      tagIds: [t1],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.addFanArts(
      pitId,
      [const NewImage(file: 'f1.png')],
      author: '@a',
      tagIds: [t1],
    );
    await db.addFanArts(pitId, [const NewImage(file: 'f2.png')], author: '@b');

    final byUsage = await db.watchTagUsage(pitId, byUsage: true).first;
    expect(byUsage.map((u) => (u.tag.name, u.count)), [
      ('企劃', 3),
      ('角色1', 3),
      ('零次', 0),
    ]);
    expect(byUsage.first.tag.id, t2); // 次數相同時按名稱
    expect(t3, isNotEmpty);

    expect((await db.watchFanArts(pitId, tagId: t1).first).single.author, '@a');
    expect(
      (await db.watchDraftViews(pitId, tagId: t2).first).single.draft.title,
      'd1',
    );
    expect((await db.watchPieceViews(pitId, tagId: t2).first).length, 2);
    expect((await db.watchIdeaViews(pitId, tagId: t1).first).length, 1);
    expect((await db.watchDraftViews(pitId).first).length, 2);
  });

  test('坑內搜尋：分段順序、文字與 tag 條件、+N、腦洞全部、排除隱藏與雜物', () async {
    final role = await db.createTag(pitId, '角色1');
    for (var i = 0; i < 5; i++) {
      await piece('成圖$i', DateTime(2026, 2, 1 + i), tagIds: [role]);
    }
    await piece('無關', DateTime(2026, 2, 20));
    await piece('正文命中', DateTime(2026, 2, 21), body: '畫了角色1的夏天');
    for (var i = 0; i < 4; i++) {
      await db.saveDraft(
        pitId: pitId,
        title: '草稿$i',
        images: [NewImage(file: 'd$i.png')],
        tagIds: [role],
        ideaIds: const [],
      );
    }
    for (var i = 0; i < 5; i++) {
      await db.saveIdea(
        pitId: pitId,
        title: '腦洞$i',
        body: i == 0 ? '含 角色1 的字' : '',
        images: const [],
        tagIds: i == 1 ? [role] : const [],
        draftIds: const [],
        pieceIds: const [],
      );
    }
    await db.addFanArts(
      pitId,
      [for (var i = 0; i < 4; i++) NewImage(file: 'f$i.png')],
      author: '@角色1太太',
      tagIds: const [],
    );
    await db.addFanArts(
      pitId,
      [const NewImage(file: 'tagged.png')],
      author: '@x',
      tagIds: [role],
    );
    // 被移到雜物的同人圖不能被搜到
    await db.addFanArts(
      pitId,
      [const NewImage(file: 'gone.png')],
      author: '@角色1',
      tagIds: [role],
    );
    final gone = (await db.watchFanArts(pitId).first).firstWhere(
      (f) => f.imageFile == 'gone.png',
    );
    await db.moveAlbumImages(
      from: AlbumCell.fan,
      ids: [gone.id],
      to: AlbumCell.junk,
    );

    // 只用 tag
    var r = await db.watchPitSearch(pitId, tagId: role).first;
    expect(r.pieces.total, 5);
    expect(r.pieces.items.length, 3);
    expect(r.pieces.more, 2);
    expect(r.drafts.total, 4);
    expect(r.fanArts.total, 1);
    expect(r.fanArts.items.single.imageFile, 'tagged.png');
    expect(r.ideas.total, 1);
    expect(r.total, 5 + 1 + 4 + 1);

    // 文字：比對標題、內文、作者、tag 名稱
    r = await db.watchPitSearch(pitId, text: '角色1').first;
    expect(r.pieces.total, 6); // 5 個有 tag ＋ 內文命中
    expect(r.fanArts.total, 5); // 4 個作者命中 ＋ tag 命中；雜物那張不算
    expect(r.drafts.total, 4);
    expect(r.ideas.total, 2); // 內文命中 ＋ tag 命中
    expect(r.ideas.items.length, 2); // 腦洞給全部

    // 多個詞要全部命中；不分大小寫
    r = await db.watchPitSearch(pitId, text: '腦洞1 角色1').first;
    expect(r.total, 1);
    r = await db.watchPitSearch(pitId, text: '腦洞3', tagId: role).first;
    expect(r.isEmpty, isTrue);

    // 沒條件＝空結果
    expect((await db.watchPitSearch(pitId).first).isEmpty, isTrue);
  });

  test('回顧設定：月份對齊預設與儲存', () async {
    var s = await db.watchReviewSettings(2026).first;
    expect(s.monthAlign, isNull);
    expect(s.effectiveMonthAlign, 'start'); // 月份在圖上
    await db.saveReviewSettings(s.copyWith(monthOnImage: false));
    s = await db.watchReviewSettings(2026).first;
    expect(s.effectiveMonthAlign, 'center'); // 空白位置
    expect(s.updatedAt, isNotNull);
    await db.saveReviewSettings(s.copyWith(monthAlign: const Value('end')));
    s = await db.watchReviewSettings(2026).first;
    expect(s.effectiveMonthAlign, 'end');
  });
}
