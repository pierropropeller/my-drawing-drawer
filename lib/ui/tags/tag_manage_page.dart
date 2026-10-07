import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';

/// 管理 tag：新增、改名、刪除，顯示使用次數。
class TagManagePage extends ConsumerWidget {
  const TagManagePage({super.key, required this.pitId});
  final String pitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final db = ref.watch(databaseProvider);
    final usage = ref.watch(tagUsageProvider(pitId)).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('管理 tag')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增 tag'),
        onPressed: () async {
          final name = await promptText(context, title: '新增 tag');
          if (name != null) await db.createTag(pitId, name);
        },
      ),
      body: usage.isEmpty
          ? Center(
              child: Text('還沒有 tag', style: TextStyle(color: t.text3)),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: usage.length,
              itemBuilder: (_, i) {
                final u = usage[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: t.borderCard),
                  ),
                  child: ListTile(
                    title: Text('#${u.tag.name}'),
                    subtitle: Text('使用 ${u.count} 次'),
                    onTap: () async {
                      final name = await promptText(
                        context,
                        title: 'Tag 名稱',
                        initial: u.tag.name,
                      );
                      if (name != null) await db.renameTag(u.tag.id, name);
                    },
                    trailing: IconButton(
                      tooltip: '刪除',
                      icon: Icon(Icons.delete_outline, color: t.danger),
                      onPressed: () async {
                        final ok = await confirmDelete(
                          context,
                          title: '刪除 tag「${u.tag.name}」？',
                          message: u.count > 0 ? '已使用的內容會一併移除這個 tag。' : null,
                        );
                        if (ok) await db.deleteTag(u.tag.id);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
