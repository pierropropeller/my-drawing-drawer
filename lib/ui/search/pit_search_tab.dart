import 'package:flutter/material.dart';

import '../../data/search_queries.dart';
import 'search_hits.dart';

/// 坑內搜尋結果的單一相冊（PitSearchResultTab，D-107）：該相冊所有符合的內容。
/// 圖片類＝九宮格（貼邊、間距 2px，同其他九宮格）；腦洞＝文字卡直向列出。
/// 點圖照開原本的預覽／詳情。
class PitSearchResultTab extends StatelessWidget {
  const PitSearchResultTab({
    super.key,
    required this.section,
    required this.res,
    required this.opener,
    required this.selection,
  });
  final PitSearchSection section;
  final PitSearchResult res;
  final SearchOpener opener;
  final SearchSelection selection;

  /// 這個相冊目前所有的格子（單一相冊頁拿全部結果）。
  List<SearchTile> get tiles => searchTilesOf(res, section);

  @override
  Widget build(BuildContext context) {
    final list = tiles;
    if (section == PitSearchSection.ideas) {
      return ListView.separated(
        key: const ValueKey('searchTabIdeas'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => IdeaResultCard(
          tile: list[i],
          selection: selection,
          onTap: () => opener.open(section, list[i].index),
        ),
      );
    }
    return GridView.builder(
      key: const ValueKey('searchTabGrid'),
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => SearchTileCell(
        tile: list[i],
        selection: selection,
        onTap: () => opener.open(section, list[i].index),
      ),
    );
  }
}
