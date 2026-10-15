import 'package:drift/drift.dart';

import 'database.dart';

/// 媒體（D-080）：匯入後補上探測結果、找出還沒有截圖的影片。
extension MediaQueries on AppDatabase {
  /// 匯入影片之後，UI 探測完寬高／長度／第一格截圖，用這個補寫進資料庫。
  /// 同一個檔案名稱出現在哪裡（官方圖、同人圖、雜物、素材庫、腦洞／草稿／成圖／推活的圖）就全部更新。
  ///
  /// - 只寫有給的欄位（null＝不動）；[width]／[height] 要大於 0 才寫。
  /// - 有實際寫入的列會更新 updatedAt，腦洞／草稿／成圖／推活的圖則是更新它**所屬紀錄**的 updatedAt
  ///   （圖片跟著紀錄文件同步），所以補完截圖之後下次同步會把新資訊與截圖檔傳出去。
  /// - 副作用：官方圖／同人圖列的 updatedAt 變新，會排到「最新」的前面一次。
  Future<void> setMediaMeta(
    String file, {
    int? width,
    int? height,
    int? durationMs,
    String? posterFile,
  }) {
    final hasSize = (width ?? 0) > 0 && (height ?? 0) > 0;
    if (!hasSize && durationMs == null && posterFile == null) {
      return Future.value();
    }
    final now = DateTime.now();
    return transaction(() async {
      await (update(
        officialImages,
      )..where((i) => i.imageFile.equals(file))).write(
        OfficialImagesCompanion(
          width: hasSize ? Value(width!) : const Value.absent(),
          height: hasSize ? Value(height!) : const Value.absent(),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          posterFile: posterFile == null
              ? const Value.absent()
              : Value(posterFile),
          updatedAt: Value(now),
        ),
      );
      await (update(fanArts)..where((i) => i.imageFile.equals(file))).write(
        FanArtsCompanion(
          width: hasSize ? Value(width!) : const Value.absent(),
          height: hasSize ? Value(height!) : const Value.absent(),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          posterFile: posterFile == null
              ? const Value.absent()
              : Value(posterFile),
          updatedAt: Value(now),
        ),
      );
      await (update(junkImages)..where((i) => i.imageFile.equals(file))).write(
        JunkImagesCompanion(
          width: hasSize ? Value(width!) : const Value.absent(),
          height: hasSize ? Value(height!) : const Value.absent(),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          posterFile: posterFile == null
              ? const Value.absent()
              : Value(posterFile),
          updatedAt: Value(now),
        ),
      );
      await (update(
        materialImages,
      )..where((i) => i.imageFile.equals(file))).write(
        MaterialImagesCompanion(
          width: hasSize ? Value(width!) : const Value.absent(),
          height: hasSize ? Value(height!) : const Value.absent(),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          posterFile: posterFile == null
              ? const Value.absent()
              : Value(posterFile),
          updatedAt: Value(now),
        ),
      );
      final rows = await (select(
        entityImages,
      )..where((i) => i.imageFile.equals(file))).get();
      if (rows.isEmpty) return;
      await (update(
        entityImages,
      )..where((i) => i.imageFile.equals(file))).write(
        EntityImagesCompanion(
          width: hasSize ? Value(width!) : const Value.absent(),
          height: hasSize ? Value(height!) : const Value.absent(),
          durationMs: durationMs == null
              ? const Value.absent()
              : Value(durationMs),
          posterFile: posterFile == null
              ? const Value.absent()
              : Value(posterFile),
          updatedAt: Value(now),
        ),
      );
      Set<String> ownersOf(OwnerType t) => {
        for (final r in rows)
          if (r.ownerType == t) r.ownerId,
      };
      await (update(ideas)..where((x) => x.id.isIn(ownersOf(OwnerType.idea))))
          .write(IdeasCompanion(updatedAt: Value(now)));
      await (update(drafts)..where((x) => x.id.isIn(ownersOf(OwnerType.draft))))
          .write(DraftsCompanion(updatedAt: Value(now)));
      await (update(pieces)..where((x) => x.id.isIn(ownersOf(OwnerType.piece))))
          .write(PiecesCompanion(updatedAt: Value(now)));
      await (update(oshiRecords)
            ..where((x) => x.id.isIn(ownersOf(OwnerType.oshi))))
          .write(OshiRecordsCompanion(updatedAt: Value(now)));
    });
  }

  /// 還沒有截圖的影片檔名（未刪除的列；去重）。App 啟動或匯入後可以用它補產生截圖，
  /// 再用 [setMediaMeta] 寫回。
  Future<List<String>> videosWithoutPoster() async {
    final out = <String>{};
    bool missing(String? poster) => poster == null || poster.isEmpty;
    for (final r
        in await (select(officialImages)..where(
              (i) => i.kind.equalsValue(MediaKind.video) & i.deletedAt.isNull(),
            ))
            .get()) {
      if (missing(r.posterFile)) out.add(r.imageFile);
    }
    for (final r
        in await (select(fanArts)..where(
              (i) => i.kind.equalsValue(MediaKind.video) & i.deletedAt.isNull(),
            ))
            .get()) {
      if (missing(r.posterFile)) out.add(r.imageFile);
    }
    for (final r
        in await (select(junkImages)..where(
              (i) => i.kind.equalsValue(MediaKind.video) & i.deletedAt.isNull(),
            ))
            .get()) {
      if (missing(r.posterFile)) out.add(r.imageFile);
    }
    for (final r
        in await (select(materialImages)..where(
              (i) => i.kind.equalsValue(MediaKind.video) & i.deletedAt.isNull(),
            ))
            .get()) {
      if (missing(r.posterFile)) out.add(r.imageFile);
    }
    for (final r
        in await (select(entityImages)..where(
              (i) => i.kind.equalsValue(MediaKind.video) & i.deletedAt.isNull(),
            ))
            .get()) {
      if (missing(r.posterFile)) out.add(r.imageFile);
    }
    return out.toList();
  }
}
