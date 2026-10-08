import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/image_store.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/dashed_box.dart';
import '../common/svg_icon.dart';
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

/// 表單頂部的多張圖選擇區：84×84 縮圖（可移除）＋虛線「＋」格，自動換行。
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: items[i].picked != null
                      ? Image.file(
                          File(items[i].picked!.path),
                          cacheWidth: 300,
                          fit: BoxFit.cover,
                        )
                      : StoredImage(items[i].stored!.file, cacheWidth: 300),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const SvgIcon(
                        AppIcons.closeX,
                        size: 12,
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: onAdd,
          child: Semantics(
            label: '加圖',
            child: SizedBox(
              width: 84,
              height: 84,
              child: DashedBox(
                color: t.dashed,
                radius: Radii.image,
                child: Center(
                  child: SvgIcon(AppIcons.plus, size: 26, color: t.dashedText),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
