import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/oshi_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart' show confirmDelete;
import '../album/album_view.dart' show ChipRow, ChipRowManageButton;
import '../album/image_masonry.dart' show SelectMark;
import '../album/group_manage_page.dart';
import '../common/drag_select.dart';
import '../common/empty_state.dart';
import '../common/media_widgets.dart';
import '../common/nav_bar_hidden.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart';
import '../entity/entity_widgets.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'oshi_detail_page.dart';
import 'oshi_form_page.dart';
import 'oshi_group_sheet.dart';
import 'oshi_icons.dart';
import 'oshi_select_actions.dart';
import 'oshi_select_bar.dart';
import 'oshi_selection.dart';
import 'oshi_widgets.dart';

/// 推活的兩種佈局，記在本機設定（跟裝置走）。
enum OshiLayout { timeline, grid }

const _kLayoutKey = 'oshiLayout';

/// 推活列表（OshiTimeline／OshiGrid）：時間軸（預設）或網格，分組 pills，右上搜尋。
/// 有導覽列（瀏覽用的頁面）。[tagId] 不為 null 時是 tag 篩選狀態（D-065）。
class OshiListPage extends ConsumerStatefulWidget {
  const OshiListPage({super.key, required this.pitId, this.tagId});
  final String pitId;
  final String? tagId;

  @override
  ConsumerState<OshiListPage> createState() => _OshiListPageState();
}

class _OshiListPageState extends ConsumerState<OshiListPage>
    with HidesNavBar<OshiListPage> {
  // 瀏覽時有導覽列；進入多選才隱藏（build 時依 _sel.active 同步）。
  @override
  bool get hidesNavBarOnOpen => false;

  String? _groupId;
  late OshiLayout _layout = _readLayout();
  final _sel = OshiSelection();

  OshiLayout _readLayout() {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs?.getString(_kLayoutKey) == 'grid'
        ? OshiLayout.grid
        : OshiLayout.timeline;
  }

  @override
  void initState() {
    super.initState();
    _sel.addListener(_onSelection);
    // 從舊版同步進來的坑沒有推活分組，進來時補一次預設分組（只在從沒有過時才建立）。
    ref.read(databaseProvider).ensureOshiGroups(widget.pitId);
  }

  void _onSelection() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sel.dispose();
    super.dispose();
  }

  void _setLayout(OshiLayout v) {
    setState(() => _layout = v);
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kLayoutKey, v == OshiLayout.grid ? 'grid' : 'timeline');
  }

  /// 新增：先打開相簿選圖，選好再進入新增頁（同其他列表）。
  Future<void> _add(String? groupId) async {
    final picked = await ref.read(imagePickerProvider)(context);
    if (picked.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OshiFormPage(
          pitId: widget.pitId,
          initialImages: [for (final x in picked) x.path],
          initialGroupId: groupId,
        ),
      ),
    );
  }

  /// 點一筆：多選中＝切換選取；否則開詳情。
  void _tap(OshiRecordView v) {
    if (_sel.active) {
      _sel.toggle(v.record.id);
    } else {
      _open(v);
    }
  }

  List<OshiRecordView> _picked(List<OshiRecordView> views) => [
    for (final v in views)
      if (_sel.isSelected(v.record.id)) v,
  ];

  Future<void> _group(List<OshiRecordView> picked) async {
    if (picked.isEmpty) return;
    final common = commonOshiGroup(picked);
    final choice = await showOshiGroupSheet(
      context,
      pitId: widget.pitId,
      count: picked.length,
      initial: common.uniform ? OshiGroupChoice(common.groupId) : null,
    );
    if (choice == null || !mounted) return;
    await OshiSelectActions(ref.read(databaseProvider))
        .setGroup(picked.map((v) => v.record.id), choice.groupId);
    if (mounted) _sel.exit();
  }

  Future<void> _tag(List<OshiRecordView> picked) async {
    if (picked.isEmpty) return;
    final applied = await showOshiTagSheet(
      context,
      pitId: widget.pitId,
      ids: [for (final v in picked) v.record.id],
    );
    if (applied == true && mounted) _sel.exit();
  }

  Future<void> _delete(List<OshiRecordView> picked) async {
    if (picked.isEmpty) return;
    final ok = await confirmDelete(
      context,
      title: context.l10n.oshiDeleteSelectedTitle(picked.length),
    );
    if (!ok || !mounted) return;
    await OshiSelectActions(ref.read(databaseProvider))
        .delete(picked.map((v) => v.record.id));
    if (mounted) _sel.exit();
  }

  void _open(OshiRecordView v) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OshiDetailPage(
        pitId: widget.pitId,
        recordId: v.record.id,
        listFiltered: widget.tagId != null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'oshi'))).value ?? const [];
    // 篩選中的分組被刪除時退回「全部」。
    final groupId = groups.any((g) => g.id == _groupId) ? _groupId : null;
    final filtered = widget.tagId != null;
    // 標題列一律顯示全部筆數；篩選時符合的筆數在篩選列。
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.oshi ?? 0;
    final views =
        ref
            .watch(oshiRecordsProvider((widget.pitId, groupId, widget.tagId)))
            .value ??
        const [];
    final fullyEmpty = total == 0 && views.isEmpty;
    final title = pitName == null
        ? context.l10n.oshiTitle
        : context.l10n.albumTitleWithPit(pitName, context.l10n.oshiTitle);
    _sel.updateOrder([for (final v in views) v.record.id]);
    final selecting = _sel.active;
    setNavBarHidden(selecting);
    final picked = _picked(views);
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sel.exit();
      },
      child: Scaffold(
        floatingActionButton: (fullyEmpty || selecting)
            ? null
            : EntityFab(
                label: context.l10n.oshiAddRecord,
                onPressed: () => _add(groupId),
              ),
        bottomNavigationBar: selecting
            ? OshiSelectBar(
                onGroup: () => _group(picked),
                onTag: () => _tag(picked),
                onDelete: () => _delete(picked),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (selecting)
                OshiSelectHeader(
                  count: picked.length,
                  allSelected: _sel.allSelected,
                  onExit: _sel.exit,
                  onToggleAll: () =>
                      _sel.allSelected ? _sel.exit() : _sel.selectAll(),
                )
              else
                SubPageHeader(
                  title: title,
                  gap: 4,
                  trailing: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        context.l10n.oshiCountRecords(total),
                        style: TextStyle(color: t.text3, fontSize: 12),
                      ),
                    ),
                    _LayoutToggle(layout: _layout, onChanged: _setLayout),
                    SearchIconButton(pitId: widget.pitId),
                  ],
                ),
              if (!fullyEmpty) ...[
                if (filtered)
                  TagFilterBar(
                    pitId: widget.pitId,
                    kind: TaggedKind.oshi,
                    tagId: widget.tagId!,
                    countText: context.l10n.oshiCountRecords(views.length),
                  ),
                // 多選時分組 pills 隱藏（OshiSelect）。
                if (!selecting)
                  ChipRow(
                    options: [for (final g in groups) (g.id, g.name)],
                    selected: groupId,
                    onSelected: (v) => setState(() => _groupId = v),
                    trailing: ChipRowManageButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => GroupManagePage(
                            pitId: widget.pitId,
                            kind: 'oshi',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              Expanded(
                child: views.isEmpty
                    ? EmptyState(
                        svg: OshiIcons.star,
                        text: context.l10n.oshiEmpty,
                        color: t.oshi,
                        actionLabel: context.l10n.oshiEmptyAction,
                        onAction: () => _add(groupId),
                      )
                    // 長按＋拖曳連續多選（D-081）：index ＝ views 的順序
                    // （時間軸分段攤平後與 views 同序；月份標題不是項目）。
                    : DragSelectArea(
                        itemCount: views.length,
                        isSelected: (i) => _sel.isSelected(views[i].record.id),
                        onChanged: (idx, finished) =>
                            _sel.applyIndices(idx, finished: finished),
                        child: _layout == OshiLayout.timeline
                            ? TimelineView(
                                entries: [
                                  for (var i = 0; i < views.length; i++)
                                    oshiTimelineEntry(
                                      views[i],
                                      onTap: () => _tap(views[i]),
                                      selected: selecting
                                          ? _sel.isSelected(views[i].record.id)
                                          : null,
                                      dragIndex: i,
                                    ),
                                ],
                                countLabel: context.l10n.oshiCountRecords,
                              )
                            : _OshiGrid(
                                views: views,
                                selection: _sel,
                                onTap: _tap,
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

/// 時間軸／網格的分段切換（34×32 兩格，選中＝深色底）。
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.layout, required this.onChanged});
  final OshiLayout layout;
  final ValueChanged<OshiLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget seg(OshiLayout v, String icon, String label) {
      final on = layout == v;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: Container(
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: on ? t.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgIcon(
                icon,
                size: 18,
                strokeWidth: icon == OshiIcons.layoutGrid ? 1.7 : 1.8,
                color: on ? t.ground : t.text3,
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
        children: [
          seg(
            OshiLayout.timeline,
            OshiIcons.layoutTimeline,
            context.l10n.oshiLayoutTimeline,
          ),
          const SizedBox(width: 3),
          seg(
            OshiLayout.grid,
            OshiIcons.layoutGrid,
            context.l10n.pieceViewNine,
          ),
        ],
      ),
    );
  }
}

/// 九宮格（OshiGrid，D-078）：同草稿／雜物／素材庫的九宮格——一排 3 格正方形、貼邊、間距 2px、
/// 沒有圓角、圖下沒有字；多張圖右下角張數。多選時右上角勾選圈，選中加 2px 主色框（D-079）。
class _OshiGrid extends StatelessWidget {
  const _OshiGrid({
    required this.views,
    required this.selection,
    required this.onTap,
  });
  final List<OshiRecordView> views;
  final OshiSelection selection;
  final void Function(OshiRecordView v) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selecting = selection.active;
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnsForWidth(
          MediaQuery.sizeOf(context).width,
          phone: 3,
        ),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: views.length,
      itemBuilder: (_, i) {
        final v = views[i];
        final picked = selection.isSelected(v.record.id);
        return DragSelectItem(
          index: i,
          child: GestureDetector(
            onTap: () => onTap(v),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              key: ValueKey('oshi-grid-${v.record.id}'),
              fit: StackFit.expand,
              children: [
                MediaThumb(
                  MediaSource.fromImageRef(v.cover),
                  cacheWidth: 400,
                  count: v.images.length,
                ),
                if (picked)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: t.accent, width: 2),
                    ),
                  ),
                if (selecting)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: SelectMark(selected: picked),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
