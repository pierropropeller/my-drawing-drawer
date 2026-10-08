import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'album_view.dart';
import 'group_manage_page.dart';

/// 表單裡的分組欄：標題＋右上「管理」＋分組 chips。
/// [kind]：`official`（官方圖冊）或 `fan`（好看同人圖）。
class GroupPicker extends ConsumerWidget {
  const GroupPicker({
    super.key,
    required this.pitId,
    required this.kind,
    required this.selected,
    required this.onSelected,
    this.label = '分組',
    this.allowClear = false,
  });

  final String pitId;
  final String kind;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String label;

  /// 同人圖的分組可留空：再點一次已選的分組即取消。
  final bool allowClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider((pitId, kind))).value ?? const [];
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
                  label,
                  style: TextStyle(
                    color: context.tokens.text2,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GroupManagePage(pitId: pitId, kind: kind),
                  ),
                ),
                child: Text(
                  '管理',
                  style: TextStyle(
                    color: context.tokens.piece.fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ChipRow(
          padding: EdgeInsets.zero,
          accentSelected: true,
          wrap: true,
          allLabel: null,
          options: [for (final g in groups) (g.id, g.name)],
          selected: selected,
          onSelected: (v) => onSelected(allowClear && v == selected ? null : v),
        ),
      ],
    );
  }
}
