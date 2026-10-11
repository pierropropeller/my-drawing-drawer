import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../data/oshi_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../album/album_view.dart';
import '../album/group_manage_page.dart';
import '../common/empty_state.dart';
import '../common/responsive.dart';
import '../common/svg_icon.dart';
import '../common/timeline.dart';
import '../entity/entity_widgets.dart';
import '../search/tag_filter_bar.dart';
import '../search/tagged_list.dart';
import 'oshi_detail_page.dart';
import 'oshi_form_page.dart';
import 'oshi_icons.dart';
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

class _OshiListPageState extends ConsumerState<OshiListPage> {
  String? _groupId;
  late OshiLayout _layout = _readLayout();

  OshiLayout _readLayout() {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs?.getString(_kLayoutKey) == 'grid'
        ? OshiLayout.grid
        : OshiLayout.timeline;
  }

  @override
  void initState() {
    super.initState();
    // 從舊版同步進來的坑沒有推活分組，進來時補一次預設分組（只在從沒有過時才建立）。
    ref.read(databaseProvider).ensureOshiGroups(widget.pitId);
  }

  void _setLayout(OshiLayout v) {
    setState(() => _layout = v);
    ref
        .read(sharedPrefsProvider)
        ?.setString(_kLayoutKey, v == OshiLayout.grid ? 'grid' : 'timeline');
  }

  /// 新增：先打開相簿選圖，選好再進入新增頁（同其他列表）。
  Future<void> _add(String? groupId) async {
    final picked = await ref.read(imagePickerProvider)();
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
    return Scaffold(
      floatingActionButton: fullyEmpty
          ? null
          : EntityFab(
              label: context.l10n.oshiAddRecord,
              onPressed: () => _add(groupId),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
              ChipRow(
                options: [for (final g in groups) (g.id, g.name)],
                selected: groupId,
                onSelected: (v) => setState(() => _groupId = v),
                trailing: ChipRowManageButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GroupManagePage(pitId: widget.pitId, kind: 'oshi'),
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
                  : _layout == OshiLayout.timeline
                  ? TimelineView(
                      entries: [
                        for (final v in views)
                          oshiTimelineEntry(v, onTap: () => _open(v)),
                      ],
                      countLabel: context.l10n.oshiCountRecords,
                    )
                  : _OshiGrid(views: views, onTap: _open),
            ),
          ],
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
                strokeWidth: 1.8,
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
            context.l10n.oshiLayoutGrid,
          ),
        ],
      ),
    );
  }
}

/// 網格（OshiGrid）：兩欄瀑布流，圖下一行＝左日期、右分組小標；多張圖右下圓形數字。
class _OshiGrid extends StatelessWidget {
  const _OshiGrid({required this.views, required this.onTap});
  final List<OshiRecordView> views;
  final void Function(OshiRecordView v) onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
      crossAxisCount: columnsForWidth(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: views.length,
      itemBuilder: (_, i) {
        final v = views[i];
        final im = v.cover;
        final aspect = (im.width > 0 && im.height > 0)
            ? im.width / im.height
            : 1.0;
        return GestureDetector(
          key: ValueKey('oshi-grid-${v.record.id}'),
          onTap: () => onTap(v),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: aspect.clamp(0.4, 2.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.image),
                      child: StoredImage(im.file, cacheWidth: 500),
                    ),
                    if (v.images.length > 1)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: RoundCountBadge(v.images.length),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        oshiMd(v.date),
                        maxLines: 1,
                        style: TextStyle(color: t.text2, fontSize: 12.5),
                      ),
                    ),
                    if (v.group != null) ...[
                      const SizedBox(width: 6),
                      OshiGroupTag(v.group!.name),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
