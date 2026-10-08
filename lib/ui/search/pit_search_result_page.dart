import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../data/search_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/fan_art_preview_page.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../entity/draft_detail_page.dart';
import '../entity/entity_widgets.dart';
import '../entity/idea_detail_page.dart';
import '../entity/piece_detail_page.dart';
import 'search_widgets.dart';
import 'tag_filter_bar.dart';
import 'tagged_list.dart';

/// 坑內搜尋結果（PitSearchResult，D-051）：
/// 分段順序 成圖 → 好看同人圖 → 草稿 → 腦洞；圖片類一排 3 格、第 3 格 +N，
/// 腦洞直向全列、往下捲動分批載入。設計稿沒有畫 `<nav>`，隱藏底部導覽列。
class PitSearchResultPage extends ConsumerStatefulWidget {
  const PitSearchResultPage({
    super.key,
    required this.pitId,
    this.text = '',
    this.tagId,
    this.category = SearchCategory.all,
  });
  final String pitId;
  final String text;
  final String? tagId;
  final SearchCategory category;

  /// 腦洞每批載入的數量。
  static const ideaBatch = 20;

  @override
  ConsumerState<PitSearchResultPage> createState() =>
      _PitSearchResultPageState();
}

class _PitSearchResultPageState extends ConsumerState<PitSearchResultPage>
    with HidesNavBar<PitSearchResultPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  late String _text = widget.text;
  late String? _tagId = widget.tagId;
  late SearchCategory _category = widget.category;
  int _ideaShown = PitSearchResultPage.ideaBatch;

  /// 一次捲動期間只載入一批：等新一批排版完、捲動範圍更新後才會再載入。
  bool _batchPending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery({String? text, Object? tagId = _keep}) {
    setState(() {
      if (text != null) _text = text;
      if (!identical(tagId, _keep)) _tagId = tagId as String?;
      _ideaShown = PitSearchResultPage.ideaBatch;
    });
  }

  static const _keep = Object();

  void _clearTag() {
    if (_text.trim().isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    _setQuery(tagId: null);
  }

  /// 詳情頁點 tag：離開搜尋，進該格的篩選列表（列表有導覽列，搜尋頁沒有）。
  void _tagTap(TaggedKind kind, String tagId) =>
      openTaggedList(context, widget.pitId, kind, tagId, leaveSearch: true);

  /// 點「+N」：離開搜尋，進該格列表並帶同一個 tag；
  /// 純文字搜尋沒有 tag 可帶，開完整列表。
  void _more(TaggedKind kind) =>
      openTaggedList(context, widget.pitId, kind, _tagId, leaveSearch: true);

  void _push(Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kSearchFlowRoute),
      builder: (_) => page,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name ?? '';
    final tags = ref.watch(tagsProvider(widget.pitId)).value ?? const [];
    final tagName = tags.where((e) => e.id == _tagId).firstOrNull?.name ?? '';
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'fan'))).value ?? const [];
    final res =
        ref
            .watch(pitSearchProvider((widget.pitId, _text.trim(), _tagId)))
            .value ??
        PitSearchResult.empty;
    bool show(SearchCategory c) =>
        _category == SearchCategory.all || _category == c;

    final slivers = <Widget>[];
    void section(Widget w) => slivers.add(SliverToBoxAdapter(child: w));

    if (show(SearchCategory.piece) && !res.pieces.isEmpty) {
      section(
        _ImageSection(
          title: context.l10n.searchCategoryPiece,
          total: res.pieces.total,
          files: [for (final v in res.pieces.items) v.images.firstOrNull?.file],
          more: res.pieces.more,
          onTap: (i) => _push(
            PieceDetailPage(
              pieceId: res.pieces.items[i].piece.id,
              pitId: widget.pitId,
              onTagTap: (id) => _tagTap(TaggedKind.piece, id),
            ),
          ),
          onMore: () => _more(TaggedKind.piece),
        ),
      );
    }
    if (show(SearchCategory.fan) && !res.fanArts.isEmpty) {
      final names = {for (final g in groups) g.id: g.name};
      final items = [
        for (final f in res.fanArts.items)
          AlbumImage(
            id: f.id,
            file: f.imageFile,
            width: f.width,
            height: f.height,
            kind: AlbumKind.fanArt,
            author: f.author,
            groupName: names[f.groupId],
            groupId: f.groupId,
            createdAt: f.createdAt,
          ),
      ];
      section(
        _ImageSection(
          title: context.l10n.pitsFanArt,
          total: res.fanArts.total,
          files: [for (final f in res.fanArts.items) f.imageFile],
          more: res.fanArts.more,
          onTap: (i) => _push(
            FanArtPreviewPage(
              pitId: widget.pitId,
              images: items,
              initialIndex: i,
              onTagTap: (id) => _tagTap(TaggedKind.fan, id),
            ),
          ),
          onMore: () => _more(TaggedKind.fan),
        ),
      );
    }
    if (show(SearchCategory.draft) && !res.drafts.isEmpty) {
      section(
        _ImageSection(
          title: context.l10n.searchCategoryDraft,
          total: res.drafts.total,
          files: [for (final v in res.drafts.items) v.images.firstOrNull?.file],
          more: res.drafts.more,
          onTap: (i) => _push(
            DraftDetailPage(
              draftId: res.drafts.items[i].draft.id,
              pitId: widget.pitId,
              onTagTap: (id) => _tagTap(TaggedKind.draft, id),
            ),
          ),
          onMore: () => _more(TaggedKind.draft),
        ),
      );
    }
    if (show(SearchCategory.idea) && !res.ideas.isEmpty) {
      final shown = res.ideas.items.length < _ideaShown
          ? res.ideas.items.length
          : _ideaShown;
      section(_SectionHeader(context.l10n.searchCategoryIdea, res.ideas.total));
      slivers.add(
        SliverList.separated(
          itemCount: shown,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final v = res.ideas.items[i];
            return _IdeaResultCard(
              view: v,
              onTap: () => _push(
                IdeaDetailPage(
                  ideaId: v.idea.id,
                  pitId: widget.pitId,
                  onTagTap: (id) => _tagTap(TaggedKind.idea, id),
                ),
              ),
            );
          },
        ),
      );
      if (shown < res.ideas.items.length) {
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
                    if (_tagId != null) ...[
                      TagFilterPill(name: tagName, onClear: _clearTag),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: SearchField(
                        controller: _controller,
                        hint: _tagId == null
                            ? context.l10n.searchHint(pitName)
                            : '',
                        onChanged: (v) => _setQuery(text: v),
                      ),
                    ),
                  ],
                ),
              ),
              SearchCategoryChips(
                selected: _category,
                onSelected: (c) => setState(() => _category = c),
                counts: {
                  SearchCategory.all: res.total,
                  SearchCategory.piece: res.pieces.total,
                  SearchCategory.fan: res.fanArts.total,
                  SearchCategory.draft: res.drafts.total,
                  SearchCategory.idea: res.ideas.total,
                },
              ),
              Expanded(
                child: slivers.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.searchNoResults,
                          style: TextStyle(color: t.text3, fontSize: 14),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          // 接近底部時多載入一批腦洞。
                          if (!_batchPending &&
                              n.metrics.extentAfter < 400 &&
                              _ideaShown < res.ideas.items.length) {
                            _batchPending = true;
                            setState(
                              () => _ideaShown += PitSearchResultPage.ideaBatch,
                            );
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
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 段頭：粗體名稱＋淡色數字（沒有「全部」）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.total);
  final String title;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text.rich(
        TextSpan(
          text: title,
          children: [
            TextSpan(
              text: '  $total',
              style: TextStyle(color: t.text4, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: t.ink,
        ),
      ),
    );
  }
}

/// 圖片類的一段：草稿多圖卡樣式，一排 3 格正方形、間距 4、外框圓角 10；
/// 超過 3 筆時第 3 格蓋深色層寫「+N」，點它進該格列表。
class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.title,
    required this.total,
    required this.files,
    required this.more,
    required this.onTap,
    required this.onMore,
  });
  final String title;
  final int total;

  /// 前 3 筆的縮圖檔名（null＝沒有圖，顯示佔位）。
  final List<String?> files;
  final int more;
  final ValueChanged<int> onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    Widget cell(int i) {
      final file = files[i];
      final isMore = more > 0 && i == 2;
      return AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: isMore ? onMore : () => onTap(i),
          child: Stack(
            fit: StackFit.expand,
            children: [
              file == null
                  ? const ImagePlaceholder()
                  : StoredImage(file, cacheWidth: 300),
              if (isMore)
                Container(
                  color: const Color(0x802B2622),
                  alignment: Alignment.center,
                  child: Text(
                    '+$more',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title, total),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            spacing: 4,
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: i < files.length ? cell(i) : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 腦洞結果卡：標題＋內文一行（artboard 的白底圓角 16 卡）。
class _IdeaResultCard extends StatelessWidget {
  const _IdeaResultCard({required this.view, required this.onTap});
  final IdeaView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = view.idea.body.replaceAll('\n', ' ');
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.borderCard),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              view.idea.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            if (body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
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
    );
  }
}
