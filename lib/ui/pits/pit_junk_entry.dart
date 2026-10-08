import 'package:flutter/material.dart';

/// 打開某個坑的雜物列表。
/// 暫時的佔位頁；統籌合併後改指向 `JunkListPage(pitId: pitId)`。
void openJunk(BuildContext context, String pitId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('雜物'))),
    ),
  );
}
