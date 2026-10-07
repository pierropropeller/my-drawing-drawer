import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/image_store.dart';
import '../../theme/tokens.dart';
import 'album_image.dart';

/// 表單裡的一張圖：剛從相簿選的（[picked]）或已存在 App 內的（[stored]）。
class ImageItem {
  const ImageItem.picked(XFile this.picked) : stored = null;
  const ImageItem.stored(NewImage this.stored) : picked = null;

  final XFile? picked;
  final NewImage? stored;

  /// 匯入新選的圖，已存在的直接沿用。
  Future<NewImage> resolve(ImageStore store) async =>
      stored ?? await store.import(picked!);
}

Future<List<NewImage>> resolveImages(
  ImageStore store,
  List<ImageItem> items,
) async => [for (final i in items) await i.resolve(store)];

/// 表單頂部的多張圖選擇區：縮圖＋移除、虛線「新增圖片」格。
class ImagePickerField extends ConsumerWidget {
  const ImagePickerField({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ImageItem> items;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.image),
                      child: items[i].picked != null
                          ? Image.file(
                              File(items[i].picked!.path),
                              cacheWidth: 300,
                              fit: BoxFit.cover,
                            )
                          : StoredImage(items[i].stored!.file, cacheWidth: 300),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.image),
                border: Border.all(color: t.dashed, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: t.dashedText),
                  const SizedBox(height: 4),
                  Text(
                    '新增圖片',
                    style: TextStyle(color: t.dashedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
