import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// 進推活列表（OshiTimeline）的單一入口：[tagId] 有值＝帶著同一個 tag 篩選（D-065 搜尋「+N」）。
/// 暫時只推一個寫著「推活」的佔位頁；統籌合併時接到 `OshiListPage(pitId:, tagId:)`。
void openOshiList(BuildContext context, String pitId, {String? tagId}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _OshiPlaceholder(label: context.l10n.pitsCellOshi),
    ),
  );
}

/// 進推活詳情（OshiDetail）的單一入口。暫時是佔位頁；統籌合併時接到推活詳情頁。
void openOshiDetail(BuildContext context, String recordId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _OshiPlaceholder(label: context.l10n.pitsCellOshi),
    ),
  );
}

class _OshiPlaceholder extends StatelessWidget {
  const _OshiPlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Text(label))),
  );
}
