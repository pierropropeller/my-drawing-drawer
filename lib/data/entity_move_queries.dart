import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart' show ImageRef, entityImageRef;

/// 跨坑移動腦洞／摸魚／成圖（CR 2026-11-09，artboard `EntityMoveSheet`、`MoveUnlinkConfirm`、
/// `MoveTagConfirm`）。
///
/// 規則：
/// - 只改項目的 `pitId`；圖片、內文、日期、成圖的連結／商稿欄位都跟著項目走。
/// - 關聯（腦洞↔摸魚、腦洞↔成圖、摸魚↔成圖）一律斷開：被移動的項目都是同一種，關聯的另一端
///   一定是別種、留在原坑。UI 會先用 [crossPitLinksOf] 列出來讓使用者確認。
/// - tag 按坑獨立：按**名稱**對應目標坑已有的 tag；目標坑沒有的，[createMissingTags]＝true
///   就在目標坑新增同名 tag，false 就不帶過去。UI 先用 [missingTagNamesForMove] 問使用者。
/// - 原坑該格（腦洞／摸魚／成圖）的封面、坑封面若是被移走的圖，清掉。

/// 移動時列出的關聯對象（會斷開的那一端）。
class MoveLinkedItem {
  const MoveLinkedItem({
    required this.type,
    required this.id,
    this.title,
    this.body,
    this.firstImage,
  });

  final OwnerType type;
  final String id;
  final String? title;
  final String? body;
  final ImageRef? firstImage;
}

TagTarget tagTargetOf(OwnerType t) => switch (t) {
  OwnerType.idea => TagTarget.idea,
  OwnerType.draft => TagTarget.draft,
  OwnerType.piece => TagTarget.piece,
  OwnerType.oshi => TagTarget.oshi,
};

extension EntityMoveQueries on AppDatabase {
  /// [ids]（都是 [type]）連著的、未刪除的關聯對象；移動後會斷開。照種類（腦洞、摸魚、成圖）排。
  Future<List<MoveLinkedItem>> crossPitLinksOf(
    OwnerType type,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final ideaIds = <String>{};
    final draftIds = <String>{};
    final pieceIds = <String>{};
    if (type == OwnerType.idea) {
      draftIds.addAll(
        (await (select(
          ideaDrafts,
        )..where((x) => x.ideaId.isIn(ids))).get()).map((r) => r.draftId),
      );
      pieceIds.addAll(
        (await (select(
          ideaPieces,
        )..where((x) => x.ideaId.isIn(ids))).get()).map((r) => r.pieceId),
      );
    } else if (type == OwnerType.draft) {
      ideaIds.addAll(
        (await (select(
          ideaDrafts,
        )..where((x) => x.draftId.isIn(ids))).get()).map((r) => r.ideaId),
      );
      pieceIds.addAll(
        (await (select(
          draftPieces,
        )..where((x) => x.draftId.isIn(ids))).get()).map((r) => r.pieceId),
      );
    } else if (type == OwnerType.piece) {
      ideaIds.addAll(
        (await (select(
          ideaPieces,
        )..where((x) => x.pieceId.isIn(ids))).get()).map((r) => r.ideaId),
      );
      draftIds.addAll(
        (await (select(
          draftPieces,
        )..where((x) => x.pieceId.isIn(ids))).get()).map((r) => r.draftId),
      );
    }
    final out = <MoveLinkedItem>[];
    if (ideaIds.isNotEmpty) {
      final rows =
          await (select(ideas)
                ..where((x) => x.id.isIn(ideaIds) & x.deletedAt.isNull())
                ..orderBy([(x) => OrderingTerm.desc(x.date)]))
              .get();
      for (final r in rows) {
        out.add(
          MoveLinkedItem(
            type: OwnerType.idea,
            id: r.id,
            title: r.title,
            body: r.body,
            firstImage: await _firstImage(OwnerType.idea, r.id),
          ),
        );
      }
    }
    if (draftIds.isNotEmpty) {
      final rows =
          await (select(drafts)
                ..where((x) => x.id.isIn(draftIds) & x.deletedAt.isNull())
                ..orderBy([(x) => OrderingTerm.desc(x.date)]))
              .get();
      for (final r in rows) {
        out.add(
          MoveLinkedItem(
            type: OwnerType.draft,
            id: r.id,
            title: r.title,
            body: r.body,
            firstImage: await _firstImage(OwnerType.draft, r.id),
          ),
        );
      }
    }
    if (pieceIds.isNotEmpty) {
      final rows =
          await (select(pieces)
                ..where((x) => x.id.isIn(pieceIds) & x.deletedAt.isNull())
                ..orderBy([(x) => OrderingTerm.desc(x.finishedAt)]))
              .get();
      for (final r in rows) {
        out.add(
          MoveLinkedItem(
            type: OwnerType.piece,
            id: r.id,
            title: r.title,
            body: r.body,
            firstImage: await _firstImage(OwnerType.piece, r.id),
          ),
        );
      }
    }
    return out;
  }

  Future<ImageRef?> _firstImage(OwnerType type, String ownerId) async {
    final r =
        await (select(entityImages)
              ..where(
                (i) =>
                    i.ownerType.equalsValue(type) &
                    i.ownerId.equals(ownerId) &
                    i.deletedAt.isNull(),
              )
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)])
              ..limit(1))
            .getSingleOrNull();
    return r == null ? null : entityImageRef(r);
  }

  /// [ids] 帶有、但 [targetPitId] 還沒有（按名稱）的 tag 名稱，照名稱排序、不重複。
  Future<List<String>> missingTagNamesForMove(
    TagTarget target,
    List<String> ids,
    String targetPitId,
  ) async {
    if (ids.isEmpty) return const [];
    final src = await _tagNamesOf(target, ids);
    if (src.isEmpty) return const [];
    final have = {
      for (final t
          in await (select(tags)..where(
                (t) =>
                    t.pitId.equals(targetPitId) &
                    t.name.isIn(src) &
                    t.deletedAt.isNull(),
              ))
              .get())
        t.name,
    };
    return [
      for (final n in src)
        if (!have.contains(n)) n,
    ];
  }

  Future<List<String>> _tagNamesOf(TagTarget target, List<String> ids) async {
    final links =
        await (select(tagLinks)..where(
              (l) => l.targetType.equalsValue(target) & l.targetId.isIn(ids),
            ))
            .get();
    if (links.isEmpty) return const [];
    final rows =
        await (select(tags)..where(
              (t) =>
                  t.id.isIn(links.map((l) => l.tagId).toSet()) &
                  t.deletedAt.isNull(),
            ))
            .get();
    return ({for (final t in rows) t.name}.toList()..sort());
  }

  /// 把 [ids]（都是 [type]）移到 [targetPitId]。已經在目標坑的項目不動。
  Future<void> moveEntitiesToPit(
    OwnerType type,
    List<String> ids,
    String targetPitId, {
    required bool createMissingTags,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final target = tagTargetOf(type);
      // 目前所在坑（跳過已經在目標坑的）。
      final from = <String, String>{}; // id → 原坑
      switch (type) {
        case OwnerType.idea:
          for (final r in await (select(
            ideas,
          )..where((x) => x.id.isIn(ids))).get()) {
            if (r.pitId != targetPitId) from[r.id] = r.pitId;
          }
        case OwnerType.draft:
          for (final r in await (select(
            drafts,
          )..where((x) => x.id.isIn(ids))).get()) {
            if (r.pitId != targetPitId) from[r.id] = r.pitId;
          }
        case OwnerType.piece:
          for (final r in await (select(
            pieces,
          )..where((x) => x.id.isIn(ids))).get()) {
            if (r.pitId != targetPitId) from[r.id] = r.pitId;
          }
        case OwnerType.oshi:
          throw ArgumentError.value(type, 'type', '推活不在跨坑移動範圍');
      }
      if (from.isEmpty) return;
      final moved = from.keys.toList();

      // 1. 斷開關聯。連接關係由腦洞（腦洞↔摸魚、腦洞↔成圖）與成圖（摸魚↔成圖）擁有，
      //    同步時隨它們的文件走，所以受影響的腦洞、成圖都要更新 updatedAt。
      final touchIdeas = <String>{};
      final touchPieces = <String>{};
      switch (type) {
        case OwnerType.idea:
          touchIdeas.addAll(moved);
          touchPieces.addAll(
            (await (select(
              ideaPieces,
            )..where((x) => x.ideaId.isIn(moved))).get()).map((r) => r.pieceId),
          );
          await (delete(ideaDrafts)..where((x) => x.ideaId.isIn(moved))).go();
          await (delete(ideaPieces)..where((x) => x.ideaId.isIn(moved))).go();
        case OwnerType.draft:
          touchIdeas.addAll(
            (await (select(
              ideaDrafts,
            )..where((x) => x.draftId.isIn(moved))).get()).map((r) => r.ideaId),
          );
          touchPieces.addAll(
            (await (select(
              draftPieces,
            )..where((x) => x.draftId.isIn(moved))).get()).map(
              (r) => r.pieceId,
            ),
          );
          await (delete(ideaDrafts)..where((x) => x.draftId.isIn(moved))).go();
          await (delete(draftPieces)..where((x) => x.draftId.isIn(moved))).go();
        case OwnerType.piece:
          touchPieces.addAll(moved);
          touchIdeas.addAll(
            (await (select(
              ideaPieces,
            )..where((x) => x.pieceId.isIn(moved))).get()).map((r) => r.ideaId),
          );
          await (delete(ideaPieces)..where((x) => x.pieceId.isIn(moved))).go();
          await (delete(draftPieces)..where((x) => x.pieceId.isIn(moved))).go();
        case OwnerType.oshi:
          break;
      }

      // 2. tag：按名稱對應到目標坑。
      for (final id in moved) {
        final names = await _tagNamesOf(target, [id]);
        final mapped = <String>[];
        for (final n in names) {
          final existing =
              await (select(tags)..where(
                    (t) =>
                        t.pitId.equals(targetPitId) &
                        t.name.equals(n) &
                        t.deletedAt.isNull(),
                  ))
                  .getSingleOrNull();
          if (existing != null) {
            mapped.add(existing.id);
          } else if (createMissingTags) {
            mapped.add(await createTag(targetPitId, n));
          }
        }
        await setTags(target, id, mapped);
      }

      // 3. 改坑。
      switch (type) {
        case OwnerType.idea:
          await (update(ideas)..where((x) => x.id.isIn(moved))).write(
            IdeasCompanion(pitId: Value(targetPitId), updatedAt: Value(now)),
          );
        case OwnerType.draft:
          await (update(drafts)..where((x) => x.id.isIn(moved))).write(
            DraftsCompanion(pitId: Value(targetPitId), updatedAt: Value(now)),
          );
        case OwnerType.piece:
          await (update(pieces)..where((x) => x.id.isIn(moved))).write(
            PiecesCompanion(pitId: Value(targetPitId), updatedAt: Value(now)),
          );
        case OwnerType.oshi:
          break;
      }
      if (touchIdeas.isNotEmpty) {
        await (update(ideas)..where((x) => x.id.isIn(touchIdeas))).write(
          IdeasCompanion(updatedAt: Value(now)),
        );
      }
      if (touchPieces.isNotEmpty) {
        await (update(pieces)..where((x) => x.id.isIn(touchPieces))).write(
          PiecesCompanion(updatedAt: Value(now)),
        );
      }

      // 4. 原坑的封面若是被移走的圖，清掉。
      final imgs =
          await (select(entityImages)..where(
                (i) => i.ownerType.equalsValue(type) & i.ownerId.isIn(moved),
              ))
              .get();
      if (imgs.isEmpty) return;
      final imgIds = {for (final i in imgs) i.id};
      final files = <String>{
        for (final i in imgs) i.imageFile,
        for (final i in imgs)
          if (i.posterFile != null) i.posterFile!,
      };
      for (final pitId in from.values.toSet()) {
        final p = await (select(
          pits,
        )..where((x) => x.id.equals(pitId))).getSingleOrNull();
        if (p == null) continue;
        final clearCover =
            p.coverImageId != null && imgIds.contains(p.coverImageId);
        final cellFile = switch (type) {
          OwnerType.idea => p.ideaCoverFile,
          OwnerType.draft => p.draftCoverFile,
          OwnerType.piece => p.pieceCoverFile,
          OwnerType.oshi => null,
        };
        final clearCell = cellFile != null && files.contains(cellFile);
        if (!clearCover && !clearCell) continue;
        await (update(pits)..where((x) => x.id.equals(pitId))).write(
          PitsCompanion(
            coverImageId: clearCover ? const Value(null) : const Value.absent(),
            ideaCoverFile: clearCell && type == OwnerType.idea
                ? const Value(null)
                : const Value.absent(),
            draftCoverFile: clearCell && type == OwnerType.draft
                ? const Value(null)
                : const Value.absent(),
            pieceCoverFile: clearCell && type == OwnerType.piece
                ? const Value(null)
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}
