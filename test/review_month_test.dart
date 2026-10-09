import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';

/// 年度回顧月份挑圖（D-056）。
void main() {
  late AppDatabase db;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: 'A');
  });
  tearDown(() => db.close());

  Future<String> piece(
    String file,
    DateTime at, {
    int likes = 0,
    bool published = true,
    bool commission = false,
    bool withImage = true,
  }) async {
    final id = await db.savePiece(
      pitId: pitId,
      title: 't-$file',
      body: '',
      images: withImage ? [NewImage(file: file), NewImage(file: '2$file')] : [],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: at,
      ideaIds: const [],
      draftIds: const [],
      isPublished: published,
      isCommission: commission,
    );
    await db.setActualLikes(id, likes);
    return id;
  }

  test('watchReviewMonthPieces：該月有圖的成圖（含私稿、商稿），新到舊；排除已刪、無圖、別月', () async {
    await piece('a.png', DateTime(2026, 3, 1), likes: 5);
    await piece('b.png', DateTime(2026, 3, 9), likes: 2, published: false);
    await piece('c.png', DateTime(2026, 3, 5), commission: true);
    await piece('noimg.png', DateTime(2026, 3, 6), withImage: false);
    await piece('apr.png', DateTime(2026, 4, 1));
    final gone = await piece('del.png', DateTime(2026, 3, 7));
    await db.deletePieces([gone]);

    final list = await db.watchReviewMonthPieces(2026, 3).first;
    expect(list.map((p) => p.file), ['b.png', 'c.png', 'a.png']);
    expect(list.first.title, 't-b.png');
    expect(list.last.actualLikes, 5);
    expect(list.first.finishedAt, DateTime(2026, 3, 9));
    expect(await db.watchReviewMonthPieces(2026, 5).first, isEmpty);
    expect(await db.watchReviewMonthPieces(2025, 3).first, isEmpty);
  });

  test('預設代表圖：互動量最高；同分取最新；手動挑覆蓋；清回預設', () async {
    await piece('low.png', DateTime(2026, 3, 20), likes: 1);
    await piece('hi1.png', DateTime(2026, 3, 2), likes: 9);
    await piece('hi2.png', DateTime(2026, 3, 10), likes: 9);
    await piece('only.png', DateTime(2026, 6, 1));

    var months = await db.watchReviewMonths(2026).first;
    expect(months[3], 'hi2.png'); // 9 讚並列 → 較新
    expect(months[6], 'only.png');
    expect(months.containsKey(5), isFalse);

    await db.setReviewMonthImage(2026, 3, 'low.png');
    months = await db.watchReviewMonths(2026).first;
    expect(months[3], 'low.png');

    // 手動挑了之後互動量變動，不影響手動選擇
    final summary = (await db.watchReviewMonthSummaries(2026).first)[3]!;
    expect(
      (summary.pieceCount, summary.isManual, summary.canPick),
      (3, true, true),
    );
    expect((await db.watchReviewMonthSummaries(2026).first)[6]!.canPick, false);

    await db.setReviewMonthImage(2026, 3, null); // 清回預設
    months = await db.watchReviewMonths(2026).first;
    expect(months[3], 'hi2.png');
    final s2 = (await db.watchReviewMonthSummaries(2026).first)[3]!;
    expect((s2.isManual, s2.file), (false, 'hi2.png'));

    // 刻意留空（舊行為）仍可用
    await db.setReviewMonth(2026, 6, null);
    months = await db.watchReviewMonths(2026).first;
    expect(months.containsKey(6), isTrue);
    expect(months[6], isNull);
  });

  test('預設代表圖：私稿與商稿也算候選', () async {
    await piece('pub.png', DateTime(2026, 8, 1), likes: 1);
    await piece('priv.png', DateTime(2026, 8, 2), likes: 4, published: false);
    expect((await db.watchReviewMonths(2026).first)[8], 'priv.png');
  });

  test('defaultReviewPiece 純函式', () {
    ReviewMonthPiece p(String id, int likes, int day) => ReviewMonthPiece(
      pieceId: id,
      title: id,
      file: id,
      width: 0,
      height: 0,
      actualLikes: likes,
      finishedAt: DateTime(2026, 1, day),
    );
    expect(defaultReviewPiece(const []), isNull);
    expect(defaultReviewPiece([p('a', 1, 1), p('b', 1, 2)])!.pieceId, 'b');
    expect(defaultReviewPiece([p('a', 3, 1), p('b', 1, 9)])!.pieceId, 'a');
  });
}
