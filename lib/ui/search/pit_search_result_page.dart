import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/batch_tag_queries.dart';
import '../../data/search_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/search_providers.dart';
import '../../theme/tokens.dart';
import '../album/tag_batch_sheet.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/swipe_to_switch.dart';
import '../entity/entity_select.dart' show showEntityTagSheet;
import '../album/album_icons.dart';
import 'filter_pills.dart';
import 'pit_search_tab.dart';
import 'search_hits.dart';
import 'search_wide.dart';
import 'search_widgets.dart';
import '../common/top_toast.dart' show BottomInsetAnchor;

/// 坑內搜尋結果（PitSearchResult，D-051、D-107）：
/// 頂部相冊 pills（只列有結果的，每顆帶數字）＋分段總覽——分段順序 成圖 → 官方圖冊 → 好看同人圖 → 推活 →
/// 摸魚 → 腦洞（D-065）；圖片類一排 3 格、第 3 格 +N（點它切到那一段的相冊），少於 3 筆就照實際張數放、
/// 各自圓角（D-061）；腦洞直向全列、往下捲動分批載入。選了某個相冊＝[PitSearchResultTab]。
///
/// 搜尋列可帶 tag（`#tag ×`）、關鍵字，或灰色的「未加 tag ×」（[untagged]，D-108，這時長按結果可多選批量補 tag）。
/// 設計稿沒有畫 `<nav>`，隱藏底部導覽列。
class PitSearchResultPage extends ConsumerStatefulWidget {
  const PitSearchResultPage({
    super.key,
    required this.pitId,
    this.text = '',
    this.tagId,
    this.untagged = false,
    this.includePitName = false,
    this.category = SearchCategory.all,
  });
  final String pitId;
  final String text;
  final String? tagId;

  /// 「未加 tag」篩選（PitSearchUntagged）。
  final bool untagged;

  /// 從全坑搜尋點坑名進來：坑名也算搜尋範圍。
  final bool includePitName;
  final SearchCategory category;

  /// 腦洞每批載入的數量。
  static const ideaBatch = 20;

  @override
  ConsumerState<PitSearchResultPage> createState() =>
      _PitSearchResultPageState();
}

class _PitSearchResultPageState extends ConsumerState<PitSearchResultPage>
    with
        HidesNavBar<PitSearchResultPage>,
        HidesNavBarWhenCompact<PitSearchResultPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late String _text = widget.text;
  late String? _tagId = widget.tagId;
  late bool _untagged = widget.untagged;
  late SearchCategory _category = widget.category;
  int _ideaShown = PitSearchResultPage.ideaBatch;

  /// 多選（只有「未加 tag」結果支援，D-108）。
  bool _selecting = false;
  final Set<String> _selected = {};

  /// 一次捲動期間只載入一批：等新一批排版完、捲動範圍更新後才會再載入。
  bool _batchPending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setText(String v) {
    setState(() {
      _text = v;
      _ideaShown = PitSearchResultPage.ideaBatch;
    });
  }

  /// 按搜尋列裡 chip 的「×」：沒有別的條件就離開；還有文字就只拿掉 chip。
  void _clearFilter() {
    if (_text.trim().isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _tagId = null;
      _untagged = false;
      _ideaShown = PitSearchResultPage.ideaBatch;
    });
  }

  void _select(SearchCategory c) => setState(() {
    _category = c;
    _ideaShown = PitSearchResultPage.ideaBatch;
  });

  void _exitSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  void _toggle(SearchTile tile) => setState(() {
    if (!_selected.remove(tile.key)) _selected.add(tile.key);
    if (_selected.isEmpty) _selecting = false;
  });

  void _startSelecting(SearchTile tile) => setState(() {
    _selecting = true;
    _selected
      ..clear()
      ..add(tile.key);
  });

  Future<void> _tagSelected() async {
    final ids = _selected.toList()..sort();
    if (ids.isEmpty) return;
    final applied = await showEntityTagSheet(
      context,
      pitId: widget.pitId,
      ids: ids,
      backend: BatchTagBackend(
        watch: (db, ids) =>
            db.watchTagCoverageMixed([for (final k in ids) TagRef.parse(k)]),
        apply: (db, ids, {required add, required remove, required newNames}) =>
            db.applyBatchTagsMixed(
              [for (final k in ids) TagRef.parse(k)],
              addTagIds: add,
              removeTagIds: remove,
              newTagNames: newNames,
            ),
        countText: (l, count) => l.searchSelectedCount(count),
      ),
    );
    if (applied == true && mounted) _exitSelecting();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name ?? '';
    final tags = ref.watch(tagsProvider(widget.pitId)).value ?? const [];
    final tagName = tags.where((e) => e.id == _tagId).firstOrNull?.name ?? '';
    final names = watchGroupNames(ref, widget.pitId);
    final res =
        ref
            .watch(
              pitSearchProvider(
                PitSearchQuery(
                  widget.pitId,
                  text: _text.trim(),
                  tagId: _tagId,
                  untagged: _untagged,
                  includePitName: widget.includePitName,
                  unlimited: true,
                ),
              ),
            )
            .value ??
        PitSearchResult.empty;
    // 目前相冊的結果變成 0 筆（pill 被隱藏，例如補完 tag 後）時退回「全部」。
    final counts = {
      SearchCategory.all: res.total,
      for (final s in PitSearchSection.values) s.category: res.counts[s] ?? 0,
    };
    final category = (counts[_category] ?? 0) == 0
        ? SearchCategory.all
        : _category;
    final section = category.section;
    final opener = SearchOpener(
      context,
      pitId: widget.pitId,
      res: res,
      fanGroupNames: names.fan,
      officialGroupNames: names.official,
    );
    // 「未加 tag」結果才有多選。
    final selection = _untagged
        ? SearchSelection(
            selecting: _selecting,
            selected: _selected,
            onToggle: _toggle,
            onStart: _startSelecting,
          )
        : SearchSelection.none;

    if (searchIsWide(context)) {
      return _wide(
        context,
        res: res,
        counts: counts,
        category: category,
        section: section,
        opener: opener,
        selection: selection,
        pitName: pitName,
        tagName: tagName,
      );
    }

    final Widget body;
    if (res.isEmpty) {
      body = Center(
        child: Text(
          l.searchNoResults,
          style: TextStyle(color: t.text3, fontSize: 14),
        ),
      );
    } else if (section != null) {
      body = PitSearchResultTab(
        section: section,
        res: res,
        opener: opener,
        selection: selection,
      );
    } else {
      body = _overview(res, opener, selection);
    }

    final allSelectedInTab =
        section != null &&
        searchTilesOf(res, section).every((x) => _selected.contains(x.key));

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelecting();
      },
      child: Scaffold(
        bottomNavigationBar: _selecting
            ? SearchSelectBar(onTag: _tagSelected)
            : null,
        body: SafeArea(
          bottom: false,
          child: ContentWidth(
            child: Column(
              children: [
                if (_selecting)
                  SearchSelectHeader(
                    count: _selected.length,
                    // 「全選」只在單一相冊頁（那裡才有該相冊的全部結果）。
                    onToggleAll: section == null
                        ? null
                        : () => setState(() {
                            final all = searchTilesOf(res, section);
                            if (allSelectedInTab) {
                              _selected.clear();
                              _selecting = false;
                            } else {
                              _selected.addAll(all.map((x) => x.key));
                            }
                          }),
                    allSelected: allSelectedInTab,
                    onExit: _exitSelecting,
                  )
                else ...[
                  SearchBarRow(
                    child: Row(
                      children: [
                        if (_tagId != null) ...[
                          TagFilterPill(name: tagName, onClear: _clearFilter),
                          const SizedBox(width: 6),
                        ],
                        if (_untagged) ...[
                          UntaggedFilterPill(onClear: _clearFilter),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: SearchField(
                            controller: _controller,
                            hint: _tagId == null && !_untagged
                                ? l.searchHint(pitName)
                                : '',
                            onChanged: _setText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SearchCategoryChips(
                    selected: category,
                    onSelected: _select,
                    counts: counts,
                  ),
                ],
                Expanded(
                  child: SwipeToSwitch.among<SearchCategory>(
                    enabled: !_selecting,
                    order: visibleSearchCategories(counts),
                    current: category,
                    onChanged: _select,
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// iPad（PitSearchResult／PitSearchResultTab／PitSearchUntagged 稿）：icon rail＋返回鍵＋寬輸入框；
  /// 左邊 210 寬的直排相冊清單（只列有結果的，帶數字），右邊是分段總覽或單一相冊的 6 欄九宮格。
  /// 「未加 tag」結果：長按進多選，右邊內容區底部出現工具列。
  Widget _wide(
    BuildContext context, {
    required PitSearchResult res,
    required Map<SearchCategory, int> counts,
    required SearchCategory category,
    required PitSearchSection? section,
    required SearchOpener opener,
    required SearchSelection selection,
    required String pitName,
    required String tagName,
  }) {
    final t = context.tokens;
    final l = context.l10n;
    final pickable = [
      for (final s in section == null ? res.visibleSections : [section])
        ...searchTilesOf(res, s),
    ];
    final allSelected =
        pickable.isNotEmpty && pickable.every((x) => _selected.contains(x.key));
    final inset = _selecting ? WideSelectBar.height + 24 : 24.0;
    final Widget body;
    if (res.isEmpty) {
      body = Center(
        child: Text(
          l.searchNoResults,
          style: TextStyle(color: t.text3, fontSize: 14),
        ),
      );
    } else if (section != null) {
      body = PitSearchResultTab(
        section: section,
        res: res,
        opener: opener,
        selection: selection,
        wide: true,
        bottomInset: inset,
      );
    } else {
      body = _wideOverview(res, opener, selection, inset);
    }
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelecting();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WideSearchHeader(
                child: WideSearchInput(
                  child: Row(
                    children: [
                      if (_tagId != null) ...[
                        TagFilterPill(name: tagName, onClear: _clearFilter),
                        const SizedBox(width: 6),
                      ],
                      if (_untagged) ...[
                        UntaggedFilterPill(onClear: _clearFilter),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: SearchField(
                          controller: _controller,
                          hint: _tagId == null && !_untagged
                              ? l.searchHint(pitName)
                              : '',
                          fontSize: 16,
                          onChanged: _setText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WideAlbumNav(
                        counts: counts,
                        selected: category,
                        onSelected: _select,
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: SwipeToSwitch.among<SearchCategory>(
                                enabled: !_selecting,
                                order: visibleSearchCategories(counts),
                                current: category,
                                onChanged: _select,
                                child: body,
                              ),
                            ),
                            if (_selecting)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: WideSelectBar(
                                  count: _selected.length,
                                  allSelected: allSelected,
                                  onExit: _exitSelecting,
                                  onToggleAll: () => setState(() {
                                    if (allSelected) {
                                      _selected.clear();
                                      _selecting = false;
                                    } else {
                                      _selected.addAll(
                                        pickable.map((x) => x.key),
                                      );
                                    }
                                  }),
                                  onTag: _tagSelected,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// iPad 分段總覽（「全部」）：圖片一排 6 格＋「+N」（點它切到那個相冊）、腦洞文字卡兩欄。
  Widget _wideOverview(
    PitSearchResult res,
    SearchOpener opener,
    SearchSelection selection,
    double bottomInset,
  ) {
    final l = context.l10n;
    final children = <Widget>[];
    for (final s in res.visibleSections) {
      final total = res.counts[s]!;
      final all = searchTilesOf(res, s);
      final Widget content;
      if (s == PitSearchSection.ideas) {
        final shown = all.length < _ideaShown ? all.length : _ideaShown;
        content = Column(
          children: [
            IdeaCardsGrid(
              tiles: all.take(shown).toList(),
              selection: selection,
              onTap: (tile) => opener.open(s, tile.index),
            ),
            if (shown < all.length)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    key: Key('ideas-loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        );
      } else {
        final shownTiles = all.take(WideThumbRow.columns).toList();
        content = WideThumbRow(
          tiles: shownTiles,
          more: total - shownTiles.length,
          selection: selection,
          onTap: (tile) => opener.open(s, tile.index),
          onMore: () => _select(s.category),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            key: ValueKey('searchSection-${s.name}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchSectionHeader(s.title(l), total, wide: true),
              content,
            ],
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_batchPending &&
            n.metrics.extentAfter < 400 &&
            _ideaShown < res.ideas.items.length) {
          _batchPending = true;
          setState(() => _ideaShown += PitSearchResultPage.ideaBatch);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _batchPending = false,
          );
        }
        return false;
      },
      child: ListView(
        key: const ValueKey('searchWideOverview'),
        padding: EdgeInsets.only(bottom: bottomInset),
        children: children,
      ),
    );
  }

  /// 分段總覽（「全部」）。
  Widget _overview(
    PitSearchResult res,
    SearchOpener opener,
    SearchSelection selection,
  ) {
    final l = context.l10n;
    final slivers = <Widget>[];
    void section(Widget w) => slivers.add(SliverToBoxAdapter(child: w));

    for (final s in res.visibleSections) {
      final total = res.counts[s]!;
      final all = searchTilesOf(res, s);
      if (s == PitSearchSection.ideas) {
        final shown = all.length < _ideaShown ? all.length : _ideaShown;
        section(SearchSectionHeader(s.title(l), total));
        slivers.add(
          SliverList.separated(
            itemCount: shown,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => IdeaResultCard(
              tile: all[i],
              selection: selection,
              onTap: () => opener.open(s, all[i].index),
            ),
          ),
        );
        if (shown < all.length) {
          section(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  key: Key('ideas-loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        continue;
      }
      final shownTiles = all.take(3).toList();
      section(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchSectionHeader(s.title(l), total),
            SearchThumbRow(
              tiles: shownTiles,
              more: total - shownTiles.length,
              selection: selection,
              onTap: (tile) => opener.open(s, tile.index),
              // 「+N」：切到那一段的相冊（D-107）。
              onMore: () => _select(s.category),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 接近底部時多載入一批腦洞。
        if (!_batchPending &&
            n.metrics.extentAfter < 400 &&
            _ideaShown < res.ideas.items.length) {
          _batchPending = true;
          setState(() => _ideaShown += PitSearchResultPage.ideaBatch);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _batchPending = false,
          );
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
        ],
      ),
    );
  }
}

/// 多選的標題列：左「×」取消、「已選 N 筆」、右「全選」（只在單一相冊頁）。
/// 版型同推活／摸魚多選（OshiSelect）。
class SearchSelectHeader extends StatelessWidget {
  const SearchSelectHeader({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onExit,
    this.onToggleAll,
  });
  final int count;
  final bool allSelected;
  final VoidCallback onExit;
  final VoidCallback? onToggleAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          Tooltip(
            message: l.albumCancelSelect,
            child: InkResponse(
              key: const ValueKey('searchSelectExit'),
              radius: 24,
              onTap: onExit,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(
                    AppIcons.closeX,
                    size: 22,
                    strokeWidth: 2,
                    color: t.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.searchSelectedCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          if (onToggleAll != null)
            TextButton(
              key: const ValueKey('searchSelectAll'),
              onPressed: onToggleAll,
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
        ],
      ),
    );
  }
}

/// 多選的底部動作列：只有「tag」（沒有導覽列）。
class SearchSelectBar extends StatelessWidget {
  const SearchSelectBar({super.key, required this.onTag});
  final VoidCallback onTag;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return BottomInsetAnchor(
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
            key: const ValueKey('searchSelectTag'),
            onTap: onTag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgIcon(
                    AlbumIcons.tag,
                    size: 22,
                    color: t.ink,
                    strokeWidth: 1.7,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.shareMoveTag,
                    style: TextStyle(color: t.ink, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 段頭：粗體名稱＋淡色數字（沒有「全部」）。
class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader(
    this.title,
    this.total, {
    super.key,
    this.wide = false,
  });
  final String title;
  final int total;

  /// iPad：名稱 15、數字 13，上方不留白、下方 10。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: wide
          ? const EdgeInsets.fromLTRB(2, 0, 2, 10)
          : const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text.rich(
        TextSpan(
          text: title,
          children: [
            TextSpan(
              text: '  $total',
              style: TextStyle(
                color: t.text4,
                fontWeight: FontWeight.w500,
                fontSize: wide ? 13 : null,
              ),
            ),
          ],
        ),
        style: TextStyle(
          fontSize: wide ? 15 : 14,
          fontWeight: FontWeight.w700,
          color: t.ink,
        ),
      ),
    );
  }
}
