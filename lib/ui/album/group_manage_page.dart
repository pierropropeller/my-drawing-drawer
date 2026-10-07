import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../data/database.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.watch(databaseProvider);
    final groups = ref.watch(groupsProvider((pitId, kind))).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('管理分組')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增分組'),
        onPressed: () async {
          final name = await promptText(context, title: '新增分組');
          if (name != null) await db.addGroup(pitId, name, kind: kind);
        },
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: t.borderCard),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: i,
                  child: Icon(Icons.drag_handle, color: t.text3),
                ),
                title: Text(g.name),
                onTap: () async {
                  final name = await promptText(
                    context,
                    title: '分組名稱',
                    initial: g.name,
                  );
                  if (name != null) await db.renameGroup(g.id, name);
                },
                trailing: IconButton(
                  tooltip: '刪除',
                  icon: Icon(Icons.delete_outline, color: t.danger),
                  onPressed: () => _delete(context, ref, g),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
