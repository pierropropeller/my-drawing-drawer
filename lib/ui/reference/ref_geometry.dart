import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/widgets.dart' show Matrix4;

import '../../data/ref_view_queries.dart';

/// 參考圖檢視的座標換算（純 Dart，好測試）。
///
/// 約定：
/// - 「內容」＝一個和視窗（viewport）一樣大的方塊，圖片以 fit（完整顯示）置中在裡面；
///   InteractiveViewer 的矩陣是 `translate(tx, ty) · scale(zoom)`，所以 zoom＝相對於 fit 的倍數，
///   畫面上的「180%」就是 zoom × 100。
/// - 狀態用「視窗正中央對到的圖片位置（0～1）」＋縮放存，不存矩陣：拉窗、轉方向之後，
///   由新的視窗大小重新算出矩陣，位置不會跑掉。
/// - 翻轉只是畫面鏡像；存的位置一律是未翻轉座標，翻轉時視窗中央那一點不動。
class RefGeometry {
  const RefGeometry({required this.viewport, required this.image});

  /// 視窗（可視範圍）大小。
  final Size viewport;

  /// 圖片原始像素大小；未知（0）時當成和視窗同比例（fit 後鋪滿）。
  final Size image;

  bool get _hasImage => image.width > 0 && image.height > 0;

  /// fit 縮放：每個圖片像素佔幾個邏輯像素。
  double get fitScale {
    if (!_hasImage) return 1;
    return math.min(
      viewport.width / image.width,
      viewport.height / image.height,
    );
  }

  /// fit 後圖片在內容裡的大小（置中）。
  Size get fitted => _hasImage
      ? Size(image.width * fitScale, image.height * fitScale)
      : viewport;

  /// 目前狀態對應的 zoom（相對於 fit）。鎖定縮放時以絕對縮放為準。
  double zoomOf(RefViewSnapshot s) {
    if (s.locked && s.scale > 0 && fitScale > 0) {
      return s.scale / fitScale;
    }
    return s.zoom;
  }

  /// 由狀態算出 InteractiveViewer 的矩陣。
  Matrix4 matrixFor(RefViewSnapshot s) {
    final z = zoomOf(s);
    final f = fitted;
    final ux = s.flipped ? 1 - s.centerX : s.centerX;
    final px = viewport.width / 2 + (ux - 0.5) * f.width;
    final py = viewport.height / 2 + (s.centerY - 0.5) * f.height;
    final tx = viewport.width / 2 - z * px;
    final ty = viewport.height / 2 - z * py;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(z, z, z, 1);
  }

  /// 由矩陣讀回狀態（保留 [base] 的旗標：鎖定、翻轉、灰階、背景）。
  RefViewSnapshot snapshotFrom(Matrix4 m, RefViewSnapshot base) {
    final z = m.getMaxScaleOnAxis();
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    final px = (viewport.width / 2 - tx) / z;
    final py = (viewport.height / 2 - ty) / z;
    final f = fitted;
    var ux = f.width == 0 ? 0.5 : (px - viewport.width / 2) / f.width + 0.5;
    final vy = f.height == 0
        ? 0.5
        : (py - viewport.height / 2) / f.height + 0.5;
    if (base.flipped) ux = 1 - ux;
    return base.copyWith(
      zoom: z,
      scale: z * fitScale,
      centerX: ux,
      centerY: vy,
    );
  }

  /// 視窗中央對到的畫面點（內容座標）；測試用。
  Offset centerInContent(Matrix4 m) {
    final z = m.getMaxScaleOnAxis();
    return Offset(
      (viewport.width / 2 - m.entry(0, 3)) / z,
      (viewport.height / 2 - m.entry(1, 3)) / z,
    );
  }
}
