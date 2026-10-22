import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../common/svg_icon.dart';
import 'global_search_page.dart';
import 'pit_search_page.dart';
import 'pit_search_result_page.dart';
import 'search_icons.dart';
import 'search_widgets.dart';

/// 搜尋流程（全坑搜尋、PitSearch、結果頁、從結果開啟的詳情）的 route 名稱。
/// 這些頁面都隱藏導覽列。
const kSearchFlowRoute = 'pit-search-flow';

/// 點任何一個 tag（詳情／預覽頁、搜尋結果）：進該坑的坑內搜尋結果頁，搜尋列帶著這個 tag，
/// 範圍是整個坑，相冊預設「全部」（D-107，取代 D-043、D-051、D-065 回到列表並篩選的做法）。
/// 走所屬分頁自己的 Navigator（不用 rootNavigator）；一律推入新頁，返回鍵回到原本的頁面。
void openTagSearch(
  BuildContext context,
  String pitId,
  String tagId, {
  SearchCategory category = SearchCategory.all,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kSearchFlowRoute),
      builder: (_) =>
          PitSearchResultPage(pitId: pitId, tagId: tagId, category: category),
    ),
  );
}

/// 開啟坑內搜尋（PitSearch）。
void openPitSearch(BuildContext context, String pitId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kSearchFlowRoute),
      builder: (_) => PitSearchPage(pitId: pitId),
    ),
  );
}

/// 開啟全坑搜尋（GlobalSearch，主頁右上的搜尋鍵，D-105）。
void openGlobalSearch(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kSearchFlowRoute),
      builder: (_) => const GlobalSearchPage(),
    ),
  );
}

/// 列表標題列右上的搜尋 icon（40×40，22px，stroke 1.9）。
class SearchIconButton extends StatelessWidget {
  const SearchIconButton({super.key, required this.pitId});
  final String pitId;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.commonSearch,
    child: InkResponse(
      radius: 24,
      onTap: () => openPitSearch(context, pitId),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SvgIcon(
            SearchIcons.search,
            size: 22,
            strokeWidth: 1.9,
            color: context.tokens.ink,
          ),
        ),
      ),
    ),
  );
}
