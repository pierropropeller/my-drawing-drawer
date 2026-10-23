import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_queries.dart';
import 'providers.dart';

/// 坑內搜尋（PitSearchResult／PitSearchResultTab）。頁面拿全部結果（[PitSearchQuery.unlimited]），
/// 分段總覽自己取前 3 筆。離開頁面或改了關鍵字就釋放。
final pitSearchProvider = StreamProvider.autoDispose
    .family<PitSearchResult, PitSearchQuery>(
      (ref, q) => ref
          .watch(databaseProvider)
          .watchPitSearch(
            q.pitId,
            text: q.text,
            tagId: q.tagId,
            untagged: q.untagged,
            includePitName: q.includePitName,
            thumbLimit: q.unlimited ? null : 3,
          ),
    );

/// 「未加 tag」的數量（PitSearch 的卡片，D-108）。
final untaggedCountProvider = StreamProvider.autoDispose.family<int, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchUntaggedCount(pitId),
);

/// 全坑搜尋頁（還沒輸入）：按坑分組的常用 tag（D-105）。
final globalTagGroupsProvider =
    StreamProvider.autoDispose<List<GlobalTagGroup>>(
      (ref) => ref.watch(databaseProvider).watchGlobalTagGroups(),
    );

/// 全坑搜尋結果（D-105）。key＝輸入的文字。
final globalSearchProvider = StreamProvider.autoDispose
    .family<GlobalSearchHits, String>(
      (ref, text) => ref.watch(databaseProvider).watchGlobalSearch(text),
    );

/// iPad 版全坑搜尋結果（P-028）：每坑圖片一排 6 格，所以每段要多載入一些縮圖。key＝輸入的文字。
final globalSearchWideProvider = StreamProvider.autoDispose
    .family<GlobalSearchHits, String>(
      (ref, text) =>
          ref.watch(databaseProvider).watchGlobalSearch(text, thumbLimit: 6),
    );
