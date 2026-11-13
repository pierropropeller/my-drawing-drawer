import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'entity_queries.dart' show watchAssembled;
import 'search_queries.dart';

/// 舊版作者文字遷移成作者時用的 id：由名字決定，各裝置各自遷移得到同一個作者（D-156）。
String authorIdForName(String name) =>
    const Uuid().v5(Namespace.url.value, 'drawer-author:${name.trim()}');

/// 遷移出來的作者的建立／更新時間：很早，使用者在任何裝置改過的版本一定比較新。
final _legacyAuthorTime = DateTime.utc(2000, 1, 4);

/// 作者列表的一列（D-156）。
class AuthorSummary {
  const AuthorSummary({
    required this.author,
    required this.count,
    this.mainPitId,
    this.mainPitName,
    this.latest = const [],
  });
  final Author author;

  /// 這位作者的同人圖張數（不含最近刪除、移走的）。
  final int count;

  /// 主坑＝這位作者同人圖最多的坑；同數時取最近加入同人圖的那個坑。沒有同人圖是 null。
  final String? mainPitId;
  final String? mainPitName;

  /// 最新加入的同人圖（最多三張，列表 layout 右側顯示）。
  final List<FanArt> latest;
}

/// 作者列表：作者（手動排序）＋列表上方的坑分頁（有作者以它為主坑的坑，依主頁順序）。
class AuthorList {
  const AuthorList(this.authors, this.pits);
  final List<AuthorSummary> authors;
  final List<Pit> pits;
  static const empty = AuthorList([], []);
}

/// 作者詳情：依坑分組的同人圖（坑依主頁順序；坑內新→舊）。
class AuthorDetail {
  const AuthorDetail(this.author, this.groups);
  final Author author;
  final List<(Pit, List<FanArt>)> groups;
  int get count => groups.fold(0, (n, g) => n + g.$2.length);
}

/// 作者資料（D-156）。
extension AuthorQueries on AppDatabase {
  /// 舊版自由輸入的作者文字 → 作者（同名合併；已有同名作者就歸給他，否則新建、id 由名字決定）。
  /// 已經有 authorId 的不動。分享進來、從影片擷取的同人圖只帶作者文字，存完也跑這裡。
  /// 遷移時跑一次，同步拉下來的同人圖可能也還沒有 authorId，同步後再跑一次。
  /// 不動同人圖的 updatedAt：各裝置各自轉換的結果相同，不需要重新上傳。
  Future<void> linkLegacyAuthors() async {
    final rows = await customSelect(
      "SELECT DISTINCT TRIM(author) AS name FROM fan_arts "
      "WHERE author_id IS NULL AND TRIM(author) != ''",
    ).get();
    if (rows.isEmpty) {
      await refreshAuthorNameCache();
      return;
    }
    await transaction(() async {
      for (final r in rows) {
        final name = r.read<String>('name');
        // 已有同名的作者（例如在作者列表建立的）就歸給他，不另建。
        final same =
            await (select(authors)
                  ..where((a) => a.deletedAt.isNull() & a.name.equals(name))
                  ..orderBy([(a) => OrderingTerm.asc(a.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        final id = same?.id ?? authorIdForName(name);
        // 已有的（含已刪除的）不重建：刪掉的作者不會因為舊文字又長回來。
        if (same == null) {
          await into(authors).insert(
            AuthorsCompanion.insert(
              id: Value(id),
              name: name,
              createdAt: Value(_legacyAuthorTime),
              updatedAt: Value(_legacyAuthorTime),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
        await customUpdate(
          'UPDATE fan_arts SET author_id = ? '
          'WHERE author_id IS NULL AND TRIM(author) = ? '
          'AND EXISTS (SELECT 1 FROM authors WHERE id = ? AND deleted_at IS NULL)',
          variables: [
            Variable<String>(id),
            Variable<String>(name),
            Variable<String>(id),
          ],
          updates: {fanArts},
        );
      }
    });
    await refreshAuthorNameCache();
  }

  /// 同人圖的作者文字（本機快取）跟著作者名字走；作者已刪除的清空。不動 updatedAt。
  Future<void> refreshAuthorNameCache() async {
    await customUpdate(
      'UPDATE fan_arts SET author = '
      '(SELECT name FROM authors a WHERE a.id = fan_arts.author_id) '
      'WHERE author_id IS NOT NULL AND EXISTS (SELECT 1 FROM authors a '
      'WHERE a.id = fan_arts.author_id AND a.deleted_at IS NULL AND a.name != fan_arts.author)',
      updates: {fanArts},
    );
    await customUpdate(
      "UPDATE fan_arts SET author_id = NULL, author = '' "
      'WHERE author_id IS NOT NULL AND EXISTS (SELECT 1 FROM authors a '
      'WHERE a.id = fan_arts.author_id AND a.deleted_at IS NOT NULL)',
      updates: {fanArts},
    );
  }

  // ---- 讀 ----

  Stream<Author?> watchAuthor(String id) =>
      (select(authors)..where((a) => a.id.equals(id))).watchSingleOrNull();

  Future<Author?> loadAuthor(String id) =>
      (select(authors)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// 未刪除的作者，依手動排序（新增的在最前面）。
  Future<List<Author>> loadAuthors() =>
      (select(authors)
            ..where((a) => a.deletedAt.isNull())
            ..orderBy([
              (a) => OrderingTerm.asc(a.sortOrder),
              (a) => OrderingTerm.desc(a.createdAt),
              (a) => OrderingTerm.asc(a.name),
            ]))
          .get();

  Stream<List<Author>> watchAuthors() =>
      watchAssembled(this, {authors}, loadAuthors);

  Stream<int> watchAuthorCount() => watchAuthors().map((l) => l.length);

  /// 看得到的同人圖（未刪除、沒移走、坑沒刪除），新→舊。
  Future<List<FanArt>> _visibleFanArts({String? authorId}) {
    final q =
        select(fanArts)
            .join([innerJoin(pits, pits.id.equalsExp(fanArts.pitId))])
          ..where(
            fanArts.deletedAt.isNull() &
                fanArts.hidden.equals(false) &
                pits.deletedAt.isNull() &
                (authorId == null
                    ? fanArts.authorId.isNotNull()
                    : fanArts.authorId.equals(authorId)),
          )
          ..orderBy([OrderingTerm.desc(fanArts.createdAt)]);
    return q.map((r) => r.readTable(fanArts)).get();
  }

  Future<AuthorList> loadAuthorList() async {
    final list = await loadAuthors();
    final arts = await _visibleFanArts();
    final pitsOrdered = await loadAllPitsOrdered();
    final pitName = {for (final p in pitsOrdered) p.id: p.name};
    final byAuthor = <String, List<FanArt>>{};
    for (final f in arts) {
      byAuthor.putIfAbsent(f.authorId!, () => []).add(f);
    }
    final mains = <String>{};
    final out = <AuthorSummary>[];
    for (final a in list) {
      final mine = byAuthor[a.id] ?? const <FanArt>[];
      // arts 已是新→舊：第一次出現的坑就是最近加入的，同數時先到先贏。
      final counts = <String, int>{};
      final firstSeen = <String, int>{};
      for (final (i, f) in mine.indexed) {
        counts[f.pitId] = (counts[f.pitId] ?? 0) + 1;
        firstSeen.putIfAbsent(f.pitId, () => i);
      }
      String? main;
      for (final e in counts.entries) {
        if (main == null ||
            e.value > counts[main]! ||
            (e.value == counts[main]! &&
                firstSeen[e.key]! < firstSeen[main]!)) {
          main = e.key;
        }
      }
      if (main != null) mains.add(main);
      out.add(
        AuthorSummary(
          author: a,
          count: mine.length,
          mainPitId: main,
          mainPitName: main == null ? null : pitName[main],
          latest: mine.take(3).toList(),
        ),
      );
    }
    return AuthorList(out, [
      for (final p in pitsOrdered)
        if (mains.contains(p.id)) p,
    ]);
  }

  Stream<AuthorList> watchAuthorList() => watchAssembled(this, {
    authors,
    fanArts,
    pits,
    pitSortSettings,
  }, loadAuthorList);

  Future<AuthorDetail?> loadAuthorDetail(String id) async {
    final a = await loadAuthor(id);
    if (a == null || a.deletedAt != null) return null;
    final arts = await _visibleFanArts(authorId: id);
    final byPit = <String, List<FanArt>>{};
    for (final f in arts) {
      byPit.putIfAbsent(f.pitId, () => []).add(f);
    }
    return AuthorDetail(a, [
      for (final p in await loadAllPitsOrdered())
        if (byPit.containsKey(p.id)) (p, byPit[p.id]!),
    ]);
  }

  Stream<AuthorDetail?> watchAuthorDetail(String id) => watchAssembled(this, {
    authors,
    fanArts,
    pits,
    pitSortSettings,
  }, () => loadAuthorDetail(id));

  // ---- 寫 ----

  /// 新增作者（排在最前面）。回傳 id。
  Future<String> addAuthor(AuthorsCompanion data) async {
    final first =
        await (select(authors)
              ..where((a) => a.deletedAt.isNull())
              ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    final row = await into(authors).insertReturning(
      data.copyWith(sortOrder: Value((first?.sortOrder ?? 1) - 1)),
    );
    return row.id;
  }

  /// 更新作者；名字有變時同人圖的作者文字一起換（本機快取）。
  Future<void> updateAuthor(String id, AuthorsCompanion data) async {
    await (update(authors)..where((a) => a.id.equals(id))).write(
      data.copyWith(updatedAt: Value(DateTime.now())),
    );
    if (data.name.present) await refreshAuthorNameCache();
  }

  /// 刪除作者。同人圖留著，作者欄變回空白（同人圖要重新上傳，別的裝置才會清空）。
  Future<void> deleteAuthors(Iterable<String> ids) {
    final list = ids.toList();
    if (list.isEmpty) return Future.value();
    final now = DateTime.now();
    return transaction(() async {
      await (update(authors)..where((a) => a.id.isIn(list))).write(
        AuthorsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (update(fanArts)..where((f) => f.authorId.isIn(list))).write(
        FanArtsCompanion(
          authorId: const Value(null),
          author: const Value(''),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// 手動排序（全部作者的新順序）。只動順序有變的作者。
  Future<void> reorderAuthors(List<String> ids) async {
    final now = DateTime.now();
    final cur = {for (final a in await loadAuthors()) a.id: a.sortOrder};
    await transaction(() async {
      for (final (i, id) in ids.indexed) {
        if (cur[id] == i) continue;
        await (update(authors)..where((a) => a.id.equals(id))).write(
          AuthorsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }
}
