import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';

/// 腦洞狀態由關係推導，不儲存（HANDOFF 3.4）。
enum IdeaStatus { open, hatching, hatched }

class ImageRef {
  const ImageRef(this.file, this.width, this.height);
  final String file;
  final int width;
  final int height;

  double get aspect => (width > 0 && height > 0) ? width / height : 1;
}

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

class DraftView {
  const DraftView({
    required this.draft,
    required this.images,
    required this.tags,
    required this.ideaIds,
    required this.pieceIds,
  });

  final Draft draft;
  final List<ImageRef> images;
  final List<Tag> tags;
  final List<String> ideaIds;
  final List<String> pieceIds;

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
  });

  final Piece piece;
  final List<ImageRef> images;
  final List<Tag> tags;
  final List<SocialLink> links;
  final List<String> ideaIds;
  final List<String> draftIds;
}

/// 先取一次，之後每當相關資料表有變動就重新取。
Stream<T> watchAssembled<T>(
  AppDatabase db,
  Set<TableInfo> tables,
  Future<T> Function() load,
) async* {
  yield await load();
  await for (final _ in db.tableUpdates(TableUpdateQuery.onAllTables(tables))) {
    yield await load();
  }
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
    entityImages,
    tagLinks,
    tags,
    ideaDrafts,
    draftPieces,
  };
  Set<TableInfo> get _pieceTables => {
    pieces,
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
    return [for (final r in rows) ImageRef(r.imageFile, r.width, r.height)];
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

  Future<void> _replaceImages(
    OwnerType type,
    String id,
    List<NewImage> images,
  ) async {
    await (delete(
      entityImages,
    )..where((e) => e.ownerType.equalsValue(type) & e.ownerId.equals(id))).go();
    for (var i = 0; i < images.length; i++) {
      await into(entityImages).insert(
        EntityImagesCompanion.insert(
          ownerType: type,
          ownerId: id,
          imageFile: images[i].file,
          width: Value(images[i].width),
          height: Value(images[i].height),
          sortOrder: Value(i),
        ),
      );
    }
  }

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
                ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
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
    DateTime? createdAt,
  }) {
    return transaction(() async {
      String ideaId;
      if (id == null) {
        final row = await into(ideas).insertReturning(
          IdeasCompanion.insert(
            pitId: pitId,
            title: title,
            body: Value(body),
            createdAt: createdAt == null
                ? const Value.absent()
                : Value(createdAt),
          ),
        );
        ideaId = row.id;
      } else {
        ideaId = id;
        await (update(ideas)..where((i) => i.id.equals(id))).write(
          IdeasCompanion(
            title: Value(title),
            body: Value(body),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await _replaceImages(OwnerType.idea, ideaId, images);
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
  Future<DraftView> _draftView(Draft d) async => DraftView(
    draft: d,
    images: await _imagesOf(OwnerType.draft, d.id),
    tags: await _tagsOf(TagTarget.draft, d.id),
    ideaIds:
        (await (select(ideaDrafts)..where((x) => x.draftId.equals(d.id))).get())
            .map((r) => r.ideaId)
            .toList(),
    pieceIds:
        (await (select(
              draftPieces,
            )..where((x) => x.draftId.equals(d.id))).get())
            .map((r) => r.pieceId)
            .toList(),
  );

  Stream<List<DraftView>> watchDraftViews(String pitId) {
    return watchAssembled(this, _draftTables, () async {
      final rows =
          await (select(drafts)
                ..where((d) => d.pitId.equals(pitId) & d.deletedAt.isNull())
                ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
              .get();
      return [for (final r in rows) await _draftView(r)];
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
    DateTime? createdAt,
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
          ),
        );
        draftId = row.id;
      } else {
        draftId = id;
        await (update(drafts)..where((d) => d.id.equals(id))).write(
          DraftsCompanion(
            title: Value(clean(title)),
            body: Value(clean(body)),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await _replaceImages(OwnerType.draft, draftId, images);
      await setTags(TagTarget.draft, draftId, tagIds);
      await setDraftIdeas(draftId, ideaIds);
      return draftId;
    });
  }

  Future<void> setDraftIdeas(String draftId, List<String> ideaIds) async {
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
      await (delete(ideaDrafts)..where((x) => x.draftId.isIn(ids))).go();
      await (delete(draftPieces)..where((x) => x.draftId.isIn(ids))).go();
    });
  }

  // ---------- 成圖 ----------
  Future<PieceView> _pieceView(Piece p) async => PieceView(
    piece: p,
    images: await _imagesOf(OwnerType.piece, p.id),
    tags: await _tagsOf(TagTarget.piece, p.id),
    links:
        (await (select(pieceLinks)
                  ..where((l) => l.pieceId.equals(p.id) & l.deletedAt.isNull()))
                .get())
            .map((l) => SocialLink(l.platform, l.url))
            .toList(),
    ideaIds:
        (await (select(ideaPieces)..where((x) => x.pieceId.equals(p.id))).get())
            .map((r) => r.ideaId)
            .toList(),
    draftIds:
        (await (select(
              draftPieces,
            )..where((x) => x.pieceId.equals(p.id))).get())
            .map((r) => r.draftId)
            .toList(),
  );

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
  }) {
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
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      await _replaceImages(OwnerType.piece, pieceId, images);
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
    await (delete(ideaPieces)..where((x) => x.pieceId.equals(pieceId))).go();
    for (final i in ideaIds) {
      await into(ideaPieces)
          .insert(IdeaPiecesCompanion.insert(ideaId: i, pieceId: pieceId));
    }
  }

  Future<void> setPieceDrafts(String pieceId, List<String> draftIds) async {
    await (delete(draftPieces)..where((x) => x.pieceId.equals(pieceId))).go();
    for (final d in draftIds) {
      await into(draftPieces)
          .insert(DraftPiecesCompanion.insert(draftId: d, pieceId: pieceId));
    }
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
      await (delete(ideaPieces)..where((x) => x.pieceId.isIn(ids))).go();
      await (delete(draftPieces)..where((x) => x.pieceId.isIn(ids))).go();
    });
  }
}
