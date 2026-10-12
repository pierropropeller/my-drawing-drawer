import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/material_queries.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'material_category.dart';

/// 選分類的單選 bottom sheet（MaterialMoveSheet）：列出 7 個分類和張數。
///
/// 兩種用途：多選的「移動」（標題「移動到」、按鈕「移動」），
/// 以及在「全部」下加圖時先選分類（標題「加入到」、按鈕「加入」）。取消回傳 null。
Future<MaterialCategory?> showMaterialCategorySheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required int count,
  MaterialCategory? initial,
}) {
  final t = context.tokens;
  return showModalBottomSheet<MaterialCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.ground,
    barrierColor: const Color(0xFF1E1A17).withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => MaterialCategorySheet(
      title: title,
      confirmLabel: confirmLabel,
      count: count,
      initial: initial,
    ),
  );
}

class MaterialCategorySheet extends ConsumerStatefulWidget {
  const MaterialCategorySheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.count,
    this.initial,
  });

  final String title;
  final String confirmLabel;

  /// 這次要處理幾張（標題右側）。
  final int count;

  /// 預選的分類（移動時是所選圖共同的分類）。
  final MaterialCategory? initial;

  @override
  ConsumerState<MaterialCategorySheet> createState() =>
      _MaterialCategorySheetState();
}

class _MaterialCategorySheetState extends ConsumerState<MaterialCategorySheet> {
  late MaterialCategory? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final counts =
        ref.watch(materialCountsProvider).value ?? MaterialCounts.empty;
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
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    l.commonCountImages(widget.count),
                    style: TextStyle(fontSize: 12.5, color: t.text3),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                children: [
                  for (final c in MaterialCategory.values)
                    _CategoryRow(
                      key: ValueKey('materialCat-${c.name}'),
                      label: c.label(l),
                      count: counts.of(c),
                      selected: _picked == c,
                      onTap: () => setState(() => _picked = c),
                    ),
                ],
              ),
            ),
            GestureDetector(
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
                  widget.confirmLabel,
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
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
                context.l10n.commonCountImages(count),
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
