import 'package:flutter/painting.dart';

/// 參考圖檢視的固定配色（RefFull／RefSplit artboard）：背景的「深／淺」是檢視狀態，
/// 不隨 App 主題變化。強調色（accent）另外跟主題。
class RefPalette {
  const RefPalette({
    required this.pane,
    required this.stage,
    required this.fg,
    required this.sub,
    required this.off,
    required this.chip,
    required this.line,
    required this.danger,
    required this.activeBtn,
  });

  /// 整頁底色。
  final Color pane;

  /// 圖片舞台底色。
  final Color stage;
  final Color fg;
  final Color sub;

  /// 沒有啟用的工具列文字／icon 色。
  final Color off;
  final Color chip;
  final Color line;
  final Color danger;

  /// 資料面板開關按鈕「開啟」時的底色。
  final Color activeBtn;

  static const dark = RefPalette(
    pane: Color(0xFF1E1B18),
    stage: Color(0xFF141210),
    fg: Color(0xFFF5F0E8),
    sub: Color(0xFFA49A8C),
    off: Color(0xFFCFC6BA),
    chip: Color(0x1FFFFFFF),
    line: Color(0x14FFFFFF),
    danger: Color(0xFFF08A76),
    activeBtn: Color(0x1FFFFFFF),
  );

  static const light = RefPalette(
    pane: Color(0xFFF3EFE9),
    stage: Color(0xFFE8E2D9),
    fg: Color(0xFF2B2622),
    sub: Color(0xFF6E655B),
    off: Color(0xFF6E655B),
    chip: Color(0x142B2622),
    line: Color(0xFFE2D9CC),
    danger: Color(0xFFB84B38),
    activeBtn: Color(0x142B2622),
  );

  static RefPalette of({required bool lightBg}) => lightBg ? light : dark;

  /// 圖上浮動 pill 的底色（兩種背景都是深色半透明，artboard 固定值）。
  static const floating = Color(0xD1161412);
  static const floatingFg = Color(0xFFF5F0E8);
  static const floatingOff = Color(0xFFCFC6BA);
}
