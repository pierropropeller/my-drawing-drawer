import 'package:drift/drift.dart';

import 'album_queries.dart';
import 'database.dart';
import 'entity_queries.dart';
import 'oshi_queries.dart';

/// 搜尋結果的段（也是分頁 chips）；列舉順序＝顯示順序（D-051、D-065）。
enum PitSearchSection { pieces, official, fanArts, oshi, drafts, ideas }

/// 搜尋結果的一段（成圖／官方圖冊／好看同人圖／推活／草稿／腦洞）。
class PitSearchGroup<T> {
  const PitSearchGroup(this.total, this.items);

  /// 符合條件的總數（段頭的數字、「+N」的 N＝total − items.length）。
  final int total;

  /// 圖片類（成圖、官方圖、同人圖、草稿）只含前幾筆（預設 3）；腦洞含全部。
  final List<T> items;

  int get more => total - items.length;
  bool get isEmpty => total == 0;

  static const empty = PitSearchGroup<Never>(0, []);
}

/// 坑內搜尋結果；分段順序：成圖 → 官方圖冊 → 好看同人圖 → 推活 → 草稿 → 腦洞（D-051、D-065、D-089）。
class PitSearchResult {
  const PitSearchResult({
    required this.pieces,
    this.official = PitSearchGroup.empty,
    required this.fanArts,
    this.oshi = PitSearchGroup.empty,
    required this.drafts,
    required this.ideas,
  });

  final PitSearchGroup<PieceView> pieces;
  final PitSearchGroup<OfficialImage> official;
  final PitSearchGroup<FanArt> fanArts;
  final PitSearchGroup<OshiRecordView> oshi;
  final PitSearchGroup<DraftView> drafts;
  final PitSearchGroup<IdeaView> ideas;

  /// 分頁 chips「全部」的數字。
  int get total =>
      pieces.total +
      official.total +
      fanArts.total +
      oshi.total +
      drafts.total +
      ideas.total;
  bool get isEmpty => total == 0;

  /// 各段的實際筆數（D-061：少於 3 張時照實際張數放，不補格、不顯示「+N」）。
  Map<PitSearchSection, int> get counts => {
    PitSearchSection.pieces: pieces.total,
    PitSearchSection.official: official.total,
    PitSearchSection.fanArts: fanArts.total,
    PitSearchSection.oshi: oshi.total,
    PitSearchSection.drafts: drafts.total,
    PitSearchSection.ideas: ideas.total,
  };

  /// 結果不是 0 的段，依顯示順序（0 筆的分頁與分段都不顯示，D-061）。
  List<PitSearchSection> get visibleSections => [
    for (final e in counts.entries)
      if (e.value > 0) e.key,
  ];

  static const empty = PitSearchResult(
    pieces: PitSearchGroup.empty,
    official: PitSearchGroup.empty,
    fanArts: PitSearchGroup.empty,
    oshi: PitSearchGroup.empty,
    drafts: PitSearchGroup.empty,
    ideas: PitSearchGroup.empty,
  );
}

/// 坑內搜尋的條件（provider 的 key）。
class PitSearchQuery {
  const PitSearchQuery(
    this.pitId, {
    this.text = '',
    this.tagId,
    this.untagged = false,
    this.includePitName = false,
    this.unlimited = false,
  });
  final String pitId;
  final String text;
  final String? tagId;

  /// 只要沒有任何 tag 的項目（D-108）。
  final bool untagged;

  /// 從全坑搜尋點坑名進來時：坑名也算搜尋範圍（D-105 的範圍含坑名）。
  final bool includePitName;

  /// 單一相冊頁要全部結果，不是每段前幾筆（D-107）。
  final bool unlimited;

  @override
  bool operator ==(Object other) =>
      other is PitSearchQuery &&
      other.pitId == pitId &&
      other.text == text &&
      other.tagId == tagId &&
      other.untagged == untagged &&
      other.includePitName == includePitName &&
      other.unlimited == unlimited;

  @override
  int get hashCode =>
      Object.hash(pitId, text, tagId, untagged, includePitName, unlimited);
}

/// 把搜尋文字以空白分詞（小寫）。
List<String> searchTerms(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

extension SearchQueries on AppDatabase {
  /// 搜尋會讀到的資料表（watchAssembled 用）。
  Set<TableInfo> get searchTables => {
    pieces,
    drafts,
    ideas,
    fanArts,
    officialImages,
    oshiRecords,
    officialGroups,
    entityImages,
    tags,
    tagLinks,
  };

  /// 坑內搜尋。[text] 以空白分詞，每個詞都要出現在「標題／內文（推活＝描述、分組名稱）／作者／tag 名稱」
  /// 其中之一（不分大小寫）；[tagId] 要求項目有該 tag；[untagged] 要求項目沒有任何 tag（D-108，
  /// 雜物沒有 tag，不在搜尋範圍）。條件都沒給時回傳空結果。
  /// 已刪除、被移走而隱藏的同人圖、雜物都不會出現。
  /// [thumbLimit]：圖片類每段最多回傳幾筆（null＝全部，單一相冊頁用）。
  /// [includePitName]：坑名也當作每個項目的搜尋欄位（全坑搜尋的範圍含坑名，D-105）。
  Stream<PitSearchResult> watchPitSearch(
    String pitId, {
    String text = '',
    String? tagId,
    bool untagged = false,
    int? thumbLimit = 3,
    bool includePitName = false,
  }) {
    final terms = searchTerms(text);
    if (terms.isEmpty && tagId == null && !untagged) {
      return Stream.value(PitSearchResult.empty);
    }
    return watchAssembled(
      this,
      {...searchTables, if (includePitName) pits},
      () async => searchPitOnce(
        pitId,
        terms: terms,
        tagId: tagId,
        untagged: untagged,
        thumbLimit: thumbLimit,
        pitName: includePitName
            ? (await (select(
                pits,
              )..where((p) => p.id.equals(pitId))).getSingleOrNull())?.name
            : null,
      ),
    );
  }

  /// 「未加 tag」的總數（D-108）：坑內沒有任何 tag 的官方圖、同人圖、推活、摸魚、成圖、腦洞；雜物不算。
  Stream<int> watchUntaggedCount(String pitId) =>
      watchPitSearch(pitId, untagged: true, thumbLimit: 0).map((r) => r.total);

  /// [watchPitSearch] 的一次性版本；[terms] 已分詞（小寫）。
  Future<PitSearchResult> searchPitOnce(
    String pitId, {
    List<String> terms = const [],
    String? tagId,
    bool untagged = false,
    int? thumbLimit = 3,
    String? pitName,
  }) async {
    final extra = pitName?.toLowerCase();

    bool match(Iterable<String?> fields, List<Tag> tagList) {
      if (untagged && tagList.isNotEmpty) return false;
      if (tagId != null && !tagList.any((t) => t.id == tagId)) return false;
      final hay = [
        for (final f in fields)
          if (f != null && f.isNotEmpty) f.toLowerCase(),
        for (final t in tagList) t.name.toLowerCase(),
        ?extra,
      ];
      return terms.every((term) => hay.any((h) => h.contains(term)));
    }

    PitSearchGroup<T> group<T>(List<T> all, {required bool limited}) =>
        PitSearchGroup(
          all.length,
          limited && thumbLimit != null && all.length > thumbLimit
              ? all.sublist(0, thumbLimit)
              : all,
        );

    final pieceHits = [
      for (final v in await loadPieceViews(pitId))
        if (match([v.piece.title, v.piece.body], v.tags)) v,
    ];
    final draftHits = [
      for (final v in await loadDraftViews(pitId))
        if (match([v.draft.title, v.draft.body], v.tags)) v,
    ];
    final ideaHits = [
      for (final v in await loadIdeaViews(pitId))
        if (match([v.idea.title, v.idea.body], v.tags)) v,
    ];
    final oshiHits = [
      for (final v in await loadOshiViews(pitId))
        if (match([
          v.record.title,
          v.record.description,
          v.group?.name,
        ], v.tags))
          v,
    ];

    // 官方圖、同人圖的 tag：坑內所有還存在的 tag 連結，一次載入。
    final linkRows =
        await (select(tagLinks)
                .join([innerJoin(tags, tags.id.equalsExp(tagLinks.tagId))])
              ..where(
                tags.pitId.equals(pitId) &
                    tags.deletedAt.isNull() &
                    (tagLinks.targetType.equalsValue(TagTarget.fanArt) |
                        tagLinks.targetType.equalsValue(TagTarget.official)),
              ))
            .get();
    final tagsOf = <TagTarget, Map<String, List<Tag>>>{};
    for (final r in linkRows) {
      final l = r.readTable(tagLinks);
      tagsOf
          .putIfAbsent(l.targetType, () => {})
          .putIfAbsent(l.targetId, () => [])
          .add(r.readTable(tags));
    }

    final fanRows =
        await (select(fanArts)
              ..where(
                (f) =>
                    f.pitId.equals(pitId) &
                    f.deletedAt.isNull() &
                    f.hidden.equals(false),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.updatedAt)]))
            .get();
    final fanHits = [
      for (final f in fanRows)
        if (match([f.author], tagsOf[TagTarget.fanArt]?[f.id] ?? const [])) f,
    ];

    // 官方圖（D-089）：比對分組名稱與 tag 名稱。
    final officialRows =
        await (select(officialImages)
              ..where(
                (f) =>
                    f.pitId.equals(pitId) &
                    f.deletedAt.isNull() &
                    f.hidden.equals(false),
              )
              ..orderBy([(f) => OrderingTerm.desc(f.updatedAt)]))
            .get();
    final groupNames = {
      for (final g in await (select(
        officialGroups,
      )..where((g) => g.pitId.equals(pitId))).get())
        g.id: g.name,
    };
    final officialHits = [
      for (final o in officialRows)
        if (match([
          groupNames[o.groupId],
        ], tagsOf[TagTarget.official]?[o.id] ?? const []))
          o,
    ];

    return PitSearchResult(
      pieces: group(pieceHits, limited: true),
      official: group(officialHits, limited: true),
      fanArts: group(fanHits, limited: true),
      oshi: group(oshiHits, limited: true),
      drafts: group(draftHits, limited: true),
      ideas: group(ideaHits, limited: false),
    );
  }
}

// ---------------------------------------------------------------------------
// 全坑搜尋（D-105）
// ---------------------------------------------------------------------------

/// 全坑搜尋頁（還沒輸入）：一個坑和它的 tag（常用的在前，含次數）。
class GlobalTagGroup {
  const GlobalTagGroup(this.pit, this.tags);
  final Pit pit;
  final List<TagUsage> tags;
}

/// 輸入文字後符合的 tag；同名 tag 在不同坑各是一筆。
class GlobalTagHit {
  const GlobalTagHit(this.pit, this.tag);
  final Pit pit;
  final Tag tag;
}

/// 一個坑的搜尋結果（有符合內容才會出現）。
class GlobalPitResult {
  const GlobalPitResult(this.pit, this.result);
  final Pit pit;
  final PitSearchResult result;
  int get total => result.total;
}

class GlobalSearchHits {
  const GlobalSearchHits({this.tags = const [], this.pits = const []});
  final List<GlobalTagHit> tags;

  /// 符合筆數多的坑在前（同筆數依主頁順序）。
  final List<GlobalPitResult> pits;
  bool get isEmpty => tags.isEmpty && pits.isEmpty;
  static const empty = GlobalSearchHits();
}

extension GlobalSearchQueries on AppDatabase {
  /// 全部的坑：現坑 → 淺坑 → 封存坑（封存坑排最後），各自依主頁順序。
  Future<List<Pit>> loadAllPitsOrdered() async => [
    for (final s in [PitStatus.active, PitStatus.shallow, PitStatus.archived])
      ...await watchPitsByStatus({s}).first,
  ];

  /// 還沒輸入時：按坑分組的常用 tag。沒有 tag 的坑不列。
  Stream<List<GlobalTagGroup>> watchGlobalTagGroups() =>
      watchAssembled(this, {...searchTables, pits}, () async {
        final out = <GlobalTagGroup>[];
        for (final pit in await loadAllPitsOrdered()) {
          final usage = await loadTagUsage(pit.id, byUsage: true);
          if (usage.isNotEmpty) out.add(GlobalTagGroup(pit, usage));
        }
        return out;
      });

  /// 全坑搜尋。範圍：坑名、tag、標題、內文／描述、同人圖作者（每個詞都要符合）。
  /// [thumbLimit]：每坑圖片類最多回傳幾筆。
  Stream<GlobalSearchHits> watchGlobalSearch(
    String text, {
    int thumbLimit = 3,
  }) {
    final terms = searchTerms(text);
    if (terms.isEmpty) return Stream.value(GlobalSearchHits.empty);
    return watchAssembled(this, {...searchTables, pits}, () async {
      final tagHits = <GlobalTagHit>[];
      final pitHits = <GlobalPitResult>[];
      for (final pit in await loadAllPitsOrdered()) {
        final tagRows =
            await (select(tags)
                  ..where((t) => t.pitId.equals(pit.id) & t.deletedAt.isNull())
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get();
        for (final t in tagRows) {
          final n = t.name.toLowerCase();
          if (terms.every(n.contains)) tagHits.add(GlobalTagHit(pit, t));
        }
        final res = await searchPitOnce(
          pit.id,
          terms: terms,
          thumbLimit: thumbLimit,
          pitName: pit.name,
        );
        if (res.total > 0) pitHits.add(GlobalPitResult(pit, res));
      }
      // 穩定排序：筆數多的在前，同筆數維持主頁順序。
      final indexed = [for (final (i, p) in pitHits.indexed) (i, p)];
      indexed.sort((a, b) {
        final c = b.$2.total.compareTo(a.$2.total);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
      return GlobalSearchHits(
        tags: tagHits,
        pits: [for (final e in indexed) e.$2],
      );
    });
  }
}
