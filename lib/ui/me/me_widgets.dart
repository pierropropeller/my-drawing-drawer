import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../common/nav_bar_hidden.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../../l10n/l10n.dart';

/// 我的 → 子頁（主題色、備份與同步）的自訂標題列：返回箭頭＋襯線標題（設計稿 22/14/12）。
class MeSubHeader extends StatelessWidget {
  const MeSubHeader(this.title, {super.key, this.bottom = 12});
  final String title;

  /// 標題列下方留白：主題色／備份 12，其餘子頁 8。
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 22, 14, bottom),
      child: Row(
        children: [
          Tooltip(
            message: context.l10n.commonBack,
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
  if (at == null) return l10nStatic.meNotSyncedYet;
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final hm = '${two(at.hour)}:${two(at.minute)}';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10nStatic.meTimeToday(hm);
  if (diff == 1) return l10nStatic.meTimeYesterday(hm);
  return l10nStatic.meTimeDate(at.month, at.day, hm);
}

/// 「我的」子頁的外框。
///
/// 一般（手機／整頁）＝藏導覽的 Scaffold＋返回列 [MeSubHeader]；
/// [embedded]（iPad 右側內容面板）＝只有襯線大標題（Profile 稿 24/700）和內容，不藏導覽。
class MePageFrame extends StatelessWidget {
  const MePageFrame({
    super.key,
    required this.title,
    required this.child,
    this.embedded = false,
    this.bottom = 12,
  });
  final String title;
  final Widget child;
  final bool embedded;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 30, 40, 14),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: child,
            ),
          ),
        ],
      );
    }
    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              MeSubHeader(title, bottom: bottom),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
