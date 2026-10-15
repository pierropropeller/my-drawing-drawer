import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';

/// 選分組的結果：[groupId]＝null 表示「不分組」。（sheet 取消時回傳 null，不是這個物件。）
class OshiGroupChoice {
  const OshiGroupChoice(this.groupId);
  final String? groupId;
}

/// 推活多選的「分組」單選 bottom sheet：列出該坑的推活分組和筆數，最後一列「不分組」。
/// 樣式同素材庫「移動到」sheet（MaterialMoveSheet）。
Future<OshiGroupChoice?> showOshiGroupSheet(
  BuildContext context, {
  required String pitId,
  required int count,

  /// 預選：選取的紀錄都在同一組時傳 [OshiGroupChoice]（groupId 可為 null＝都沒分組）。
  OshiGroupChoice? initial,
}) {
  final t = context.tokens;
  return showModalBottomSheet<OshiGroupChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) =>
        OshiGroupSheet(pitId: pitId, count: count, initial: initial),
  );
}

class OshiGroupSheet extends ConsumerStatefulWidget {
  const OshiGroupSheet({
    super.key,
    required this.pitId,
    required this.count,
    this.initial,
  });
  final String pitId;
  final int count;
  final OshiGroupChoice? initial;

  @override
  ConsumerState<OshiGroupSheet> createState() => _OshiGroupSheetState();
}

class _OshiGroupSheetState extends ConsumerState<OshiGroupSheet> {
  late OshiGroupChoice? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final groups =
        ref.watch(groupsProvider((widget.pitId, 'oshi'))).value ?? const [];
    final counts =
        ref.watch(oshiGroupCountsProvider(widget.pitId)).value ?? const {};
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.albumMoveTo,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l.oshiCountRecords(widget.count),
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  for (final g in groups)
                    _GroupRow(
                      key: ValueKey('oshiGroup-${g.id}'),
                      label: g.name,
                      count: counts[g.id] ?? 0,
                      selected: _picked != null && _picked!.groupId == g.id,
                      onTap: () =>
                          setState(() => _picked = OshiGroupChoice(g.id)),
                    ),
                  _GroupRow(
                    key: const ValueKey('oshiGroup-none'),
                    label: l.oshiNoGroup,
                    count: counts[null] ?? 0,
                    selected: _picked != null && _picked!.groupId == null,
                    onTap: () =>
                        setState(() => _picked = const OshiGroupChoice(null)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              key: const ValueKey('oshiGroupConfirm'),
              onTap: _picked == null
                  ? null
                  : () => Navigator.of(context).pop(_picked),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _picked == null
                      ? t.accent.withValues(alpha: 0.4)
                      : t.accent,
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
                child: Text(
                  l.commonMove,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                context.l10n.oshiCountRecords(count),
                style: TextStyle(fontSize: 12.5, color: t.text4),
              ),
              const SizedBox(width: 12),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.accent : t.dashed,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.accent,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
