import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../l10n/l10n.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'search_icons.dart';

/// 搜尋分類；順序＝完成度（D-051）：全部／成圖／同人圖／草稿／腦洞。
enum SearchCategory {
  all,
  piece,
  fan,
  draft,
  idea;

  String label(AppLocalizations l) => switch (this) {
    all => l.commonAll,
    piece => l.searchCategoryPiece,
    fan => l.searchCategoryFan,
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
  });
  final TextEditingController controller;
  final String hint;
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
      style: TextStyle(fontSize: 15, color: t.ink),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: t.text4),
      ),
    );
  }
}

/// 分類分頁 chips（全部／成圖／同人圖／草稿／腦洞）。[counts] 給了就在名稱後面加數字。
/// 樣式照 PitSearch：間距 6、左右內距 13（比列表 chips 窄，五顆放得進一排）。
class SearchCategoryChips extends StatelessWidget {
  const SearchCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts,
  });
  final SearchCategory selected;
  final ValueChanged<SearchCategory> onSelected;
  final Map<SearchCategory, int>? counts;

  String _label(AppLocalizations l, SearchCategory c) =>
      counts == null ? c.label(l) : '${c.label(l)} ${counts![c] ?? 0}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        spacing: 6,
        children: [
          for (final c in SearchCategory.values)
            GestureDetector(
              onTap: () => onSelected(c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c == selected ? t.ink : t.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c == selected ? t.ink : t.border),
                ),
                child: Text(
                  _label(context.l10n, c),
                  style: TextStyle(
                    color: c == selected ? t.surface : t.text2,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
