import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/image_store.dart';

/// 由原圖產生縮圖（D-099）。
/// - 預設：本機列表縮圖，長邊 [ImageStore.thumbMaxEdge]px、JPEG 品質 [thumbQuality]（約 30KB）。
/// - 占位圖（[placeholder]）：長邊 [ImageStore.placeholderMaxEdge]px、品質
///   [ImageStore.placeholderQuality]（約 1KB），同步到 Drive 供原圖未到時模糊顯示。
/// GIF 取第一格；影片不在這裡處理（它的 poster 是另一張 jpg，自己有縮圖）。
abstract class ThumbnailMaker {
  /// 回傳 JPEG 位元組；讀不了（壞檔、不支援的格式）回傳 null，不丟例外。
  Future<Uint8List?> make(File source, {bool placeholder = false});
}

const thumbQuality = 80;

/// 預設實作：
/// 1. 用引擎解碼並**縮小到目標尺寸**（原生執行緒、不會把整張大圖解成 RGBA，記憶體只有縮圖大小，
///    也會處理 EXIF 方向；GIF 取第一格）；
/// 2. JPEG 編碼（純 Dart `image` 套件）丟到 isolate（[compute]），不卡主執行緒；
/// 3. 引擎解不了時退回純 Dart 解碼（也在 isolate 裡）。
class DefaultThumbnailMaker implements ThumbnailMaker {
  const DefaultThumbnailMaker();

  @override
  Future<Uint8List?> make(File source, {bool placeholder = false}) async {
    final edge = placeholder
        ? ImageStore.placeholderMaxEdge
        : ImageStore.thumbMaxEdge;
    final quality = placeholder
        ? ImageStore.placeholderQuality
        : thumbQuality;
    final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty) return null;
    try {
      final raw = await _decodeScaled(bytes, edge);
      if (raw != null) {
        return await compute(_encodeRaw, (raw, quality));
      }
    } catch (_) {
      // 引擎解不了：改用純 Dart。
    }
    try {
      return await compute(_encodeFromBytes, (bytes, edge, quality));
    } catch (_) {
      return null;
    }
  }
}

class _Raw {
  _Raw(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

Future<_Raw?> _decodeScaled(Uint8List bytes, int edge) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? desc;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    desc = await ui.ImageDescriptor.encoded(buffer);
    final w = desc.width, h = desc.height;
    if (w <= 0 || h <= 0) return null;
    final scale = (w > h ? w : h) > edge ? edge / (w > h ? w : h) : 1.0;
    final tw = (w * scale).round().clamp(1, edge);
    final th = (h * scale).round().clamp(1, edge);
    codec = await desc.instantiateCodec(targetWidth: tw, targetHeight: th);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final out = _Raw(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      image.width,
      image.height,
    );
    image.dispose();
    return out;
  } finally {
    codec?.dispose();
    desc?.dispose();
    buffer?.dispose();
  }
}

/// 透明背景鋪白底再編成 JPEG。
Uint8List _encodeRaw((_Raw, int) args) {
  final raw = args.$1, quality = args.$2;
  final px = raw.rgba;
  for (var i = 0; i + 3 < px.length; i += 4) {
    final a = px[i + 3];
    if (a == 255) continue;
    px[i] = (px[i] * a + 255 * (255 - a)) ~/ 255;
    px[i + 1] = (px[i + 1] * a + 255 * (255 - a)) ~/ 255;
    px[i + 2] = (px[i + 2] * a + 255 * (255 - a)) ~/ 255;
    px[i + 3] = 255;
  }
  final image = img.Image.fromBytes(
    width: raw.width,
    height: raw.height,
    bytes: px.buffer,
    bytesOffset: px.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

Uint8List? _encodeFromBytes((Uint8List, int, int) args) {
  final bytes = args.$1, edge = args.$2, quality = args.$3;
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  image = img.bakeOrientation(image);
  if (image.width > edge || image.height > edge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: edge)
        : img.copyResize(image, height: edge);
  }
  if (image.hasAlpha) {
    final bg = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    )..clear(img.ColorRgb8(255, 255, 255));
    img.compositeImage(bg, image);
    image = bg;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}
