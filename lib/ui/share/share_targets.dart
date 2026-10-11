import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../common/nav_bar_hidden.dart';

/// 分享進來選「推活」按「下一步」時，打開推活的新增頁，圖片先放好（D-059）。
///
/// [images] 是已複製進 App 儲存空間的檔案路徑。[context] 必須在「坑」分頁的
/// Navigator 之下。
///
/// 暫時只推一個寫著「推活」的佔位頁；統籌合併時改接
/// `OshiFormPage(pitId: pitId, initialImages: …)`，這是唯一要改的地方。
void openOshiForm(BuildContext context, String pitId, List<String> images) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _OshiFormPlaceholder(pitId: pitId, images: images),
    ),
  );
}

class _OshiFormPlaceholder extends StatefulWidget {
  const _OshiFormPlaceholder({required this.pitId, required this.images});
  final String pitId;
  final List<String> images;

  @override
  State<_OshiFormPlaceholder> createState() => _OshiFormPlaceholderState();
}

// 新增頁沒有導覽列。
class _OshiFormPlaceholderState extends State<_OshiFormPlaceholder>
    with HidesNavBar<_OshiFormPlaceholder> {
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(context.l10n.shareMoveOshi)));
}
