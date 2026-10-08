import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'album_actions.dart';

/// 管理分組：拖曳排序、改名、刪除、新增。
class GroupManagePage extends ConsumerWidget {
  const GroupManagePage({
    super.key,
    required this.pitId,
    this.kind = 'official',
  });
  final String pitId;

  /// `official`（官方圖冊）或 `fan`（好看同人圖）。
  final String kind;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OfficialGroup g,
  ) async {
    final ok = await confirmDelete(
      context,
      title: '刪除分組「${g.name}」？',
      message: '組內的圖會移到其他分組。',
    );
    if (!ok) return;
    final done = await ref.read(databaseProvider).deleteGroup(g.id);
    if (!done && context.mounted) showSnack(context, '至少要保留一個分組');
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    OfficialGroup g,
  ) async {
    final name = await promptText(context, title: '分組名稱', initial: g.name);
    if (name != null) await ref.read(databaseProvider).renameGroup(g.id, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);
    final groups = ref.watch(groupsProvider((pitId, kind))).value ?? const [];
    // 每個分組的張數。
    final counts = <String, int>{};
    if (kind == 'fan') {
      for (final r
          in ref.watch(fanArtsProvider((pitId, null))).value ?? const []) {
        final id = r.groupId;
        if (id != null) counts[id] = (counts[id] ?? 0) + 1;
      }
    } else {
      for (final r
          in ref.watch(officialProvider((pitId, null))).value ?? const []) {
        counts[r.groupId] = (counts[r.groupId] ?? 0) + 1;
      }
    }
    final rowLine = BorderSide(color: t.borderCard);
    // 管理頁沒有底部導覽列（GroupManage 沒畫 nav）。
    return HideNavBar(
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 58,
          titleSpacing: 6,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: IconButton(
              tooltip: '返回',
              padding: EdgeInsets.zero,
              icon: SvgIcon(AppIcons.back, color: t.ink, strokeWidth: 1.9),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          title: Text(
            '管理分組',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: Text(
                kind == 'fan' ? '分組只用於好看同人圖，拖曳可調整次序' : '分組只用於官方圖冊，拖曳可調整次序',
                style: TextStyle(color: t.text3, fontSize: 12.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: t.borderCard),
              ),
              child: Column(
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: groups.length,
                    onReorderItem: (from, to) {
                      final ids = groups.map((g) => g.id).toList();
                      ids.insert(to, ids.removeAt(from));
                      db.reorderGroups(ids);
                    },
                    itemBuilder: (_, i) {
                      final g = groups[i];
                      return Container(
                        key: ValueKey(g.id),
                        padding: const EdgeInsets.fromLTRB(0, 6, 4, 6),
                        decoration: BoxDecoration(
                          color: t.surface,
                          border: Border(bottom: rowLine),
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 2,
                                ),
                                child: SvgIcon(
                                  AppIcons.dragDots,
                                  size: 18,
                                  fill: 'currentColor',
                                  strokeWidth: 0,
                                  color: dark
                                      ? t.text4
                                      : const Color(0xFFC9BEB0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _rename(context, ref, g),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    g.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Text(
                                '${counts[g.id] ?? 0} 張',
                                style: TextStyle(
                                  color: t.text4,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            _RowButton(
                              tooltip: '重新命名 ${g.name}',
                              svg: AppIcons.edit,
                              color: t.text2,
                              onTap: () => _rename(context, ref, g),
                            ),
                            _RowButton(
                              tooltip: '刪除 ${g.name}',
                              svg: AppIcons.trash,
                              color: t.danger,
                              onTap: () => _delete(context, ref, g),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  InkWell(
                    onTap: () async {
                      final name = await promptText(context, title: '新增分組');
                      if (name != null) {
                        await db.addGroup(pitId, name, kind: kind);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          SvgIcon(
                            AppIcons.plus,
                            size: 18,
                            color: t.dashedText,
                            strokeWidth: 2,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '新增分組',
                            style: TextStyle(
                              color: t.dashedText,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.tooltip,
    required this.svg,
    required this.color,
    required this.onTap,
  });
  final String tooltip;
  final String svg;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    icon: SvgIcon(svg, size: 20, color: color),
  );
}
