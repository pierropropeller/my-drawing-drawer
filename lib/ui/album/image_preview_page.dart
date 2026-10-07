import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'fan_art_edit_page.dart';

/// 圖片預覽：深色全屏、圖片滿版；分享、下載、設為封面、編輯、刪除。
class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.pitId,
    required this.images,
    required this.initialIndex,
  });

  final String pitId;
  final List<AlbumImage> images;
  final int initialIndex;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage> {
  late final _items = [...widget.images];
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  AlbumImage get _current => _items[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final n = await downloadImages(ref, [_current]);
    if (mounted) showSnack(context, n > 0 ? '已儲存到相簿' : '儲存失敗');
  }

  Future<void> _setCover() async {
    await ref.read(databaseProvider).setCover(widget.pitId, _current.id);
    if (mounted) showSnack(context, '已設為封面');
  }

  Future<void> _edit() async {
    final db = ref.read(databaseProvider);
    final im = _current;
    if (im.kind == AlbumKind.official) {
      final groups = await ref.read(groupsProvider(widget.pitId).future);
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(16), child: Text('更換分組')),
              for (final g in groups)
                ListTile(
                  title: Text(g.name),
                  onTap: () => Navigator.pop(ctx, g.id),
                ),
            ],
          ),
        ),
      );
      if (picked != null) {
        await db.setOfficialGroup(im.id, picked);
        if (mounted) showSnack(context, '已更換分組');
      }
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FanArtEditPage(pitId: widget.pitId, imageId: im.id),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(context, title: '刪除這張圖？');
    if (!ok || !mounted) return;
    final db = ref.read(databaseProvider);
    final im = _current;
    if (im.kind == AlbumKind.official) {
      await db.deleteOfficial([im.id]);
    } else {
      await db.deleteFanArts([im.id]);
    }
    if (!mounted) return;
    setState(() => _items.removeAt(_index));
    if (_items.isEmpty) {
      Navigator.of(context).pop();
    } else if (_index >= _items.length) {
      _index = _items.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_index + 1} / ${_items.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: SizedBox.expand(
            child: StoredImage(_items[i].file, fit: BoxFit.contain),
          ),
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Action(Icons.ios_share, '分享', () => shareImage(ref, _current)),
                _Action(Icons.download_outlined, '下載', _download),
                _Action(Icons.photo_outlined, '設為封面', _setCover),
                _Action(Icons.edit_outlined, '編輯', _edit),
                _Action(Icons.delete_outline, '刪除', _delete),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
