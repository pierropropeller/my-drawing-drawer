import 'package:flutter/material.dart';

import '../common/swipe_to_switch.dart';

import '../../data/search_queries.dart';
import '../../theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'search_icons.dart';

/// 結果頁的分段標題（成圖／官方圖冊／好看同人圖／推活／摸魚／腦洞）與對應的相冊 pill。
extension PitSearchSectionX on PitSearchSection {
  SearchCategory get category => switch (this) {
    PitSearchSection.pieces => SearchCategory.piece,
    PitSearchSection.official => SearchCategory.official,
    PitSearchSection.fanArts => SearchCategory.fan,
    PitSearchSection.oshi => SearchCategory.oshi,
    PitSearchSection.drafts => SearchCategory.draft,
    PitSearchSection.ideas => SearchCategory.idea,
  };

  String title(AppLocalizations l) => switch (this) {
    PitSearchSection.pieces => l.searchCategoryPiece,
    PitSearchSection.official => l.pitsOfficial,
    PitSearchSection.fanArts => l.pitsFanArt,
    PitSearchSection.oshi => l.pitSearchCategoryOshi,
    PitSearchSection.drafts => l.searchCategoryDraft,
    PitSearchSection.ideas => l.searchCategoryIdea,
  };
}

extension SearchCategoryX on SearchCategory {
  /// 對應的結果分段；「全部」＝null。
  PitSearchSection? get section => switch (this) {
    SearchCategory.all => null,
    SearchCategory.piece => PitSearchSection.pieces,
    SearchCategory.official => PitSearchSection.official,
    SearchCategory.fan => PitSearchSection.fanArts,
    SearchCategory.oshi => PitSearchSection.oshi,
    SearchCategory.draft => PitSearchSection.drafts,
    SearchCategory.idea => PitSearchSection.ideas,
  };
}

/// 搜尋分類；順序（D-051、D-065）：全部／成圖／同人圖／推活／草稿／腦洞。
enum SearchCategory {
  all,
  piece,
  official,
  fan,
  oshi,
  draft,
  idea;

  String label(AppLocalizations l) => switch (this) {
    all => l.commonAll,
    piece => l.searchCategoryPiece,
    official => l.searchCategoryOfficial,
    fan => l.searchCategoryFan,
    oshi => l.pitSearchCategoryOshi,
    draft => l.searchCategoryDraft,
    idea => l.searchCategoryIdea,
  };
}

/// 搜尋頁頂部：返回鍵＋主色細框的輸入列（PitSearch／PitSearchResult 共用）。
class SearchBarRow extends StatelessWidget {
  const SearchBarRow({super.key, required this.child});

  /// 輸入列內、放大鏡右側的內容（輸入框，或「#tag ×」pill＋輸入框）。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 16, 8),
      child: Row(
        children: [
          InkResponse(
            radius: 24,
            onTap: () => Navigator.of(context).maybePop(),
            child: Semantics(
              button: true,
              label: context.l10n.commonBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: t.accent, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SvgIcon(SearchIcons.search, size: 18, color: t.text3),
                  const SizedBox(width: 8),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 輸入框（無框線）；字級 15。
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.fontSize = 15,
  });
  final TextEditingController controller;
  final String hint;

  /// iPad 搜尋框字級 16（稿），手機 15。
  final double fontSize;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: t.accent,
      style: TextStyle(fontSize: fontSize, color: t.ink),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, color: t.text4),
      ),
    );
  }
}

/// 分類 chips 實際顯示的順序：[counts] 為 null 全部都有；給了就略過筆數 0 的（「全部」一律保留）。
List<SearchCategory> visibleSearchCategories(
  Map<SearchCategory, int>? counts,
) => [
  for (final c in SearchCategory.values)
    if (counts == null || c == SearchCategory.all || (counts[c] ?? 0) > 0) c,
];

/// 分類分頁 chips（全部／成圖／同人圖／推活／草稿／腦洞）。[counts] 給了就在名稱後面加數字，
/// 並略過筆數 0 的分頁（D-061；「全部」一律保留）。
/// 樣式照 PitSearch：間距 6、左右內距 13（比列表 chips 窄，放得進一排）。
class SearchCategoryChips extends StatelessWidget {
  const SearchCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts,
    this.wide = false,
  });
  final SearchCategory selected;
  final ValueChanged<SearchCategory> onSelected;
  final Map<SearchCategory, int>? counts;

  /// iPad（PitSearch 稿）：高 38、字 14、左右內距 16、間距 8，沒有外圍邊距（由頁面給）。
  final bool wide;

  String _label(AppLocalizations l, SearchCategory c) =>
      counts == null ? c.label(l) : '${c.label(l)} ${counts![c] ?? 0}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // 外層 Align：橫向 SingleChildScrollView 在 Column（預設置中）裡會縮成內容寬並置中，
    // 設計稿是靠左。
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: wide
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Row(
          spacing: wide ? 8 : 6,
          children: [
            for (final c in visibleSearchCategories(counts))
              EnsureVisibleWhenSelected(
                selected: c == selected,
                child: GestureDetector(
                  onTap: () => onSelected(c),
                  child: Container(
                    key: ValueKey('searchCategory-${c.name}'),
                    height: wide ? 38 : null,
                    alignment: wide ? Alignment.center : null,
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 16 : 13,
                      vertical: wide ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: c == selected ? t.ink : t.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: c == selected ? t.ink : t.border,
                      ),
                    ),
                    child: Text(
                      _label(context.l10n, c),
                      style: TextStyle(
                        color: c == selected ? t.surface : t.text2,
                        fontSize: wide ? 14 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
