import 'dart:typed_data';

/// 直接從 HEIC／HEIF 檔案的 box 結構讀出顯示寬高（不解碼像素）。
///
/// 只當**備援**：匯入時平台解碼器（iOS 的 ImageIO）讀不出尺寸才用，讓瀑布流仍有正確比例。
/// 取 `meta > iprp > ipco` 裡面積最大的 `ispe`（主圖，縮圖較小），並套用 `irot`（直拍照片是旋轉 90／270 度）。
/// 讀不出來回傳 null。
({int width, int height})? heifDimensions(Uint8List b) {
  var width = 0, height = 0, rotation = 0;

  int u32(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  void scan(int start, int end, int depth) {
    if (depth > 6) return;
    var o = start;
    while (o + 8 <= end && o + 8 <= b.length) {
      var size = u32(o);
      final type = String.fromCharCodes(b.sublist(o + 4, o + 8));
      var header = 8;
      if (size == 1) {
        if (o + 16 > end || o + 16 > b.length) return;
        // 64 位元大小：高 32 位元不為 0 的不會是我們要的小 box。
        if (u32(o + 8) != 0) return;
        size = u32(o + 12);
        header = 16;
      } else if (size == 0) {
        size = end - o;
      }
      if (size < header) return;
      final bodyStart = o + header;
      final bodyEnd = (o + size > end) ? end : o + size;
      switch (type) {
        case 'meta': // FullBox：多 4 位元組 version／flags。
          scan(bodyStart + 4, bodyEnd, depth + 1);
        case 'iprp' || 'ipco':
          scan(bodyStart, bodyEnd, depth + 1);
        case 'ispe': // FullBox：version／flags(4)、width(4)、height(4)。
          if (bodyEnd - bodyStart >= 12) {
            final w = u32(bodyStart + 4), h = u32(bodyStart + 8);
            if (w > 0 && h > 0 && w * h > width * height) {
              width = w;
              height = h;
            }
          }
        case 'irot':
          if (bodyEnd > bodyStart) rotation = b[bodyStart] & 3;
      }
      o += size;
    }
  }

  // 一定要是 ISO box 檔案：第 4～8 位元組 `ftyp`。
  if (b.length < 16 || String.fromCharCodes(b.sublist(4, 8)) != 'ftyp') {
    return null;
  }
  scan(0, b.length, 0);
  if (width <= 0 || height <= 0 || width > 1 << 20 || height > 1 << 20) {
    return null;
  }
  return rotation.isOdd
      ? (width: height, height: width)
      : (width: width, height: height);
}
