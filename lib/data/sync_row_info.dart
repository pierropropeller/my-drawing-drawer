import 'package:drift/drift.dart';

import 'database.dart';

/// 同步進度 sheet 一行要顯示的「這張圖屬於哪裡」（D-099）。
enum SyncRowKind {
  official,
  fan,
  junk,
  material,
  piece,
  draft,
  idea,
  oshi,
  cover,
}

class SyncRowInfo {
  const SyncRowInfo({
    required this.kind,
    this.pitName,
    this.title,
    this.materialCategory,
    this.posterFile,
  });

  final SyncRowKind kind;

  /// 所屬坑名（素材庫沒有坑）。
  final String? pitName;

  /// 腦洞／摸魚／成圖／推活的標題（沒有標題為 null）。
  final String? title;

  /// 素材庫的分類（只有 [SyncRowKind.material]）。
  final MaterialCategory? materialCategory;

  /// 這個檔案是影片時，它的 poster 圖檔名（列的縮圖用 poster）。
  final String? posterFile;

  @override
  bool operator ==(Object other) =>
      other is SyncRowInfo &&
      other.kind == kind &&
      other.pitName == pitName &&
      other.title == title &&
      other.materialCategory == materialCategory &&
      other.posterFile == posterFile;

  @override
  int get hashCode =>
      Object.hash(kind, pitName, title, materialCategory, posterFile);

  @override
  String toString() => 'SyncRowInfo($kind, $pitName, $title)';
}

class _Hit {
  _Hit(this.kind, {this.pitId, this.category, this.poster});
  final SyncRowKind kind;
  String? pitId;
  final MaterialCategory? category;
  final String? poster;
  String? title;
}

extension SyncRowInfoQueries on AppDatabase {
  /// 一次查一批圖片檔名所屬的實體、坑名與標題（同步 sheet 用，D-099）。
  /// 每張資料表各一個 `IN (...)` 查詢，再各一次批次查坑名與標題；**不逐張查**。
  ///
  /// 同一檔案出現在多處時的優先順序：官方圖冊 → 好看同人圖 → 雜物 → 素材庫 → 成圖 → 摸魚 → 腦洞
  /// → 推活 → 坑封面。已刪除、被移動而隱藏的列、所屬實體已刪除的不算。
  /// 影片的 poster 檔也會對應到同一個實體。找不到的檔案不在回傳的 map 裡。
  Future<Map<String, SyncRowInfo>> syncRowInfos(Iterable<String> files) async {
    final want = files.where((f) => f.isNotEmpty).toSet().toList();
    if (want.isEmpty) return const {};
    final hits = <String, _Hit>{};

    void add(String image, String? poster, _Hit Function(String? poster) make) {
      if (want.contains(image)) hits.putIfAbsent(image, () => make(poster));
      if (poster != null && want.contains(poster)) {
        hits.putIfAbsent(poster, () => make(null));
      }
    }

    final official =
        await (select(officialImages)..where(
              (i) =>
                  (i.imageFile.isIn(want) | i.posterFile.isIn(want)) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false),
            ))
            .get();
    for (final r in official) {
      add(
        r.imageFile,
        r.posterFile,
        (p) => _Hit(SyncRowKind.official, pitId: r.pitId, poster: p),
      );
    }
    final fan =
        await (select(fanArts)..where(
              (i) =>
                  (i.imageFile.isIn(want) | i.posterFile.isIn(want)) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false),
            ))
            .get();
    for (final r in fan) {
      add(
        r.imageFile,
        r.posterFile,
        (p) => _Hit(SyncRowKind.fan, pitId: r.pitId, poster: p),
      );
    }
    final junk =
        await (select(junkImages)..where(
              (i) =>
                  (i.imageFile.isIn(want) | i.posterFile.isIn(want)) &
                  i.deletedAt.isNull() &
                  i.hidden.equals(false),
            ))
            .get();
    for (final r in junk) {
      add(
        r.imageFile,
        r.posterFile,
        (p) => _Hit(SyncRowKind.junk, pitId: r.pitId, poster: p),
      );
    }
    final material =
        await (select(materialImages)..where(
              (i) =>
                  (i.imageFile.isIn(want) | i.posterFile.isIn(want)) &
                  i.deletedAt.isNull(),
            ))
            .get();
    for (final r in material) {
      add(
        r.imageFile,
        r.posterFile,
        (p) => _Hit(SyncRowKind.material, category: r.category, poster: p),
      );
    }

    // 成圖 → 摸魚 → 腦洞 → 推活：圖片列只知道 ownerId，標題與坑由擁有者批次查。
    for (final (type, kind) in [
      (OwnerType.piece, SyncRowKind.piece),
      (OwnerType.draft, SyncRowKind.draft),
      (OwnerType.idea, SyncRowKind.idea),
      (OwnerType.oshi, SyncRowKind.oshi),
    ]) {
      final rows =
          await (select(entityImages)..where(
                (e) =>
                    e.ownerType.equalsValue(type) &
                    (e.imageFile.isIn(want) | e.posterFile.isIn(want)) &
                    e.deletedAt.isNull(),
              ))
              .get();
      if (rows.isEmpty) continue;
      final ids = {for (final e in rows) e.ownerId}.toList();
      final map = switch (type) {
        OwnerType.piece => {
          for (final o in await (select(
            pieces,
          )..where((p) => p.id.isIn(ids) & p.deletedAt.isNull())).get())
            o.id: (pitId: o.pitId, title: o.title),
        },
        OwnerType.draft => {
          for (final o in await (select(
            drafts,
          )..where((p) => p.id.isIn(ids) & p.deletedAt.isNull())).get())
            o.id: (pitId: o.pitId, title: o.title),
        },
        OwnerType.idea => {
          for (final o in await (select(
            ideas,
          )..where((p) => p.id.isIn(ids) & p.deletedAt.isNull())).get())
            o.id: (pitId: o.pitId, title: o.title),
        },
        OwnerType.oshi => {
          for (final o in await (select(
            oshiRecords,
          )..where((p) => p.id.isIn(ids) & p.deletedAt.isNull())).get())
            o.id: (pitId: o.pitId, title: o.title),
        },
      };
      for (final e in rows) {
        final owner = map[e.ownerId];
        if (owner == null) continue; // 擁有者已刪除
        add(e.imageFile, e.posterFile, (p) {
          final h = _Hit(kind, pitId: owner.pitId, poster: p);
          final t = owner.title?.trim();
          h.title = (t == null || t.isEmpty) ? null : t;
          return h;
        });
      }
    }

    // 坑自己的封面檔（淺坑封面）。
    final covers = await (select(
      pits,
    )..where((p) => p.coverFile.isIn(want) & p.deletedAt.isNull())).get();
    for (final r in covers) {
      final f = r.coverFile!;
      hits.putIfAbsent(f, () => _Hit(SyncRowKind.cover, pitId: r.id));
    }

    // 坑名：一次查。
    final pitIds = {
      for (final h in hits.values)
        if (h.pitId != null) h.pitId!,
    }.toList();
    final names = <String, String>{};
    if (pitIds.isNotEmpty) {
      for (final p in await (select(
        pits,
      )..where((p) => p.id.isIn(pitIds))).get()) {
        names[p.id] = p.name;
      }
    }
    return {
      for (final e in hits.entries)
        e.key: SyncRowInfo(
          kind: e.value.kind,
          pitName: names[e.value.pitId],
          title: e.value.title,
          materialCategory: e.value.category,
          posterFile: e.value.poster,
        ),
    };
  }
}
