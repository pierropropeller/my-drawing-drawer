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
  const MePanel({
    super.key,
    required this.padding,
    required this.child,
    this.borderColor,
    this.borderWidth = 1,
  });
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// 換掉外框色／粗細（例如 Drive 已滿的紅框，BackupFull）；null＝一般卡片外框。
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.panel),
        border: Border.all(
          color: borderColor ?? t.borderCard,
          width: borderWidth,
        ),
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
      final back = MeEmbeddedBack.maybeOf(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (back != null) _EmbeddedBackButton(back),
          Padding(
            padding: EdgeInsets.fromLTRB(40, back == null ? 30 : 8, 40, 14),
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

/// iPad「我的」右欄：從「個人化」點進子頁時，子頁頂部多一顆「‹ 個人化」返回鍵（Profile 稿）。
/// 由 ProfilePage 包在子頁外面；[MePageFrame] 的 embedded 版讀到它就畫返回鍵。
class MeEmbeddedBack extends InheritedWidget {
  const MeEmbeddedBack({
    super.key,
    required this.label,
    required this.onBack,
    required super.child,
  });

  /// 返回鍵上的字（上一層的名稱，例如「個人化」）。
  final String label;
  final VoidCallback onBack;

  static MeEmbeddedBack? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MeEmbeddedBack>();

  @override
  bool updateShouldNotify(MeEmbeddedBack oldWidget) => oldWidget.label != label;
}

/// 「‹ 個人化」：36 高、14 字、text2，箭頭 18／線寬 2（Profile 稿）。
class _EmbeddedBackButton extends StatelessWidget {
  const _EmbeddedBackButton(this.back);
  final MeEmbeddedBack back;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 40, 0),
      child: Semantics(
        button: true,
        label: back.label,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('meEmbeddedBack'),
          borderRadius: BorderRadius.circular(10),
          onTap: back.onBack,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  SvgIcon(
                    AppIcons.back,
                    size: 18,
                    color: t.text2,
                    strokeWidth: 2,
                  ),
                  Text(
                    back.label,
                    style: TextStyle(fontSize: 14, color: t.text2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「我的」「個人化」卡片裡的一列（Profile／Personalize 稿）：38px 圓角色塊 icon（或自訂 [leading]）、
/// 標題、右邊目前值、箭頭；列與列之間 1px 分隔線（[last] 沒有）。
class MeListRow extends StatelessWidget {
  const MeListRow({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.tileBg,
    this.tileFg,
    this.value,
    this.last = false,
    this.iconSize = 21,
    this.iconStroke = 1.7,
  });

  final String? icon;
  final Widget? leading;
  final Color? tileBg;
  final Color? tileFg;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool last;
  final double iconSize;
  final double iconStroke;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chevron = dark ? t.text4 : const Color(0xFFB7ADA0);
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: divider)),
        ),
        child: Row(
          children: [
            leading ??
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: SvgIcon(
                      icon!,
                      size: iconSize,
                      color: tileFg,
                      strokeWidth: iconStroke,
                    ),
                  ),
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(value!, style: TextStyle(fontSize: 13, color: t.text4)),
              const SizedBox(width: 12),
            ],
            SvgIcon(
              AppIcons.chevronRight,
              size: 18,
              color: chevron,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
