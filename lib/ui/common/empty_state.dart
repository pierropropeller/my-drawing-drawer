import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 空白狀態模板（OfficialEmpty）：圓形 icon、說明文字、可選按鈕。
/// 同人圖、草稿、成圖等空白頁沿用，只換顏色、icon、文字。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final CategoryColor? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.official;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: c.fg),
            ),
            const SizedBox(height: 16),
            Text(text, style: TextStyle(color: t.text3, fontSize: 15)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
