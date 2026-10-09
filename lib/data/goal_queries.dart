import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart';

class GoalView {
  const GoalView({
    required this.goal,
    required this.pit,
    required this.tags,
    required this.progress,
  });

  final Goal goal;
  final Pit? pit;
  final List<Tag> tags;
  final int progress;

  int get target => goal.count;
  bool get done => progress >= target;
  double get ratio => target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  /// 自訂名稱；留空為 null，由 UI 層（`goalDisplayName`）依種類／數量／互動量自動命名。
  String? get customName => goalCustomName(goal);
}

/// 目標依進度百分比由高到低排列，已達成（100% 以上）的沉到最底；
/// 同百分比保持原本順序（建立時間，D-022）。年度、月度共用。
List<GoalView> sortGoalsByProgress(Iterable<GoalView> goals) {
  final list = goals.toList();
  final order = {for (var i = 0; i < list.length; i++) list[i]: i};
  list.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (!a.done) {
      final c = b.ratio.compareTo(a.ratio);
      if (c != 0) return c;
    }
    return order[a]!.compareTo(order[b]!);
  });
  return list;
}

/// 使用者填的目標名稱（去頭尾空白）；沒填為 null。
/// 自動命名的文字在 UI 層由 ARB 組出（`goalDisplayName`）。
String? goalCustomName(Goal g) {
  final custom = g.name?.trim();
  return (custom != null && custom.isNotEmpty) ? custom : null;
}

/// 時間軸上的一筆（腦洞／草稿／成圖）。
class TimelineItem {
  const TimelineItem({
    required this.kind,
    required this.id,
    required this.pitId,
    required this.time,
    required this.title,
    this.file,
    this.files = const [],
    this.text = '',
    this.tagNames = const [],
    this.actualLikes = 0,
    this.targetLikes = 0,
  });

  final GoalKind kind;
  final String id;
  final String pitId;
  final DateTime time;
  final String title;
  final String? file;

  /// 所有圖片（時間軸顯示縮圖列）。
  final List<String> files;

  /// 內文（腦洞顯示）。
  final String text;
  final List<String> tagNames;

  /// 成圖的互動量。
  final int actualLikes;
  final int targetLikes;
}

extension ReviewSettingAlign on ReviewSetting {
  /// 月份對齊（D-039）：沒設定時，月份在圖上＝靠左（start），在空白位置＝置中（center）。
  String get effectiveMonthAlign =>
      monthAlign ?? (monthOnImage ? 'start' : 'center');
}

DateTime monthStart(int year, int month) => DateTime(year, month);
DateTime monthEnd(int year, int month) => DateTime(year, month + 1);

extension GoalQueries on AppDatabase {
  Set<TableInfo> get _goalTables => {
    goals,
    pits,
    tags,
    tagLinks,
    ideas,
    drafts,
    pieces,
  };

  Future<int> _progress(Goal g, List<Tag> goalTags) async {
    final start = g.period == GoalPeriod.year
        ? DateTime(g.year)
        : monthStart(g.year, g.month ?? 1);
    final end = g.period == GoalPeriod.year
        ? DateTime(g.year + 1)
        : monthEnd(g.year, g.month ?? 1);
    final tagIds = goalTags.map((t) => t.id).toList();

    Future<bool> hasAllTags(TagTarget type, String id) async {
      if (tagIds.isEmpty) return true;
      final rows =
          await (select(tagLinks)..where(
                (l) => l.targetType.equalsValue(type) & l.targetId.equals(id),
              ))
              .get();
      final have = rows.map((r) => r.tagId).toSet();
      return tagIds.every(have.contains);
    }

    var n = 0;
    switch (g.kind) {
      case GoalKind.idea:
        final rows =
            await (select(ideas)..where(
                  (i) =>
                      i.deletedAt.isNull() &
                      i.createdAt.isBiggerOrEqualValue(start) &
                      i.createdAt.isSmallerThanValue(end) &
                      (g.pitId == null
                          ? const Constant(true)
                          : i.pitId.equals(g.pitId!)),
                ))
                .get();
        for (final r in rows) {
          if (await hasAllTags(TagTarget.idea, r.id)) n++;
        }
      case GoalKind.draft:
        final rows =
            await (select(drafts)..where(
                  (i) =>
                      i.deletedAt.isNull() &
                      i.createdAt.isBiggerOrEqualValue(start) &
                      i.createdAt.isSmallerThanValue(end) &
                      (g.pitId == null
                          ? const Constant(true)
                          : i.pitId.equals(g.pitId!)),
                ))
                .get();
        for (final r in rows) {
          if (await hasAllTags(TagTarget.draft, r.id)) n++;
        }
      case GoalKind.piece:
        final rows =
            await (select(pieces)..where(
                  (i) =>
                      i.deletedAt.isNull() &
                      i.finishedAt.isBiggerOrEqualValue(start) &
                      i.finishedAt.isSmallerThanValue(end) &
                      (g.pitId == null
                          ? const Constant(true)
                          : i.pitId.equals(g.pitId!)) &
                      // 互動量門檻只計算已公開發佈的成圖（D-046）。
                      (g.requireLikes == null
                          ? const Constant(true)
                          : i.isPublished.equals(true) &
                                i.actualLikes.isBiggerOrEqualValue(
                                  g.requireLikes!,
                                )),
                ))
                .get();
        for (final r in rows) {
          if (await hasAllTags(TagTarget.piece, r.id)) n++;
        }
    }
    return n;
  }

  Future<GoalView> _goalView(Goal g) async {
    final tagRows =
        await (select(tags)
                .join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
              ..where(
                tagLinks.targetType.equalsValue(TagTarget.goal) &
                    tagLinks.targetId.equals(g.id) &
                    tags.deletedAt.isNull(),
              ))
            .get();
    final goalTags = tagRows.map((r) => r.readTable(tags)).toList();
    final pit = g.pitId == null
        ? null
        : await (select(pits)
                ..where((p) => p.id.equals(g.pitId!) & p.deletedAt.isNull()))
              .getSingleOrNull();
    return GoalView(
      goal: g,
      pit: pit,
      tags: goalTags,
      progress: await _progress(g, goalTags),
    );
  }

  Stream<List<GoalView>> watchGoalViews(
    GoalPeriod period,
    int year, {
    int? month,
  }) {
    return watchAssembled(this, _goalTables, () async {
      final rows =
          await (select(goals)
                ..where(
                  (g) =>
                      g.deletedAt.isNull() &
                      g.period.equalsValue(period) &
                      g.year.equals(year) &
                      (month == null
                          ? const Constant(true)
                          : g.month.equals(month)),
                )
                ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
              .get();
      return sortGoalsByProgress([for (final r in rows) await _goalView(r)]);
    });
  }

  Future<String> saveGoal({
    String? id,
    required GoalPeriod period,
    required int year,
    int? month,
    String? name,
    required GoalKind kind,
    required int count,
    String? pitId,
    List<String> tagIds = const [],
    int? requireLikes,
  }) {
    final cleanName = (name == null || name.trim().isEmpty)
        ? null
        : name.trim();
    return transaction(() async {
      String goalId;
      if (id == null) {
        final row = await into(goals).insertReturning(
          GoalsCompanion.insert(
            period: period,
            year: year,
            month: Value(month),
            name: Value(cleanName),
            kind: kind,
            count: count,
            pitId: Value(pitId),
            requireLikes: Value(kind == GoalKind.piece ? requireLikes : null),
          ),
        );
        goalId = row.id;
      } else {
        goalId = id;
        await (update(goals)..where((g) => g.id.equals(id))).write(
          GoalsCompanion(
            name: Value(cleanName),
            kind: Value(kind),
            count: Value(count),
            pitId: Value(pitId),
            requireLikes: Value(kind == GoalKind.piece ? requireLikes : null),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      // 未選坑時不能選 tag。
      await (delete(tagLinks)..where(
            (l) =>
                l.targetType.equalsValue(TagTarget.goal) &
                l.targetId.equals(goalId),
          ))
          .go();
      if (pitId != null) {
        for (final t in tagIds) {
          await into(tagLinks).insert(
            TagLinksCompanion.insert(
              tagId: t,
              targetType: TagTarget.goal,
              targetId: goalId,
            ),
          );
        }
      }
      return goalId;
    });
  }

  Future<void> deleteGoal(String id) {
    final now = DateTime.now();
    return (update(goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<Goal?> goalById(String id) =>
      (select(goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<List<String>> goalTagIds(String goalId) async {
    final rows =
        await (select(tagLinks)..where(
              (l) =>
                  l.targetType.equalsValue(TagTarget.goal) &
                  l.targetId.equals(goalId),
            ))
            .get();
    return rows.map((r) => r.tagId).toList();
  }

  // ---- 月曆 / 時間軸 ----

  /// 某月每天最新一張成圖（作為月曆上的圓形日期圖）。key＝日（1~31）。
  Stream<Map<int, String>> watchMonthCovers(int year, int month) {
    return watchAssembled(this, {pieces, entityImages}, () async {
      final rows =
          await (select(pieces)
                ..where(
                  (p) =>
                      p.deletedAt.isNull() &
                      p.finishedAt.isBiggerOrEqualValue(
                        monthStart(year, month),
                      ) &
                      p.finishedAt.isSmallerThanValue(monthEnd(year, month)),
                )
                ..orderBy([(p) => OrderingTerm.asc(p.finishedAt)]))
              .get();
      final out = <int, String>{};
      for (final p in rows) {
        final im =
            await (select(entityImages)
                  ..where(
                    (e) =>
                        e.ownerType.equalsValue(OwnerType.piece) &
                        e.ownerId.equals(p.id),
                  )
                  ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)])
                  ..limit(1))
                .getSingleOrNull();
        if (im != null) out[p.finishedAt.day] = im.imageFile; // 後面的覆蓋前面＝最晚一張
      }
      return out;
    });
  }

  /// 某天所有坑的腦洞／草稿／成圖，時間新到舊。
  Stream<List<TimelineItem>> watchTimeline(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return watchAssembled(
      this,
      {ideas, drafts, pieces, entityImages, tags, tagLinks},
      () async {
        Future<List<String>> images(OwnerType t, String id) async =>
            (await (select(entityImages)
                      ..where(
                        (e) =>
                            e.ownerType.equalsValue(t) & e.ownerId.equals(id),
                      )
                      ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
                    .get())
                .map((e) => e.imageFile)
                .toList();

        Future<List<String>> tagNames(TagTarget t, String id) async {
          final q =
              select(
                  tags,
                ).join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
                ..where(
                  tagLinks.targetType.equalsValue(t) &
                      tagLinks.targetId.equals(id) &
                      tags.deletedAt.isNull(),
                )
                ..orderBy([OrderingTerm.asc(tags.name)]);
          return (await q.get()).map((r) => r.readTable(tags).name).toList();
        }

        final items = <TimelineItem>[];
        for (final i
            in await (select(ideas)..where(
                  (x) =>
                      x.deletedAt.isNull() &
                      x.createdAt.isBiggerOrEqualValue(start) &
                      x.createdAt.isSmallerThanValue(end),
                ))
                .get()) {
          final files = await images(OwnerType.idea, i.id);
          items.add(
            TimelineItem(
              kind: GoalKind.idea,
              id: i.id,
              pitId: i.pitId,
              time: i.createdAt,
              title: i.title,
              file: files.isEmpty ? null : files.first,
              files: files,
              text: i.body,
              tagNames: await tagNames(TagTarget.idea, i.id),
            ),
          );
        }
        for (final d
            in await (select(drafts)..where(
                  (x) =>
                      x.deletedAt.isNull() &
                      x.createdAt.isBiggerOrEqualValue(start) &
                      x.createdAt.isSmallerThanValue(end),
                ))
                .get()) {
          final files = await images(OwnerType.draft, d.id);
          items.add(
            TimelineItem(
              kind: GoalKind.draft,
              id: d.id,
              pitId: d.pitId,
              time: d.createdAt,
              title: d.title ?? '',
              file: files.isEmpty ? null : files.first,
              files: files,
              tagNames: await tagNames(TagTarget.draft, d.id),
            ),
          );
        }
        for (final p
            in await (select(pieces)..where(
                  (x) =>
                      x.deletedAt.isNull() &
                      x.finishedAt.isBiggerOrEqualValue(start) &
                      x.finishedAt.isSmallerThanValue(end),
                ))
                .get()) {
          final files = await images(OwnerType.piece, p.id);
          items.add(
            TimelineItem(
              kind: GoalKind.piece,
              id: p.id,
              pitId: p.pitId,
              time: p.finishedAt,
              title: p.title,
              file: files.isEmpty ? null : files.first,
              files: files,
              tagNames: await tagNames(TagTarget.piece, p.id),
              actualLikes: p.actualLikes,
              targetLikes: p.targetLikes,
            ),
          );
        }
        items.sort((a, b) => b.time.compareTo(a.time));
        return items;
      },
    );
  }

  // ---- 年度回顧 ----

  /// 該年每月的成圖圖片（最新的在前），供回顧挑選與預設。key＝月（1~12）。
  Future<Map<int, List<String>>> pieceImagesByMonth(int year) async {
    final rows =
        await (select(pieces)
              ..where(
                (p) =>
                    p.deletedAt.isNull() &
                    p.finishedAt.isBiggerOrEqualValue(DateTime(year)) &
                    p.finishedAt.isSmallerThanValue(DateTime(year + 1)),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.finishedAt)]))
            .get();
    final out = <int, List<String>>{};
    for (final p in rows) {
      final ims =
          await (select(entityImages)
                ..where(
                  (e) =>
                      e.ownerType.equalsValue(OwnerType.piece) &
                      e.ownerId.equals(p.id),
                )
                ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
              .get();
      for (final im in ims) {
        out.putIfAbsent(p.finishedAt.month, () => []).add(im.imageFile);
      }
    }
    return out;
  }

  /// 該年每月的回顧圖（key＝月 1~12，只含有成圖圖片的月份，或被手動設為空白的月份）。
  ///
  /// 解析順序（D-056）：
  /// 1. 手動挑過的圖（`YearReviewMonths.imageFile` 非空）→ 就是它；
  /// 2. 手動設為空白（`setReviewMonth(..., null)`，資料列存在且 imageFile 為 null）→ 值為 null；
  /// 3. 其餘（沒有資料列、或被 [setReviewMonthImage] 清回預設）→ 預設代表圖：
  ///    該月**互動量 `actualLikes` 最高**的成圖的第一張圖，一樣高就取 `finishedAt` 最新的。
  ///    該月沒有任何有圖的成圖 → 這個月不在結果裡。
  ///
  /// 候選成圖包含私稿與商稿（回顧是自己看的年度總結，不分公開與否），已刪除的不算。
  Stream<Map<int, String?>> watchReviewMonths(int year) {
    return watchAssembled(
      this,
      {pieces, entityImages, yearReviewMonths},
      () async {
        final out = <int, String?>{};
        final byMonth = await _reviewCandidates(year);
        for (final e in byMonth.entries) {
          out[e.key] = defaultReviewPiece(e.value)?.file;
        }
        for (final r in await (select(
          yearReviewMonths,
        )..where((m) => m.year.equals(year))).get()) {
          if (r.imageFile == null) {
            out[r.month] = null; // 手動空白
          } else if (r.imageFile!.isNotEmpty) {
            out[r.month] = r.imageFile;
          }
        }
        return out;
      },
    );
  }

  /// 某月所有「完成日期落在該月、至少有一張圖」的成圖，供「選擇 N 月的圖片」sheet。
  /// 排序：`finishedAt` 新到舊。包含私稿與商稿。
  Stream<List<ReviewMonthPiece>> watchReviewMonthPieces(int year, int month) {
    return watchAssembled(this, {
      pieces,
      entityImages,
    }, () async => (await _reviewCandidates(year))[month] ?? const []);
  }

  /// 每月的候選數與目前使用的圖（供年度回顧格決定長按是否有反應：[ReviewMonthSummary.canPick]）。
  /// 只含有候選成圖的月份。
  Stream<Map<int, ReviewMonthSummary>> watchReviewMonthSummaries(int year) {
    return watchAssembled(
      this,
      {pieces, entityImages, yearReviewMonths},
      () async {
        final byMonth = await _reviewCandidates(year);
        final rows = {
          for (final r in await (select(
            yearReviewMonths,
          )..where((m) => m.year.equals(year))).get())
            r.month: r,
        };
        return {
          for (final e in byMonth.entries)
            e.key: () {
              final r = rows[e.key];
              final manual = r != null && (r.imageFile?.isNotEmpty ?? true);
              return ReviewMonthSummary(
                pieceCount: e.value.length,
                file: manual ? r.imageFile : defaultReviewPiece(e.value)?.file,
                isManual: manual,
              );
            }(),
        };
      },
    );
  }

  /// 該年每月候選成圖（有圖、未刪除），月內 `finishedAt` 新到舊。
  Future<Map<int, List<ReviewMonthPiece>>> _reviewCandidates(int year) async {
    final rows =
        await (select(pieces)
              ..where(
                (p) =>
                    p.deletedAt.isNull() &
                    p.finishedAt.isBiggerOrEqualValue(DateTime(year)) &
                    p.finishedAt.isSmallerThanValue(DateTime(year + 1)),
              )
              ..orderBy([(p) => OrderingTerm.desc(p.finishedAt)]))
            .get();
    final out = <int, List<ReviewMonthPiece>>{};
    for (final p in rows) {
      final first =
          await (select(entityImages)
                ..where(
                  (e) =>
                      e.ownerType.equalsValue(OwnerType.piece) &
                      e.ownerId.equals(p.id) &
                      e.deletedAt.isNull(),
                )
                ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)])
                ..limit(1))
              .getSingleOrNull();
      if (first == null) continue;
      out
          .putIfAbsent(p.finishedAt.month, () => [])
          .add(
            ReviewMonthPiece(
              pieceId: p.id,
              title: p.title,
              file: first.imageFile,
              width: first.width,
              height: first.height,
              actualLikes: p.actualLikes,
              finishedAt: p.finishedAt,
            ),
          );
    }
    return out;
  }

  /// 手動指定某月的回顧圖（[file] 是圖片檔名，通常是 [ReviewMonthPiece.file]）。
  /// [file] 為 null＝**清回預設**（互動量最高）。要「刻意留空」請用 [setReviewMonth] 傳 null。
  Future<void> setReviewMonthImage(int year, int month, String? file) {
    return setReviewMonth(year, month, file ?? '');
  }

  Future<void> setReviewMonth(int year, int month, String? file) {
    return into(yearReviewMonths).insertOnConflictUpdate(
      YearReviewMonthsCompanion(
        year: Value(year),
        month: Value(month),
        imageFile: Value(file),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<ReviewSetting> watchReviewSettings(int year) {
    return (select(
      reviewSettings,
    )..where((s) => s.year.equals(year))).watchSingleOrNull().map(
      (r) =>
          r ??
          ReviewSetting(
            year: year,
            columns: 4,
            ratio: '1:1',
            monthFormat: 'Jan',
            monthOnImage: true,
          ),
    );
  }

  /// 儲存回顧排版；順便蓋上 updatedAt 讓同步判斷新舊。
  Future<void> saveReviewSettings(ReviewSetting s) {
    return into(reviewSettings)
        .insertOnConflictUpdate(s.copyWith(updatedAt: Value(DateTime.now())));
  }
}

/// 回顧某月的一張候選成圖。
class ReviewMonthPiece {
  const ReviewMonthPiece({
    required this.pieceId,
    required this.title,
    required this.file,
    required this.width,
    required this.height,
    required this.actualLikes,
    required this.finishedAt,
  });
  final String pieceId;
  final String title;

  /// 成圖的第一張圖。
  final String file;
  final int width;
  final int height;
  final int actualLikes;
  final DateTime finishedAt;
}

/// 預設代表圖：互動量最高，一樣高取 `finishedAt` 最新（再一樣取 id 較大者，結果才穩定）。
ReviewMonthPiece? defaultReviewPiece(Iterable<ReviewMonthPiece> candidates) {
  ReviewMonthPiece? best;
  for (final c in candidates) {
    if (best == null) {
      best = c;
      continue;
    }
    final byLikes = c.actualLikes.compareTo(best.actualLikes);
    final byTime = c.finishedAt.compareTo(best.finishedAt);
    if (byLikes > 0 ||
        (byLikes == 0 &&
            (byTime > 0 ||
                (byTime == 0 && c.pieceId.compareTo(best.pieceId) > 0)))) {
      best = c;
    }
  }
  return best;
}

class ReviewMonthSummary {
  const ReviewMonthSummary({
    required this.pieceCount,
    required this.file,
    required this.isManual,
  });

  /// 該月有圖的成圖數。
  final int pieceCount;

  /// 目前使用的圖（手動空白時為 null）。
  final String? file;

  /// 是否為手動挑的（含手動空白）。
  final bool isManual;

  /// 多於一張才能挑（D-056：只有一張時長按沒有反應）。
  bool get canPick => pieceCount > 1;
}
