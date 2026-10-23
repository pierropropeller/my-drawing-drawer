import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../album/album_icons.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'search_hits.dart';
import 'search_icons.dart';
import 'search_widgets.dart';

/// 搜尋頁的 iPad 版面（P-028、P-029：GlobalSearch／PitSearch／PitSearchResult 稿）：≥600 用。
/// ＜600（含 iPad 分屏的窄視窗）仍是手機版面。
bool searchIsWide(BuildContext context) => !WindowClass.of(context).isCompact;

/// iPad 搜尋輸入框：高 48、主色 1.5 細框、圓角 14，左邊放大鏡（稿：GlobalSearch／PitSearch）。
class WideSearchInput extends StatelessWidget {
  const WideSearchInput({super.key, required this.child});

  /// 放大鏡右邊的內容（輸入框，或「#tag ×」pill＋輸入框）。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.accent, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SvgIcon(
            SearchIcons.search,
            size: 19,
            strokeWidth: 1.9,
            color: t.text3,
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 坑內搜尋的頂列（PitSearch／PitSearchResult 稿）：返回鍵＋寬輸入框，左右邊距 32、上 22。
class WideSearchHeader extends StatelessWidget {
  const WideSearchHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
      child: Row(
        children: [
          Transform.translate(
            offset: const Offset(-10, 0),
            child: InkResponse(
              key: const ValueKey('searchWideBack'),
              radius: 26,
              onTap: () => Navigator.of(context).maybePop(),
              child: Semantics(
                button: true,
                label: context.l10n.commonBack,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SvgIcon(
                      AppIcons.back,
                      color: t.ink,
                      strokeWidth: 1.9,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 返回鍵往左收 10（稿：margin-left -10），輸入框補回這 10。
          const SizedBox(width: 2),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// iPad 的 tag chip：高 38、字 14，後面是次數；[label] 是坑名時（搜尋結果的 tag）改成右側小標。
class WideTagChip extends StatelessWidget {
  const WideTagChip({
    super.key,
    required this.name,
    required this.onTap,
    this.count,
    this.pitLabel,
  });
  final String name;
  final int? count;

  /// 全坑搜尋結果的 tag：右邊的坑名小標（稿：灰底圓角 pill 11.5）。
  final String? pitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: EdgeInsets.fromLTRB(14, 0, pitLabel == null ? 14 : 12, 0),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#$name', style: TextStyle(fontSize: 14, color: t.ink)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontSize: 12, color: t.text4)),
            ],
            if (pitLabel != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  color: t.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pitLabel!,
                  style: TextStyle(fontSize: 11.5, color: t.text2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// iPad 結果的圖片一排 6 格（格間距 4、整排圓角 12 裁切）；[tiles] 最多 6 個，
/// [more] > 0 時第 6 格蓋「+N」。格子大小固定為整排寬度的六分之一，少於 6 張就靠左，不補空格。
class WideThumbRow extends StatelessWidget {
  const WideThumbRow({
    super.key,
    required this.tiles,
    required this.more,
    required this.selection,
    required this.onTap,
    required this.onMore,
  });
  final List<SearchTile> tiles;
  final int more;
  final SearchSelection selection;
  final ValueChanged<SearchTile> onTap;
  final VoidCallback onMore;

  static const columns = 6;
  static const gap = 4.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cell = (c.maxWidth - gap * (columns - 1)) / columns;
        final shown = tiles.take(columns).toList();
        return Align(
          alignment: Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: gap,
              children: [
                for (var i = 0; i < shown.length; i++)
                  SizedBox(
                    width: cell,
                    height: cell,
                    child: SearchTileCell(
                      tile: shown[i],
                      selection: selection,
                      onTap: more > 0 && i == columns - 1
                          ? onMore
                          : () => onTap(shown[i]),
                      overlay: more > 0 && i == columns - 1
                          ? Semantics(
                              button: true,
                              label: context.l10n.ipadsearchMoreSemantics,
                              child: MoreOverlay(more, fontSize: 20),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// iPad 腦洞文字卡：兩欄（間距 10），每張一行標題＋一行內文。
class IdeaCardsGrid extends StatelessWidget {
  const IdeaCardsGrid({
    super.key,
    required this.tiles,
    required this.selection,
    required this.onTap,
  });
  final List<SearchTile> tiles;
  final SearchSelection selection;
  final ValueChanged<SearchTile> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: w,
                child: IdeaResultCard(
                  tile: tile,
                  selection: selection,
                  onTap: () => onTap(tile),
                  wide: true,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 結果頁左邊的直排相冊清單（寬 210，只列有結果的；選中＝深色底，數字在右）。
class WideAlbumNav extends StatelessWidget {
  const WideAlbumNav({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });
  final Map<SearchCategory, int> counts;
  final SearchCategory selected;
  final ValueChanged<SearchCategory> onSelected;

  static const width = 210.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return SizedBox(
      width: width,
      child: ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              l.ipadsearchAlbums,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.text3,
                letterSpacing: 1,
              ),
            ),
          ),
          for (final c in SearchCategory.values)
            if (c == SearchCategory.all || (counts[c] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Semantics(
                  button: true,
                  selected: c == selected,
                  child: GestureDetector(
                    key: ValueKey('searchAlbum-${c.name}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelected(c),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: c == selected ? t.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.label(l),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: c == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: c == selected ? t.surface : t.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${counts[c] ?? 0}',
                            style: TextStyle(
                              fontSize: 13,
                              color: c == selected
                                  ? t.surface.withValues(alpha: .7)
                                  : t.text4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 未加 tag 多選的底部工具列（PitSearchUntagged 稿）：蓋在右側內容區底部，高 64。
/// 「× 已選 N 項｜全選｜加 tag」。
class WideSelectBar extends StatelessWidget {
  const WideSelectBar({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onExit,
    required this.onToggleAll,
    required this.onTag,
  });
  final int count;
  final bool allSelected;
  final VoidCallback onExit;
  final VoidCallback onToggleAll;
  final VoidCallback onTag;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: l.albumCancelSelect,
            child: InkResponse(
              key: const ValueKey('searchSelectExit'),
              radius: 24,
              onTap: onExit,
              child: SizedBox(
                width: 36,
                height: 36,
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.ipadsearchSelectedItems(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            key: const ValueKey('searchSelectAll'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggleAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Text(
                allSelected ? l.commonDeselectAll : l.commonSelectAll,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.accentStrong,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: const ValueKey('searchSelectTag'),
            behavior: HitTestBehavior.opaque,
            onTap: onTag,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgIcon(
                    AlbumIcons.tag,
                    size: 18,
                    strokeWidth: 1.8,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.ipadsearchAddTag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
