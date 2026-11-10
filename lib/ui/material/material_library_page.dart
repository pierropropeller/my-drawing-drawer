import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/database.dart';
import '../../data/album_order_queries.dart';
import '../../data/material_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../state/sensitive.dart';
import '../common/sensitive_actions.dart';
import '../common/swipe_pager.dart';
import '../../l10n/l10n.dart';
import '../../media/media_import.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_icons.dart';
import '../album/album_image.dart';
import '../album/album_view.dart' show ChipRow;
import '../album/image_masonry.dart' show SelectMark, SquareGrid, liftShadow;
import '../album/reorder_masonry.dart';
import '../pits/pit_reorder_grid.dart';
import '../common/sort_done_button.dart';
import '../common/drag_select.dart';
import '../common/media_widgets.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../entity/entity_widgets.dart' show EntityFab;
import 'inspo_category_manage_page.dart';
import 'inspo_pit_sheet.dart';
import 'inspo_preview_page.dart';
import 'material_category_sheet.dart';
import 'material_icons.dart';
import '../common/top_toast.dart' show BottomInsetAnchor;

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

  /// 分類 id。
  final String? initialCategory;

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

  late String? _category = widget.initialCategory;

  /// 「全部」＋自訂分類（D-143）。
  List<String?> _orderOf(List<InspoCategory> cats) => [
    null,
    for (final c in cats) c.id,
  ];

  /// 左右滑的小數頁碼，分類 pills 的深色底跟著它滑（D-118）。
  late final _progress = ValueNotifier<double>(
    _orderOf(ref.read(inspoCategoriesProvider).value ?? const [])
        .indexOf(_category)
        .clamp(0, 999)
        .toDouble(),
  );

  @override
  void dispose() {
    if (_sorting) navLocked.value = false;
    _progress.dispose();
    super.dispose();
  }

  late MaterialLayout _layout = _readLayout();
  bool _selecting = false;
  final Set<String> _selected = {};

  /// 編輯排序中（D-134，AlbumSortEdit）。
  bool _sorting = false;

  /// 剛放手、資料庫還沒回來的新順序：(分類, id 順序)。
  (String?, List<String>)? _pending;

  void _enterSort() => setState(() {
    _selecting = false;
    _selected.clear();
    _sorting = true;
    navLocked.value = true;
  });

  void _exitSort() {
    navLocked.value = false;
    setState(() => _sorting = false);
  }

  /// 某個分類（null＝全部）的圖，套上手動順序（沒排過＝更新日期新→舊）。
  List<MaterialImage> _ordered(WidgetRef ref, String? category) {
    final rows = ref.watch(materialsProvider(category)).value ?? const [];
    final saved = ref
        .watch(albumOrderProvider(AlbumOrderScope.inspo(category)))
        .value;
    final pending = _pending;
    if (pending != null && pending.$1 == category) {
      // 存好的順序回來了就不用再蓋。
      if (saved != null && listEquals(saved, pending.$2)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_pending, pending)) {
            setState(() => _pending = null);
          }
        });
      }
      return applyAlbumOrder(rows, pending.$2, (r) => r.id);
    }
    return applyAlbumOrder(rows, saved, (r) => r.id);
  }

  void _reorder(List<MaterialImage> rows, int from, int to) {
    final ids = [for (final r in rows) r.id];
    ids.insert(to, ids.removeAt(from));
    final category = _category;
    setState(() => _pending = (category, ids));
    ref
        .read(databaseProvider)
        .saveAlbumOrder(AlbumOrderScope.inspo(category), ids);
  }

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
    // 預覽（InspoPreview，自己會隱藏導覽列），走「我的」分頁的 Navigator。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InspoPreviewPage(images: rows, initialIndex: i),
      ),
    );
  }

  /// 加圖：開相簿選圖；在分類下預設歸該分類，在「全部」下先選分類。
  Future<void> _add() async {
    // 素材庫自己的加圖：直接開相簿，不彈「從素材庫選取」的來源選單。
    // 靈感廣場自己的加圖：選圖 sheet 不列「靈感廣場」那段（只有新增參考圖才列）。
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
    final cats = {for (final p in picked) p.categoryKey};
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
      context.l10n.albumMovedCount(
        picked.length,
        (ref.read(inspoCategoriesProvider).value ?? const [])
                .where((c) => c.id == target)
                .firstOrNull
                ?.name ??
            '',
      ),
      success: true,
    );
    _exit();
  }

  /// 放進坑（InspoPitSheet，D-142）。
  Future<void> _place(List<MaterialImage> picked) async {
    if (picked.isEmpty) return;
    final ok = await placeInPit(context, ref, [for (final p in picked) p.id]);
    if (ok && mounted) _exit();
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
      title: context.l10n.trashDeleteItemsTitle(picked.length),
      toTrash: true,
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteMaterials([
      for (final p in picked) p.id,
    ]);
    if (mounted) _exit();
  }

  /// 編輯排序的標題列：「編輯排序」＋「靈感廣場」，右邊「完成」（AlbumSortEdit）。
  PreferredSizeWidget _sortAppBar({required bool wide}) {
    final t = context.tokens;
    final l = context.l10n;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: wide ? 72 : 68,
      titleSpacing: wide ? (widget.embedded ? 40 : 32) : 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.pitsortTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: wide ? 24 : 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l.materialTitle,
            style: TextStyle(color: t.text3, fontSize: wide ? 13 : 12),
          ),
        ],
      ),
      actions: [
        SortDoneButton(
          key: const ValueKey('albumSortDone'),
          big: wide,
          onTap: _exitSort,
        ),
        SizedBox(width: wide ? 32 : 20),
      ],
    );
  }

  /// 編輯排序：版面跟現在選的一樣（瀑布＝[ReorderMasonry]；九宮格＝正方形 [PitReorderGrid]）。
  Widget _sortGrid(
    List<MaterialImage> rows,
    Map<String, String> notes,
    String? Function(String id) pitsLine,
    int? columns,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    if (_layout == MaterialLayout.grid) {
      final cols =
          columns ??
          (WindowClass.of(context).isCompact
              ? columnsForWidth(width, phone: 3)
              : math.max(3, gridColumnsFor(width, minCell: 150)));
      final album = _asAlbum(rows);
      return SingleChildScrollView(
        key: const ValueKey('albumSortScroll'),
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 40),
        child: LayoutBuilder(
          builder: (context, box) {
            final cell = (box.maxWidth - 2 * (cols - 1)) / cols;
            return PitReorderGrid(
              key: const ValueKey('albumSortGrid'),
              count: rows.length,
              columns: cols,
              cellWidth: cell,
              cellHeight: cell,
              gapX: 2,
              gapY: 2,
              placeholderRadius: 0,
              liftScale: 1.08,
              itemBuilder: (context, i, dragging, lifted) => DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: lifted ? liftShadow : null,
                ),
                child: MediaThumb(album[i].media, cacheWidth: 400),
              ),
              onReorder: (from, to) => _reorder(rows, from, to),
            );
          },
        ),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('albumSortScroll'),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
      child: ReorderMasonry(
        key: const ValueKey('albumSortGrid'),
        count: rows.length,
        columns: columns ?? columnsForWidth(width),
        crossGap: 8,
        mainGap: 8,
        idOf: (i) => rows[i].id,
        estimateHeight: (i, w) {
          final r = rows[i];
          final aspect = (r.width > 0 && r.height > 0)
              ? r.width / r.height
              : 1.0;
          var h = w / aspect.clamp(0.4, 2.5);
          if (notes.containsKey(r.id)) h += 40;
          if (pitsLine(r.id) != null) h += 21;
          return h;
        },
        itemBuilder: (context, i, lifted) => _InspoTile(
          row: rows[i],
          note: notes[rows[i].id],
          inPits: pitsLine(rows[i].id),
          selecting: false,
          isSelected: false,
          lifted: lifted,
          onTap: () {},
        ),
        onReorder: (from, to) => _reorder(rows, from, to),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    setNavBarHidden(_selecting || _sorting);
    final cats = ref.watch(inspoCategoriesProvider).value ?? const [];
    // 停在的分類被刪了（別台裝置）就回「全部」。
    if (_category != null &&
        cats.isNotEmpty &&
        !cats.any((c) => c.id == _category)) {
      _category = null;
    }
    final order = _orderOf(cats);
    final rows = _ordered(ref, _category);
    final notes = {
      for (final r in rows)
        if ((r.note ?? '').isNotEmpty) r.id: r.note!,
    };
    final placed = ref.watch(placedPitsProvider).value ?? const {};
    String? pitsLine(String id) {
      final names = [for (final p in placed[id] ?? const []) p.name];
      return names.isEmpty ? null : names.join(l.inspoPitsSeparator);
    }

    final total = ref.watch(materialCountsProvider).value?.total ?? 0;
    final fullyEmpty = total == 0 && rows.isEmpty;
    final picked = _picked(rows);
    final allSelected = rows.isNotEmpty && picked.length >= rows.length;
    final embedded = widget.embedded;
    final serif = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: embedded ? 24 : 19, fontWeight: FontWeight.w700);
    return PopScope(
      canPop: !_selecting && !_sorting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _sorting ? _exitSort() : _exit();
      },
      child: Scaffold(
        appBar: _sorting
            ? _sortAppBar(wide: embedded || !WindowClass.of(context).isCompact)
            : AppBar(
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
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
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
                        IconButton(
                          key: const ValueKey('albumSortButton'),
                          tooltip: l.albumsortButton,
                          icon: SvgIcon(
                            AlbumIcons.sort,
                            size: 21,
                            color: t.ink,
                            strokeWidth: 1.9,
                          ),
                          onPressed: _enterSort,
                        ),
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
                            allSelected
                                ? l.commonDeselectAll
                                : l.commonSelectAll,
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
        floatingActionButton: (_selecting || _sorting || fullyEmpty)
            ? null
            : EntityFab(label: l.materialAddLabel, onPressed: _add),
        bottomNavigationBar: _selecting
            ? BottomInsetAnchor(
                child: Container(
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
                            l.inspoPlaceInPit,
                            MaterialLibIcons.placeInPit,
                            t.ink,
                            iconSize: 22,
                            strokeWidth: 1.7,
                            onTap: () => _place(picked),
                          ),
                        ),
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
              Widget page(List<MaterialImage> rows) =>
                  _sorting && rows.isNotEmpty
                  ? _sortGrid(rows, notes, pitsLine, columns)
                  : rows.isEmpty
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
                      onDragSelect: (idx, done) => _dragSelect(rows, idx, done),
                      onTap: (im, i) => _open(rows, i),
                    )
                  : _Masonry(
                      rows: rows,
                      notes: notes,
                      pitsLine: pitsLine,
                      columns: columns,
                      selecting: _selecting,
                      selected: _selected,
                      onDragSelect: (idx, done) => _dragSelect(rows, idx, done),
                      onTap: (i) => _open(rows, i),
                    );
              return Column(
                children: [
                  if (!fullyEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: ChipRow(
                            options: [for (final c in cats) (c.id, c.name)],
                            selected: _category,
                            progress: _progress,
                            onSelected: (id) => setState(() => _category = id),
                            padding: const EdgeInsets.fromLTRB(20, 6, 4, 12),
                          ),
                        ),
                        // 管理分類（InspoList 篩選列最右，D-143）。
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 8, 6),
                          child: Container(
                            width: 44,
                            height: 34,
                            decoration: BoxDecoration(
                              border: Border(left: BorderSide(color: t.border)),
                            ),
                            child: IconButton(
                              key: const ValueKey('inspoManageCategories'),
                              tooltip: l.inspoManageCategories,
                              padding: EdgeInsets.zero,
                              icon: SvgIcon(
                                AppIcons.sliders,
                                size: 20,
                                color: t.text2,
                                strokeWidth: 1.8,
                              ),
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const InspoCategoryManagePage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_sorting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l.albumsortHint,
                          style: TextStyle(color: t.text2, fontSize: 12.5),
                        ),
                      ),
                    ),
                  Expanded(
                    // 左右滑動切換分類，內容跟著手指走（D-118）。
                    child: SwipePager<String?>(
                      enabled: !_selecting && !_sorting && !fullyEmpty,
                      order: order,
                      current: _category,
                      progress: _progress,
                      onChanged: (c) => setState(() => _category = c),
                      itemBuilder: (context, c) => c == _category
                          ? page(rows)
                          : Consumer(
                              builder: (context, ref, _) =>
                                  page(_ordered(ref, c)),
                            ),
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
    required this.notes,
    required this.pitsLine,
    this.columns,
    required this.selecting,
    required this.selected,
    required this.onDragSelect,
    required this.onTap,
  });
  final List<MaterialImage> rows;

  /// 有說明的圖：id → 說明（縮圖下兩行）。
  final Map<String, String> notes;

  /// 放進了哪些坑（「坑A、坑B」）；沒放進任何坑＝null。
  final String? Function(String id) pitsLine;

  /// 欄數；null＝沿用手機的 [columnsForWidth]。
  final int? columns;
  final bool selecting;
  final Set<String> selected;
  final void Function(Set<int> indices, bool finished) onDragSelect;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final grid = MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
      crossAxisCount:
          columns ?? columnsForWidth(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final tile = _InspoTile(
          row: r,
          note: notes[r.id],
          inPits: pitsLine(r.id),
          selecting: selecting,
          isSelected: selected.contains(r.id),
          onTap: () => onTap(i),
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

/// 靈感廣場瀑布的一格：圖＋說明（兩行）＋放進了哪些坑（InspoList）。編輯排序也用（[lifted]＝正被拖著）。
class _InspoTile extends StatelessWidget {
  const _InspoTile({
    required this.row,
    required this.note,
    required this.inPits,
    required this.selecting,
    required this.isSelected,
    required this.onTap,
    this.lifted = false,
  });
  final MaterialImage row;
  final String? note;
  final String? inPits;
  final bool selecting;
  final bool isSelected;
  final VoidCallback onTap;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = row;
    final note = this.note;
    final inPits = this.inPits;
    final aspect = (r.width > 0 && r.height > 0) ? r.width / r.height : 1.0;
    final image = AspectRatio(
      aspectRatio: aspect.clamp(0.4, 2.5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (lifted)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.image),
                boxShadow: liftShadow,
              ),
            ),
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
    );
    // 縮圖下：說明（兩行）、放進了哪些坑（InspoList）。
    return GestureDetector(
      key: ValueKey('material-${r.id}'),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          image,
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.45, color: t.text2),
              ),
            ),
          if (inPits != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  SvgIcon(
                    AppIcons.folder,
                    size: 12,
                    color: t.text3,
                    strokeWidth: 1.8,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      inPits,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: t.text3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
