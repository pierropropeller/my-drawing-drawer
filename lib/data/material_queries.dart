import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'tables.dart' show uuid, materialCategoryIdOf;

/// 靈感廣場各分類的張數與總數（Profile 的卡片、移動 sheet 的「N 張」）。key＝分類 id。
class MaterialCounts {
  const MaterialCounts(this.byCategory);

  final Map<String, int> byCategory;

  int of(String categoryId) => byCategory[categoryId] ?? 0;
  int get total => byCategory.values.fold(0, (a, b) => a + b);

  static const empty = MaterialCounts({});

  @override
  bool operator ==(Object other) =>
      other is MaterialCounts &&
      other.byCategory.length == byCategory.length &&
      byCategory.entries.every((e) => other.of(e.key) == e.value);

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final e in byCategory.entries) Object.hash(e.key, e.value),
  ]);
}

/// 廣場圖實際所屬的分類 id（D-143）：舊資料沒有 categoryId，用舊的固定分類對應的預設分類。
extension MaterialImageCategory on MaterialImage {
  String get categoryKey => categoryId ?? materialCategoryIdOf(category);
}

/// 寫給舊版 App 看的固定分類：預設分類對應回去，自訂分類一律寫 `clothing`。
MaterialCategory legacyMaterialCategory(String categoryId) {
  for (final c in MaterialCategory.values) {
    if (materialCategoryIdOf(c) == categoryId) return c;
  }
  return MaterialCategory.clothing;
}

/// SQL：廣場圖的分類 id（categoryId 為 null 時用舊分類拼出預設 id）。
const _catExpr = "COALESCE(category_id, 'mcat-' || category)";

/// 素材庫（D-071）。不屬於任何坑；不計入目標、時間軸、搜尋、封面與坑統計。
extension MaterialQueries on AppDatabase {
  /// 素材列表，新的在前；[category]（分類 id）為 null＝全部。
  /// createdAt 只有秒精度，同一秒的先後以寫入順序（rowid）決定。
  Stream<List<MaterialImage>> watchMaterials({String? category}) {
    return (select(materialImages)
          ..where(
            (m) =>
                m.deletedAt.isNull() &
                (category == null
                    ? const Constant(true)
                    : const CustomExpression<String>(_catExpr)
                          .equals(category)),
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
    String category,
    List<NewImage> images, {
    String? note,
  }) {
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
            category: legacyMaterialCategory(category),
            categoryId: Value(category),
            note: Value(note),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
      return ids;
    });
  }

  /// 改分類（多選的「移動」）。已經在目標分類的不動（不蓋 updatedAt，避免無謂同步）。
  Future<void> moveMaterials(Iterable<String> ids, String category) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (update(materialImages)..where(
          (m) =>
              m.id.isIn(list) &
              m.deletedAt.isNull() &
              const CustomExpression<String>(_catExpr).equals(category).not(),
        ))
        .write(
          MaterialImagesCompanion(
            category: Value(legacyMaterialCategory(category)),
            categoryId: Value(category),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// 軟刪除（同步用）。
  Future<void> deleteMaterials(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final now = DateTime.now();
    await transaction(() async {
      final live = [
        for (final m in await (select(
          materialImages,
        )..where((m) => m.id.isIn(list) & m.deletedAt.isNull())).get())
          m.id,
      ];
      await (update(materialImages)..where((m) => m.id.isIn(live))).write(
        MaterialImagesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      // 放進各坑的那幾張一起收起來（同一個 deletedAt，還原時一起回來；不另外出現在最近刪除）。
      final placed = [
        for (final o in await (select(
          officialImages,
        )..where((o) => o.materialId.isIn(live) & o.deletedAt.isNull())).get())
          o.id,
      ];
      if (placed.isNotEmpty) await deleteOfficial(placed, at: now);
    });
  }

  /// 各分類張數＋總數。
  Stream<MaterialCounts> watchMaterialCounts() {
    return customSelect(
      'SELECT $_catExpr AS cat, COUNT(*) AS n FROM material_images '
      'WHERE deleted_at IS NULL GROUP BY cat',
      readsFrom: {materialImages},
    ).watch().map(
      (rows) => MaterialCounts({
        for (final r in rows) r.read<String>('cat'): r.read<int>('n'),
      }),
    );
  }
}
