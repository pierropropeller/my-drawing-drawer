import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';

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

class _ImageGalleryPageState extends ConsumerState<ImageGalleryPage> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => shareImage(ref, _current),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final n = await downloadImages(ref, [_current]);
              if (context.mounted) {
                showSnack(context, n > 0 ? '已儲存到相簿' : '儲存失敗');
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: SizedBox.expand(
            child: StoredImage(widget.images[i].file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
