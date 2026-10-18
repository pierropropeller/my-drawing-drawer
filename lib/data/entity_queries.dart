import 'dart:async';

import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'media.dart';
import 'payment.dart';

/// 腦洞狀態由關係推導，不儲存（HANDOFF 3.4）。
enum IdeaStatus { open, hatching, hatched }

class ImageRef {
  const ImageRef(
    this.file,
    this.width,
    this.height, {
    this.kind = MediaKind.image,
    this.durationMs,
    this.poster,
  });
  final String file;
  final int width;
  final int height;

  /// 媒體種類（D-080）：圖片／GIF／影片。
  final MediaKind kind;

  /// 影片長度（毫秒）；只有影片。
  final int? durationMs;

  /// 影片第一格截圖的檔名；影片尚未產生截圖時為 null。
  final String? poster;

  double get aspect => (width > 0 && height > 0) ? width / height : 1;

  bool get isVideo => kind == MediaKind.video;
  bool get isGif => kind == MediaKind.gif;

  /// 需要靜態圖的地方（封面、縮圖）用的檔名：影片＝[poster]（可能是 null），其餘＝[file]。
  String? get staticFile => staticFileOf(kind, file, poster);

  /// 編輯表單把既有圖片原樣送回 `saveXxx` 用（保留媒體欄位）。
  NewImage toNewImage() => NewImage(
    file: file,
    width: width,
    height: height,
    kind: kind,
    durationMs: durationMs,
    posterFile: poster,
  );
}

/// 腦洞／草稿／成圖／推活的圖片列 → 視圖模型。
ImageRef entityImageRef(EntityImage r) => ImageRef(
  r.imageFile,
  r.width,
  r.height,
  kind: r.kind,
  durationMs: r.durationMs,
  poster: r.posterFile,
);

class IdeaView {
  const IdeaView({
    required this.idea,
    required this.images,
    required this.tags,
    required this.draftIds,
    required this.pieceIds,
  });

  final Idea idea;
  final List<ImageRef> images;
  final List<Tag> tags;
  final List<String> draftIds;
  final List<String> pieceIds;

  IdeaStatus get status => pieceIds.isNotEmpty
      ? IdeaStatus.hatched
      : (draftIds.isNotEmpty ? IdeaStatus.hatching : IdeaStatus.open);
}

/// 關聯對象的摘要（草稿的「關聯成圖」、成圖的「關聯草稿」顯示用）。
class LinkedItem {
  const LinkedItem({required this.id, this.title, this.firstImage});
  final String id;

  /// 成圖一定有標題；草稿可能沒有（顯示「無標題」由 UI 決定）。
  final String? title;
  final ImageRef? firstImage;
}

class DraftView {
  const DraftView({
    required this.draft,
    required this.images,
    required this.tags,
    required this.ideaIds,
    required this.pieceIds,
    this.linkedPieces = const [],
  });

  final Draft draft;
  final List<ImageRef> images;
  final List<Tag> tags;
  final List<String> ideaIds;
  final List<String> pieceIds;

  /// 關聯的成圖（D-069），完成日期新到舊，順序同 [pieceIds]；已刪除的成圖不含。
  final List<LinkedItem> linkedPieces;

  /// 純圖草稿：沒有標題、內文、tag、連接。
  bool get imageOnly =>
      (draft.title ?? '').isEmpty &&
      (draft.body ?? '').isEmpty &&
      tags.isEmpty &&
      ideaIds.isEmpty &&
      pieceIds.isEmpty;
}

class SocialLink {
  const SocialLink(this.platform, this.url);
  final String platform;
  final String url;
}

class PieceView {
  const PieceView({
    required this.piece,
    required this.images,
    required this.tags,
    required this.links,
    required this.ideaIds,
    required this.draftIds,
    this.linkedDrafts = const [],
  });

  final Piece piece;
  final List<ImageRef> images;
  final List<Tag> tags;
  final List<SocialLink> links;
  final List<String> ideaIds;
  final List<String> draftIds;

  /// 關聯的草稿（D-069），日期新到舊，順序同 [draftIds]；已刪除的草稿不含。
  final List<LinkedItem> linkedDrafts;

  /// 商稿收款狀態（只有 [Piece.isCommission] 時有意義）。
  PaymentState get payment =>
      paymentStateOf(amount: piece.amount, received: piece.receivedAmount);
}

/// 先取一次，之後每當相關資料表有變動就重新取。
///
/// 先訂閱資料表變動、再取第一次：取資料的期間（手機上可能要好幾百毫秒）有寫入的話，
/// 不會漏掉，取完會再取一次。變動連續來時合併成一次；單次取資料失敗只送出錯誤，之後的變動仍會更新。
Stream<T> watchAssembled<T>(
  AppDatabase db,
  Set<TableInfo> tables,
  Future<T> Function() load,
) {
  late final StreamController<T> out;
  StreamSubscription<void>? sub;
  var running = false;
  var dirty = false;
  var closed = false;

  Future<void> pump() async {
    if (running) {
      dirty = true;
      return;
    }
    running = true;
    try {
      do {
        dirty = false;
        try {
          final value = await load();
          if (closed) return;
          out.add(value);
        } catch (e, st) {
          if (closed) return;
          out.addError(e, st);
        }
      } while (dirty && !closed);
    } finally {
      running = false;
    }
  }

  out = StreamController<T>(
    onListen: () {
      sub = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => unawaited(pump()));
      unawaited(pump());
    },
    onCancel: () {
      closed = true;
      // 不等取消完成：在假時鐘的測試裡等它會卡住，真機上也沒有需要等的。
      unawaited(sub?.cancel());
      sub = null;
    },
  );
  return out.stream;
}

extension EntityQueries on AppDatabase {
  Set<TableInfo> get _ideaTables => {
    ideas,
    entityImages,
    tagLinks,
    tags,
    ideaDrafts,
    ideaPieces,
  };
  Set<TableInfo> get _draftTables => {
    drafts,
    pieces,
    entityImages,
    tagLinks,
    tags,
    ideaDrafts,
    draftPieces,
  };
  Set<TableInfo> get _pieceTables => {
    pieces,
    drafts,
    entityImages,
    tagLinks,
    tags,
    pieceLinks,
    ideaPieces,
    draftPieces,
  };

  Future<List<ImageRef>> _imagesOf(OwnerType type, String id) async {
    final rows =
        await (select(entityImages)
              ..where(
                (e) => e.ownerType.equalsValue(type) & e.ownerId.equals(id),
              )
              ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
            .get();
    return [for (final r in rows) entityImageRef(r)];
  }

  /// 腦洞／草稿的日期（D-070）：
  /// - [given] 為 null：新增＝現在；編輯＝維持 [previous]。
  /// - [given] 是「只有日期」（00:00:00，日期選擇器選出來的）：與 [previous] 同一天就沿用
  ///   [previous]（保留原本的時間，時間軸順序不亂跳）；是今天就取現在；其他天維持 00:00。
  /// - 其他（帶時間）原樣儲存，例如目標日頁 ＋ 傳進來的「現在」。
  DateTime _resolveDate(DateTime? given, {DateTime? previous}) {
    if (given == null) return previous ?? DateTime.now();
    final dateOnly =
        given.hour == 0 &&
        given.minute == 0 &&
        given.second == 0 &&
        given.millisecond == 0;
    if (!dateOnly) return given;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (previous != null && sameDay(previous, given)) return previous;
    final now = DateTime.now();
    return sameDay(now, given) ? now : given;
  }

  Future<List<Tag>> _tagsOf(TagTarget type, String id) async {
    final q =
        select(tags)
            .join([innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id))])
          ..where(
            tagLinks.targetType.equalsValue(type) &
                tagLinks.targetId.equals(id) &
                tags.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(tags.name)]);
    return (await q.get()).map((r) => r.readTable(tags)).toList();
  }

  /// 以整組替換圖片清單；檔名相同的沿用原本的列（id 不變，坑封面才不會因為編輯而失效）。
  Future<void> replaceEntityImages(
    OwnerType type,
    String id,
    List<NewImage> images,
  ) async {
    final existing =
        await (select(entityImages)..where(
              (e) => e.ownerType.equalsValue(type) & e.ownerId.equals(id),
            ))
            .get();
    final keep = <String, EntityImage>{};
    for (final r in existing) {
      if (images.any((n) => n.file == r.imageFile) &&
          !keep.containsKey(r.imageFile)) {
        keep[r.imageFile] = r;
      }
    }
    final keepIds = keep.values.map((r) => r.id).toSet();
    await (delete(entityImages)..where(
          (e) =>
              e.ownerType.equalsValue(type) &
              e.ownerId.equals(id) &
              e.id.isIn(keepIds).not(),
        ))
        .go();
    for (var i = 0; i < images.length; i++) {
      final old = keep[images[i].file];
      if (old != null) {
        // 媒體欄位只在新資料有資訊時才覆寫：表單把舊圖原樣送回時（只帶檔名與寬高）
        // 不會把影片洗回圖片，而同步進來的新截圖／長度仍能補上。
        final n = images[i];
        await (update(entityImages)..where((e) => e.id.equals(old.id))).write(
          EntityImagesCompanion(
            sortOrder: Value(i),
            width: Value(n.width),
            height: Value(n.height),
            kind: n.kind == MediaKind.image
                ? const Value.absent()
                : Value(n.kind),
            durationMs: n.durationMs == null
                ? const Value.absent()
                : Value(n.durationMs),
            posterFile: n.posterFile == null
                ? const Value.absent()
                : Value(n.posterFile),
          ),
        );
      } else {
        await into(entityImages).insert(
          EntityImagesCompanion.insert(
            ownerType: type,
            ownerId: id,
            imageFile: images[i].file,
            width: Value(images[i].width),
            height: Value(images[i].height),
            kind: Value(images[i].kind),
            durationMs: Value(images[i].durationMs),
            posterFile: Value(images[i].posterFile),
            sortOrder: Value(i),
          ),
        );
      }
    }
  }

  // ---------- 一次性載入（搜尋等組合查詢用）----------
  Future<List<IdeaView>> loadIdeaViews(String pitId) async => [
    for (final r
        in await (select(ideas)
              ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
              ..orderBy(_ideaByDateDesc))
            .get())
      await _ideaView(r),
  ];

  Future<List<DraftView>> loadDraftViews(String pitId) async => [
    for (final r
        in await (select(drafts)
              ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
              ..orderBy(_draftByDateDesc))
            .get())
      await _draftView(r),
  ];

  Future<List<PieceView>> loadPieceViews(String pitId) async => [
    for (final r
        in await (select(pieces)
              ..where((p) => p.pitId.equals(pitId) & p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
            .get())
      await _pieceView(r),
  ];

  // 腦洞／草稿列表：日期新到舊（D-070），同日以建立時間新到舊。
  List<OrderClauseGenerator<$IdeasTable>> get _ideaByDateDesc => [
    (i) => OrderingTerm.desc(i.date),
    (i) => OrderingTerm.desc(i.createdAt),
    (i) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
  ];
  List<OrderClauseGenerator<$DraftsTable>> get _draftByDateDesc => [
    (d) => OrderingTerm.desc(d.date),
    (d) => OrderingTerm.desc(d.createdAt),
    (d) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
  ];

  // ---------- 腦洞 ----------
  Future<IdeaView> _ideaView(Idea i) async => IdeaView(
    idea: i,
    images: await _imagesOf(OwnerType.idea, i.id),
    tags: await _tagsOf(TagTarget.idea, i.id),
    draftIds:
        (await (select(ideaDrafts)..where((x) => x.ideaId.equals(i.id))).get())
            .map((r) => r.draftId)
            .toList(),
    pieceIds:
        (await (select(ideaPieces)..where((x) => x.ideaId.equals(i.id))).get())
            .map((r) => r.pieceId)
            .toList(),
  );

  Stream<List<IdeaView>> watchIdeaViews(String pitId, {String? tagId}) {
    return watchAssembled(this, _ideaTables, () async {
      final rows =
          await (select(ideas)
                ..where((i) => i.pitId.equals(pitId) & i.deletedAt.isNull())
                ..orderBy(_ideaByDateDesc))
              .get();
      final views = [for (final r in rows) await _ideaView(r)];
      return tagId == null
          ? views
          : views.where((v) => v.tags.any((t) => t.id == tagId)).toList();
    });
  }

  Stream<IdeaView?> watchIdeaView(String id) {
    return watchAssembled(this, _ideaTables, () async {
      final r =
          await (select(ideas)
                ..where((i) => i.id.equals(id) & i.deletedAt.isNull()))
              .getSingleOrNull();
      return r == null ? null : await _ideaView(r);
    });
  }

  Future<String> saveIdea({
    String? id,
    required String pitId,
    required String title,
    required String body,
    required List<NewImage> images,
    required List<String> tagIds,
    required List<String> draftIds,
    required List<String> pieceIds,
    DateTime? date,
    DateTime? createdAt, // 相容舊呼叫：新增且沒給 date 時當作 date
  }) {
    return transaction(() async {
      String ideaId;
      if (id == null) {
        final row = await into(ideas).insertReturning(
          IdeasCompanion.insert(
            pitId: pitId,
            title: title,
            body: Value(body),
            date: Value(_resolveDate(date ?? createdAt)),
            createdAt: createdAt == null
                ? const Value.absent()
                : Value(createdAt),
          ),
        );
        ideaId = row.id;
      } else {
        ideaId = id;
        final old = await (select(
          ideas,
        )..where((i) => i.id.equals(id))).getSingle();
        await (update(ideas)..where((i) => i.id.equals(id))).write(
          IdeasCompanion(
            title: Value(title),
            body: Value(body),
            date: Value(_resolveDate(date, previous: old.date)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await replaceEntityImages(OwnerType.idea, ideaId, images);
      await setTags(TagTarget.idea, ideaId, tagIds);
      await setIdeaDrafts(ideaId, draftIds);
      await setIdeaPieces(ideaId, pieceIds);
      return ideaId;
    });
  }

  Future<void> setIdeaDrafts(String ideaId, List<String> draftIds) async {
    await (delete(ideaDrafts)..where((x) => x.ideaId.equals(ideaId))).go();
    for (final d in draftIds) {
      await into(ideaDrafts)
          .insert(IdeaDraftsCompanion.insert(ideaId: ideaId, draftId: d));
    }
  }

  Future<void> setIdeaPieces(String ideaId, List<String> pieceIds) async {
    await (delete(ideaPieces)..where((x) => x.ideaId.equals(ideaId))).go();
    for (final p in pieceIds) {
      await into(ideaPieces)
          .insert(IdeaPiecesCompanion.insert(ideaId: ideaId, pieceId: p));
    }
  }

  Future<void> deleteIdeas(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(ideas)..where((i) => i.id.isIn(ids))).write(
        IdeasCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (delete(ideaDrafts)..where((x) => x.ideaId.isIn(ids))).go();
      await (delete(ideaPieces)..where((x) => x.ideaId.isIn(ids))).go();
    });
  }

  // ---------- 草稿 ----------
  Future<DraftView> _draftView(Draft d) async {
    final pieceLinks = await _livePieceLinks(d.id);
    return DraftView(
      draft: d,
      images: await _imagesOf(OwnerType.draft, d.id),
      tags: await _tagsOf(TagTarget.draft, d.id),
      ideaIds:
          (await (select(
                ideaDrafts,
              )..where((x) => x.draftId.equals(d.id))).get())
              .map((r) => r.ideaId)
              .toList(),
      pieceIds: [for (final p in pieceLinks) p.id],
      linkedPieces: pieceLinks,
    );
  }

  /// 草稿關聯的成圖（略過已刪除的）。
  Future<List<LinkedItem>> _livePieceLinks(String draftId) async {
    final ids = (await (select(
      draftPieces,
    )..where((x) => x.draftId.equals(draftId))).get()).map((r) => r.pieceId);
    final found = <(Piece, LinkedItem)>[];
    for (final id in ids) {
      final p =
          await (select(pieces)
                ..where((x) => x.id.equals(id) & x.deletedAt.isNull()))
              .getSingleOrNull();
      if (p == null) continue;
      final im = await _imagesOf(OwnerType.piece, id);
      found.add((
        p,
        LinkedItem(
          id: id,
          title: p.title,
          firstImage: im.isEmpty ? null : im.first,
        ),
      ));
    }
    // 順序固定：完成日期新到舊（關係表本身沒有順序）。
    found.sort((a, b) => b.$1.finishedAt.compareTo(a.$1.finishedAt));
    return [for (final f in found) f.$2];
  }

  /// 成圖關聯的草稿（略過已刪除的）。
  Future<List<LinkedItem>> _liveDraftLinks(String pieceId) async {
    final ids = (await (select(
      draftPieces,
    )..where((x) => x.pieceId.equals(pieceId))).get()).map((r) => r.draftId);
    final found = <(Draft, LinkedItem)>[];
    for (final id in ids) {
      final d =
          await (select(drafts)
                ..where((x) => x.id.equals(id) & x.deletedAt.isNull()))
              .getSingleOrNull();
      if (d == null) continue;
      final im = await _imagesOf(OwnerType.draft, id);
      found.add((
        d,
        LinkedItem(
          id: id,
          title: d.title,
          firstImage: im.isEmpty ? null : im.first,
        ),
      ));
    }
    // 順序固定：日期新到舊（關係表本身沒有順序）。
    found.sort((a, b) => b.$1.date.compareTo(a.$1.date));
    return [for (final f in found) f.$2];
  }

  /// [tagId]：只列出有這個 tag 的草稿（D-043）。
  Stream<List<DraftView>> watchDraftViews(String pitId, {String? tagId}) {
    return watchAssembled(this, _draftTables, () async {
      final rows =
          await (select(drafts)
                ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
                ..orderBy(_draftByDateDesc))
              .get();
      final views = [for (final r in rows) await _draftView(r)];
      return tagId == null
          ? views
          : views.where((v) => v.tags.any((t) => t.id == tagId)).toList();
    });
  }

  Stream<DraftView?> watchDraftView(String id) {
    return watchAssembled(this, _draftTables, () async {
      final r =
          await (select(drafts)
                ..where((d) => d.id.equals(id) & d.deletedAt.isNull()))
              .getSingleOrNull();
      return r == null ? null : await _draftView(r);
    });
  }

  Future<String> saveDraft({
    String? id,
    required String pitId,
    String? title,
    String? body,
    required List<NewImage> images,
    required List<String> tagIds,
    required List<String> ideaIds,
    List<String>? pieceIds, // null＝不動關聯成圖（D-069）
    DateTime? date,
    DateTime? createdAt, // 相容舊呼叫：新增且沒給 date 時當作 date
  }) {
    String? clean(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    return transaction(() async {
      String draftId;
      if (id == null) {
        final row = await into(drafts).insertReturning(
          DraftsCompanion.insert(
            pitId: pitId,
            title: Value(clean(title)),
            body: Value(clean(body)),
            date: Value(_resolveDate(date ?? createdAt)),
            createdAt: createdAt == null
                ? const Value.absent()
                : Value(createdAt),
          ),
        );
        draftId = row.id;
      } else {
        draftId = id;
        final old = await (select(
          drafts,
        )..where((d) => d.id.equals(id))).getSingle();
        await (update(drafts)..where((d) => d.id.equals(id))).write(
          DraftsCompanion(
            title: Value(clean(title)),
            body: Value(clean(body)),
            date: Value(_resolveDate(date, previous: old.date)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await replaceEntityImages(OwnerType.draft, draftId, images);
      await setTags(TagTarget.draft, draftId, tagIds);
      await setDraftIdeas(draftId, ideaIds);
      if (pieceIds != null) await setDraftPieces(draftId, pieceIds);
      return draftId;
    });
  }

  /// 連接關係由腦洞那邊擁有（同步時隨腦洞文件走），從草稿／成圖側修改時要更新腦洞的 updatedAt。
  Future<void> _touchIdeas(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    await (update(ideas)..where((i) => i.id.isIn(set))).write(
      IdeasCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// 草稿↔成圖的關係由**成圖**那邊擁有（同步時隨成圖文件走，文件有 draftIds），
  /// 所以從草稿側修改時要把受影響（原本的與新的）成圖的 updatedAt 往前蓋，另一台才拉得到。
  Future<void> _touchPieces(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    await (update(pieces)..where((p) => p.id.isIn(set))).write(
      PiecesCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// 以整組替換草稿的關聯成圖（D-069）；會更新受影響成圖的 updatedAt。
  Future<void> setDraftPieces(String draftId, List<String> pieceIds) async {
    final old = (await (select(
      draftPieces,
    )..where((x) => x.draftId.equals(draftId))).get()).map((r) => r.pieceId);
    await _touchPieces([...old, ...pieceIds]);
    await (delete(draftPieces)..where((x) => x.draftId.equals(draftId))).go();
    for (final p in pieceIds.toSet()) {
      await into(draftPieces)
          .insert(DraftPiecesCompanion.insert(draftId: draftId, pieceId: p));
    }
  }

  Future<void> setDraftIdeas(String draftId, List<String> ideaIds) async {
    final old = (await (select(
      ideaDrafts,
    )..where((x) => x.draftId.equals(draftId))).get()).map((r) => r.ideaId);
    await _touchIdeas([...old, ...ideaIds]);
    await (delete(ideaDrafts)..where((x) => x.draftId.equals(draftId))).go();
    for (final i in ideaIds) {
      await into(ideaDrafts)
          .insert(IdeaDraftsCompanion.insert(ideaId: i, draftId: draftId));
    }
  }

  Future<void> deleteDrafts(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(drafts)..where((d) => d.id.isIn(ids))).write(
        DraftsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      // 關係由腦洞／成圖擁有：它們的文件裡還記著這份草稿，要一併更新才會同步出去。
      await _touchIdeas(
        (await (select(
          ideaDrafts,
        )..where((x) => x.draftId.isIn(ids))).get()).map((r) => r.ideaId),
      );
      await _touchPieces(
        (await (select(
          draftPieces,
        )..where((x) => x.draftId.isIn(ids))).get()).map((r) => r.pieceId),
      );
      await (delete(ideaDrafts)..where((x) => x.draftId.isIn(ids))).go();
      await (delete(draftPieces)..where((x) => x.draftId.isIn(ids))).go();
    });
  }

  // ---------- 成圖 ----------
  Future<PieceView> _pieceView(Piece p) async {
    final draftLinks = await _liveDraftLinks(p.id);
    return PieceView(
      piece: p,
      images: await _imagesOf(OwnerType.piece, p.id),
      tags: await _tagsOf(TagTarget.piece, p.id),
      links:
          (await (select(pieceLinks)..where(
                    (l) => l.pieceId.equals(p.id) & l.deletedAt.isNull(),
                  ))
                  .get())
              .map((l) => SocialLink(l.platform, l.url))
              .toList(),
      ideaIds:
          (await (select(
                ideaPieces,
              )..where((x) => x.pieceId.equals(p.id))).get())
              .map((r) => r.ideaId)
              .toList(),
      draftIds: [for (final d in draftLinks) d.id],
      linkedDrafts: draftLinks,
    );
  }

  Stream<List<PieceView>> watchPieceViews(String pitId, {String? tagId}) {
    return watchAssembled(this, _pieceTables, () async {
      final rows =
          await (select(pieces)
                ..where((p) => p.pitId.equals(pitId) & p.deletedAt.isNull())
                ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
              .get();
      final views = [for (final r in rows) await _pieceView(r)];
      return tagId == null
          ? views
          : views.where((v) => v.tags.any((t) => t.id == tagId)).toList();
    });
  }

  Stream<PieceView?> watchPieceView(String id) {
    return watchAssembled(this, _pieceTables, () async {
      final r =
          await (select(pieces)
                ..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
              .getSingleOrNull();
      return r == null ? null : await _pieceView(r);
    });
  }

  Future<String> savePiece({
    String? id,
    required String pitId,
    required String title,
    required String body,
    required List<NewImage> images,
    required List<String> tagIds,
    required List<SocialLink> links,
    required int targetLikes,
    required DateTime finishedAt,
    required List<String> ideaIds,
    required List<String> draftIds,
    bool? isPublished,
    DateTime? publishedAt,
    bool? isCommission,
    String? client,
    double? amount,
    String? currency,
    double? receivedAmount,
    DateTime? dueAt,
  }) {
    // 兩組欄位各自獨立：傳了 [isPublished] 才寫「公開發佈」組（isPublished、publishedAt）；
    // 傳了 [isCommission] 才寫「商稿」組（isCommission、client、amount、currency、
    // receivedAmount、dueAt）。沒傳的組在編輯時保持原樣，新增時用預設（未公開、非商稿）。
    // 關閉開關時資料仍保留（UI 隱藏即可）。
    final writePublish = isPublished != null;
    final writeCommission = isCommission != null;
    final cleanClient = (client ?? '').trim();
    final cleanCurrency = (currency == null || currency.trim().isEmpty)
        ? 'CNY'
        : currency.trim();
    return transaction(() async {
      String pieceId;
      if (id == null) {
        final row = await into(pieces).insertReturning(
          PiecesCompanion.insert(
            pitId: pitId,
            title: title,
            body: Value(body),
            targetLikes: Value(targetLikes),
            finishedAt: Value(finishedAt),
            isPublished: Value(isPublished ?? false),
            publishedAt: Value(
              (isPublished ?? false)
                  ? (publishedAt ?? finishedAt)
                  : publishedAt,
            ),
            isCommission: Value(isCommission ?? false),
            client: Value(cleanClient),
            amount: Value(amount),
            currency: Value(cleanCurrency),
            receivedAmount: Value(receivedAmount ?? 0),
            dueAt: Value(dueAt),
          ),
        );
        pieceId = row.id;
      } else {
        pieceId = id;
        await (update(pieces)..where((p) => p.id.equals(id))).write(
          PiecesCompanion(
            title: Value(title),
            body: Value(body),
            targetLikes: Value(targetLikes),
            finishedAt: Value(finishedAt),
            isPublished: writePublish
                ? Value(isPublished)
                : const Value.absent(),
            publishedAt: writePublish
                ? Value(isPublished ? (publishedAt ?? finishedAt) : publishedAt)
                : const Value.absent(),
            isCommission: writeCommission
                ? Value(isCommission)
                : const Value.absent(),
            client: writeCommission ? Value(cleanClient) : const Value.absent(),
            amount: writeCommission ? Value(amount) : const Value.absent(),
            currency: writeCommission
                ? Value(cleanCurrency)
                : const Value.absent(),
            receivedAmount: writeCommission
                ? Value(receivedAmount ?? 0)
                : const Value.absent(),
            dueAt: writeCommission ? Value(dueAt) : const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await replaceEntityImages(OwnerType.piece, pieceId, images);
      await setTags(TagTarget.piece, pieceId, tagIds);
      await (delete(pieceLinks)..where((l) => l.pieceId.equals(pieceId))).go();
      for (final l in links) {
        await into(pieceLinks).insert(
          PieceLinksCompanion.insert(
            pieceId: pieceId,
            platform: l.platform,
            url: l.url,
          ),
        );
      }
      await setPieceIdeas(pieceId, ideaIds);
      await setPieceDrafts(pieceId, draftIds);
      return pieceId;
    });
  }

  Future<void> setPieceIdeas(String pieceId, List<String> ideaIds) async {
    final old = (await (select(
      ideaPieces,
    )..where((x) => x.pieceId.equals(pieceId))).get()).map((r) => r.ideaId);
    await _touchIdeas([...old, ...ideaIds]);
    await (delete(ideaPieces)..where((x) => x.pieceId.equals(pieceId))).go();
    for (final i in ideaIds) {
      await into(ideaPieces)
          .insert(IdeaPiecesCompanion.insert(ideaId: i, pieceId: pieceId));
    }
  }

  Future<void> setPieceDrafts(String pieceId, List<String> draftIds) async {
    await (delete(draftPieces)..where((x) => x.pieceId.equals(pieceId))).go();
    for (final d in draftIds.toSet()) {
      await into(draftPieces)
          .insert(DraftPiecesCompanion.insert(draftId: d, pieceId: pieceId));
    }
  }

  /// 只更新已收金額（詳情頁／收入頁快速收款用）。
  Future<void> setReceivedAmount(String pieceId, double received) {
    return (update(pieces)..where((p) => p.id.equals(pieceId))).write(
      PiecesCompanion(
        receivedAmount: Value(received < 0 ? 0 : received),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setActualLikes(String pieceId, int likes) {
    return (update(pieces)..where((p) => p.id.equals(pieceId))).write(
      PiecesCompanion(
        actualLikes: Value(likes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deletePieces(Iterable<String> ids) {
    final now = DateTime.now();
    return transaction(() async {
      await (update(pieces)..where((p) => p.id.isIn(ids))).write(
        PiecesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _touchIdeas(
        (await (select(
          ideaPieces,
        )..where((x) => x.pieceId.isIn(ids))).get()).map((r) => r.ideaId),
      );
      await (delete(ideaPieces)..where((x) => x.pieceId.isIn(ids))).go();
      await (delete(draftPieces)..where((x) => x.pieceId.isIn(ids))).go();
    });
  }
}
