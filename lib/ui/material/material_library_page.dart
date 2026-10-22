import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/database.dart';
import '../../data/entity_queries.dart' show ImageRef;
import '../../data/material_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../state/sensitive.dart';
import '../common/sensitive_actions.dart';
import '../../l10n/l10n.dart';
import '../../media/media_import.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_icons.dart';
import '../album/album_image.dart';
import '../album/album_view.dart' show ChipRow;
import '../album/image_masonry.dart' show SelectMark, SquareGrid;
import '../common/drag_select.dart';
import '../common/media_widgets.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../entity/entity_widgets.dart' show EntityFab;
import '../entity/image_gallery_page.dart';
import 'material_category.dart';
import 'material_category_sheet.dart';
import 'material_icons.dart';

/// 素材庫的兩種版面，記在本機設定（跟裝置走）。
enum MaterialLayout { waterfall, grid }

const _kLayoutKey = 'materialLayout';

/// 素材庫（MaterialList／MaterialGrid／MaterialSelect，D-071）。
///
/// 瀏覽時有底部導覽列（入口在「我的」，走「我的」分頁的 Navigator）；長按進多選
/// （分享／下載／移動／刪除）時導覽列隱藏。[initialCategory] 是一開始停在哪個分類
/// （分享進來存完後停在剛存的分類）。
class MaterialLibraryPage extends ConsumerStatefulWidget {
  const MaterialLibraryPage({
    super.key,
    this.initialCategory,
    this.embedded = false,
  });
  final MaterialCategory? initialCategory;

  /// 在 iPad「我的」右側內容面板裡顯示（Profile 稿）：沒有返回鍵，標題旁顯示張數，欄數依面板闊度。
  final bool embedded;

  @override
  ConsumerState<MaterialLibraryPage> createState() =>
      _MaterialLibraryPageState();
}

class _MaterialLibraryPageState extends ConsumerState<MaterialLibraryPage>
    with HidesNavBar<MaterialLibraryPage> {
  // 瀏覽時有導覽列；進入多選才隱藏（build 時依 _selecting 同步）。
  @override
  bool get hidesNavBarOnOpen => false;

  late MaterialCategory? _category = widget.initialCategory;
  late MaterialLayout _layout = _readLayout();
  bool _selecting = false;
  final Set<String> _selected = {};

  MaterialLayout _readLayout() =>
      ref.read(sharedPrefsProvider)?.getString(_kLayoutKey) == 'grid'
      ? MaterialLayout.grid
      : MaterialLayout.waterfall;

  void _setLayout(MaterialLayout v) {
    setState(() => _layout = v);
    ref
        .read(sharedPrefsProvider)
        ?.setString(
          _kLayoutKey,
          v == MaterialLayout.grid ? 'grid' : 'waterfall',
        );
  }

  void _exit() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  /// 目前列表裡被選中的素材（換分類後看不到的不算）。
  List<MaterialImage> _picked(List<MaterialImage> rows) =>
      rows.where((r) => _selected.contains(r.id)).toList();

  List<AlbumImage> _asAlbum(Iterable<MaterialImage> rows) => [
    for (final r in rows)
      AlbumImage(
        id: r.id,
        file: r.imageFile,
        width: r.width,
        height: r.height,
        kind: AlbumKind.junk,
        createdAt: r.createdAt,
        mediaKind: r.kind,
        durationMs: r.durationMs,
        posterFile: r.posterFile,
      ),
  ];

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
    if (_selected.isEmpty) _selecting = false;
  });

  /// 長按＋拖曳連續多選（D-081）。
  void _dragSelect(List<MaterialImage> rows, Set<int> idx, bool finished) =>
      setState(() {
        _selected
          ..clear()
          ..addAll([
            for (final i in idx)
              if (i < rows.length) rows[i].id,
          ]);
        _selecting = !finished || _selected.isNotEmpty;
      });

  void _longPress(String id) => setState(() {
    _selecting = true;
    _selected.add(id);
  });

  void _open(List<MaterialImage> rows, int i) {
    if (_selecting) {
      _toggle(rows[i].id);
      return;
    }
    // 預覽沿用 ImageGalleryPage（自己會隱藏導覽列），走「我的」分頁的 Navigator。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageGalleryPage(
          images: [
            for (final r in rows)
              ImageRef(
                r.imageFile,
                r.width,
                r.height,
                kind: r.kind,
                durationMs: r.durationMs,
                poster: r.posterFile,
              ),
          ],
          initialIndex: i,
        ),
      ),
    );
  }

  /// 加圖：開相簿選圖；在分類下預設歸該分類，在「全部」下先選分類。
  Future<void> _add() async {
    // 素材庫自己的加圖：直接開相簿，不彈「從素材庫選取」的來源選單。
    final picked = await ref.read(photoPickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    var category = _category;
    if (category == null) {
      category = await showMaterialCategorySheet(
        context,
        title: context.l10n.shareTitle,
        confirmLabel: context.l10n.shareAdd,
        count: picked.length,
      );
      if (category == null || !mounted) return;
    }
    final store = await ref.read(imageStoreProvider.future);
    final images = [for (final f in picked) await importPickedMedia(store, f)];
    await ref.read(databaseProvider).addMaterials(category, images);
    if (mounted) showSnack(context, context.l10n.shareAdded, success: true);
  }

  Future<void> _download(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    final n = await downloadImages(ref, _asAlbum(picked));
    if (!mounted) return;
    showSnack(
      context,
      n > 0
          ? context.l10n.albumSavedCountToGallery(n)
          : context.l10n.albumSaveFailed,
    );
    _exit();
  }

  Future<void> _share(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    await shareImages(ref, _asAlbum(picked));
  }

  Future<void> _move(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    // 所選圖都在同一個分類時預選它。
    final cats = {for (final p in picked) p.category};
    final target = await showMaterialCategorySheet(
      context,
      title: context.l10n.albumMoveTo,
      confirmLabel: context.l10n.commonMove,
      count: picked.length,
      initial: cats.length == 1 ? cats.first : null,
    );
    if (target == null || !mounted) return;
    await ref.read(databaseProvider).moveMaterials([
      for (final p in picked) p.id,
    ], target);
    if (!mounted) return;
    showSnack(
      context,
      context.l10n.albumMovedCount(picked.length, target.label(context.l10n)),
      success: true,
    );
    _exit();
  }

  /// 「敏感」動作（D-104）：素材庫不屬於任何坑，只看總開關。
  Future<void> _sensitive(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    final done = await applySensitiveToSelection(
      context,
      ref,
      SensitiveSource.material,
      [for (final p in picked) p.id],
    );
    if (done && mounted) _exit();
  }

  Future<void> _delete(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    final ok = await confirmDelete(
      context,
      title: context.l10n.albumDeleteImagesTitle(picked.length),
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteMaterials([
      for (final p in picked) p.id,
    ]);
    if (mounted) _exit();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    setNavBarHidden(_selecting);
    final rows = ref.watch(materialsProvider(_category)).value ?? const [];
    final total = ref.watch(materialCountsProvider).value?.total ?? 0;
    final fullyEmpty = total == 0 && rows.isEmpty;
    final picked = _picked(rows);
    final allSelected = rows.isNotEmpty && picked.length >= rows.length;
    final embedded = widget.embedded;
    final serif = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: embedded ? 24 : 19, fontWeight: FontWeight.w700);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: embedded ? 72 : null,
          leadingWidth: (embedded && !_selecting) ? 0 : 58,
          titleSpacing: (embedded && !_selecting) ? 40 : 4,
          leading: (embedded && !_selecting)
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _selecting
                      ? IconButton(
                          tooltip: l.albumCancelSelect,
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
                          tooltip: l.commonBack,
                          padding: EdgeInsets.zero,
                          icon: SvgIcon(
                            AppIcons.back,
                            color: t.ink,
                            strokeWidth: 1.9,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                ),
          title: (embedded && !_selecting)
              ? Text.rich(
                  TextSpan(
                    text: l.materialTitle,
                    children: [
                      TextSpan(
                        text: '  ${l.commonCountImages(total)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.text3,
                          fontFamily: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: serif,
                )
              : Text(
                  _selecting
                      ? l.commonSelectedCount(picked.length)
                      : l.materialTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: serif,
                ),
          actions: _selecting
              ? [
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                        _selecting = false;
                      } else {
                        _selected
                          ..clear()
                          ..addAll(rows.map((r) => r.id));
                      }
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: t.piece.fg,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      allSelected ? l.commonDeselectAll : l.commonSelectAll,
                    ),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      l.commonCountImages(rows.length),
                      style: TextStyle(color: t.text3, fontSize: 12),
                    ),
                  ),
                  _LayoutToggle(layout: _layout, onChanged: _setLayout),
                  const SizedBox(width: 6),
                ],
        ),
        floatingActionButton: (_selecting || fullyEmpty)
            ? null
            : EntityFab(label: l.materialAddLabel, onPressed: _add),
        bottomNavigationBar: _selecting
            ? Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                decoration: BoxDecoration(
                  color: t.nav,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BarAction(
                          l.commonShare,
                          AppIcons.share,
                          t.ink,
                          iconSize: 22,
                          strokeWidth: 1.7,
                          onTap: () => _share(picked),
                        ),
                      ),
                      Expanded(
                        child: _BarAction(
                          l.commonDownload,
                          AppIcons.download,
                          t.ink,
                          iconSize: 22,
                          strokeWidth: 1.7,
                          onTap: () => _download(picked),
                        ),
                      ),
                      if (ref.watch(sensitiveMarkingProvider(null)))
                        Expanded(
                          child: _BarAction(
                            l.sensitiveAction,
                            AppIcons.eyeSlash,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.9,
                            onTap: () => _sensitive(picked),
                          ),
                        ),
                      Expanded(
                        child: _BarAction(
                          l.commonMove,
                          AlbumIcons.moveFolder,
                          t.ink,
                          iconSize: 22,
                          strokeWidth: 1.7,
                          onTap: () => _move(picked),
                        ),
                      ),
                      Expanded(
                        child: _BarAction(
                          l.commonDelete,
                          AppIcons.trash,
                          t.danger,
                          iconSize: 20,
                          strokeWidth: 1.8,
                          onTap: () => _delete(picked),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: embedded ? 20 : 0),
          child: LayoutBuilder(
            builder: (context, box) {
              // 欄數：手機（＜600）維持原本的欄數；其餘依可用闊度 gridColumnsFor
              // （面板內 5 欄：最小格寬 120）。
              final int? columns = embedded
                  ? gridColumnsFor(box.maxWidth - 40, minCell: 130)
                  : (WindowClass.of(context).isCompact
                        ? null
                        : gridColumnsFor(box.maxWidth - 40));
              return Column(
                children: [
                  if (!fullyEmpty)
                    ChipRow(
                      options: [
                        for (final c in MaterialCategory.values)
                          (c.name, c.label(l)),
                      ],
                      selected: _category?.name,
                      onSelected: (id) => setState(
                        () => _category = id == null
                            ? null
                            : MaterialCategory.values.byName(id),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    ),
                  Expanded(
                    child: rows.isEmpty
                        ? EmptyState(
                            svg: AppIcons.image,
                            text: l.materialEmpty,
                            color: t.official,
                            actionLabel: l.albumAddImage,
                            onAction: _add,
                          )
                        : _layout == MaterialLayout.grid
                        ? SquareGrid(
                            images: _asAlbum(rows),
                            columns: columns,
                            selecting: _selecting,
                            selected: _selected,
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 96),
                            onLongPress: (im) => _longPress(im.id),
                            onDragSelect: (idx, done) =>
                                _dragSelect(rows, idx, done),
                            onTap: (im, i) => _open(rows, i),
                          )
                        : _Masonry(
                            rows: rows,
                            columns: columns,
                            selecting: _selecting,
                            selected: _selected,
                            onDragSelect: (idx, done) =>
                                _dragSelect(rows, idx, done),
                            onTap: (i) => _open(rows, i),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 瀑布：兩欄、圖片原比例、圓角 12、間距 8（MaterialList）。
class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.rows,
    this.columns,
    required this.selecting,
    required this.selected,
    required this.onDragSelect,
    required this.onTap,
  });
  final List<MaterialImage> rows;

  /// 欄數；null＝沿用手機的 [columnsForWidth]。
  final int? columns;
  final bool selecting;
  final Set<String> selected;
  final void Function(Set<int> indices, bool finished) onDragSelect;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final grid = MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
      crossAxisCount:
          columns ?? columnsForWidth(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final isSelected = selected.contains(r.id);
        final aspect = (r.width > 0 && r.height > 0) ? r.width / r.height : 1.0;
        final tile = GestureDetector(
          key: ValueKey('material-${r.id}'),
          onTap: () => onTap(i),
          child: AspectRatio(
            aspectRatio: aspect.clamp(0.4, 2.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.image),
                  child: MediaThumb(
                    MediaSource.row(
                      file: r.imageFile,
                      kind: r.kind,
                      durationMs: r.durationMs,
                      posterFile: r.posterFile,
                      width: r.width,
                      height: r.height,
                    ),
                    cacheWidth: 500,
                    badgeInset: 7,
                  ),
                ),
                if (isSelected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.image),
                      border: Border.all(color: t.accent, width: 2),
                    ),
                  ),
                if (selecting)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: SelectMark(selected: isSelected),
                  ),
              ],
            ),
          ),
        );
        return DragSelectItem(index: i, child: tile);
      },
    );
    return DragSelectArea(
      itemCount: rows.length,
      isSelected: (i) => selected.contains(rows[i].id),
      onChanged: onDragSelect,
      child: grid,
    );
  }
}

/// 瀑布｜九宮格的兩格切換（34×30，外框圓角 12、底色 chipBg；選中＝白底＋淡影）。
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.layout, required this.onChanged});
  final MaterialLayout layout;
  final ValueChanged<MaterialLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(MaterialLayout v, String icon, String label) {
      final on = layout == v;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            width: 34,
            height: 30,
            decoration: BoxDecoration(
              color: on ? t.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2B2622).withValues(alpha: 0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: SvgIcon(
                icon,
                size: 18,
                strokeWidth: 1.8,
                color: on ? t.ink : t.text4,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.chipBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(
            MaterialLayout.waterfall,
            MaterialLibIcons.layoutWaterfall,
            context.l10n.materialLayoutWaterfall,
          ),
          const SizedBox(width: 2),
          seg(
            MaterialLayout.grid,
            MaterialLibIcons.layoutGrid,
            context.l10n.materialLayoutGrid,
          ),
        ],
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
        // 放在 bottomNavigationBar 時高度不受限，要縮到內容大小。
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
