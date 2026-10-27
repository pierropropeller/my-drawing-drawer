import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/batch_tag_queries.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../entity/entity_name.dart';
import '../../data/entity_queries.dart';
import '../../data/search_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/fan_art_preview_page.dart';
import '../album/image_masonry.dart' show SelectMark;
import '../album/image_preview_page.dart';
import '../common/media_widgets.dart';
import '../entity/draft_detail_page.dart';
import '../entity/entity_widgets.dart' show ImagePlaceholder;
import '../entity/idea_detail_page.dart';
import '../entity/piece_detail_page.dart';
import '../pits/pit_oshi_entry.dart';
import 'tagged_list.dart';

/// 搜尋結果裡一格（或一張卡）的資料：種類、項目 id、縮圖（腦洞沒有）。
/// PitSearchResult、PitSearchResultTab、GlobalSearchResult 共用。
class SearchTile {
  const SearchTile({
    required this.section,
    required this.id,
    required this.index,
    this.media,
    this.idea,
  });

  final PitSearchSection section;

  /// 項目 id（成圖／草稿／腦洞／推活＝該筆的 id；官方圖／同人圖＝圖片列 id）。
  final String id;

  /// 在該段結果裡的位置（開預覽頁時當 initialIndex）。
  final int index;
  final MediaSource? media;
  final IdeaView? idea;

  TagTarget get target => switch (section) {
    PitSearchSection.pieces => TagTarget.piece,
    PitSearchSection.official => TagTarget.official,
    PitSearchSection.fanArts => TagTarget.fanArt,
    PitSearchSection.oshi => TagTarget.oshi,
    PitSearchSection.drafts => TagTarget.draft,
    PitSearchSection.ideas => TagTarget.idea,
  };

  /// 多選時用的鍵（字串形式的 [TagRef]）。
  String get key => TagRef(target, id).key;

  bool get isImage => section != PitSearchSection.ideas;
}

MediaSource? _firstMedia(List<ImageRef> images) =>
    images.isEmpty ? null : MediaSource.fromImageRef(images.first);

/// [res] 裡 [section] 這一段目前載入的所有格子（圖片類預設只有前 3 筆；單一相冊頁是全部）。
List<SearchTile> searchTilesOf(PitSearchResult res, PitSearchSection section) {
  SearchTile at(int i, String id, {MediaSource? media, IdeaView? idea}) =>
      SearchTile(section: section, id: id, index: i, media: media, idea: idea);
  switch (section) {
    case PitSearchSection.pieces:
      return [
        for (final (i, v) in res.pieces.items.indexed)
          at(i, v.piece.id, media: _firstMedia(v.images)),
      ];
    case PitSearchSection.official:
      return [
        for (final (i, o) in res.official.items.indexed)
          at(
            i,
            o.id,
            media: MediaSource.row(
              file: o.imageFile,
              kind: o.kind,
              durationMs: o.durationMs,
              posterFile: o.posterFile,
            ),
          ),
      ];
    case PitSearchSection.fanArts:
      return [
        for (final (i, f) in res.fanArts.items.indexed)
          at(
            i,
            f.id,
            media: MediaSource.row(
              file: f.imageFile,
              kind: f.kind,
              durationMs: f.durationMs,
              posterFile: f.posterFile,
            ),
          ),
      ];
    case PitSearchSection.oshi:
      return [
        for (final (i, v) in res.oshi.items.indexed)
          at(i, v.record.id, media: MediaSource.fromImageRef(v.cover)),
      ];
    case PitSearchSection.drafts:
      return [
        for (final (i, v) in res.drafts.items.indexed)
          at(i, v.draft.id, media: _firstMedia(v.images)),
      ];
    case PitSearchSection.ideas:
      return [
        for (final (i, v) in res.ideas.items.indexed) at(i, v.idea.id, idea: v),
      ];
  }
}

/// 打開搜尋結果的一筆：成圖／摸魚／腦洞進詳情，官方圖、同人圖進預覽頁（可左右滑同一段的其他張），
/// 推活進推活詳情。全部都掛在搜尋流程的 route 名稱下（隱藏導覽列）。
/// 詳情裡點 tag 由各頁自己處理（進該坑的搜尋結果頁，D-107）。
class SearchOpener {
  SearchOpener(
    this.context, {
    required this.pitId,
    required this.res,
    this.fanGroupNames = const {},
    this.officialGroupNames = const {},
  });

  final BuildContext context;
  final String pitId;
  final PitSearchResult res;
  final Map<String, String> fanGroupNames;
  final Map<String, String> officialGroupNames;

  void _push(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kSearchFlowRoute),
      builder: (_) => page,
    ),
  );

  void open(PitSearchSection section, int i) {
    switch (section) {
      case PitSearchSection.pieces:
        _push(
          PieceDetailPage(
            pieceId: res.pieces.items[i].piece.id,
            pitId: pitId,
            order: [for (final x in res.pieces.items) x.piece.id],
          ),
        );
      case PitSearchSection.official:
        _push(
          ImagePreviewPage(
            pitId: pitId,
            images: [
              for (final o in res.official.items)
                AlbumImage(
                  id: o.id,
                  file: o.imageFile,
                  width: o.width,
                  height: o.height,
                  kind: AlbumKind.official,
                  groupName: officialGroupNames[o.groupId],
                  groupId: o.groupId,
                  createdAt: o.createdAt,
                  mediaKind: o.kind,
                  durationMs: o.durationMs,
                  posterFile: o.posterFile,
                ),
            ],
            initialIndex: i,
          ),
        );
      case PitSearchSection.fanArts:
        _push(
          FanArtPreviewPage(
            pitId: pitId,
            images: [
              for (final f in res.fanArts.items)
                AlbumImage(
                  id: f.id,
                  file: f.imageFile,
                  width: f.width,
                  height: f.height,
                  kind: AlbumKind.fanArt,
                  author: f.author,
                  groupName: fanGroupNames[f.groupId],
                  groupId: f.groupId,
                  createdAt: f.createdAt,
                  mediaKind: f.kind,
                  durationMs: f.durationMs,
                  posterFile: f.posterFile,
                ),
            ],
            initialIndex: i,
          ),
        );
      case PitSearchSection.oshi:
        openOshiDetail(
          context,
          pitId,
          res.oshi.items[i].record.id,
          inSearchFlow: true,
          order: [for (final x in res.oshi.items) x.record.id],
        );
      case PitSearchSection.drafts:
        _push(
          DraftDetailPage(
            draftId: res.drafts.items[i].draft.id,
            pitId: pitId,
            order: [for (final x in res.drafts.items) x.draft.id],
          ),
        );
      case PitSearchSection.ideas:
        _push(
          IdeaDetailPage(
            ideaId: res.ideas.items[i].idea.id,
            pitId: pitId,
            order: [for (final x in res.ideas.items) x.idea.id],
          ),
        );
    }
  }
}

/// 一個坑裡官方圖、同人圖的分組名稱（預覽頁的說明用）。
({Map<String, String> fan, Map<String, String> official}) watchGroupNames(
  WidgetRef ref,
  String pitId,
) {
  final fan = ref.watch(groupsProvider((pitId, 'fan'))).value ?? const [];
  final official =
      ref.watch(groupsProvider((pitId, 'official'))).value ?? const [];
  return (
    fan: {for (final g in fan) g.id: g.name},
    official: {for (final g in official) g.id: g.name},
  );
}

/// 多選狀態：選取的 [SearchTile.key]；null＝不在多選模式。
class SearchSelection {
  const SearchSelection({
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onStart,
  });
  final bool selecting;
  final Set<String> selected;

  /// 多選中點一下：切換選取。
  final ValueChanged<SearchTile> onToggle;

  /// 長按：進入多選並選取這一筆。null＝這個畫面不支援多選。
  final ValueChanged<SearchTile>? onStart;

  static const none = SearchSelection(
    selecting: false,
    selected: {},
    onToggle: _noop,
    onStart: null,
  );
  static void _noop(SearchTile _) {}
}

/// 圖片格：縮圖一律走 [MediaThumb]（敏感內容的模糊與標記由共用元件處理）；
/// 多選中右上角有選取圈。
class SearchTileCell extends StatelessWidget {
  const SearchTileCell({
    super.key,
    required this.tile,
    required this.selection,
    required this.onTap,
    this.overlay,
    this.cacheWidth = 300,
  });
  final SearchTile tile;
  final SearchSelection selection;
  final VoidCallback onTap;

  /// 蓋在縮圖上的內容（第 3 格的「+N」）。
  final Widget? overlay;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final m = tile.media;
    final isSelected = selection.selected.contains(tile.key);
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selection.selecting ? () => selection.onToggle(tile) : onTap,
        onLongPress: selection.onStart == null || selection.selecting
            ? null
            : () => selection.onStart!(tile),
        child: Stack(
          fit: StackFit.expand,
          children: [
            m == null
                ? const ImagePlaceholder()
                : MediaThumb(m, cacheWidth: cacheWidth),
            if (overlay != null && !selection.selecting) overlay!,
            if (selection.selecting)
              Positioned(
                top: 6,
                right: 6,
                child: SelectMark(selected: isSelected),
              ),
          ],
        ),
      ),
    );
  }
}

/// 腦洞結果卡：標題＋內文一行（artboard 的白底圓角 16 卡）。
class IdeaResultCard extends StatelessWidget {
  const IdeaResultCard({
    super.key,
    required this.tile,
    required this.selection,
    required this.onTap,
    this.wide = false,
  });
  final SearchTile tile;
  final SearchSelection selection;
  final VoidCallback onTap;

  /// iPad（P-028、P-029）：內距 16×13、標題 15、內文 13 距標題 4。
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final view = tile.idea!;
    final body = view.idea.body.replaceAll('\n', ' ');
    final isSelected = selection.selected.contains(tile.key);
    return GestureDetector(
      onTap: selection.selecting ? () => selection.onToggle(tile) : onTap,
      onLongPress: selection.onStart == null || selection.selecting
          ? null
          : () => selection.onStart!(tile),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(
            color: isSelected && selection.selecting ? t.accent : t.borderCard,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entityDisplayName(
                      context.l10n,
                      title: view.idea.title,
                      body: view.idea.body,
                      date: view.idea.date,
                      kind: GoalKind.idea,
                    ),
                    style: TextStyle(
                      fontSize: wide ? 15 : 14.5,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  if (body.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: wide ? 4 : 3),
                      child: Text(
                        body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.text2),
                      ),
                    ),
                ],
              ),
            ),
            if (selection.selecting) ...[
              const SizedBox(width: 10),
              SelectMark(selected: isSelected),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「+N」蓋層（第 3 格）。
class MoreOverlay extends StatelessWidget {
  const MoreOverlay(this.more, {super.key, this.fontSize = 18});
  final int more;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0x802B2622),
    alignment: Alignment.center,
    child: Text(
      '+$more',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 一排 3 格（草稿多圖卡樣式，格間距 4、外框圓角 10）。[tiles] 最多 3 個；
/// [more] > 0 時第 3 格蓋「+N」，點它呼叫 [onMore]。
/// 少於 3 筆（D-061，PitSearchFew）：照實際張數放、不補空格、不顯示「+N」，每張各自圓角 10。
class SearchThumbRow extends StatelessWidget {
  const SearchThumbRow({
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

  @override
  Widget build(BuildContext context) {
    final few = tiles.length < 3;
    Widget cell(int i) {
      final isMore = more > 0 && i == 2;
      return SearchTileCell(
        tile: tiles[i],
        selection: selection,
        onTap: isMore ? onMore : () => onTap(tiles[i]),
        overlay: isMore ? MoreOverlay(more) : null,
      );
    }

    final row = Row(
      spacing: 4,
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: i < tiles.length
                ? (few
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: cell(i),
                        )
                      : cell(i))
                : const SizedBox.shrink(),
          ),
      ],
    );
    return few
        ? row
        : ClipRRect(borderRadius: BorderRadius.circular(10), child: row);
  }
}
