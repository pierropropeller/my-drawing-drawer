import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 測試用：強制「這是平板裝置（iPad）」或「這是手機」；null＝照真實裝置判斷。
@visibleForTesting
bool? debugTabletDeviceOverride;

/// 這台「裝置」是不是 iPad（螢幕短邊 ≥ 600 的 iOS 裝置）。
///
/// 和 [WindowClass]（看視窗闊度）不同：iPad 分屏的窄視窗（約 400 寬）闊度上是 compact，
/// 但畫面該用 iPad 設計稿的 400 版（RespRef400、New*400…），而不是手機版。
/// 這裡看的是整個螢幕（不是視窗），所以分屏、Slide Over、拉窗都不會改變結果。
/// 手機（含橫向）永遠是 false，手機版面因此不受 iPad 400 稿影響。
bool isTabletDevice(BuildContext context) {
  final override = debugTabletDeviceOverride;
  if (override != null) return override;
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  final display = View.of(context).display;
  final ratio = display.devicePixelRatio;
  if (ratio <= 0) return false;
  return display.size.shortestSide / ratio >= 600;
}
