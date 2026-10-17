import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// iPad／Android 平板響應式的視窗級別（RespSpec）。
///
/// 一律按「視窗闊度」判斷，不猜裝置：iPad 分屏（Split View／Slide Over）可以自由拉闊收窄，
/// Android 平板和 iPad 用同一套。斷點：0 / 600 / 840 / 1200。
enum WindowClass {
  /// ＜600：手機版面（底部導覽列、2 欄、分兩頁、預覽全螢幕）。
  compact,

  /// 600–839：左 icon rail 84、3 欄、分兩頁、預覽／篩選面板用底部 sheet。
  medium,

  /// 840–1199：主頁／坑頁／目標用完整 sidebar 260；分區內用 icon rail 84；
  /// 列表＋詳情並排；預覽／篩選面板固定在右側（300–340）。
  expanded,

  /// ≥1200：同 expanded，右側面板 340–380。
  large;

  static const double mediumMin = 600;
  static const double expandedMin = 840;
  static const double largeMin = 1200;

  /// 依闊度（邏輯像素）判斷級別。區域元件（例如面板內）請用 [LayoutBuilder] 的
  /// `constraints.maxWidth` 傳進來，不要用整個視窗的闊度。
  static WindowClass forWidth(double width) {
    if (width >= largeMin) return large;
    if (width >= expandedMin) return expanded;
    if (width >= mediumMin) return medium;
    return compact;
  }

  /// 目前視窗的級別（整個 App 視窗的闊度）。
  static WindowClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;

  /// ≥600：有 icon rail／sidebar，不再用底部導覽列。
  bool get hasSideNav => this != compact;

  /// ≥840：列表＋詳情並排、右側固定面板。
  bool get isWide => this == expanded || this == large;
}

/// 格狀欄數：`max(2, floor(可用闊 ÷ 180))`（RespSpec）。逐格增減，不跳 layout。
int gridColumnsFor(double availableWidth, {double minCell = 180}) =>
    math.max(2, (availableWidth / minCell).floor());

/// 側面板闊度：在 [min]～[max] 之間，取視窗闊度的 [fraction]（稿中 300–340／340–380 是範圍，不是固定值）。
double panelWidthFor(
  double windowWidth, {
  double min = 300,
  double max = 340,
  double fraction = 0.28,
}) => (windowWidth * fraction).clamp(min, max).toDouble();
