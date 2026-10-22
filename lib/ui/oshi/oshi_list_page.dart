import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart' show OfficialGroup;
import '../../data/oshi_queries.dart';
import '../../data/sensitive_queries.dart';
import '../../state/sensitive.dart';
import '../common/sensitive_actions.dart';
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
import '../common/window_class.dart';
import '../album/ipadlists_icons.dart';
import '../album/wide_layout.dart';
import '../entity/entity_widgets.dart';
import '../search/tagged_list.dart';
import 'oshi_detail_page.dart';
import 'oshi_form_page.dart';
import 'oshi_group_sheet.dart';
import 'oshi_icons.dart';
import 'oshi_select_actions.dart';
import 'oshi_select_bar.dart';
import 'oshi_selection.dart';
import 'oshi_widgets.dart';
import '../pits/pit_section_tabs.dart';

/// 推活的兩種佈局，記在本機設定（跟裝置走）。
enum OshiLayout { timeline, grid }

const _kLayoutKey = 'oshiLayout';

/// 推活列表（OshiTimeline／OshiGrid）：時間軸（預設）或網格，分組 pills，右上搜尋。
/// 有導覽列（瀏覽用的頁面）。點 tag 一律進坑內搜尋結果頁（D-107），這裡沒有 tag 篩選狀態。
class OshiListPage extends ConsumerStatefulWidget {
  const OshiListPage({super.key, required this.pitId});
  final String pitId;

  @override
  ConsumerState<OshiListPage> createState() => _OshiListPageState();
}

class _OshiListPageState extends ConsumerState<OshiListPage>
    with HidesNavBar<OshiListPage> {
  // 瀏覽時有導覽列；進入多選才隱藏（build 時依 _sel.active 同步）。
  @override
  bool get hidesNavBarOnOpen => false;

  String? _groupId;

  // 寬版右側篩選面板的狀態（只在並排時套用；窄視窗時保留，不丟）。
  final _queryCtl = TextEditingController();
  String _query = '';
  String? _panelTagId;
  int? _jumpedMonth;
  final _scroll = ScrollController();
  final _monthKeys = <int, GlobalKey>{};
  final _gridAreaKey = GlobalKey();

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
    _queryCtl.dispose();
    _scroll.dispose();
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
    await openOshiFormPage(
      context,
      pitId: widget.pitId,
      initialImages: [for (final x in picked) x.path],
      initialGroupId: groupId,
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

  Future<void> _sensitive(List<OshiRecordView> picked) async {
    if (picked.isEmpty) return;
    final done = await applySensitiveToSelection(
      context,
      ref,
      SensitiveSource.oshi,
      [for (final v in picked) v.record.id],
    );
    if (done && mounted) _sel.exit();
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
      builder: (_) =>
          OshiDetailPage(pitId: widget.pitId, recordId: v.record.id),
    ),
  );

  /// 寬版：左邊時間軸／網格，右邊篩選面板（Oshi 設計稿，290）。
  Widget _wideBody(Widget content, Widget panel, bool showPanel) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: KeyedSubtree(key: _gridAreaKey, child: content),
      ),
      if (showPanel) panel,
    ],
  );

  Widget _panel({
    required WideSpec spec,
    required List<OfficialGroup> groups,
    required Map<String?, int> counts,
    required bool showUngrouped,
    required String? groupId,
    required int total,
    required List<OshiRecordView> views,
  }) {
    final t = context.tokens;
    final l = context.l10n;
    // 角色 tag：這個坑所有推活紀錄用到的 tag（依使用次數），不受目前篩選影響。
    final all =
        ref.watch(oshiRecordsProvider((widget.pitId, null, null))).value ??
        const <OshiRecordView>[];
    final tagCount = <String, int>{};
    final tagName = <String, String>{};
    for (final v in all) {
      for (final tag in v.tags) {
        tagCount[tag.id] = (tagCount[tag.id] ?? 0) + 1;
        tagName[tag.id] = tag.name;
      }
    }
    final tagIds = tagCount.keys.toList()
      ..sort((a, b) => tagCount[b]!.compareTo(tagCount[a]!));
    // 月份：目前列出的紀錄有哪些月份（新到舊）；前 7 個直接列，其餘合成「更早」。
    final months = <int>[];
    for (final v in views) {
      final ym = v.date.year * 100 + v.date.month;
      if (!months.contains(ym)) months.add(ym);
    }
    final shown = months.take(months.length > 8 ? 7 : 8).toList();
    final earlier = months.length > 8 ? months[7] : null;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: t.text3,
        ),
      ),
    );
    Widget groupRow(String? id, String name, int n) {
      final on = groupId == id;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _groupId = id),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? t.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? t.surface : t.ink,
                    ),
                  ),
                ),
                Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: on ? t.surface.withValues(alpha: .8) : t.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget chip(String text, bool on, VoidCallback onTap, {double h = 34}) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: h),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: on ? t.accentSoft : t.surface,
              border: Border.all(color: on ? t.accent : t.border),
              borderRadius: BorderRadius.circular(h == 34 ? 999 : 9),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: h == 34 ? 13 : 12.5,
                color: on ? t.accentStrong : t.text2,
              ),
            ),
          ),
        );

    return SizedBox(
      width: spec.panel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.nav,
          border: Border(left: BorderSide(color: t.border)),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 18, spec.hpad - 4, 24),
          children: [
            Semantics(
              label: l.ipadListsOshiSearchLabel,
              textField: true,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border.all(color: t.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    SvgIcon(
                      IpadListsIcons.search,
                      size: 18,
                      strokeWidth: 1.9,
                      color: t.text3,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _queryCtl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration.collapsed(
                          hintText: l.ipadListsOshiSearchHint,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(child: label(l.albumGroupLabel)),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: t.text2,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            GroupManagePage(pitId: widget.pitId, kind: 'oshi'),
                      ),
                    ),
                    child: Text(
                      l.commonManage,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
            groupRow(null, l.commonAll, total),
            for (final g in groups) groupRow(g.id, g.name, counts[g.id] ?? 0),
            if (showUngrouped)
              groupRow(
                oshiUngroupedFilter,
                l.oshiPillUngrouped,
                counts[null] ?? 0,
              ),
            if (tagIds.isNotEmpty) ...[
              label(l.ipadListsOshiCharacterTags),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in tagIds)
                    chip(
                      '#${tagName[id]}',
                      _panelTagId == id,
                      () => setState(
                        () => _panelTagId = _panelTagId == id ? null : id,
                      ),
                    ),
                ],
              ),
            ],
            if (months.isNotEmpty) ...[
              label(l.ipadListsOshiJumpToMonth),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.1,
                children: [
                  for (final ym in shown)
                    chip(
                      l.ipadListsMonthShort(ym % 100),
                      (_jumpedMonth ?? months.first) == ym,
                      () => _jumpToMonth(ym, views),
                      h: 44,
                    ),
                  if (earlier != null)
                    chip(
                      l.ipadListsOshiEarlier,
                      false,
                      () => _jumpToMonth(earlier, views),
                      h: 44,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 跳到某個月份（[ym]＝年×100＋月）：時間軸捲到該月標題；網格捲到該月第一筆所在的列。
  /// 時間軸是惰性建構，目標還沒建出來時先依方向捲一段再找，找到後精準對齊。
  Future<void> _jumpToMonth(int ym, List<OshiRecordView> views) async {
    setState(() => _jumpedMonth = ym);
    final c = _scroll;
    if (!c.hasClients) return;
    if (_layout == OshiLayout.grid) {
      final idx = views.indexWhere(
        (v) => v.date.year * 100 + v.date.month == ym,
      );
      final box = _gridAreaKey.currentContext?.findRenderObject() as RenderBox?;
      if (idx < 0 || box == null) return;
      final g = _OshiGridMetrics.of(
        box.size.width,
        MediaQuery.sizeOf(context).width,
      );
      final offset = 4 + (idx ~/ g.cols) * (g.cell + g.gap);
      await c.animateTo(
        offset.clamp(0.0, c.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    final months = <int>[];
    for (final v in views) {
      final m = v.date.year * 100 + v.date.month;
      if (!months.contains(m)) months.add(m);
    }
    final target = months.indexOf(ym);
    for (var attempt = 0; attempt < 40 && mounted; attempt++) {
      final ctx = _monthKeys[ym]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        return;
      }
      // 目標還沒建出來：看目前已建出的月份在目標的上方還是下方，往目標方向捲一屏。
      var builtIdx = -1;
      for (var i = 0; i < months.length; i++) {
        if (_monthKeys[months[i]]?.currentContext != null) {
          builtIdx = i;
          break;
        }
      }
      final dir = builtIdx < 0 || builtIdx < target ? 1.0 : -1.0;
      final next = (c.offset + dir * c.position.viewportDimension * 0.8).clamp(
        0.0,
        c.position.maxScrollExtent,
      );
      if (next == c.offset) return;
      c.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pitName = ref.watch(pitProvider(widget.pitId)).value?.name;
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'oshi'))).value ?? const [];
    // 篩選中的分組被刪除時退回「全部」。
    final counts =
        ref.watch(oshiGroupCountsProvider(widget.pitId)).value ?? const {};
    // 「無分組」pill：有分組的和沒分組的紀錄同時存在才出現，放在最後。
    final showUngrouped =
        (counts[null] ?? 0) > 0 &&
        counts.entries.any((e) => e.key != null && e.value > 0);
    final groupId =
        groups.any((g) => g.id == _groupId) ||
            (showUngrouped && _groupId == oshiUngroupedFilter)
        ? _groupId
        : null;
    // 標題列一律顯示全部筆數。
    final total = ref.watch(pitStatsProvider(widget.pitId)).value?.oshi ?? 0;
    final wide = WindowClass.of(context).isWide;
    final spec = WideSpec.of(
      MediaQuery.sizeOf(context).width,
      expanded: (270, 290),
      large: (290, 320),
    );
    final baseViews =
        ref
            .watch(
              oshiRecordsProvider((
                widget.pitId,
                groupId,
                wide ? _panelTagId : null,
              )),
            )
            .value ??
        const [];
    final q = _query.trim().toLowerCase();
    final views = wide && q.isNotEmpty
        ? [
            for (final v in baseViews)
              if ((v.record.title ?? '').toLowerCase().contains(q) ||
                  (v.record.description ?? '').toLowerCase().contains(q))
                v,
          ]
        : baseViews;
    final fullyEmpty = total == 0 && views.isEmpty;
    final title = pitName == null
        ? context.l10n.oshiTitle
        : context.l10n.albumTitleWithPit(pitName, context.l10n.oshiTitle);
    _sel.updateOrder([for (final v in views) v.record.id]);
    final selecting = _sel.active;
    setNavBarHidden(selecting);
    final picked = _picked(views);
    // 每個月份標題都要有 key，「跳到月份」才找得到。
    for (final v in views) {
      _monthKeys.putIfAbsent(v.date.year * 100 + v.date.month, GlobalKey.new);
    }
    final showPanel = wide && !selecting;
    final Widget content = views.isEmpty
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
                    controller: _scroll,
                    headerKeys: _monthKeys,
                    padding: EdgeInsets.fromLTRB(
                      wide ? spec.hpad : 20,
                      4,
                      wide ? 12 : 20,
                      96,
                    ),
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
                    controller: _scroll,
                    wideInset: wide ? spec.hpad : null,
                  ),
          );
    final Widget panel = _panel(
      spec: spec,
      groups: groups,
      counts: counts,
      showUngrouped: showUngrouped,
      groupId: groupId,
      total: total,
      views: views,
    );
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
                onSensitive: ref.watch(sensitiveMarkingProvider(widget.pitId))
                    ? () => _sensitive(picked)
                    : null,
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
              if (!selecting)
                PitSectionTabBar(
                  pitId: widget.pitId,
                  selected: PitSection.oshi,
                ),
              if (!fullyEmpty) ...[
                // 多選時分組 pills 隱藏（OshiSelect）。
                if (!selecting && !wide)
                  ChipRow(
                    options: [
                      for (final g in groups) (g.id, g.name),
                      if (showUngrouped)
                        (oshiUngroupedFilter, context.l10n.oshiPillUngrouped),
                    ],
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
                child: wide ? _wideBody(content, panel, showPanel) : content,
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

/// 寬版網格的欄數與格子大小（Oshi 設計稿：4 欄、間距 12；依可用闊度逐格增減）。
class _OshiGridMetrics {
  const _OshiGridMetrics(this.cols, this.cell, this.gap);
  final int cols;
  final double cell;
  final double gap;

  /// [areaWidth]＝網格區闊度（不含右側面板）；[windowWidth] 用來決定左右邊距。
  static _OshiGridMetrics of(double areaWidth, double windowWidth) {
    final inset = WideSpec.of(windowWidth).hpad;
    const gap = 12.0;
    final inner = areaWidth - inset - 12;
    final cols = math.max(3, gridColumnsFor(inner, minCell: 170));
    return _OshiGridMetrics(cols, (inner - gap * (cols - 1)) / cols, gap);
  }
}

/// 九宮格（OshiGrid，D-078）：同草稿／雜物／素材庫的九宮格——一排 3 格正方形、貼邊、間距 2px、
/// 沒有圓角、圖下沒有字；多張圖右下角張數。多選時右上角勾選圈，選中加 2px 主色框（D-079）。
class _OshiGrid extends StatelessWidget {
  const _OshiGrid({
    required this.views,
    required this.selection,
    required this.onTap,
    this.controller,
    this.wideInset,
  });

  /// 非 null＝平板寬版樣式（稿：4 欄、間距 12、圓角 14、左下日期標）；左右邊距用這個值。
  final double? wideInset;
  final ScrollController? controller;
  final List<OshiRecordView> views;
  final OshiSelection selection;
  final void Function(OshiRecordView v) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selecting = selection.active;
    final wide = wideInset != null;
    return LayoutBuilder(
      builder: (context, c) {
        final m = wide
            ? _OshiGridMetrics.of(c.maxWidth, MediaQuery.sizeOf(context).width)
            : null;
        return _grid(context, t, selecting, wide, m);
      },
    );
  }

  Widget _grid(
    BuildContext context,
    AppTokens t,
    bool selecting,
    bool wide,
    _OshiGridMetrics? m,
  ) {
    return GridView.builder(
      controller: controller,
      padding: wide
          ? EdgeInsets.fromLTRB(wideInset!, 4, 12, 96)
          : const EdgeInsets.only(top: 8, bottom: 96),
      gridDelegate: wide
          ? SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: m!.cols,
              mainAxisSpacing: m.gap,
              crossAxisSpacing: m.gap,
            )
          : SliverGridDelegateWithFixedCrossAxisCount(
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(wide ? 14 : 0),
                  child: MediaThumb(
                    MediaSource.fromImageRef(v.cover),
                    cacheWidth: 400,
                    count: v.images.length,
                  ),
                ),
                if (picked)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(wide ? 14 : 0),
                      border: Border.all(color: t.accent, width: 2),
                    ),
                  ),
                // 寬版：左下日期標（稿：白底半透明、11.5/600）。
                if (wide)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        oshiMd(v.date),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B2622),
                        ),
                      ),
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
