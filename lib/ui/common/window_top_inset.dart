import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iPad 頁面頂部的保底讓位（邏輯像素）。
///
/// iPadOS 26 視窗模式在視窗左上角有紅黃綠三個視窗控制點（和狀態列同高、位在螢幕最上方），
/// 全螢幕時是狀態列（iPad 的 top safe inset 約 24）。頁面標題列（返回鍵）若直接從視窗最上緣開始，
/// 會被控制點蓋住、很難按。做法同 Twitter／Telegram：整個內容往下推到控制點／狀態列之下。
/// 28 只夠全螢幕（狀態列）用。
const double kTabletTopInsetFloor = 28;

/// 視窗化（iPadOS 視窗模式／分屏）而原生又量不到控制點區域時的較大保底。
/// 實機（iPadOS 26，約 2px/pt 的截圖）量到：控制點藥丸在狀態列下方，y≈44–65pt、x≈21–82pt，
/// 28 會被完全蓋住；內容起點要在 65pt 之下再留一點空隙，取 72。
const double kTabletWindowedTopInsetFloor = 72;

/// 原生量到控制點下緣時，內容起點再往下留的間距。
const double kTabletControlsGap = 8;

/// 平板（iPad）的判斷門檻：螢幕（不是視窗）短邊 ≥ 600 pt。iPhone 最大 440；iPad mini 744。
const double kTabletShortestSide = 600;

/// 原生（iOS）回報的視窗資訊。每個欄位都可能是 null（取不到），Dart 端以保底值為預設。
@immutable
class NativeWindowInsets {
  const NativeWindowInsets({
    this.isPad,
    this.top,
    this.leading,
    this.windowed,
    this.controlsRight,
    this.controlsBottom,
  });

  /// `UIDevice.userInterfaceIdiom == .pad`。視窗被縮得很窄時，只看視窗大小會誤判成手機，
  /// 所以優先用原生的裝置種類。
  final bool? isPad;

  /// 視窗頂部需要讓出的高度：`max(window.safeAreaInsets.top, 狀態列高度)`。
  final double? top;

  /// 視窗左側的 safe inset（目前只回報，版面還沒有用到）。
  final double? leading;

  /// 視窗是否小於整個螢幕（iPadOS 視窗模式）。
  final bool? windowed;

  /// iOS 26 視窗控制點區域（`layoutGuide(for:)`）：被占用的右緣 x（視窗座標，pt）。
  /// 取不到、或沒有控制點（全螢幕）為 null。
  final double? controlsRight;

  /// 視窗控制點區域的下緣 y（視窗座標，pt）。取不到、或沒有控制點為 null。
  final double? controlsBottom;

  static NativeWindowInsets? fromMap(Object? raw) {
    if (raw is! Map) return null;
    double? num_(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
    double? positive(Object? v) {
      final d = num_(v);
      return d != null && d > 0 ? d : null;
    }

    final isPad = raw['isPad'];
    final windowed = raw['windowed'];
    return NativeWindowInsets(
      isPad: isPad is bool ? isPad : null,
      top: num_(raw['top']),
      leading: num_(raw['leading']),
      windowed: windowed is bool ? windowed : null,
      controlsRight: positive(raw['controlsRight']),
      controlsBottom: positive(raw['controlsBottom']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NativeWindowInsets &&
      other.isPad == isPad &&
      other.top == top &&
      other.leading == leading &&
      other.windowed == windowed &&
      other.controlsRight == controlsRight &&
      other.controlsBottom == controlsBottom;

  @override
  int get hashCode =>
      Object.hash(isPad, top, leading, windowed, controlsRight, controlsBottom);
}

/// 原生通道（ios/Runner/AppDelegate.swift 的 `io.molly.drawer/window`）。
/// 沒有實作、丟例外、回傳格式不對都回 null——Dart 端用保底值。
abstract final class WindowInsetsChannel {
  static const _channel = MethodChannel('io.molly.drawer/window');

  static Future<NativeWindowInsets?> fetch() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('windowInsets');
      return NativeWindowInsets.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  /// 原生在視窗大小／位置改變時主動呼叫 `windowInsetsChanged`（格式同 `windowInsets`）。
  /// 只保留一個監聽者；傳 null 取消。
  static void listen(void Function(NativeWindowInsets? value)? onChanged) {
    if (onChanged == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'windowInsetsChanged') {
        onChanged(NativeWindowInsets.fromMap(call.arguments));
      }
      return null;
    });
  }
}

/// 頂部讓位的計算（純函式，好測試）。
///
/// 只有「iOS 且是 iPad」才調整，只會加大、不會縮小 [current]：
/// 1. 至少 [kTabletTopInsetFloor]（狀態列），原生回報更大的 top 就採用；
/// 2. 原生量到視窗控制點下緣 → 取「下緣 + [kTabletControlsGap]」；
/// 3. 量不到、但視窗化（原生 `windowed`，沒有就看 [windowedByGeometry]）→ 至少 [kTabletWindowedTopInsetFloor]。
/// 其他平台、手機一律原樣回傳。
double resolveTopInset({
  required double current,
  required bool isIos,
  required bool isTablet,
  NativeWindowInsets? native,
  bool windowedByGeometry = false,
}) {
  if (!isIos || !isTablet) return current;
  var top = math.max(current, math.max(kTabletTopInsetFloor, native?.top ?? 0));
  final controlsBottom = native?.controlsBottom;
  if (controlsBottom != null && controlsBottom > 0) {
    return math.max(top, controlsBottom + kTabletControlsGap);
  }
  if (native?.windowed ?? windowedByGeometry) {
    top = math.max(top, kTabletWindowedTopInsetFloor);
  }
  return top;
}

/// 視窗是否小於螢幕（原生沒回報 `windowed` 時的備援）：視窗任一邊比 `Display` 小。
bool isWindowedByGeometry(BuildContext context) {
  final view = View.maybeOf(context);
  if (view == null) return false;
  final display = view.display;
  final ratio = display.devicePixelRatio;
  final screen = display.size;
  if (ratio <= 0 || screen.isEmpty) return false;
  final window = MediaQuery.sizeOf(context);
  return window.width < screen.width / ratio - 1 ||
      window.height < screen.height / ratio - 1;
}

/// 這個裝置是不是平板：原生說了算；沒有就看螢幕（`Display`，不是視窗）的短邊，
/// 拿不到螢幕尺寸才退回視窗短邊。
bool isTabletDevice(BuildContext context, NativeWindowInsets? native) {
  final isPad = native?.isPad;
  if (isPad != null) return isPad;
  final view = View.maybeOf(context);
  if (view != null) {
    final display = view.display;
    final ratio = display.devicePixelRatio;
    final size = display.size;
    if (ratio > 0 && !size.isEmpty) {
      return size.shortestSide / ratio >= kTabletShortestSide;
    }
  }
  return MediaQuery.sizeOf(context).shortestSide >= kTabletShortestSide;
}

/// 根層讓位：iPad 上把 `MediaQuery` 的頂部 padding／viewPadding 補到避開視窗控制點
/// （見 [resolveTopInset]：控制點下緣＋8／視窗化保底 72／全螢幕 28），
/// 所有用 `SafeArea`／`AppBar`／`MediaQuery.padding` 的頁面（含導覽 rail、sidebar）都跟著往下讓，
/// 不用逐頁改。放在 `MaterialApp.builder` 裡。Modal、sheet 會自己清掉頂部 padding，不受影響。
///
/// Android、手機（含 iPhone）完全不動。
class TabletTopInsetGuard extends StatefulWidget {
  const TabletTopInsetGuard({
    super.key,
    required this.child,
    this.loadNative = WindowInsetsChannel.fetch,
  });

  final Widget child;

  /// 讀原生視窗資訊（測試可換掉）。只在 iOS 呼叫。
  final Future<NativeWindowInsets?> Function() loadNative;

  @override
  State<TabletTopInsetGuard> createState() => _TabletTopInsetGuardState();
}

class _TabletTopInsetGuardState extends State<TabletTopInsetGuard>
    with WidgetsBindingObserver {
  NativeWindowInsets? _native;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isIos) {
      WidgetsBinding.instance.addObserver(this);
      WindowInsetsChannel.listen(_onNative);
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_isIos) WindowInsetsChannel.listen(null);
    super.dispose();
  }

  /// 視窗被拉動（視窗模式）時，原生的 inset 可能改變，重讀一次。
  @override
  void didChangeMetrics() => unawaited(_refresh());

  /// 原生主動通知（視窗拉動、分屏、控制點出現／消失）。
  void _onNative(NativeWindowInsets? v) {
    if (!mounted || v == _native) return;
    setState(() => _native = v);
  }

  Future<void> _refresh() async {
    _onNative(await widget.loadNative());
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final tablet = _isIos && isTabletDevice(context, _native);
    final top = resolveTopInset(
      current: mq.padding.top,
      isIos: _isIos,
      isTablet: tablet,
      native: _native,
      windowedByGeometry: tablet && isWindowedByGeometry(context),
    );
    if (top <= mq.padding.top) return widget.child;
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(top: top),
        viewPadding: mq.viewPadding.copyWith(
          top: math.max(top, mq.viewPadding.top),
        ),
      ),
      child: widget.child,
    );
  }
}
