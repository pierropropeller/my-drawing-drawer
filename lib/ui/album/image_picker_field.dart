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

  /// 為 null＝不顯示虛線「＋」格（例如編輯單張同人圖）。
  final VoidCallback? onAdd;
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
              // 「×」按鈕超出縮圖右上角 6px（D-018、OfficialNew）。
              clipBehavior: Clip.none,
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
                  top: -6,
                  right: -6,
                  child: Semantics(
                    button: true,
                    label: '移除圖片',
                    child: GestureDetector(
                      onTap: () => onRemove(i),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2622),
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ground, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const SvgIcon(
                          AppIcons.closeX,
                          size: 11,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (onAdd != null)
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
                    child: SvgIcon(
                      AppIcons.plus,
                      size: 26,
                      color: t.dashedText,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
