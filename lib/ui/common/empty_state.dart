import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'app_icons.dart';
import 'svg_icon.dart';

/// 空白狀態模板（OfficialEmpty／IdeaEmpty／MainEmpty／GoalEmpty）：
/// 96×96、圓角 28 的分類底色 icon 塊、襯線 19px 標題、實心主色按鈕（含加號）。
///
/// icon 優先用設計稿的 SVG 圖形 [svg]（見 `AppIcons`）；沒給時退回 Material [icon]。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.svg,
    required this.text,
    this.subtitle,
    this.color,
    this.actionLabel,
    this.onAction,
    this.actionSvg = AppIcons.plus,
  }) : assert(icon != null || svg != null, 'icon 或 svg 至少要給一個');

  final IconData? icon;

  /// 設計稿 inline SVG 圖形（24×24 內的 `<path>` 等）。
  final String? svg;
  final String text;

  /// 標題下方的補充說明（可選）。
  final String? subtitle;
  final CategoryColor? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 按鈕左側的圖形，預設加號；傳空字串則不顯示。
  final String actionSvg;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.official;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: svg != null
                  ? SvgIcon(svg!, size: 42, color: c.fg, strokeWidth: 1.5)
                  : Icon(icon, size: 42, color: c.fg),
            ),
            const SizedBox(height: 18),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text3, fontSize: 13, height: 1.4),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionSvg.isNotEmpty) ...[
                        SvgIcon(
                          actionSvg,
                          size: 18,
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
