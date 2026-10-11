import 'package:flutter/material.dart';

import '../oshi/oshi_detail_page.dart';
import '../oshi/oshi_list_page.dart';
import '../search/tagged_list.dart';

/// 進推活列表（OshiTimeline）的單一入口：[tagId] 有值＝帶著同一個 tag 篩選（D-065 搜尋「+N」）。
void openOshiList(BuildContext context, String pitId, {String? tagId}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OshiListPage(pitId: pitId, tagId: tagId),
    ),
  );
}

/// 進推活詳情（OshiDetail）的單一入口。從搜尋流程進來時 [inSearchFlow] 為 true，
/// 讓詳情裡點 tag 能一併關掉整串搜尋頁面。
void openOshiDetail(
  BuildContext context,
  String pitId,
  String recordId, {
  bool inSearchFlow = false,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: inSearchFlow
          ? const RouteSettings(name: kSearchFlowRoute)
          : null,
      builder: (_) => OshiDetailPage(pitId: pitId, recordId: recordId),
    ),
  );
}
