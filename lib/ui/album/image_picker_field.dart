import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/album_queries.dart';
import '../../data/image_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/add_tile_content.dart';
import '../common/app_icons.dart';
import '../../data/media.dart';
import '../../media/media_import.dart';
import '../../media/video_probe.dart';
import '../common/dashed_box.dart';
import '../common/media_widgets.dart';
import '../common/reorder_tile.dart';
import '../common/svg_icon.dart';
import '../../state/sensitive.dart';
import 'form_image_preview_page.dart';
import 'sensitive_form.dart';

/// 表單裡的一張圖：剛從相簿選的（[picked]）或已存在 App 內的（[stored]）。
///
/// 敏感內容標記（D-104）存在 [sensitive]（表單內可切換，變動時通知監聽者，縮圖小標與「全部標為敏感」列跟著更新）；
/// 存檔時 [resolve] 把它寫進 [NewImage.sensitive]。
class ImageItem extends ChangeNotifier {
  ImageItem.picked(XFile this.picked, {bool sensitive = false})
    : stored = null,
      // ignore: prefer_initializing_formals
      _sensitive = sensitive;
  ImageItem.stored(NewImage this.stored)
    : picked = null,
      _sensitive = stored.sensitive;

  final XFile? picked;
  final NewImage? stored;
  bool _sensitive;

  /// 這張圖有沒有標為敏感（D-104）。
  bool get sensitive => _sensitive;
  set sensitive(bool v) {
    if (v == _sensitive) return;
    _sensitive = v;
    notifyListeners();
  }

  /// 匯入新選的圖／GIF／影片，已存在的直接沿用；帶著目前的敏感標記。
  Future<NewImage> resolve(ImageStore store) async =>
      (stored ?? await importPickedMedia(store, picked!)).copyWith(
        sensitive: _sensitive,
      );
}

Future<List<NewImage>> resolveImages(
  ImageStore store,
  List<ImageItem> items,
) async => [for (final i in items) await i.resolve(store)];

/// 表單縮圖（D-080）：圖片＝圖片、GIF＝靜態第一格＋「GIF」小標、影片＝第一格截圖＋「▶ 長度」小標。
/// 剛選的影片還沒匯入，這裡臨時向原生要一張截圖（同一個檔案只問一次）。
class ImageItemThumb extends ConsumerWidget {
  const ImageItemThumb(this.item, {super.key, this.cacheWidth = 300});
  final ImageItem item;
  final int cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = item.stored;
    if (stored != null) {
      return MediaThumb(
        MediaSource.fromNewImage(stored),
        cacheWidth: cacheWidth,
        animate: false,
        // 表單裡的小圖不模糊（D-104）：只在左下角加小標，方便看清楚自己在標哪張。
        protectSensitive: false,
      );
    }
    final path = item.picked!.path;
    switch (mediaKindFromExtension(path)) {
      case MediaKind.video:
        return _PickedVideoThumb(path, probe: ref.watch(videoProbeProvider));
      case MediaKind.gif:
        return Stack(
          fit: StackFit.passthrough,
          children: [
            FirstFrameImage(
              provider: ResizeImage.resizeIfNeeded(
                cacheWidth,
                null,
                FileImage(File(path)),
              ),
            ),
            const Positioned(left: 5, bottom: 5, child: MediaBadgeGif()),
          ],
        );
      case MediaKind.image:
        return Image.file(
          File(path),
          cacheWidth: cacheWidth,
          fit: BoxFit.cover,
        );
    }
  }
}

final _pickedVideoMeta = <String, Future<VideoMeta?>>{};

class _PickedVideoThumb extends StatelessWidget {
  const _PickedVideoThumb(this.path, {required this.probe});
  final String path;
  final VideoProbe probe;

  @override
  Widget build(BuildContext context) {
    final future = _pickedVideoMeta.putIfAbsent(
      path,
      () => probe.probe(path, maxPosterSide: 300),
    );
    return FutureBuilder<VideoMeta?>(
      future: future,
      builder: (context, snap) {
        final meta = snap.data;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (meta != null && meta.hasPoster)
              Image.memory(meta.poster!, fit: BoxFit.cover)
            else
              const MediaPlaceholder(),
            Positioned(
              left: 5,
              bottom: 5,
              child: MediaBadgeVideo(durationMs: meta?.durationMs),
            ),
          ],
        );
      },
    );
  }
}

/// 表單頂部的多張圖選擇區：84×84 縮圖（可移除）＋虛線「＋」格，自動換行。
class ImagePickerField extends ConsumerWidget {
  const ImagePickerField({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    this.onReorder,
    this.pitId,
  });

  final List<ImageItem> items;

  /// 表單所在的坑（D-104）：總開關和這個坑的敏感內容都開了，才出現「全部標為敏感」列、
  /// 縮圖小標與預覽頁的逐張標記鈕。null＝沒有標記功能。
  final String? pitId;

  /// 為 null＝不顯示虛線「＋」格（例如編輯單張同人圖）。
  final VoidCallback? onAdd;
  final void Function(int index) onRemove;

  /// 長按拖曳排序；為 null＝不能排序。
  final void Function(int from, int to)? onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final marking = pitId != null && ref.watch(sensitiveMarkingProvider(pitId));
    final grid = ReorderableImageGrid(
      count: items.length,
      size: 84,
      onReorder: onReorder,
      itemBuilder: (context, i, hide) => SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          fit: StackFit.expand,
          // 「×」按鈕超出縮圖右上角 6px（D-018、OfficialNew）。
          clipBehavior: Clip.none,
          children: [
            // 點一下開全螢幕預覽（D-102）；長按仍是拖曳排序，× 在縮圖右上角另外接。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hide
                  ? null
                  : () => FormImagePreviewPage.open(
                      context,
                      items,
                      i,
                      canMark: marking,
                    ),
              child: Semantics(
                button: true,
                label: context.l10n.albumPreviewImage,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ImageItemThumb(items[i], cacheWidth: 300),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FormSensitiveBadge(
                            item: items[i],
                            pitId: pitId,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!hide)
              Positioned(
                top: -6,
                right: -6,
                child: Semantics(
                  button: true,
                  label: context.l10n.albumRemoveImage,
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
      trailing: onAdd == null
          ? null
          : GestureDetector(
              onTap: onAdd,
              child: Semantics(
                label: context.l10n.albumAddImage,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: DashedBox(
                    color: t.dashed,
                    radius: Radii.image,
                    child: Center(
                      child: AddTileContent(label: context.l10n.albumAddImage),
                    ),
                  ),
                ),
              ),
            ),
    );
    if (!marking) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grid,
        SensitiveMarkAllRow(items: items, pitId: pitId),
      ],
    );
  }
}
