import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/search_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/search_providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import 'pit_search_result_page.dart';
import 'search_hits.dart';
import 'search_widgets.dart';
import 'tagged_list.dart';

/// 全坑搜尋（GlobalSearch／GlobalSearchResult，D-105）：主頁右上搜尋鍵進來。
///
/// 還沒輸入：按坑分組列出常用 tag（不同坑的同名 tag 各在自己那組；封存坑排最後），
/// 點 tag＝進該坑的坑內搜尋結果並帶上這個 tag。
/// 輸入文字後：先列符合的 tag（chip 右邊小標寫坑名），再按坑分組列出內容結果
/// （符合筆數多的坑在前；點組標題＝進該坑的坑內搜尋並帶同一個關鍵字）。
/// 搜尋範圍：坑名、tag、標題、內文／描述、同人圖作者。設計稿沒有畫 `<nav>`，隱藏底部導覽列。
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage>
    with HidesNavBar<GlobalSearchPage> {
  final _controller = TextEditingController();
  String _text = '';

  /// 輸入下一個字、新結果還沒回來時，先留著上一筆結果，畫面不會閃成空白。
  GlobalSearchHits _last = GlobalSearchHits.empty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) => setState(() => _text = v);

  void _clear() {
    _controller.clear();
    setState(() => _text = '');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final query = _text.trim();
    final Widget body;
    if (query.isEmpty) {
      body = _TagGroups(
        groups: ref.watch(globalTagGroupsProvider).value ?? const [],
      );
    } else {
      final async = ref.watch(globalSearchProvider(query));
      if (async.hasValue) _last = async.requireValue;
      body = _Results(text: query, hits: _last);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SearchBarRow(
                child: Row(
                  children: [
                    Expanded(
                      child: SearchField(
                        controller: _controller,
                        hint: l.globalSearchHint,
                        autofocus: true,
                        onChanged: _onChanged,
                      ),
                    ),
                    if (_text.isNotEmpty)
                      GestureDetector(
                        key: const ValueKey('globalSearchClear'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _clear,
                        child: Semantics(
                          button: true,
                          label: l.globalSearchClear,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: SvgIcon(
                              AppIcons.closeX,
                              size: 16,
                              strokeWidth: 2.2,
                              color: t.text4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小色塊的底色：沿用主頁坑卡片的佔位色（依序 官方／同人／草稿／淺綠）。
Color _pitTint(BuildContext context, int index) {
  final t = context.tokens;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final tints = [
    t.official.bg,
    t.fanArt.bg,
    t.draft.bg,
    dark ? const Color(0xFF2C3529) : const Color(0xFFE7EFE4),
  ];
  return tints[index % tints.length];
}

class _PitHeading extends StatelessWidget {
  const _PitHeading({
    super.key,
    required this.pit,
    required this.tint,
    this.count,
    this.onTap,
  });
  final Pit pit;
  final Color tint;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (count != null) ...[
              Text('$count', style: TextStyle(fontSize: 12.5, color: t.text4)),
              const SizedBox(width: 8),
              SvgIcon(
                AppIcons.chevronRight,
                size: 16,
                color: t.text4,
                strokeWidth: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 還沒輸入：按坑分組的常用 tag。
class _TagGroups extends StatelessWidget {
  const _TagGroups({required this.groups});
  final List<GlobalTagGroup> groups;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        for (final (i, g) in groups.indexed) ...[
          _PitHeading(
            key: ValueKey('globalTagGroup-${g.pit.id}'),
            pit: g.pit,
            tint: _pitTint(context, i),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in g.tags)
                GestureDetector(
                  key: ValueKey('globalTag-${u.tag.id}'),
                  onTap: () => openTagSearch(context, g.pit.id, u.tag.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: '#${u.tag.name}',
                        children: [
                          TextSpan(
                            text: '  ${u.count}',
                            style: TextStyle(color: t.text4, fontSize: 12),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 14, color: t.ink),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 輸入文字後：符合的 tag，再按坑分組的內容結果。
class _Results extends StatelessWidget {
  const _Results({required this.text, required this.hits});
  final String text;
  final GlobalSearchHits hits;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    if (hits.isEmpty) {
      return Center(
        child: Text(
          l.searchNoResults,
          style: TextStyle(color: t.text3, fontSize: 14),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (hits.tags.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
            child: Text(
              l.globalSearchTagsHeading,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in hits.tags)
                GestureDetector(
                  key: ValueKey('globalTagHit-${h.tag.id}'),
                  onTap: () => openTagSearch(context, h.pit.id, h.tag.id),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${h.tag.name}',
                          style: TextStyle(fontSize: 14, color: t.ink),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: t.chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            h.pit.name,
                            style: TextStyle(fontSize: 11.5, color: t.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        for (final (i, g) in hits.pits.indexed)
          _PitResultGroup(
            key: ValueKey('globalPit-${g.pit.id}'),
            group: g,
            text: text,
            tint: _pitTint(context, i),
          ),
      ],
    );
  }
}

/// 一個坑的內容結果：標題（小色塊＋坑名＋筆數 ›）、圖片類合成一排 3 格（第 3 格 +N）、腦洞文字卡。
class _PitResultGroup extends ConsumerWidget {
  const _PitResultGroup({
    super.key,
    required this.group,
    required this.text,
    required this.tint,
  });
  final GlobalPitResult group;
  final String text;
  final Color tint;

  static const _imageSections = [
    PitSearchSection.pieces,
    PitSearchSection.official,
    PitSearchSection.fanArts,
    PitSearchSection.oshi,
    PitSearchSection.drafts,
  ];

  /// 進該坑的坑內搜尋（帶同一個關鍵字；坑名也算範圍，才找得到同一批結果）。
  void _openPit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kSearchFlowRoute),
        builder: (_) => PitSearchResultPage(
          pitId: group.pit.id,
          text: text,
          includePitName: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = group.result;
    final names = watchGroupNames(ref, group.pit.id);
    final opener = SearchOpener(
      context,
      pitId: group.pit.id,
      res: res,
      fanGroupNames: names.fan,
      officialGroupNames: names.official,
    );
    // 圖片類（成圖、官方圖、同人圖、推活、摸魚）合成一排：依分段順序取前 3 格。
    final imageTotal = _imageSections.fold<int>(
      0,
      (n, s) => n + (res.counts[s] ?? 0),
    );
    final tiles = [for (final s in _imageSections) ...searchTilesOf(res, s)]
        .take(3)
        .toList();
    final ideas = searchTilesOf(res, PitSearchSection.ideas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PitHeading(
          pit: group.pit,
          tint: tint,
          count: group.total,
          onTap: () => _openPit(context),
        ),
        if (tiles.isNotEmpty)
          SearchThumbRow(
            tiles: tiles,
            more: imageTotal - tiles.length,
            selection: SearchSelection.none,
            onTap: (tile) => opener.open(tile.section, tile.index),
            // 合併成一排的「+N」：進該坑的坑內搜尋（相冊「全部」）。
            onMore: () => _openPit(context),
          ),
        for (final tile in ideas)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: IdeaResultCard(
              tile: tile,
              selection: SearchSelection.none,
              onTap: () => opener.open(tile.section, tile.index),
            ),
          ),
      ],
    );
  }
}
