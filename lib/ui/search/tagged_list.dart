import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../album/fan_art_list_page.dart';
import '../common/svg_icon.dart';
import '../entity/draft_list_page.dart';
import '../entity/finished_list_page.dart';
import '../entity/idea_list_page.dart';
import 'pit_search_page.dart';
import 'search_icons.dart';

/// 有 tag 的四種列表（D-043）。
enum TaggedKind { fan, idea, draft, piece }

/// 搜尋流程（PitSearch、結果頁、從結果開啟的詳情）的 route 名稱。
/// 這些頁面都隱藏導覽列；離開搜尋去列表時要整串關掉，列表的導覽列才會回來。
const kSearchFlowRoute = 'pit-search-flow';

/// 該格的列表頁；[tagId] 不為 null 時是 tag 篩選狀態。
Widget taggedListPage(TaggedKind kind, String pitId, String? tagId) =>
    switch (kind) {
      TaggedKind.fan => FanArtListPage(pitId: pitId, tagId: tagId),
      TaggedKind.idea => IdeaListPage(pitId: pitId, tagId: tagId),
      TaggedKind.draft => DraftListPage(pitId: pitId, tagId: tagId),
      TaggedKind.piece => FinishedListPage(pitId: pitId, tagId: tagId),
    };

/// 回到該格列表並套用 tag 篩選（[tagId] 為 null＝完整列表）。
/// 走所屬分頁自己的 Navigator（不用 rootNavigator）。
/// [replace]：取代目前最上層的頁面（已在篩選列表裡換 tag、或按「×」回完整列表時用，
/// 返回鍵才不會一路退過每個篩選狀態）。
/// [popTop]：先關掉最上層頁面（從詳情／預覽點 tag 時，關掉詳情再處理）。
/// [leaveSearch]：從搜尋流程出來時，先關掉整串搜尋頁面（結果頁、搜尋頁、詳情）。
void openTaggedList(
  BuildContext context,
  String pitId,
  TaggedKind kind,
  String? tagId, {
  bool replace = false,
  bool popTop = false,
  bool leaveSearch = false,
}) {
  final nav = Navigator.of(context);
  if (leaveSearch) {
    nav.popUntil((r) => r.settings.name != kSearchFlowRoute);
  } else if (popTop && nav.canPop()) {
    nav.pop();
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => taggedListPage(kind, pitId, tagId),
  );
  if (replace) {
    nav.pushReplacement(route);
  } else {
    nav.push(route);
  }
}

/// 列表頁處理 tag 點擊的共同做法：
/// 完整列表＝推入篩選列表；已是篩選列表＝換掉目前的篩選（取代，返回鍵仍回到上一頁）。
/// [fromDetail]：點擊來自列表上方的詳情／預覽頁。
void onListTagTap(
  BuildContext listContext, {
  required String pitId,
  required TaggedKind kind,
  required String tagId,
  required bool listFiltered,
  bool fromDetail = false,
}) {
  openTaggedList(
    listContext,
    pitId,
    kind,
    tagId,
    replace: listFiltered,
    popTop: fromDetail,
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
