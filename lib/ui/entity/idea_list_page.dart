import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'idea_form_page.dart';

/// 我的腦洞：卡片顯示標題、狀態、內文兩行、配圖、tag、日期；長按多選（只有刪除）。
/// 瀏覽狀態有底部導覽列；多選時隱藏（IdeaSelect）。
class IdeaListPage extends ConsumerStatefulWidget {
  const IdeaListPage({
    super.key,
    required this.pitId,
    this.tagId,
    this.onTagTap,
  });
  final String pitId;

  /// 只顯示有這個 tag 的腦洞；有值時標題列下多一條「#tag ×」篩選列（D-043）。
  final String? tagId;

  /// 點 tag 的回呼；省略＝預設導覽（回到本格列表並篩選）。
  final void Function(String tagId)? onTagTap;

  @override
  ConsumerState<IdeaListPage> createState() => _IdeaListPageState();
}

class _IdeaListPageState extends ConsumerState<IdeaListPage>
    with HidesNavBar<IdeaListPage> {
  bool _selecting = false;
  final Set<String> _selected = {};

  // 瀏覽時有導覽列，進入多選才隱藏。
  @override
  bool get hidesNavBarOnOpen => false;

  void _exit() {
    setNavBarHidden(false);
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _delete() async {
    final ok = await confirmDelete(
      context,
      title: '刪除 ${_selected.length} 個腦洞？',
    );
    if (!ok || !mounted) return;
    await ref.read(databaseProvider).deleteIdeas(_selected);
    if (mounted) _exit();
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      if (_selected.isEmpty) _selecting = false;
    });
    if (!_selecting) setNavBarHidden(false);
  }

  void _openNew() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => IdeaFormPage(pitId: widget.pitId)),
  );

  /// 卡片或詳情頁點 tag 的預設處理（D-043）。
  void _tagTap(String id, {bool fromDetail = false}) => onListTagTap(
    context,
    pitId: widget.pitId,
    kind: TaggedKind.idea,
    tagId: id,
    listFiltered: widget.tagId != null,
    fromDetail: fromDetail,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final views =
        ref.watch(ideaViewsProvider((widget.pitId, widget.tagId))).value ??
        const [];
    // 標題列一律顯示全部數量；篩選時符合的數量在篩選列。
    final all = widget.tagId == null
        ? views
        : (ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? views);
    final unhatched = all.where((v) => v.status != IdeaStatus.hatched).length;
    final title = pitName == null ? '我的腦洞' : '$pitName · 我的腦洞';
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        floatingActionButton: _selecting || views.isEmpty
            ? null
            : EntityFab(label: '新增腦洞', onPressed: _openNew),
        bottomNavigationBar: _selecting
            ? _SelectBar(enabled: _selected.isNotEmpty, onDelete: _delete)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_selecting)
                SubPageHeader(
                  title: '已選 ${_selected.length} 個',
                  leadingIcon: AppIcons.closeX,
                  leadingSize: 22,
                  leadingStroke: 2,
                  onBack: _exit,
                  trailing: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selected.length == views.length) {
                            _selected.clear();
                            _selecting = false;
                          } else {
                            _selected.addAll(views.map((v) => v.idea.id));
                          }
                        });
                        if (!_selecting) setNavBarHidden(false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: t.piece.fg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        '全選',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                SubPageHeader(
                  title: title,
                  trailing: [
                    HeaderCount(
                      unhatched > 0
                          ? '${all.length} 個 · $unhatched 未孵'
                          : '${all.length} 個',
                    ),
                    SearchIconButton(pitId: widget.pitId),
                  ],
                ),
              if (!_selecting && widget.tagId != null)
                TagFilterBar(
                  pitId: widget.pitId,
                  kind: TaggedKind.idea,
                  tagId: widget.tagId!,
                  countText: '${views.length} 個',
                ),
              Expanded(
                child: views.isEmpty
                    ? EmptyState(
                        svg: AppIcons.pitIdea,
                        text: '還沒有腦洞',
                        color: t.idea,
                        actionLabel: '記下第一個腦洞',
                        onAction: _openNew,
                      )
                    : ContentWidth(
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            _selecting ? 16 : 20,
                            8,
                            20,
                            96,
                          ),
                          itemCount: views.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final v = views[i];
                            final isSel = _selected.contains(v.idea.id);
                            final card = _IdeaCard(
                              view: v,
                              selected: isSel,
                              selecting: _selecting,
                              onTagTap: _selecting
                                  ? null
                                  : (widget.onTagTap ?? _tagTap),
                            );
                            if (!_selecting) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => IdeaDetailPage(
                                      ideaId: v.idea.id,
                                      pitId: widget.pitId,
                                      onTagTap:
                                          widget.onTagTap ??
                                          (id) => _tagTap(id, fromDetail: true),
                                    ),
                                  ),
                                ),
                                onLongPress: () {
                                  setNavBarHidden(true);
                                  setState(() {
                                    _selecting = true;
                                    _selected.add(v.idea.id);
                                  });
                                },
                                child: card,
                              );
                            }
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _toggle(v.idea.id),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: SelectDot(isSel),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: card),
                                ],
                              ),
                            );
                          },
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

/// 選取模式底部：只有「刪除」。
class _SelectBar extends StatelessWidget {
  const _SelectBar({required this.enabled, required this.onDelete});
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = enabled ? t.danger : t.danger.withValues(alpha: 0.4);
    return Container(
      decoration: BoxDecoration(
        color: t.nav,
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: enabled ? onDelete : null,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgIcon(AppIcons.trash, size: 22, color: color),
                const SizedBox(height: 4),
                Text('刪除', style: TextStyle(color: color, fontSize: 11.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.view,
    required this.selected,
    required this.selecting,
    this.onTagTap,
  });
  final IdeaView view;
  final bool selected;
  final bool selecting;
  final void Function(String tagId)? onTagTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final idea = view.idea;
    return EntityCard(
      selected: selected,
      selecting: selecting,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  idea.title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IdeaStatusChip(view),
            ],
          ),
          if (idea.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              idea.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.text2, fontSize: 13, height: 1.55),
            ),
          ],
          if (view.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final im in view.images)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 54,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: StoredImage(im.file, cacheWidth: 200),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: TagPills(view.tags, onTagTap: onTagTap)),
              const SizedBox(width: 6),
              Text(
                fmtMd(idea.createdAt),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
