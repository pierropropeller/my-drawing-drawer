import 'package:drift/drift.dart';

import '../data/album_queries.dart';
import '../data/database.dart';
import '../data/entity_queries.dart';

/// 一種可同步的實體。每筆實體序列化成一份 JSON 文件；
/// 連接關係、tag、圖片清單等「附屬資料」跟著擁有它的實體文件一起走：
/// - 腦洞文件：tagIds、draftIds、pieceIds、images
/// - 草稿文件：tagIds、images
/// - 成圖文件：tagIds、images、links、draftIds
/// - 同人圖／目標文件：tagIds
abstract class SyncKind {
  const SyncKind();
  String get name;

  /// 本機所有未刪除與已軟刪除實體的 id → updatedAt（毫秒）。
  Future<Map<String, int>> versions(AppDatabase db);

  Future<Map<String, dynamic>> encode(AppDatabase db, String id);

  /// 套用遠端文件（呼叫前已確認遠端較新）。
  Future<void> apply(AppDatabase db, Map<String, dynamic> data);

  /// 文件引用到的圖片檔名（需一併上傳／下載）。
  Set<String> imageFiles(Map<String, dynamic> data) => const {};
}

Future<List<String>> _tagIdsOf(
  AppDatabase db,
  TagTarget type,
  String id,
) async =>
    (await (db.select(db.tagLinks)..where(
              (l) => l.targetType.equalsValue(type) & l.targetId.equals(id),
            ))
            .get())
        .map((r) => r.tagId)
        .toList();

Future<List<Map<String, dynamic>>> _imagesOf(
  AppDatabase db,
  OwnerType type,
  String id,
) async => [
  for (final r
      in await (db.select(db.entityImages)
            ..where((e) => e.ownerType.equalsValue(type) & e.ownerId.equals(id))
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .get())
    {'file': r.imageFile, 'width': r.width, 'height': r.height},
];

List<NewImage> _newImages(Object? raw) => [
  for (final m in (raw as List<dynamic>? ?? const []))
    NewImage(
      file: (m as Map<String, dynamic>)['file'] as String,
      width: m['width'] as int? ?? 0,
      height: m['height'] as int? ?? 0,
    ),
];

Set<String> _entityImageFiles(Map<String, dynamic> data) => {
  for (final m in (data['images'] as List<dynamic>? ?? const []))
    (m as Map<String, dynamic>)['file'] as String,
};

class PitsKind extends SyncKind {
  const PitsKind();
  @override
  String get name => 'pits';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.pits).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.pits,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) =>
      db.into(db.pits).insertOnConflictUpdate(Pit.fromJson(data));
}

class GroupsKind extends SyncKind {
  const GroupsKind();
  @override
  String get name => 'groups';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.officialGroups).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.officialGroups,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) => db
      .into(db.officialGroups)
      .insertOnConflictUpdate(OfficialGroup.fromJson(data));
}

class OfficialKind extends SyncKind {
  const OfficialKind();
  @override
  String get name => 'official';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.officialImages).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.officialImages,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) => db
      .into(db.officialImages)
      .insertOnConflictUpdate(OfficialImage.fromJson(data));
  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    data['imageFile'] as String,
  };
}

class FanArtKind extends SyncKind {
  const FanArtKind();
  @override
  String get name => 'fanart';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.fanArts).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.fanArts,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.fanArt, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = FanArt.fromJson(data);
    await db.into(db.fanArts).insertOnConflictUpdate(row);
    await db.setTags(TagTarget.fanArt, row.id, [
      for (final t in data['tagIds'] as List<dynamic>) t as String,
    ]);
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    data['imageFile'] as String,
  };
}

class TagsKind extends SyncKind {
  const TagsKind();
  @override
  String get name => 'tags';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.tags).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.tags,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) =>
      db.into(db.tags).insertOnConflictUpdate(Tag.fromJson(data));
}

class IdeasKind extends SyncKind {
  const IdeasKind();
  @override
  String get name => 'ideas';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.ideas).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.ideas,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.idea, id),
    'draftIds': (await (db.select(
      db.ideaDrafts,
    )..where((x) => x.ideaId.equals(id))).get()).map((r) => r.draftId).toList(),
    'pieceIds': (await (db.select(
      db.ideaPieces,
    )..where((x) => x.ideaId.equals(id))).get()).map((r) => r.pieceId).toList(),
    'images': await _imagesOf(db, OwnerType.idea, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = Idea.fromJson(data);
    await db.transaction(() async {
      await db.into(db.ideas).insertOnConflictUpdate(row);
      await db.setTags(TagTarget.idea, row.id, [
        for (final t in data['tagIds'] as List<dynamic>) t as String,
      ]);
      await db.setIdeaDrafts(row.id, [
        for (final t in data['draftIds'] as List<dynamic>) t as String,
      ]);
      await db.setIdeaPieces(row.id, [
        for (final t in data['pieceIds'] as List<dynamic>) t as String,
      ]);
      await db.replaceEntityImages(
        OwnerType.idea,
        row.id,
        _newImages(data['images']),
      );
    });
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _entityImageFiles(data);
}

class DraftsKind extends SyncKind {
  const DraftsKind();
  @override
  String get name => 'drafts';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.drafts).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.drafts,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.draft, id),
    'images': await _imagesOf(db, OwnerType.draft, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = Draft.fromJson(data);
    await db.transaction(() async {
      await db.into(db.drafts).insertOnConflictUpdate(row);
      await db.setTags(TagTarget.draft, row.id, [
        for (final t in data['tagIds'] as List<dynamic>) t as String,
      ]);
      await db.replaceEntityImages(
        OwnerType.draft,
        row.id,
        _newImages(data['images']),
      );
    });
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _entityImageFiles(data);
}

class PiecesKind extends SyncKind {
  const PiecesKind();
  @override
  String get name => 'pieces';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.pieces).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.pieces,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.piece, id),
    'images': await _imagesOf(db, OwnerType.piece, id),
    'links': [
      for (final l in await (db.select(
        db.pieceLinks,
      )..where((x) => x.pieceId.equals(id) & x.deletedAt.isNull())).get())
        {'platform': l.platform, 'url': l.url},
    ],
    'draftIds':
        (await (db.select(
              db.draftPieces,
            )..where((x) => x.pieceId.equals(id))).get())
            .map((r) => r.draftId)
            .toList(),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = Piece.fromJson(data);
    await db.transaction(() async {
      await db.into(db.pieces).insertOnConflictUpdate(row);
      await db.setTags(TagTarget.piece, row.id, [
        for (final t in data['tagIds'] as List<dynamic>) t as String,
      ]);
      await db.replaceEntityImages(
        OwnerType.piece,
        row.id,
        _newImages(data['images']),
      );
      await (db.delete(
        db.pieceLinks,
      )..where((l) => l.pieceId.equals(row.id))).go();
      for (final l in data['links'] as List<dynamic>) {
        final m = l as Map<String, dynamic>;
        await db
            .into(db.pieceLinks)
            .insert(
              PieceLinksCompanion.insert(
                pieceId: row.id,
                platform: m['platform'] as String,
                url: m['url'] as String,
              ),
            );
      }
      await db.setPieceDrafts(row.id, [
        for (final t in data['draftIds'] as List<dynamic>) t as String,
      ]);
    });
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _entityImageFiles(data);
}

class GoalsKind extends SyncKind {
  const GoalsKind();
  @override
  String get name => 'goals';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.goals).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.goals,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.goal, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = Goal.fromJson(data);
    await db.into(db.goals).insertOnConflictUpdate(row);
    await db.setTags(TagTarget.goal, row.id, [
      for (final t in data['tagIds'] as List<dynamic>) t as String,
    ]);
  }
}

/// 年度回顧每月精選圖（id＝`年-月`）。
class ReviewMonthsKind extends SyncKind {
  const ReviewMonthsKind();
  @override
  String get name => 'reviewmonths';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.yearReviewMonths).get())
      '${r.year}-${r.month}': r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async {
    final p = id.split('-').map(int.parse).toList();
    return (await (db.select(db.yearReviewMonths)
              ..where((t) => t.year.equals(p[0]) & t.month.equals(p[1])))
            .getSingle())
        .toJson();
  }

  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) => db
      .into(db.yearReviewMonths)
      .insertOnConflictUpdate(YearReviewMonth.fromJson(data));
  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    if (data['imageFile'] != null) data['imageFile'] as String,
  };
}

const allSyncKinds = <SyncKind>[
  PitsKind(),
  GroupsKind(),
  TagsKind(),
  OfficialKind(),
  FanArtKind(),
  IdeasKind(),
  DraftsKind(),
  PiecesKind(),
  GoalsKind(),
  ReviewMonthsKind(),
];
