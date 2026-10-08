import 'package:flutter/material.dart';

import '../junk/junk_list_page.dart';

/// 打開某個坑的雜物列表（坑內頁最底的「雜物」入口）。
void openJunk(BuildContext context, String pitId) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => JunkListPage(pitId: pitId)));
}
