import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import 'tag_manage_page.dart';

/// 表單的 tag 欄：可多選、就地新增，旁邊有「管理」。tag 按坑獨立。
class TagPicker extends ConsumerWidget {
  const TagPicker({
    super.key,
    required this.pitId,
    required this.selected,
    required this.onChanged,
  });

  final String pitId;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tags = ref.watch(tagsProvider(pitId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Tag', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TagManagePage(pitId: pitId),
                ),
              ),
              child: const Text('管理'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              FilterChip(
                label: Text('#${tag.name}'),
                selected: selected.contains(tag.id),
                showCheckmark: false,
                selectedColor: t.accent,
                backgroundColor: t.chipBg,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  color: selected.contains(tag.id) ? Colors.white : t.text2,
                ),
                onSelected: (on) => onChanged(
                  on
                      ? [...selected, tag.id]
                      : selected.where((e) => e != tag.id).toList(),
                ),
              ),
            ActionChip(
              label: const Text('新增'),
              avatar: const Icon(Icons.add, size: 16),
              shape: const StadiumBorder(),
              onPressed: () async {
                final name = await promptText(context, title: '新增 tag');
                if (name == null) return;
                final id = await ref
                    .read(databaseProvider)
                    .createTag(pitId, name);
                if (!selected.contains(id)) onChanged([...selected, id]);
              },
            ),
          ],
        ),
      ],
    );
  }
}
