import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/svg_icon.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';
import 'piece_detail_page.dart';
import 'piece_form_page.dart';

enum _Mode { waterfall, grid, nine }

/// 成圖列表（Finished）：瀑布／田字／九宮格切換；顯示互動量；有導覽列。
/// D-043：頂部不放 tag chips，卡片不顯示 tag；[tagId] 只篩選內容（篩選列另有人接）。
class FinishedListPage extends ConsumerStatefulWidget {
  const FinishedListPage({
    super.key,
    required this.pitId,
    this.tagId,
    this.onTagTap,
  });
  final String pitId;

  /// 只列出有這個 tag 的成圖；有值時標題列下多一條「#tag ×」篩選列（D-043）。
  final String? tagId;

  /// 詳情頁點 tag 的處理；省略＝預設導覽（回到本格列表並篩選）。
  final ValueChanged<String>? onTagTap;

  @override
  ConsumerState<FinishedListPage> createState() => _FinishedListPageState();
}

class _FinishedListPageState extends ConsumerState<FinishedListPage> {
  _Mode _mode = _Mode.waterfall;

  /// 新增：先打開相簿選圖，選好再進入新增頁。
  Future<void> _add() async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PieceFormPage(pitId: widget.pitId, initialImages: picked),
      ),
    );
  }

  void _open(PieceView v) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PieceDetailPage(
        pieceId: v.piece.id,
        pitId: widget.pitId,
        onTagTap:
            widget.onTagTap ??
            (id) => onListTagTap(
              context,
              pitId: widget.pitId,
              kind: TaggedKind.piece,
              tagId: id,
              listFiltered: widget.tagId != null,
              fromDetail: true,
            ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pit = ref.watch(pitProvider(widget.pitId)).value;
    final views =
        ref.watch(pieceViewsProvider((widget.pitId, widget.tagId))).value ??
        const [];
    const pad = EdgeInsets.fromLTRB(20, 10, 20, 96);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                SubPageHeader(
                  title: pit == null ? '成圖' : '${pit.name} · 成圖',
                  titleSize: 19,
                  trailing: [
                    SearchIconButton(pitId: widget.pitId),
                    _ModeToggle(
                      mode: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                  ],
                ),
                if (widget.tagId != null)
                  TagFilterBar(
                    pitId: widget.pitId,
                    kind: TaggedKind.piece,
                    tagId: widget.tagId!,
                    countText: '${views.length} 張',
                  ),
                Expanded(
                  child: views.isEmpty
                      ? EmptyState(
                          svg: AppIcons.pitPieceEmpty,
                          text: '還沒有成圖',
                          color: t.piece,
                          actionLabel: '新增',
                          onAction: _add,
                        )
                      : switch (_mode) {
                          _Mode.waterfall => MasonryGridView.count(
                            padding: pad,
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                            itemCount: views.length,
                            itemBuilder: (_, i) => _PieceTile(
                              view: views[i],
                              onTap: () => _open(views[i]),
                              ratio: views[i].images.isEmpty
                                  ? 1
                                  : views[i].images.first.aspect.clamp(
                                      0.5,
                                      2.0,
                                    ),
                            ),
                          ),
                          _Mode.grid => GridView.builder(
                            padding: pad,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  // 方圖＋標題＋互動量
                                  childAspectRatio: 0.76,
                                ),
                            itemCount: views.length,
                            itemBuilder: (_, i) => _PieceTile(
                              view: views[i],
                              onTap: () => _open(views[i]),
                              ratio: 1,
                            ),
                          ),
                          _Mode.nine => GridView.builder(
                            padding: pad,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: views.length,
                            itemBuilder: (_, i) => _NineTile(
                              view: views[i],
                              onTap: () => _open(views[i]),
                            ),
                          ),
                        },
                ),
              ],
            ),
            if (views.isNotEmpty)
              Positioned(
                right: 18,
                bottom: 14,
                child: EntityFab(onPressed: _add, label: '新增成圖'),
              ),
          ],
        ),
      ),
    );
  }
}

/// 右上的版面切換：白底 1px 邊框、圓角 11、三顆 34×32 按鈕，選中＝主色底白圖。
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget btn(_Mode m, String label, String icon, double stroke) {
      final on = mode == m;
      return Semantics(
        button: true,
        label: label,
        selected: on,
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: on ? t.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgIcon(
                icon,
                size: 18,
                strokeWidth: stroke,
                color: on ? Colors.white : t.text4,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          btn(_Mode.waterfall, '瀑布', AppIcons.waterfallView, 1.8),
          btn(_Mode.grid, '田字', AppIcons.gridView, 1.8),
          btn(_Mode.nine, '九宮格', AppIcons.grid3x3, 1.7),
        ],
      ),
    );
  }
}

/// 圖片或圖片佔位（分類底色＋圖片 glyph）。
Widget _pieceImage(BuildContext context, PieceView v, {double glyph = 26}) {
  final t = context.tokens;
  if (v.images.isNotEmpty) {
    return StoredImage(v.images.first.file, cacheWidth: 500);
  }
  return ColoredBox(
    color: t.piece.bg,
    child: Center(
      child: SvgIcon(
        AppIcons.image,
        size: glyph,
        strokeWidth: 1.5,
        color: t.ink.withValues(alpha: .24),
      ),
    ),
  );
}

/// 瀑布／田字的卡：圖（圓角 14）、標題 14/700、愛心＋實際 / 目標。
class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.view,
    required this.onTap,
    required this.ratio,
  });
  final PieceView view;
  final VoidCallback onTap;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = view.piece;
    final reached = p.targetLikes > 0 && p.actualLikes >= p.targetLikes;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: ratio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _pieceImage(context, view),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
            child: Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          // 沒公開發佈的成圖沒有互動量，不顯示愛心列。
          if (p.isPublished)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
              child: Row(
                children: [
                  SvgIcon(
                    AppIcons.heart,
                    size: 15,
                    strokeWidth: reached ? 0 : 1.8,
                    color: t.accent,
                    fill: reached ? _hex(t.accent) : 'none',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${p.actualLikes}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.targetLikes > 0)
                    Text(
                      ' / ${p.targetLikes}',
                      style: TextStyle(fontSize: 11.5, color: t.text2),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 九宮格的格：方圖（圓角 11）、左下白色半透明愛心＋實際互動量。
class _NineTile extends StatelessWidget {
  const _NineTile({required this.view, required this.onTap});
  final PieceView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _pieceImage(context, view, glyph: 22),
              if (view.piece.isPublished)
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        SvgIcon(
                          AppIcons.heart,
                          size: 10,
                          color: t.accent,
                          fill: _hex(t.accent),
                          strokeWidth: 0,
                        ),
                        Text(
                          '${view.piece.actualLikes}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B2622),
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
}
