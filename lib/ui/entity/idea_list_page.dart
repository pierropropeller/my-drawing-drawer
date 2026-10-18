import '../common/clamped_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/media_widgets.dart';
import '../common/media_mini.dart';
import '../common/empty_state.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../album/wide_layout.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'detail_panes.dart';
import 'idea_form_page.dart';
import 'master_detail.dart';
import '../album/album_view.dart' show ChipRow;
import '../pits/pit_section_tabs.dart';

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
    with HidesNavBar<IdeaListPage>, MasterDetailState<IdeaListPage> {
  /// 寬版列表上方的狀態篩選（全部／未孵／孵化中／已孵）；null＝全部。只在並排時顯示與套用。
  IdeaStatus? _status;

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
      title: context.l10n.ideaListDeleteSelected(_selected.length),
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

  void _openNew() => openIdeaForm(context, pitId: widget.pitId);

  /// 並排時：選中該項（右側顯示詳情）；否則開詳情頁（並記住它，之後拉寬可還原）。
  void _tapItem(String id, bool wide) {
    setState(() => selectedId = id);
    if (!wide) _pushDetail(id);
  }

  /// 開詳情頁（手機／600–839，或由寬變窄時停在詳情）。
  void _pushDetail(String id) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PopWhenWide(
        child: IdeaDetailPage(
          ideaId: id,
          pitId: widget.pitId,
          onTagTap: widget.onTagTap ?? (tid) => _tagTap(tid, fromDetail: true),
        ),
      ),
    ),
  );

  /// 寬版：左邊列表（固定約 400，窄視窗縮一點）＋右邊詳情。
  Widget _splitBody(List<IdeaView> views, Widget listArea) {
    final t = context.tokens;
    final w = MediaQuery.sizeOf(context).width;
    final listW = (w * 0.42).clamp(340.0, 400.0);
    final sel = selectedId;
    final valid = sel != null && views.any((v) => v.idea.id == sel);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listW,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: t.border)),
            ),
            child: Column(
              children: [
                if (!_selecting)
                  ChipRow(
                    options: [
                      (IdeaStatus.open.name, context.l10n.ideaStatusOpen),
                      (
                        IdeaStatus.hatching.name,
                        context.l10n.ideaStatusHatchingShort,
                      ),
                      (
                        IdeaStatus.hatched.name,
                        context.l10n.ideaStatusHatchedShort,
                      ),
                    ],
                    selected: _status?.name,
                    onSelected: (v) => setState(
                      () => _status = v == null
                          ? null
                          : IdeaStatus.values.byName(v),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  ),
                Expanded(child: listArea),
              ],
            ),
          ),
        ),
        Expanded(
          child: valid
              ? IdeaDetailPane(
                  key: ValueKey(sel),
                  pitId: widget.pitId,
                  ideaId: sel,
                  onDeleted: () => setState(() => selectedId = null),
                  onTagTap:
                      widget.onTagTap ?? (id) => _tagTap(id, fromDetail: true),
                )
              : WideEmptyHint(context.l10n.ipadListsIdeaEmpty),
        ),
      ],
    );
  }

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
    final wide = WindowClass.of(context).isWide;
    syncMasterDetail(wide, _pushDetail);
    final allViews =
        ref.watch(ideaViewsProvider((widget.pitId, widget.tagId))).value ??
        const [];
    final views = wide && _status != null
        ? allViews.where((v) => v.status == _status).toList()
        : allViews;
    // 標題列一律顯示全部數量；篩選時符合的數量在篩選列。
    final all = widget.tagId == null
        ? allViews
        : (ref.watch(ideaViewsProvider((widget.pitId, null))).value ??
              allViews);
    final unhatched = all.where((v) => v.status != IdeaStatus.hatched).length;
    final title = pitName == null
        ? context.l10n.pitsIdeas
        : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsIdeas);
    final Widget listArea = views.isEmpty
        ? EmptyState(
            svg: AppIcons.pitIdea,
            text: context.l10n.ideaListEmpty,
            color: t.idea,
            actionLabel: context.l10n.ideaListEmptyAction,
            onAction: _openNew,
          )
        : ContentWidth(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(_selecting ? 16 : 20, 8, 20, 96),
              itemCount: views.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final v = views[i];
                final isSel = _selected.contains(v.idea.id);
                final card = _IdeaCard(
                  view: v,
                  selected: _selecting
                      ? isSel
                      : (wide && selectedId == v.idea.id),
                  selecting: _selecting,
                  onTagTap: _selecting ? null : (widget.onTagTap ?? _tagTap),
                );
                if (!_selecting) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tapItem(v.idea.id, wide),
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
          );
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        floatingActionButton: _selecting || views.isEmpty
            ? null
            : EntityFab(
                label: context.l10n.ideaFormTitleNew,
                onPressed: _openNew,
              ),
        bottomNavigationBar: _selecting
            ? _SelectBar(enabled: _selected.isNotEmpty, onDelete: _delete)
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_selecting)
                SubPageHeader(
                  title: context.l10n.entityConnectSelectedIdea(
                    _selected.length,
                  ),
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
                      child: Text(
                        context.l10n.commonSelectAll,
                        style: const TextStyle(
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
                          ? context.l10n.ideaListCountUnhatched(
                              all.length,
                              unhatched,
                            )
                          : context.l10n.pitsCountIdeas(all.length),
                    ),
                    SearchIconButton(pitId: widget.pitId),
                  ],
                ),
              if (!_selecting)
                PitSectionTabBar(
                  pitId: widget.pitId,
                  selected: PitSection.ideas,
                ),
              if (!_selecting && widget.tagId != null)
                TagFilterBar(
                  pitId: widget.pitId,
                  kind: TaggedKind.idea,
                  tagId: widget.tagId!,
                  countText: context.l10n.pitsCountIdeas(views.length),
                ),
              Expanded(child: wide ? _splitBody(views, listArea) : listArea),
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
                Text(
                  context.l10n.commonDelete,
                  style: TextStyle(color: color, fontSize: 11.5),
                ),
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
            ClampedText(
              idea.body,
              maxLines: 2,
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
                          child: MiniMediaThumb(
                            MediaSource.fromImageRef(im),
                            cacheWidth: 200,
                          ),
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
                fmtMd(idea.date),
                style: TextStyle(color: t.text4, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
