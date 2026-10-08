import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';

/// 簡易全屏看圖（腦洞、草稿、成圖的圖片）：可左右滑、縮放、分享、下載。
class ImageGalleryPage extends ConsumerStatefulWidget {
  const ImageGalleryPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });
  final List<ImageRef> images;
  final int initialIndex;

  @override
  ConsumerState<ImageGalleryPage> createState() => _ImageGalleryPageState();
}

class _ImageGalleryPageState extends ConsumerState<ImageGalleryPage>
    with HidesNavBar<ImageGalleryPage> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  AlbumImage get _current {
    final im = widget.images[_index];
    return AlbumImage(
      id: '',
      file: im.file,
      width: im.width,
      height: im.height,
      kind: AlbumKind.official,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ImagePreview 設計稿：深色底（不跟隨主題）、頂部返回＋「N / 總數」、底部分享／下載。
    const bg = Color(0xFF1E1B18);
    const fg = Color(0xFFF5F0E8);
    const sub = Color(0xFFE9E2D8);
    Widget action(String icon, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(icon, size: 22, strokeWidth: 1.7, color: sub),
              const SizedBox(height: 5),
              Text(label, style: const TextStyle(color: sub, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Row(
                children: [
                  InkResponse(
                    radius: 24,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SvgIcon(
                          AppIcons.back,
                          size: 24,
                          strokeWidth: 1.9,
                          color: fg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  maxScale: 5,
                  child: SizedBox.expand(
                    child: StoredImage(
                      widget.images[i].file,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
              ),
              child: Row(
                children: [
                  action(
                    AppIcons.share,
                    context.l10n.commonShare,
                    () => shareImage(ref, _current),
                  ),
                  action(
                    AppIcons.download,
                    context.l10n.commonDownload,
                    () async {
                      final n = await downloadImages(ref, [_current]);
                      if (context.mounted) {
                        showSnack(
                          context,
                          n > 0
                              ? context.l10n.entityGallerySaved
                              : context.l10n.entityGallerySaveFailed,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
