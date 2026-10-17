import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/ref_view_queries.dart';
import 'package:huakeng/ui/reference/ref_geometry.dart';

/// 縮放／位置的換算：還原、拉窗（鎖定與未鎖定）、翻轉。
void main() {
  const img = Size(2000, 3000); // 2:3 直圖

  RefGeometry geo(double w, double h) =>
      RefGeometry(viewport: Size(w, h), image: img);

  test('fit：直圖放進橫向視窗，以高度為準', () {
    final g = geo(800, 600);
    expect(g.fitScale, closeTo(0.2, 1e-9));
    expect(g.fitted.width, closeTo(400, 1e-9));
    expect(g.fitted.height, closeTo(600, 1e-9));
  });

  test('預設狀態的矩陣是單位矩陣（fit 全圖）', () {
    final g = geo(800, 600);
    final m = g.matrixFor(RefViewSnapshot.initial);
    expect(m.getMaxScaleOnAxis(), closeTo(1, 1e-9));
    expect(m.entry(0, 3), closeTo(0, 1e-9));
    expect(m.entry(1, 3), closeTo(0, 1e-9));
  });

  test('狀態 → 矩陣 → 狀態 原樣讀回', () {
    final g = geo(800, 600);
    const s = RefViewSnapshot(zoom: 1.8, centerX: 0.3, centerY: 0.65);
    final back = g.snapshotFrom(g.matrixFor(s), s);
    expect(back.zoom, closeTo(1.8, 1e-9));
    expect(back.centerX, closeTo(0.3, 1e-9));
    expect(back.centerY, closeTo(0.65, 1e-9));
    expect(back.scale, closeTo(1.8 * g.fitScale, 1e-9));
  });

  test('未鎖定拉窗：倍數與中央對到的圖片位置不變（不彈回 fit）', () {
    final a = geo(800, 600);
    const s = RefViewSnapshot(zoom: 2.5, centerX: 0.2, centerY: 0.8);
    final read = a.snapshotFrom(a.matrixFor(s), s);
    final b = geo(500, 900);
    final back = b.snapshotFrom(b.matrixFor(read), read);
    expect(back.zoom, closeTo(2.5, 1e-9));
    expect(back.centerX, closeTo(0.2, 1e-9));
    expect(back.centerY, closeTo(0.8, 1e-9));
  });

  test('鎖定縮放拉窗：絕對縮放不變，只有可視範圍改變，中央仍是同一點', () {
    final a = geo(800, 600);
    const s = RefViewSnapshot(
      zoom: 1.8,
      centerX: 0.35,
      centerY: 0.4,
      locked: true,
    );
    final read = a.snapshotFrom(a.matrixFor(s), s);
    final absolute = read.scale;
    // 拉窄、拉寬、轉直向，來回幾次。
    for (final size in const [Size(404, 900), Size(1194, 834), Size(834, 1194)]) {
      final b = geo(size.width, size.height);
      final m = b.matrixFor(read);
      final back = b.snapshotFrom(m, read);
      expect(back.scale, closeTo(absolute, 1e-9), reason: '$size 絕對縮放不變');
      expect(back.centerX, closeTo(0.35, 1e-9));
      expect(back.centerY, closeTo(0.4, 1e-9));
      // 螢幕上每個圖片像素的大小 = zoom × fit = 絕對縮放。
      expect(m.getMaxScaleOnAxis() * b.fitScale, closeTo(absolute, 1e-9));
    }
  });

  test('鎖定時拉窗，zoom 隨 fit 改變（百分比相對新視窗）', () {
    final a = geo(800, 600);
    const s = RefViewSnapshot(zoom: 2, locked: true);
    final read = a.snapshotFrom(a.matrixFor(s), s);
    final b = geo(400, 300); // 視窗縮半 → fit 縮半 → zoom 變兩倍才維持絕對大小
    expect(b.zoomOf(read), closeTo(4, 1e-9));
  });

  test('翻轉：視窗中央那一點不動（存的是未翻轉座標）', () {
    final g = geo(800, 600);
    const s = RefViewSnapshot(zoom: 2, centerX: 0.25, centerY: 0.5);
    final m1 = g.matrixFor(s);
    final read = g.snapshotFrom(m1, s);
    final flipped = read.copyWith(flipped: true);
    final m2 = g.matrixFor(flipped);
    final back = g.snapshotFrom(m2, flipped);
    expect(back.centerX, closeTo(0.25, 1e-9));
    expect(back.centerY, closeTo(0.5, 1e-9));
    // 畫面上翻轉後中央對到的是鏡像位置：內容座標的 x 對稱於中線。
    final c1 = g.centerInContent(m1).dx;
    final c2 = g.centerInContent(m2).dx;
    expect(c1 + c2, closeTo(800, 1e-6));
  });

  test('未知圖片尺寸：鋪滿視窗，不出現 NaN', () {
    const g = RefGeometry(viewport: Size(400, 300), image: Size.zero);
    expect(g.fitScale, 1);
    expect(g.fitted, const Size(400, 300));
    final m = g.matrixFor(const RefViewSnapshot(zoom: 2));
    expect(m.storage.every((v) => v.isFinite), isTrue);
  });
}
