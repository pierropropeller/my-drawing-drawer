import 'package:drift/drift.dart';

import '../data/album_queries.dart';
import '../data/database.dart';
import '../data/entity_queries.dart';
import '../data/media.dart';
import '../data/profile_queries.dart';

/// 一種可同步的實體。每筆實體序列化成一份 JSON 文件；
/// 連接關係、tag、圖片清單等「附屬資料」跟著擁有它的實體文件一起走：
/// - 腦洞文件：tagIds、draftIds、pieceIds、images
/// - 草稿文件：tagIds、images
/// - 成圖文件：tagIds、images、links、draftIds（草稿↔成圖的關係由成圖擁有，D-069）
/// - 推活文件：tagIds、images
/// - 素材庫（v8 起）：只有圖檔與分類，沒有附屬資料
/// - 官方圖（v7 起）／同人圖／目標文件：tagIds
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

/// 套用遠端文件用的 upsert。drift 的 `insertOnConflictUpdate` 在**更新**時會略過 null 欄位
/// （內部用 `toColumns(true)`），遠端把某個欄位清成 null（例如推活取消分組、清掉標題）
/// 就傳不到本機。這裡改成整列覆寫，null 也會寫進去。
extension FullUpsert<T extends Table, D> on InsertStatement<T, D> {
  Future<int> upsertFull(Insertable<D> row) => insert(
    _FullRow<D>(row),
    onConflict: DoUpdate<T, D>((_) => _FullRow<D>(row)),
  );
}

class _FullRow<D> implements Insertable<D> {
  const _FullRow(this.inner);
  final Insertable<D> inner;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) =>
      inner.toColumns(false);
}

/// 舊版文件缺少新欄位：補上預設值再交給 drift 的 fromJson（缺 key 的非空欄位會丟例外）。
/// [defaults] 的值可以是函式 `(data) => 值`，用來依同文件其他欄位推算。
Map<String, dynamic> withDefaults(
  Map<String, dynamic> data,
  Map<String, Object?> defaults,
) {
  final out = Map<String, dynamic>.of(data);
  defaults.forEach((k, v) {
    if (!out.containsKey(k)) {
      out[k] = v is Object? Function(Map<String, dynamic>) ? v(data) : v;
    }
  });
  return out;
}

/// 媒體欄位（D-080）的相容處理：
/// - 舊版 App 的文件沒有 `kind`：依檔名副檔名推（.gif／影片副檔名），其餘＝圖片；
/// - 較新版 App 的不認得種類（例如日後多了 audio）：同樣當作依副檔名推的結果，不丟例外；
/// - `durationMs`／`posterFile` 缺 key＝null（drift 的 fromJson 對可空欄位缺 key 本來就給 null）。
Map<String, dynamic> withMediaDefaults(
  Map<String, dynamic> data, {
  String fileKey = 'imageFile',
}) {
  final out = Map<String, dynamic>.of(data);
  final raw = out['kind'];
  if (!MediaKind.values.any((k) => k.name == raw)) {
    out['kind'] = mediaKindFromExtension((out[fileKey] as String?) ?? '').name;
  }
  return out;
}

/// 文件引用到的媒體檔：原檔加影片截圖（有才算）。
Set<String> _mediaFiles(Map<String, dynamic> data) => {
  data['imageFile'] as String,
  if ((data['posterFile'] as String?)?.isNotEmpty ?? false)
    data['posterFile'] as String,
};

const _albumImageDefaults = <String, Object?>{'hidden': false};

Map<String, dynamic> _albumImageJson(Map<String, dynamic> data) =>
    withMediaDefaults(
      withDefaults(data, {
        ..._albumImageDefaults,
        'imageKey': (Map<String, dynamic> d) => d['id'],
      }),
    );

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
    {
      'file': r.imageFile,
      'width': r.width,
      'height': r.height,
      'kind': r.kind.name,
      'durationMs': r.durationMs,
      'posterFile': r.posterFile,
    },
];

List<NewImage> _newImages(Object? raw) => [
  for (final m in (raw as List<dynamic>? ?? const []))
    NewImage(
      file: (m as Map<String, dynamic>)['file'] as String,
      width: m['width'] as int? ?? 0,
      height: m['height'] as int? ?? 0,
      // 舊版文件沒有 kind：依副檔名推。
      kind:
          m['kind'] is String &&
              MediaKind.values.any((k) => k.name == m['kind'])
          ? MediaKindX.parse(m['kind'] as String)
          : mediaKindFromExtension(m['file'] as String),
      durationMs: m['durationMs'] as int?,
      posterFile: m['posterFile'] as String?,
    ),
];

Set<String> _entityImageFiles(Map<String, dynamic> data) => {
  for (final m in (data['images'] as List<dynamic>? ?? const [])) ...{
    (m as Map<String, dynamic>)['file'] as String,
    if ((m['posterFile'] as String?)?.isNotEmpty ?? false)
      m['posterFile'] as String,
  },
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

  /// 文件除了 `status`／`enabledSections`／`coverFile`（D-088），另帶舊版 App 才看得懂的
  /// `archived`（bool，＝封存坑）。舊版 App 讀文件時忽略不認得的欄位。
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async {
    final pit = await (db.select(
      db.pits,
    )..where((t) => t.id.equals(id))).getSingle();
    return {...pit.toJson(), 'archived': pit.status == PitStatus.archived};
  }

  /// 套用遠端文件。舊版 App 寫的文件沒有 `status`：由 `archived` 推（true＝封存，否則現坑）；
  /// 但本機是淺坑、而舊版 App 只是改了名稱之類（archived 仍是 false）時，保留淺坑與它的格子設定。
  /// 認不得的 `status`（較新版 App 的新類型）同樣當作沒有。
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final raw = data['status'];
    final known = PitStatus.values.any((s) => s.name == raw);
    final archived = data['archived'] == true;
    var doc = Map<String, dynamic>.of(data);
    if (!known) {
      final local = await (db.select(
        db.pits,
      )..where((t) => t.id.equals(data['id'] as String))).getSingleOrNull();
      if (!archived && local != null && local.status == PitStatus.shallow) {
        doc['status'] = PitStatus.shallow.name;
        doc['enabledSections'] = const PitSectionSetConverter().toSql(
          local.enabledSections,
        );
      } else {
        doc['status'] = (archived ? PitStatus.archived : PitStatus.active).name;
      }
    }
    doc = withDefaults(doc, {'junkEnabled': false, 'enabledSections': ''});
    await db.into(db.pits).upsertFull(Pit.fromJson(doc));
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    if ((data['coverFile'] as String?)?.isNotEmpty ?? false)
      data['coverFile'] as String,
  };
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
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) =>
      db.into(db.officialGroups).upsertFull(OfficialGroup.fromJson(data));
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
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.officialImages,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.official, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = OfficialImage.fromJson(_albumImageJson(data));
    await db.transaction(() async {
      await db.into(db.officialImages).upsertFull(row);
      // 舊版（v6 以前）寫出的官方圖文件沒有 tagIds：不動本機已有的 tag。
      final raw = data['tagIds'];
      if (raw is List) {
        await db.setTags(TagTarget.official, row.id, [
          for (final t in raw) t as String,
        ]);
      }
    });
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _mediaFiles(data);
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
    final row = FanArt.fromJson(_albumImageJson(data));
    await db.into(db.fanArts).upsertFull(row);
    await db.setTags(TagTarget.fanArt, row.id, [
      for (final t in data['tagIds'] as List<dynamic>) t as String,
    ]);
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _mediaFiles(data);
}

/// 雜物（D-034）。
class JunkKind extends SyncKind {
  const JunkKind();
  @override
  String get name => 'junk';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.junkImages).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.junkImages,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) => db
      .into(db.junkImages)
      .upsertFull(JunkImage.fromJson(_albumImageJson(data)));
  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _mediaFiles(data);
}

/// 素材庫（D-071）：一張圖一份文件；沒有 tag、沒有關聯。
class MaterialKind extends SyncKind {
  const MaterialKind();
  @override
  String get name => 'material';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.materialImages).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.materialImages,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    // 較新版 App 加了本機不認識的分類：略過這份文件（不覆蓋、不丟例外），等本機更新後再說。
    final known = MaterialCategory.values.any(
      (c) => c.name == data['category'],
    );
    if (!known) return;
    await db
        .into(db.materialImages)
        .upsertFull(
          MaterialImage.fromJson(
            withMediaDefaults(withDefaults(data, {'width': 0, 'height': 0})),
          ),
        );
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => _mediaFiles(data);
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
      db.into(db.tags).upsertFull(Tag.fromJson(data));
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
    // 舊版文件沒有 date（D-070）：沿用 createdAt。
    final row = Idea.fromJson(
      withDefaults(data, {'date': (Map<String, dynamic> d) => d['createdAt']}),
    );
    await db.transaction(() async {
      await db.into(db.ideas).upsertFull(row);
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
    final row = Draft.fromJson(
      withDefaults(data, {'date': (Map<String, dynamic> d) => d['createdAt']}),
    );
    await db.transaction(() async {
      await db.into(db.drafts).upsertFull(row);
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
    // 舊版文件沒有公開發佈／商稿欄位：舊版的成圖一律是公開的，發佈日期沿用完成日期。
    final row = Piece.fromJson(
      withDefaults(data, {
        'isPublished': true,
        'publishedAt': (Map<String, dynamic> d) => d['finishedAt'],
        'isCommission': false,
        'client': '',
        'currency': 'CNY',
        'receivedAmount': 0.0,
      }),
    );
    await db.transaction(() async {
      await db.into(db.pieces).upsertFull(row);
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

/// 推活紀錄（D-057）：圖片與 tag 跟著紀錄文件走；分組走 `groups`（kind=oshi）。
class OshiKind extends SyncKind {
  const OshiKind();
  @override
  String get name => 'oshi';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.oshiRecords).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async => {
    ...(await (db.select(
      db.oshiRecords,
    )..where((t) => t.id.equals(id))).getSingle()).toJson(),
    'tagIds': await _tagIdsOf(db, TagTarget.oshi, id),
    'images': await _imagesOf(db, OwnerType.oshi, id),
  };
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) async {
    final row = OshiRecord.fromJson(data);
    await db.transaction(() async {
      await db.into(db.oshiRecords).upsertFull(row);
      await db.setTags(TagTarget.oshi, row.id, [
        for (final t in data['tagIds'] as List<dynamic>) t as String,
      ]);
      await db.replaceEntityImages(
        OwnerType.oshi,
        row.id,
        _newImages(data['images']),
      );
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
    await db.into(db.goals).upsertFull(row);
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
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) =>
      db.into(db.yearReviewMonths).upsertFull(YearReviewMonth.fromJson(data));
  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    if (data['imageFile'] != null && data['imageFile'] != '')
      data['imageFile'] as String,
  };
}

/// 年度回顧排版設定（id＝年份）。
class ReviewSettingsKind extends SyncKind {
  const ReviewSettingsKind();
  @override
  String get name => 'reviewsettings';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.reviewSettings).get())
      '${r.year}': r.updatedAt?.millisecondsSinceEpoch ?? 0,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.reviewSettings,
      )..where((t) => t.year.equals(int.parse(id)))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) =>
      db.into(db.reviewSettings).upsertFull(ReviewSetting.fromJson(data));
}

/// 使用者資料（暱稱、頭像）：單例文件，id 固定 `me`；頭像檔跟其他圖片一起上傳／下載。
/// 舊版 App 沒有這個種類，讀遠端時只認得自己知道的 `meta__{kind}__` 前綴，直接忽略，不需提高格式版本。
class ProfileKind extends SyncKind {
  const ProfileKind();
  @override
  String get name => 'profile';
  @override
  Future<Map<String, int>> versions(AppDatabase db) async => {
    for (final r in await db.select(db.userProfiles).get())
      r.id: r.updatedAt.millisecondsSinceEpoch,
  };
  @override
  Future<Map<String, dynamic>> encode(AppDatabase db, String id) async =>
      (await (db.select(
        db.userProfiles,
      )..where((t) => t.id.equals(id))).getSingle()).toJson();
  @override
  Future<void> apply(AppDatabase db, Map<String, dynamic> data) {
    final row = UserProfile.fromJson(
      withDefaults(data, {'id': profileDocId, 'nickname': ''}),
    );
    return db.into(db.userProfiles).upsertFull(row);
  }

  @override
  Set<String> imageFiles(Map<String, dynamic> data) => {
    if ((data['avatarFile'] as String?)?.isNotEmpty ?? false)
      data['avatarFile'] as String,
  };
}

const allSyncKinds = <SyncKind>[
  PitsKind(),
  GroupsKind(),
  TagsKind(),
  OfficialKind(),
  FanArtKind(),
  JunkKind(),
  MaterialKind(),
  IdeasKind(),
  DraftsKind(),
  PiecesKind(),
  OshiKind(),
  GoalsKind(),
  ReviewMonthsKind(),
  ReviewSettingsKind(),
  ProfileKind(),
];
