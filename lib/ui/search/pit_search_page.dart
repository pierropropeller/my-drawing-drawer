import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import 'pit_search_result_page.dart';
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
    with HidesNavBar<PitSearchPage> {
  final _controller = TextEditingController();
  SearchCategory _category = SearchCategory.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openResult({String text = '', String? tagId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: kSearchFlowRoute),
        builder: (_) => PitSearchResultPage(
          pitId: widget.pitId,
          text: text,
          tagId: tagId,
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              SearchBarRow(
                child: SearchField(
                  controller: _controller,
                  hint: '搜尋$pitName',
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
                      const Padding(
                        padding: EdgeInsets.fromLTRB(2, 4, 2, 10),
                        child: Text(
                          '常用 tag',
                          style: TextStyle(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
