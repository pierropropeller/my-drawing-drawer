import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/album_queries.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../entity/entity_widgets.dart';
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
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'tag',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.text2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TagManagePage(pitId: pitId),
                  ),
                ),
                child: Text(
                  '管理',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.piece.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              _TagChip(
                label: '#${tag.name}',
                on: selected.contains(tag.id),
                onTap: () => onChanged(
                  selected.contains(tag.id)
                      ? selected.where((e) => e != tag.id).toList()
                      : [...selected, tag.id],
                ),
              ),
            DashedAddChip(
              semanticLabel: '新增 tag',
              onTap: () async {
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

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? t.accent : t.surface,
          border: Border.all(color: on ? t.accent : t.border),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : t.text2,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
