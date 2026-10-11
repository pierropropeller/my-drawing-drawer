import 'package:flutter/material.dart';

import '../oshi/oshi_form_page.dart';

/// 分享進來選「推活」按「下一步」時，打開推活的新增頁，圖片先放好（D-059）。
///
/// [images] 是已複製進 App 儲存空間的檔案路徑。[context] 必須在「坑」分頁的
/// Navigator 之下。
void openOshiForm(BuildContext context, String pitId, List<String> images) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OshiFormPage(pitId: pitId, initialImages: images),
    ),
  );
}
