import 'package:drift/drift.dart';

import 'database.dart';
import 'entity_queries.dart';

/// 搜尋結果的一段（成圖／好看同人圖／草稿／腦洞）。
class PitSearchGroup<T> {
  const PitSearchGroup(this.total, this.items);

  /// 符合條件的總數（段頭的數字、「+N」的 N＝total − items.length）。
  final int total;

  /// 圖片類（成圖、同人圖、草稿）只含前幾筆（預設 3）；腦洞含全部。
  final List<T> items;

  int get more => total - items.length;
  bool get isEmpty => total == 0;

  static const empty = PitSearchGroup<Never>(0, []);
}

/// 坑內搜尋結果；分段順序＝完成度：成圖 → 好看同人圖 → 草稿 → 腦洞（D-051）。
class PitSearchResult {
  const PitSearchResult({
    required this.pieces,
    required this.fanArts,
    required this.drafts,
    required this.ideas,
  });

  final PitSearchGroup<PieceView> pieces;
  final PitSearchGroup<FanArt> fanArts;
  final PitSearchGroup<DraftView> drafts;
  final PitSearchGroup<IdeaView> ideas;

  /// 分頁 chips「全部」的數字。
  int get total => pieces.total + fanArts.total + drafts.total + ideas.total;
  bool get isEmpty => total == 0;

  static const empty = PitSearchResult(
    pieces: PitSearchGroup.empty,
    fanArts: PitSearchGroup.empty,
    drafts: PitSearchGroup.empty,
    ideas: PitSearchGroup.empty,
  );
}

extension SearchQueries on AppDatabase {
  /// 坑內搜尋。[text] 以空白分詞，每個詞都要出現在「標題／內文／作者／tag 名稱」其中之一
  /// （不分大小寫）；[tagId] 要求項目有該 tag。兩者都沒給時回傳空結果。
  /// 已刪除、被移走而隱藏的同人圖、雜物都不會出現。
  /// [thumbLimit]：圖片類每段最多回傳幾筆。
  Stream<PitSearchResult> watchPitSearch(
    String pitId, {
    String text = '',
    String? tagId,
    int thumbLimit = 3,
  }) {
    final terms = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty && tagId == null) {
      return Stream.value(PitSearchResult.empty);
    }
    return watchAssembled(
      this,
      {pieces, drafts, ideas, fanArts, entityImages, tags, tagLinks},
      () async {
        bool match(Iterable<String?> fields, List<Tag> tagList) {
          if (tagId != null && !tagList.any((t) => t.id == tagId)) {
            return false;
          }
          final hay = [
            for (final f in fields)
              if (f != null && f.isNotEmpty) f.toLowerCase(),
            for (final t in tagList) t.name.toLowerCase(),
          ];
          return terms.every((term) => hay.any((h) => h.contains(term)));
        }

        PitSearchGroup<T> group<T>(List<T> all, {required bool limited}) =>
            PitSearchGroup(
              all.length,
              limited && all.length > thumbLimit
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
        final fanHits = <FanArt>[];
        for (final f in fanRows) {
          final tagRows =
              await (select(tags).join([
                    innerJoin(tagLinks, tagLinks.tagId.equalsExp(tags.id)),
                  ])..where(
                    tagLinks.targetType.equalsValue(TagTarget.fanArt) &
                        tagLinks.targetId.equals(f.id) &
                        tags.deletedAt.isNull(),
                  ))
                  .get();
          if (match([f.author], [for (final r in tagRows) r.readTable(tags)])) {
            fanHits.add(f);
          }
        }

        return PitSearchResult(
          pieces: group(pieceHits, limited: true),
          fanArts: group(fanHits, limited: true),
          drafts: group(draftHits, limited: true),
          ideas: group(ideaHits, limited: false),
        );
      },
    );
  }
}
