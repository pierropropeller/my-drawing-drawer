import 'scroll_back.dart';
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
import '../common/swipe_pager.dart';
import '../common/window_class.dart';
import '../album/wide_layout.dart';
import '../search/tagged_list.dart';
import 'entity_widgets.dart';
import 'idea_detail_page.dart';
import 'detail_panes.dart';
import 'idea_form_page.dart';
import 'master_detail.dart';
import '../album/album_view.dart' show ChipRow;
import '../pits/pit_section_tabs.dart';
import '../common/top_toast.dart' show BottomInsetAnchor;

/// 我的腦洞：卡片顯示標題、狀態、內文兩行、配圖、tag、日期；長按多選（只有刪除）。
/// 瀏覽狀態有底部導覽列；多選時隱藏（IdeaSelect）。
class IdeaListPage extends ConsumerStatefulWidget {
  const IdeaListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<IdeaListPage> createState() => _IdeaListPageState();
}

class _IdeaListPageState extends ConsumerState<IdeaListPage>
    with HidesNavBar<IdeaListPage>, MasterDetailState<IdeaListPage> {
  /// 寬版列表上方的狀態篩選（全部／未孵／孵化中／已孵）；null＝全部。只在並排時顯示與套用。
  IdeaStatus? _status;

  bool _selecting = false;
  final Set<String> _selected = {};

  /// 左右滑的小數頁碼，狀態 chips 的深色底跟著它滑（D-118）。
  late final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

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
      title: context.l10n.trashDeleteItemsTitle(_selected.length),
      toTrash: true,
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
  void _tapItem(String id, bool wide, List<String> order) {
    setState(() => selectedId = id);
    _order = order;
    if (!wide) _pushDetail(id);
  }

  /// 開詳情時那個列表的次序（詳情頁左右滑換上／下篇，D-122）。
  List<String>? _order;

  /// 開詳情頁（手機／600–839，或由寬變窄時停在詳情）。
  void _pushDetail(String id) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          builder: (_) => PopWhenWide(
            child: IdeaDetailPage(
              ideaId: id,
              pitId: widget.pitId,
              order: _order,
              // 記住最後看的那一篇（拉寬後右邊顯示它）。
              onShown: (id) {
                if (mounted) setState(() => selectedId = id);
              },
            ),
          ),
        ),
      )
      .then((_) {
        // 返回列表時捲到最後看的那一篇（D-122）。
        final last = selectedId;
        if (mounted && last != null) _anchors.reveal(last, _order ?? const []);
      });

  final _anchors = ScrollBackAnchors();

  /// 寬版：左邊列表（固定約 400，窄視窗縮一點）＋右邊詳情。
  Widget _splitBody(
    List<IdeaView> views,
    Widget Function(IdeaStatus? status) listFor,
  ) {
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
                    progress: _progress,
                    onSelected: (v) => setState(
                      () => _status = v == null
                          ? null
                          : IdeaStatus.values.byName(v),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  ),
                Expanded(
                  // 左右滑動切換狀態 chip（全部 → 各狀態，不循環），內容跟著手指走（D-118）；多選中不作用。
                  child: SwipePager<IdeaStatus?>(
                    enabled: !_selecting,
                    order: const [
                      null,
                      IdeaStatus.open,
                      IdeaStatus.hatching,
                      IdeaStatus.hatched,
                    ],
                    current: _status,
                    progress: _progress,
                    onChanged: (v) => setState(() => _status = v),
                    itemBuilder: (context, st) => listFor(st),
                  ),
                ),
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
                )
              : WideEmptyHint(context.l10n.ipadListsIdeaEmpty),
        ),
      ],
    );
  }

  /// 卡片點 tag：進該坑的搜尋結果頁並帶上這個 tag（D-107）。
  void _tagTap(String id) => openTagSearch(context, widget.pitId, id);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final wide = WindowClass.of(context).isWide;
    syncMasterDetail(wide, _pushDetail);
    final allViews =
        ref.watch(ideaViewsProvider((widget.pitId, null))).value ?? const [];
    final views = wide && _status != null
        ? allViews.where((v) => v.status == _status).toList()
        : allViews;
    final all = allViews;
    final unhatched = all.where((v) => v.status != IdeaStatus.hatched).length;
    final title = pitName == null
        ? context.l10n.pitsIdeas
        : context.l10n.albumTitleWithPit(pitName, context.l10n.pitsIdeas);
    Widget listOf(List<IdeaView> views) => views.isEmpty
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
                final card = _anchors.wrap(
                  v.idea.id,
                  _IdeaCard(
                    view: v,
                    selected: _selecting
                        ? isSel
                        : (wide && selectedId == v.idea.id),
                    selecting: _selecting,
                    onTagTap: _selecting ? null : _tagTap,
                  ),
                );
                if (!_selecting) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _tapItem(v.idea.id, wide, [
                      for (final x in views) x.idea.id,
                    ]),
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
              Expanded(
                child: wide
                    ? _splitBody(
                        views,
                        (st) => listOf(
                          st == null
                              ? allViews
                              : allViews.where((v) => v.status == st).toList(),
                        ),
                      )
                    : listOf(views),
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
    return BottomInsetAnchor(
      child: Container(
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
              // 沒有標題（D-129）：內文頂上標題的位置，普通字重 14、最多兩行，下面不再重複內文。
              Expanded(
                child: idea.title.trim().isNotEmpty
                    ? Text(
                        idea.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      )
                    : ClampedText(
                        idea.body,
                        maxLines: 2,
                        style: TextStyle(
                          color: t.ink,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              IdeaStatusChip(view),
            ],
          ),
          if (idea.title.trim().isNotEmpty && idea.body.isNotEmpty) ...[
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
