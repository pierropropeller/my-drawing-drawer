import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/tokens.dart';
import '../common/empty_state.dart';
import 'album_actions.dart';
import 'album_image.dart';
import 'image_masonry.dart';
import 'image_preview_page.dart';

/// 官方圖冊與同人圖共用：瀑布流＋長按多選（下載／刪除）＋點擊預覽＋新增按鈕。
class AlbumView extends ConsumerStatefulWidget {
  const AlbumView({
    super.key,
    required this.pitId,
    required this.title,
    required this.images,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.emptyColor,
    required this.onAdd,
    required this.onDelete,
    this.filter,
    this.appBarActions = const [],
  });

  final String pitId;
  final String title;
  final List<AlbumImage> images;
  final String emptyLabel;
  final IconData emptyIcon;
  final CategoryColor emptyColor;
  final VoidCallback onAdd;
  final Future<void> Function(List<AlbumImage> images) onDelete;

  /// 顯示在清單上方的篩選 chips。
  final Widget? filter;
  final List<Widget> appBarActions;

  @override
  ConsumerState<AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends ConsumerState<AlbumView> {
  bool _selecting = false;
  final Set<String> _selected = {};

  void _toggle(AlbumImage im) {
    setState(() {
      if (!_selected.remove(im.id)) _selected.add(im.id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _exit() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  List<AlbumImage> get _picked =>
      widget.images.where((i) => _selected.contains(i.id)).toList();

  Future<void> _download() async {
    final n = await downloadImages(ref, _picked);
    if (!mounted) return;
    showSnack(context, n > 0 ? '已儲存 $n 張到相簿' : '儲存失敗');
    _exit();
  }

  Future<void> _delete() async {
    final picked = _picked;
    final ok = await confirmDelete(context, title: '刪除 ${picked.length} 張圖？');
    if (!ok || !mounted) return;
    await widget.onDelete(picked);
    if (mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(icon: const Icon(Icons.close), onPressed: _exit)
              : null,
          title: Text(_selecting ? '已選 ${_selected.length} 張' : widget.title),
          actions: _selecting ? const [] : widget.appBarActions,
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                onPressed: widget.onAdd,
                child: const Icon(Icons.add),
              ),
        bottomNavigationBar: _selecting
            ? SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: _download,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('下載'),
                    ),
                    TextButton.icon(
                      onPressed: _delete,
                      icon: Icon(Icons.delete_outline, color: t.danger),
                      label: Text('刪除', style: TextStyle(color: t.danger)),
                    ),
                  ],
                ),
              )
            : null,
        body: Column(
          children: [
            ?widget.filter,
            Expanded(
              child: widget.images.isEmpty
                  ? EmptyState(
                      icon: widget.emptyIcon,
                      text: widget.emptyLabel,
                      color: widget.emptyColor,
                      actionLabel: '新增',
                      onAction: widget.onAdd,
                    )
                  : ImageMasonry(
                      images: widget.images,
                      selecting: _selecting,
                      selected: _selected,
                      onLongPress: (im) => setState(() {
                        _selecting = true;
                        _selected.add(im.id);
                      }),
                      onTap: (im, i) {
                        if (_selecting) {
                          _toggle(im);
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ImagePreviewPage(
                              pitId: widget.pitId,
                              images: widget.images,
                              initialIndex: i,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一排可橫向捲動的選項 chips。[selected] 為 null 表示「全部」。
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allLabel = '全部',
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 8, 8),
  });

  final List<(String, String)> options; // (id, label)
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String? allLabel;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (allLabel != null)
                    _Chip(allLabel!, selected == null, () => onSelected(null)),
                  for (final o in options)
                    _Chip(o.$2, selected == o.$1, () => onSelected(o.$1)),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? t.accent : t.chipBg,
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : t.text2,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
