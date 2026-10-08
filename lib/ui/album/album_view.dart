import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/svg_icon.dart';
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
    required this.emptyColor,
    required this.onAdd,
    required this.onDelete,
    this.emptySvg,
    this.emptyIcon,
    this.emptyAction = '加圖',
    this.total,
    this.filter,
    this.appBarActions = const [],
  });

  final String pitId;
  final String title;
  final List<AlbumImage> images;
  final String emptyLabel;

  /// 空白頁 icon：優先用設計稿 SVG 圖形。
  final String? emptySvg;
  final IconData? emptyIcon;
  final String emptyAction;
  final CategoryColor emptyColor;
  final VoidCallback onAdd;
  final Future<void> Function(List<AlbumImage> images) onDelete;

  /// 這個相簿的總張數（標題列右側「48 張」）；省略時用目前列出的張數。
  /// 為 0 時顯示空白頁（沒有篩選列與右下新增鈕，照 OfficialEmpty）。
  final int? total;

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

  bool get _allSelected =>
      widget.images.isNotEmpty && _selected.length >= widget.images.length;

  void _toggleAll() => setState(() {
    if (_allSelected) {
      _selected.clear();
      _selecting = false;
    } else {
      _selected
        ..clear()
        ..addAll(widget.images.map((i) => i.id));
    }
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
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final total = widget.total ?? widget.images.length;
    final fullyEmpty = total == 0 && widget.images.isEmpty;
    final serif = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 58,
          titleSpacing: 4,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: _selecting
                ? IconButton(
                    tooltip: '取消選擇',
                    padding: EdgeInsets.zero,
                    icon: SvgIcon(
                      AppIcons.closeX,
                      size: 22,
                      color: t.ink,
                      strokeWidth: 2,
                    ),
                    onPressed: _exit,
                  )
                : IconButton(
                    tooltip: '返回',
                    padding: EdgeInsets.zero,
                    icon: SvgIcon(
                      AppIcons.back,
                      color: t.ink,
                      strokeWidth: 1.9,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
          ),
          title: Text(
            _selecting
                ? '已選 ${_selected.length} 張'
                : (pitName == null
                      ? widget.title
                      : '$pitName · ${widget.title}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: serif,
          ),
          actions: _selecting
              ? [
                  TextButton(
                    onPressed: _toggleAll,
                    style: TextButton.styleFrom(
                      foregroundColor: t.piece.fg,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(_allSelected ? '取消全選' : '全選'),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  ...widget.appBarActions,
                  Padding(
                    padding: const EdgeInsets.only(right: 22),
                    child: Text(
                      '$total 張',
                      style: TextStyle(color: t.text3, fontSize: 12),
                    ),
                  ),
                ],
        ),
        floatingActionButton: (_selecting || fullyEmpty)
            ? null
            : FloatingActionButton(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onPressed: widget.onAdd,
                child: const SvgIcon(
                  AppIcons.plus,
                  size: 26,
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              ),
        bottomNavigationBar: _selecting
            ? Container(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                decoration: BoxDecoration(
                  color: t.nav,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: _BarAction(
                          '下載',
                          AppIcons.download,
                          t.ink,
                          iconSize: 22,
                          strokeWidth: 1.7,
                          onTap: _download,
                        ),
                      ),
                      Expanded(
                        child: _BarAction(
                          '刪除',
                          AppIcons.trash,
                          t.danger,
                          iconSize: 20,
                          strokeWidth: 1.8,
                          onTap: _delete,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            if (!fullyEmpty) ?widget.filter,
            Expanded(
              child: widget.images.isEmpty
                  ? EmptyState(
                      icon: widget.emptyIcon,
                      svg:
                          widget.emptySvg ??
                          (widget.emptyIcon == null ? AppIcons.image : null),
                      text: widget.emptyLabel,
                      color: widget.emptyColor,
                      actionLabel: widget.emptyAction,
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
                        // 預覽頁自己會隱藏底部導覽列（HidesNavBar），走分頁的 Navigator，
                        // 這樣 Android 返回手勢只會退一頁。
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

class _BarAction extends StatelessWidget {
  const _BarAction(
    this.label,
    this.svg,
    this.color, {
    required this.iconSize,
    required this.strokeWidth,
    required this.onTap,
  });
  final String label;
  final String svg;
  final Color color;
  final double iconSize;
  final double strokeWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Column(
        // 放在 bottomNavigationBar 時高度不受限，要縮到內容大小，否則整頁會被撐滿。
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgIcon(svg, size: iconSize, color: color, strokeWidth: strokeWidth),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11.5)),
        ],
      ),
    ),
  );
}

/// 篩選列最右的「管理分組」按鈕（左側細分隔線＋兩條滑桿 icon）。
class ChipRowManageButton extends StatelessWidget {
  const ChipRowManageButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      child: Tooltip(
        message: '管理分組',
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 34,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.border)),
            ),
            alignment: Alignment.center,
            child: SvgIcon(AppIcons.sliders, size: 20, color: t.text2),
          ),
        ),
      ),
    );
  }
}

/// 一排可橫向捲動的選項 chips。[selected] 為 null 表示「全部」。
/// 預設為列表篩選樣式（選中＝深色 ink 底＋白字，未選＝白底細框）；
/// 表單裡的分組選擇請傳 [accentSelected]（選中＝主色底）。
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.allLabel = '全部',
    this.trailing,
    this.accentSelected = false,
    this.wrap = false,
    this.padding = const EdgeInsets.fromLTRB(20, 6, 0, 12),
  });

  final List<(String, String)> options; // (id, label)
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String? allLabel;
  final Widget? trailing;
  final bool accentSelected;

  /// 表單用：chips 自動換行而不是橫向捲動。
  final bool wrap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (allLabel != null)
        _Chip(
          allLabel!,
          selected == null,
          () => onSelected(null),
          accentSelected,
        ),
      for (final o in options)
        _Chip(o.$2, selected == o.$1, () => onSelected(o.$1), accentSelected),
    ];
    if (wrap) {
      return Padding(
        padding: padding,
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(spacing: 8, children: chips),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.selected, this.onTap, this.accentSelected);
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accentSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onColor = accentSelected ? t.accent : t.ink;
    return Padding(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: accentSelected ? 7 : 6,
          ),
          decoration: BoxDecoration(
            color: selected ? onColor : t.surface,
            borderRadius: BorderRadius.circular(Radii.chip),
            border: Border.all(color: selected ? onColor : t.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (accentSelected ? Colors.white : t.surface)
                  : t.text2,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
