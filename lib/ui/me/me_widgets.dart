import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';

/// 我的 → 子頁（主題色、備份與同步）的自訂標題列：返回箭頭＋襯線標題（設計稿 22/14/12）。
class MeSubHeader extends StatelessWidget {
  const MeSubHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 12),
      child: Row(
        children: [
          Tooltip(
            message: '返回',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    AppIcons.back,
                    size: 24,
                    color: t.ink,
                    strokeWidth: 1.9,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// 我的／主題色／備份頁共用的白色圓角（18）卡片。
class MePanel extends StatelessWidget {
  const MePanel({super.key, required this.padding, required this.child});
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.panel),
        border: Border.all(color: t.borderCard),
      ),
      child: child,
    );
  }
}

/// 「今天 10:32」「昨天 10:32」「3/14 10:32」。
String meTimeLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return '尚未同步';
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(at.hour)}:${two(at.minute)}';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '今天 $hm';
  if (diff == 1) return '昨天 $hm';
  return '${at.month}/${at.day} $hm';
}
