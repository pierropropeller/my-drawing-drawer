import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'fan_art_edit_page.dart';
import 'group_manage_page.dart';

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

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage>
    with HidesNavBar<ImagePreviewPage> {
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
    // 「設為封面」＝設為這一層（官方圖冊／好看同人圖）的封面；
    // 主頁坑卡片的封面要在坑內頁長按格子選擇。
    final db = ref.read(databaseProvider);
    final im = _current;
    if (im.kind == AlbumKind.official) {
      await db.setOfficialCover(widget.pitId, im.id);
    } else {
      await db.setFanArtCover(widget.pitId, im.id);
    }
    if (mounted) {
      showSnack(
        context,
        im.kind == AlbumKind.official ? '已設為官方圖冊封面' : '已設為好看同人圖封面',
      );
    }
  }

  Future<void> _edit() async {
    final db = ref.read(databaseProvider);
    final im = _current;
    if (im.kind == AlbumKind.official) {
      final groups = await db.watchGroups(widget.pitId).first;
      if (!mounted) return;
      final picked = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '更換分組',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                GroupManagePage(pitId: widget.pitId),
                          ),
                        );
                      },
                      child: const Text('管理'),
                    ),
                  ],
                ),
              ),
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
    if (_items.isEmpty) {
      return const Scaffold(backgroundColor: _Palette.bg);
    }
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final cur = _current;
    final album = cur.kind == AlbumKind.official ? '官方圖冊' : '好看同人圖';
    final author = cur.author ?? '';
    final group = cur.groupName ?? '';
    final date = cur.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return Scaffold(
      backgroundColor: _Palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const SvgIcon(
                      AppIcons.back,
                      color: _Palette.text,
                      strokeWidth: 1.9,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pitName == null ? album : '$pitName · $album',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _Palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${_index + 1} / ${_items.length}',
                      style: const TextStyle(
                        color: _Palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: PageView.builder(
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (author.isNotEmpty)
                    Text(
                      author,
                      style: const TextStyle(
                        color: _Palette.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (group.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _Palette.pill,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        group,
                        style: const TextStyle(
                          color: _Palette.bg,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (date != null)
                    Text(
                      '${date.year} / ${two(date.month)} / ${two(date.day)} 加入',
                      style: const TextStyle(
                        color: _Palette.muted,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
              ),
              child: Row(
                children: [
                  _Action(
                    AppIcons.share,
                    '分享',
                    () => shareImage(ref, _current),
                  ),
                  _Action(AppIcons.download, '下載', _download),
                  _Action(AppIcons.setCover, '設為封面', _setCover),
                  _Action(AppIcons.edit, '編輯', _edit),
                  _Action(
                    AppIcons.trash,
                    '刪除',
                    _delete,
                    color: _Palette.danger,
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

/// 預覽頁固定深色（ImagePreview 設計稿），不隨主題變化。
abstract final class _Palette {
  static const bg = Color(0xFF1E1B18);
  static const text = Color(0xFFF5F0E8);
  static const muted = Color(0xFFA49A8C);
  static const action = Color(0xFFE9E2D8);
  static const danger = Color(0xFFF08A76);
  static const pill = Color(0xFFC9D6E3);
}

class _Action extends StatelessWidget {
  const _Action(
    this.svg,
    this.label,
    this.onTap, {
    this.color = _Palette.action,
  });
  final String svg;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgIcon(svg, size: 22, color: color, strokeWidth: 1.7),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
