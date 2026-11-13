import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/author_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_view.dart' show ChipRow;
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/sort_done_button.dart';
import '../common/svg_icon.dart';
import '../common/swipe_pager.dart';
import '../common/top_toast.dart' show BottomInsetAnchor;
import '../entity/entity_widgets.dart' show EntityFab;
import '../pits/pit_reorder_grid.dart';
import 'author_detail_page.dart';
import 'author_form_page.dart';
import 'author_icons.dart';
import 'author_sync.dart';
import 'author_widgets.dart';

/// 作者列表的兩種版面，記在本機設定（跟裝置走）。
enum AuthorLayout { list, grid }

const _kLayoutKey = 'authorLayout';
const _kPillKey = 'authorPill';
const _kScrollKey = 'authorScroll';

/// 列表一列的高度（頭像 48＋上下 10＋三行字；編輯排序的佔位也是這個高度）。
const _rowHeight = 84.0;

/// 格子一格的高度（AuthorSortGrid 的 grid-auto-rows）。
const _cellHeight = 150.0;

/// 作者列表（AuthorListRows／AuthorListGrid，D-156）。入口在「我的」，走「我的」分頁的 Navigator；
/// 瀏覽時有導覽列，長按進多選（刪除、↑↓ 編輯排序）時隱藏。
/// 坑分頁＝有作者以它為主坑的坑（依主頁順序）；停在哪一頁、捲到哪裡記在本機設定。
/// 排序是一份全域的手動順序（新增的排最前面），只能在「全部」編輯，其他分頁鎖住。
class AuthorListPage extends ConsumerStatefulWidget {
  const AuthorListPage({super.key});

  @override
  ConsumerState<AuthorListPage> createState() => _AuthorListPageState();
}

class _AuthorListPageState extends ConsumerState<AuthorListPage>
    with HidesNavBar<AuthorListPage> {
  @override
  bool get hidesNavBarOnOpen => false;

  late AuthorLayout _layout =
      ref.read(sharedPrefsProvider)?.getString(_kLayoutKey) == 'grid'
      ? AuthorLayout.grid
      : AuthorLayout.list;

  /// 停在的坑（null＝全部）。
  late String? _pit = ref.read(sharedPrefsProvider)?.getString(_kPillKey);

  late final _progress = ValueNotifier<double>(0);
  bool _progressSynced = false;

  bool _selecting = false;
  final Set<String> _selected = {};
  bool _sorting = false;

  /// 剛放手、資料庫還沒回來的新順序。
  List<String>? _pending;

  /// 每個分頁的捲動位置（key＝坑 id，全部＝''）。
  final Map<String, ScrollController> _scrolls = {};
  late final Map<String, double> _savedOffsets = _readOffsets();

  @override
  void initState() {
    super.initState();
    _prefs;
  }

  Map<String, double> _readOffsets() {
    final raw = ref.read(sharedPrefsProvider)?.getStringList(_kScrollKey);
    final out = <String, double>{};
    for (final e in raw ?? const <String>[]) {
      final i = e.lastIndexOf('=');
      if (i < 0) continue;
      final v = double.tryParse(e.substring(i + 1));
      if (v != null) out[e.substring(0, i)] = v;
    }
    return out;
  }

  /// dispose 時不能再用 ref，先存起來。
  late final _prefs = ref.read(sharedPrefsProvider);

  void _saveOffsets() {
    for (final e in _scrolls.entries) {
      if (e.value.hasClients) _savedOffsets[e.key] = e.value.offset;
    }
    _prefs?.setStringList(_kScrollKey, [
      for (final e in _savedOffsets.entries) '${e.key}=${e.value}',
    ]);
  }

  ScrollController _scrollFor(String? pit) => _scrolls.putIfAbsent(
    pit ?? '',
    () => ScrollController(initialScrollOffset: _savedOffsets[pit ?? ''] ?? 0),
  );

  @override
  void dispose() {
    if (_sorting) navLocked.value = false;
    _saveOffsets();
    for (final c in _scrolls.values) {
      c.dispose();
    }
    _progress.dispose();
    super.dispose();
  }

  void _setPit(String? pit) {
    setState(() => _pit = pit);
    final p = ref.read(sharedPrefsProvider);
    if (pit == null) {
      p?.remove(_kPillKey);
    } else {
      p?.setString(_kPillKey, pit);
    }
  }

  void _setLayout(AuthorLayout v) {
    _saveOffsets();
    // 兩種版面的高度不同，換版面時回到頂端。
    for (final c in _scrolls.values) {
      c.dispose();
    }
    _scrolls.clear();
    _savedOffsets.clear();
    setState(() => _layout = v);
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kLayoutKey, v == AuthorLayout.grid ? 'grid' : 'list');
  }

  List<AuthorSummary> _rowsOf(AuthorList data, String? pit) {
    var rows = data.authors;
    final pending = _pending;
    if (pending != null) {
      final cur = [for (final r in rows) r.author.id];
      if (_sameOrder(cur, pending)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identical(_pending, pending)) {
            setState(() => _pending = null);
          }
        });
      } else {
        final byId = {for (final r in rows) r.author.id: r};
        rows = [
          for (final id in pending)
            if (byId[id] != null) byId[id]!,
          for (final r in rows)
            if (!pending.contains(r.author.id)) r,
        ];
      }
    }
    if (pit == null) return rows;
    return [
      for (final r in rows)
        if (r.mainPitId == pit) r,
    ];
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _reorder(List<AuthorSummary> rows, int from, int to) {
    final ids = [for (final r in rows) r.author.id];
    ids.insert(to, ids.removeAt(from));
    setState(() => _pending = ids);
    ref.read(databaseProvider).reorderAuthors(ids);
  }

  void _exitSelect() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _enterSort() {
    _setPit(null);
    _progress.value = 0;
    setState(() {
      _selecting = false;
      _selected.clear();
      _sorting = true;
    });
    navLocked.value = true;
  }

  void _exitSort() {
    navLocked.value = false;
    setState(() => _sorting = false);
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
    if (_selected.isEmpty) _selecting = false;
  });

  void _longPress(String id) => setState(() {
    _selecting = true;
    _selected.add(id);
  });

  void _open(AuthorSummary s) {
    if (_selecting) {
      _toggle(s.author.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthorDetailPage(authorId: s.author.id),
      ),
    );
  }

  void _add() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const AuthorFormPage()));

  Future<void> _delete(List<AuthorSummary> picked) async {
    if (picked.isEmpty) return;
    final count = picked.fold(0, (n, s) => n + s.count);
    final ok = picked.length == 1
        ? await confirmDeleteAuthor(context, picked.single.author.name, count)
        : await confirmDeleteAuthors(context, picked.length, count);
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteAuthors([
      for (final p in picked) p.author.id,
    ]);
    if (mounted) _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    setNavBarHidden(_selecting || _sorting);
    final data = ref.watch(authorListProvider).value ?? AuthorList.empty;
    // 停在的坑已經沒有作者（作者被刪、圖被移走）就回「全部」。
    if (_pit != null &&
        ref.watch(authorListProvider).hasValue &&
        !data.pits.any((p) => p.id == _pit)) {
      _pit = null;
    }
    final order = <String?>[null, for (final p in data.pits) p.id];
    if (!_progressSynced && ref.watch(authorListProvider).hasValue) {
      _progressSynced = true;
      _progress.value = order.indexOf(_pit).clamp(0, 999).toDouble();
    }
    final rows = _rowsOf(data, _pit);
    final picked = [
      for (final r in rows)
        if (_selected.contains(r.author.id)) r,
    ];
    final allSelected = rows.isNotEmpty && picked.length >= rows.length;
    final total = data.authors.length;
    final empty = total == 0;
    final serif = Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700);

    PreferredSizeWidget appBar() {
      if (_sorting) {
        return AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 76,
          titleSpacing: 20,
          title: Text(
            l.pitsortTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          actions: [
            SortDoneButton(
              key: const ValueKey('authorSortDone'),
              onTap: _exitSort,
            ),
            const SizedBox(width: 20),
          ],
        );
      }
      return AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 58,
        titleSpacing: 4,
        leading: Padding(
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
                  onPressed: _exitSelect,
                )
              : IconButton(
                  tooltip: l.commonBack,
                  padding: EdgeInsets.zero,
                  icon: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
        ),
        title: Text(
          _selecting ? l.authorSelectedCount(picked.length) : l.authorTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: serif,
        ),
        actions: _selecting
            ? [
                IconButton(
                  key: const ValueKey('authorSortButton'),
                  tooltip: l.pitsortTitle,
                  icon: SvgIcon(
                    AuthorIcons.sort,
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
                      _selected.addAll(rows.map((r) => r.author.id));
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
                    l.authorCount(total),
                    style: TextStyle(color: t.text3, fontSize: 12),
                  ),
                ),
                _LayoutToggle(layout: _layout, onChanged: _setLayout),
                const SizedBox(width: 6),
              ],
      );
    }

    Widget page(String? pit) {
      final list = pit == _pit ? rows : _rowsOf(data, pit);
      if (_sorting) return _sortView(list);
      if (list.isEmpty) {
        return EmptyState(
          svg: AuthorIcons.author,
          text: l.authorEmpty,
          color: t.oshi,
          actionLabel: l.authorAdd,
          onAction: _add,
        );
      }
      final scroll = _scrollFor(pit);
      if (_layout == AuthorLayout.grid) {
        return GridView.builder(
          key: PageStorageKey('authorGrid-$pit'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: _cellHeight,
          ),
          itemCount: list.length,
          itemBuilder: (_, i) => AuthorGridTile(
            summary: list[i],
            selecting: _selecting,
            selected: _selected.contains(list[i].author.id),
            onTap: () => _open(list[i]),
            onLongPress: () => _longPress(list[i].author.id),
          ),
        );
      }
      return ListView.builder(
        key: PageStorageKey('authorList-$pit'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        itemCount: list.length,
        itemBuilder: (_, i) => AuthorRowTile(
          summary: list[i],
          selecting: _selecting,
          selected: _selected.contains(list[i].author.id),
          onTap: () => _open(list[i]),
          onLongPress: () => _longPress(list[i].author.id),
        ),
      );
    }

    return PopScope(
      canPop: !_selecting && !_sorting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _sorting ? _exitSort() : _exitSelect();
      },
      child: Scaffold(
        appBar: appBar(),
        floatingActionButton: (_selecting || _sorting || empty)
            ? null
            : EntityFab(label: l.authorAdd, onPressed: _add),
        bottomNavigationBar: _selecting
            ? BottomInsetAnchor(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  decoration: BoxDecoration(
                    color: t.nav,
                    border: Border(top: BorderSide(color: t.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      key: const ValueKey('authorDeleteSelected'),
                      onTap: () => _delete(picked),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgIcon(
                              AppIcons.trash,
                              size: 20,
                              color: t.danger,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.commonDelete,
                              style: TextStyle(color: t.danger, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            if (!empty)
              _sorting
                  ? _LockedPills(pits: [for (final p in data.pits) p.name])
                  : ChipRow(
                      options: [for (final p in data.pits) (p.id, p.name)],
                      selected: _pit,
                      progress: _progress,
                      onSelected: _setPit,
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    ),
            if (_sorting)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.albumsortHint,
                    style: TextStyle(color: t.text2, fontSize: 12.5),
                  ),
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _saveOffsets();
                  return false;
                },
                child: SwipePager<String?>(
                  enabled: !_selecting && !_sorting && !empty,
                  order: order,
                  current: _pit,
                  progress: _progress,
                  onChanged: _setPit,
                  itemBuilder: (context, p) => page(p),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 編輯排序（AuthorSortRows／AuthorSortGrid）：長按拖動，版面跟現在選的一樣。
  Widget _sortView(List<AuthorSummary> rows) {
    return SingleChildScrollView(
      key: const ValueKey('authorSortScroll'),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 40),
      child: LayoutBuilder(
        builder: (context, box) {
          final grid = _layout == AuthorLayout.grid;
          final cols = grid ? 3 : 1;
          final cell = grid
              ? (box.maxWidth - 10 * (cols - 1)) / cols
              : box.maxWidth;
          return PitReorderGrid(
            key: const ValueKey('authorSortGrid'),
            count: rows.length,
            columns: cols,
            cellWidth: cell,
            cellHeight: grid ? _cellHeight : _rowHeight,
            gapX: grid ? 10 : 0,
            gapY: grid ? 10 : 0,
            placeholderRadius: grid ? 16 : 14,
            liftScale: grid ? 1.06 : 1.03,
            onReorder: (from, to) => _reorder(rows, from, to),
            itemBuilder: (context, i, dragging, lifted) => grid
                ? AuthorGridTile(summary: rows[i], lifted: lifted)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: lifted ? context.tokens.surface : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: lifted
                          ? const [
                              BoxShadow(
                                color: Color(0x2E2B2622),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: lifted ? 10 : 0,
                      ),
                      child: AuthorRowTile(summary: rows[i], sorting: true),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// 編輯排序時的坑分頁：只有「全部」亮著，其他變淡、不能點（AuthorSortRows）。
class _LockedPills extends StatelessWidget {
  const _LockedPills({required this.pits});
  final List<String> pits;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget pill(String label, bool on) => Opacity(
      opacity: on ? 1 : 0.4,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: on ? t.ink : t.surface,
          border: Border.all(color: on ? t.ink : t.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: on ? t.ground : t.text2,
          ),
        ),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
      child: Row(
        children: [
          pill(context.l10n.commonAll, true),
          for (final p in pits) pill(p, false),
        ],
      ),
    );
  }
}

/// 版面切換：列表／格子（AuthorListRows 標題列右側）。
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.layout, required this.onChanged});
  final AuthorLayout layout;
  final ValueChanged<AuthorLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(AuthorLayout v, String icon, String label, double stroke) {
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
                strokeWidth: stroke,
                color: on ? t.ink : t.text4,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: context.l10n.authorLayoutLabel,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: t.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg(
              AuthorLayout.list,
              AuthorIcons.layoutList,
              context.l10n.authorLayoutList,
              1.8,
            ),
            const SizedBox(width: 2),
            seg(
              AuthorLayout.grid,
              AuthorIcons.layoutGrid,
              context.l10n.authorLayoutGrid,
              1.7,
            ),
          ],
        ),
      ),
    );
  }
}

/// 給「我的」入口卡用：作者總數。
final authorCountProvider = Provider<int>(
  (ref) => ref.watch(authorListProvider).value?.authors.length ?? 0,
);
