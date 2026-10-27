import 'package:flutter/material.dart';

import '../oshi/oshi_detail_page.dart';
import '../oshi/oshi_list_page.dart';
import '../search/tagged_list.dart';

/// 進推活列表（OshiTimeline）的單一入口。
void openOshiList(BuildContext context, String pitId) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => OshiListPage(pitId: pitId)));
}

/// 進推活詳情（OshiDetail）的單一入口。從搜尋流程進來時 [inSearchFlow] 為 true（隱藏導覽列）。
void openOshiDetail(
  BuildContext context,
  String pitId,
  String recordId, {
  bool inSearchFlow = false,
  List<String>? order,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: inSearchFlow
          ? const RouteSettings(name: kSearchFlowRoute)
          : null,
      builder: (_) =>
          OshiDetailPage(pitId: pitId, recordId: recordId, order: order),
    ),
  );
}
