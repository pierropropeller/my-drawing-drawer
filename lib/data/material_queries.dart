import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'tables.dart' show uuid;

/// 素材庫各分類的張數與總數（Profile 的素材庫卡、移動 sheet 的「N 張」）。
class MaterialCounts {
  const MaterialCounts(this.byCategory);

  /// 一定包含全部 7 個分類（沒有圖的為 0）。
  final Map<MaterialCategory, int> byCategory;

  int of(MaterialCategory c) => byCategory[c] ?? 0;
  int get total => byCategory.values.fold(0, (a, b) => a + b);

  static final empty = MaterialCounts({
    for (final c in MaterialCategory.values) c: 0,
  });

  @override
  bool operator ==(Object other) =>
      other is MaterialCounts &&
      MaterialCategory.values.every((c) => of(c) == other.of(c));

  @override
  int get hashCode =>
      Object.hashAll([for (final c in MaterialCategory.values) of(c)]);
}

/// 素材庫（D-071）。不屬於任何坑；不計入目標、時間軸、搜尋、封面與坑統計。
extension MaterialQueries on AppDatabase {
  /// 素材列表，新的在前；[category] 為 null＝全部。
  /// createdAt 只有秒精度，同一秒的先後以寫入順序（rowid）決定。
  Stream<List<MaterialImage>> watchMaterials({MaterialCategory? category}) {
    return (select(materialImages)
          ..where(
            (m) =>
                m.deletedAt.isNull() &
                (category == null
                    ? const Constant(true)
                    : m.category.equalsValue(category)),
          )
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(const CustomExpression<int>('rowid')),
          ]))
        .watch();
  }

  /// 在 [category] 下一次加入一批圖（單一交易）。回傳新列的 id（與 [images] 同順序）。
  /// 同一批的圖共用同一個 createdAt；列表上這批圖的顯示順序＝[images] 的順序，且整批在舊的前面。
  Future<List<String>> addMaterials(
    MaterialCategory category,
    List<NewImage> images,
  ) {
    if (images.isEmpty) return Future.value(const []);
    final now = DateTime.now();
    final ids = [for (final _ in images) uuid.v4()];
    return transaction(() async {
      // 倒序寫入：列表同秒的先後看 rowid（後寫入的在前），這樣第一張圖會排在最上面。
      for (var i = images.length - 1; i >= 0; i--) {
        await into(materialImages).insert(
          MaterialImagesCompanion.insert(
            id: Value(ids[i]),
            imageFile: images[i].file,
            width: Value(images[i].width),
            height: Value(images[i].height),
            kind: Value(images[i].kind),
            durationMs: Value(images[i].durationMs),
            posterFile: Value(images[i].posterFile),
            sensitive: Value(images[i].sensitive),
            category: category,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
      return ids;
    });
  }

  /// 改分類（多選的「移動」）。已經在目標分類的不動（不蓋 updatedAt，避免無謂同步）。
  Future<void> moveMaterials(
    Iterable<String> ids,
    MaterialCategory category,
  ) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(materialImages)..where(
          (m) =>
              m.id.isIn(list) &
              m.deletedAt.isNull() &
              m.category.equalsValue(category).not(),
        ))
        .write(
          MaterialImagesCompanion(
            category: Value(category),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 軟刪除（同步用）。
  Future<void> deleteMaterials(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final now = DateTime.now();
    await (update(
      materialImages,
    )..where((m) => m.id.isIn(list) & m.deletedAt.isNull())).write(
      MaterialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// 各分類張數＋總數。
  Stream<MaterialCounts> watchMaterialCounts() {
    return customSelect(
      'SELECT category, COUNT(*) AS n FROM material_images '
      'WHERE deleted_at IS NULL GROUP BY category',
      readsFrom: {materialImages},
    ).watch().map((rows) {
      final out = {for (final c in MaterialCategory.values) c: 0};
      for (final r in rows) {
        final name = r.read<String>('category');
        for (final c in MaterialCategory.values) {
          if (c.name == name) out[c] = r.read<int>('n');
        }
      }
      return MaterialCounts(out);
    });
  }
}
