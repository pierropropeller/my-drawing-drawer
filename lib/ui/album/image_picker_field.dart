import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/tokens.dart';

/// 新增頁頂部的多張圖選擇區：縮圖＋移除、虛線「新增圖片」格。
class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> files;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < files.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.image),
                    child: Image.file(
                      File(files[i].path),
                      width: 104,
                      height: 104,
                      cacheWidth: 300,
                      fit: BoxFit.cover,
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
