import 'package:flutter/material.dart';

import '../oshi/oshi_form_page.dart';

/// 分享進來選「推活」按「下一步」時，打開推活的新增表單，圖片先放好（D-059）。
/// 視窗 ≥840 開置中 modal，較窄開整頁（頁面堆疊與以前相同）。
///
/// [images] 是已複製進 App 儲存空間的檔案路徑。[context] 必須在「坑」分頁的
/// Navigator 之下。
void openOshiForm(BuildContext context, String pitId, List<String> images) {
  openOshiFormPage(context, pitId: pitId, initialImages: images);
}
