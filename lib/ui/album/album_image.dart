import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';

enum AlbumKind { official, fanArt }

/// 官方圖／同人圖的共同檢視資料。
class AlbumImage {
  const AlbumImage({
    required this.id,
    required this.file,
    required this.width,
    required this.height,
    required this.kind,
  });

  final String id;
  final String file;
  final int width;
  final int height;
  final AlbumKind kind;

  double get aspect => (width > 0 && height > 0) ? width / height : 1;
}

/// 顯示 App 內儲存的圖片；[cacheWidth] 用縮圖解碼，列表請務必指定。
class StoredImage extends ConsumerWidget {
  const StoredImage(
    this.file, {
    super.key,
    this.cacheWidth,
    this.fit = BoxFit.cover,
  });

  final String file;
  final int? cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final store = ref.watch(imageStoreProvider).value;
    if (store == null) return ColoredBox(color: t.chipBg);
    return Image.file(
      store.fileOf(file),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => ColoredBox(
        color: t.chipBg,
        child: Icon(Icons.broken_image_outlined, color: t.text4),
      ),
    );
  }
}

Future<File?> resolveFile(WidgetRef ref, String name) async {
  final store = await ref.read(imageStoreProvider.future);
  return store.fileOf(name);
}
