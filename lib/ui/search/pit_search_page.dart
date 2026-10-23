import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart' show TagUsage;
import '../../state/providers.dart';
import '../../state/search_providers.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import 'pit_search_result_page.dart';
import 'search_icons.dart';
import 'search_wide.dart';
import 'search_widgets.dart';
import 'tagged_list.dart';

/// 坑內搜尋（PitSearch）：輸入框＋分類分頁＋按使用次數排序的常用 tag。
/// 設計稿沒有畫 `<nav>`，所以和詳情頁一樣隱藏底部導覽列（HidesNavBar）。
/// 送出文字或點常用 tag 就進結果頁（PitSearchResult）。
class PitSearchPage extends ConsumerStatefulWidget {
  const PitSearchPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<PitSearchPage> createState() => _PitSearchPageState();
}

class _PitSearchPageState extends ConsumerState<PitSearchPage>
    with HidesNavBar<PitSearchPage>, HidesNavBarWhenCompact<PitSearchPage> {
  final _controller = TextEditingController();
  SearchCategory _category = SearchCategory.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openResult({String text = '', String? tagId, bool untagged = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kSearchFlowRoute),
        builder: (_) => PitSearchResultPage(
          pitId: widget.pitId,
          text: text,
          tagId: tagId,
          untagged: untagged,
          category: _category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name ?? '';
    final usage =
        ref.watch(tagUsageByUsageProvider(widget.pitId)).value ?? const [];
    final untaggedCount =
        ref.watch(untaggedCountProvider(widget.pitId)).value ?? 0;
    if (searchIsWide(context)) {
      return _wide(context, pitName, usage, untaggedCount);
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SearchBarRow(
                child: SearchField(
                  controller: _controller,
                  hint: context.l10n.searchHint(pitName),
                  autofocus: true,
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    _openResult(text: v.trim());
                  },
                ),
              ),
              SearchCategoryChips(
                selected: _category,
                onSelected: (c) => setState(() => _category = c),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (usage.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                        child: Text(
                          context.l10n.searchFrequentTags,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final u in usage)
                            GestureDetector(
                              onTap: () => _openResult(tagId: u.tag.id),
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
                                        style: TextStyle(
                                          color: t.text4,
                                          fontSize: 12,
                                        ),
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
                    // 未加 tag（D-108）：坑內沒有任何 tag 的項目數；雜物沒有 tag，不算。
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: _UntaggedCard(
                        count: untaggedCount,
                        onTap: () => _openResult(untagged: true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// iPad（PitSearch 稿）：icon rail＋返回鍵＋寬輸入框；相冊 pills、常用 tag、寬 420 的「未加 tag」卡。
  Widget _wide(
    BuildContext context,
    String pitName,
    List<TagUsage> usage,
    int untaggedCount,
  ) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WideSearchHeader(
              child: WideSearchInput(
                child: SearchField(
                  controller: _controller,
                  hint: context.l10n.searchHint(pitName),
                  autofocus: true,
                  fontSize: 16,
                  onSubmitted: (v) {
                    if (v.trim().isEmpty) return;
                    _openResult(text: v.trim());
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 18, 32, 24),
                children: [
                  SearchCategoryChips(
                    wide: true,
                    selected: _category,
                    onSelected: (c) => setState(() => _category = c),
                  ),
                  if (usage.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
                      child: Text(
                        context.l10n.searchFrequentTags,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.text3,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final u in usage)
                              WideTagChip(
                                name: u.tag.name,
                                count: u.count,
                                onTap: () => _openResult(tagId: u.tag.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 26),
                        child: _UntaggedCard(
                          wide: true,
                          count: untaggedCount,
                          onTap: () => _openResult(untagged: true),
                        ),
                      ),
                    ),
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

/// 「未加 tag」卡片（PitSearch）：左邊 tag 加斜線 icon（米色底），名稱、數量、右箭頭。
class _UntaggedCard extends StatelessWidget {
  const _UntaggedCard({
    required this.count,
    required this.onTap,
    this.wide = false,
  });
  final int count;
  final VoidCallback onTap;

  /// iPad：圖示格 38、圓角 11（稿）。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      key: const ValueKey('searchUntaggedCard'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderCard),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: wide ? 38 : 36,
              height: wide ? 38 : 36,
              decoration: BoxDecoration(
                color: t.chipBg,
                borderRadius: BorderRadius.circular(wide ? 11 : 10),
              ),
              child: Center(
                child: SvgIcon(
                  SearchIcons.untagged,
                  size: 20,
                  strokeWidth: 1.7,
                  color: t.text3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.searchUntagged,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count',
              key: const ValueKey('searchUntaggedCount'),
              style: TextStyle(fontSize: 13, color: t.text3),
            ),
            const SizedBox(width: 8),
            SvgIcon(
              AppIcons.chevronRight,
              size: 18,
              color: t.text4,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
