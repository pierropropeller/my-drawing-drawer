import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'adaptive_modal.dart';
import 'app_icons.dart';
import 'svg_icon.dart';

/// 表單「加圖」虛線格的內容。
///
/// - 手機整頁：只有「＋」（照舊）。
/// - 彈出頁（New* 稿）：「＋」在上、「加圖」小字在下；page sheet（76 方格）加號 22、字 12、間距 2，
///   form sheet（3 欄方格）加號 26、字 12.5、間距 4；格子小於 80（NewIdea 的 72）只畫「＋」。
class AddTileContent extends StatelessWidget {
  const AddTileContent({super.key, required this.label, this.iconSize = 26});

  /// 「加圖」。
  final String label;

  /// 整頁版（沒有文字）的加號大小。
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sheet = AdaptiveModalScope.sheetOf(context);
    final popup = AdaptiveModalScope.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final withLabel = sheet || (popup && c.maxWidth >= 80);
        if (!withLabel) {
          return SvgIcon(
            AppIcons.plus,
            size: iconSize,
            strokeWidth: 1.8,
            color: t.dashedText,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: sheet ? 2 : 4,
          children: [
            SvgIcon(
              AppIcons.plus,
              size: sheet ? 22 : 26,
              strokeWidth: 1.8,
              color: t.dashedText,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: sheet ? 12 : 12.5,
                color: t.dashedText,
              ),
            ),
          ],
        );
      },
    );
  }
}
