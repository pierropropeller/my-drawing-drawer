import 'package:drift/drift.dart';

import 'database.dart';

/// 圖片所在的「格」（同步進度 sheet 的「坑 · 格」）。
enum ImageCell { official, fan, junk, draft, idea, piece }

class ImageLocation {
  const ImageLocation({
    required this.pitId,
    required this.pitName,
    required this.cell,
  });
  final String pitId;
  final String pitName;
  final ImageCell cell;

  @override
  bool operator ==(Object other) =>
      other is ImageLocation &&
      other.pitId == pitId &&
      other.pitName == pitName &&
      other.cell == cell;

  @override
  int get hashCode => Object.hash(pitId, pitName, cell);

  @override
  String toString() => '$pitName · $cell';
}

extension ImageLocationQueries on AppDatabase {
  /// 由圖片檔名找出它在哪個坑的哪一格；找不到（例如只被年度回顧引用）回傳 null。
  /// 同一檔案出現在多處時的優先順序：官方圖冊 → 好看同人圖 → 雜物 → 成圖 → 草稿 → 腦洞。
  /// 已刪除、被移動而隱藏的列不算。
  Future<ImageLocation?> imageLocationOf(String file) async {
    Future<ImageLocation?> build(String? pitId, ImageCell cell) async {
      if (pitId == null) return null;
      final pit = await (select(
        pits,
      )..where((p) => p.id.equals(pitId))).getSingleOrNull();
      if (pit == null) return null;
      return ImageLocation(pitId: pit.id, pitName: pit.name, cell: cell);
    }

    final o =
        await (select(officialImages)
              ..where(
                (i) =>
                    i.imageFile.equals(file) &
                    i.deletedAt.isNull() &
                    i.hidden.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (o != null) return build(o.pitId, ImageCell.official);
    final f =
        await (select(fanArts)
              ..where(
                (i) =>
                    i.imageFile.equals(file) &
                    i.deletedAt.isNull() &
                    i.hidden.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (f != null) return build(f.pitId, ImageCell.fan);
    final j =
        await (select(junkImages)
              ..where(
                (i) =>
                    i.imageFile.equals(file) &
                    i.deletedAt.isNull() &
                    i.hidden.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (j != null) return build(j.pitId, ImageCell.junk);

    // 成圖 → 草稿 → 腦洞
    for (final (type, cell) in [
      (OwnerType.piece, ImageCell.piece),
      (OwnerType.draft, ImageCell.draft),
      (OwnerType.idea, ImageCell.idea),
    ]) {
      final rows =
          await (select(entityImages)..where(
                (e) =>
                    e.imageFile.equals(file) &
                    e.ownerType.equalsValue(type) &
                    e.deletedAt.isNull(),
              ))
              .get();
      for (final e in rows) {
        final String? pitId = switch (type) {
          OwnerType.piece =>
            (await (select(pieces)..where(
                      (p) => p.id.equals(e.ownerId) & p.deletedAt.isNull(),
                    ))
                    .getSingleOrNull())
                ?.pitId,
          OwnerType.draft =>
            (await (select(drafts)..where(
                      (p) => p.id.equals(e.ownerId) & p.deletedAt.isNull(),
                    ))
                    .getSingleOrNull())
                ?.pitId,
          OwnerType.idea =>
            (await (select(ideas)..where(
                      (p) => p.id.equals(e.ownerId) & p.deletedAt.isNull(),
                    ))
                    .getSingleOrNull())
                ?.pitId,
        };
        final loc = await build(pitId, cell);
        if (loc != null) return loc;
      }
    }
    return null;
  }
}
