import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 頂部二分切換（分享 sheet 的「坑｜靈感廣場」、移動 sheet、選圖 sheet 的「相簿｜靈感廣場」）：
/// chipBg 底、圓角 12；選中的那段白底＋淡影。
class SegmentToggle extends StatelessWidget {
  const SegmentToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.segmentKeys,
    this.semanticsLabel,
    this.dark = false,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  /// 每段的 key（測試用）。
  final List<Key>? segmentKeys;
  final String? semanticsLabel;

  /// 深色底（選圖 sheet）。
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = dark ? const Color(0xFF1F1C1A) : t.chipBg;
    final onBg = dark ? const Color(0xFF3A332D) : t.surface;
    final onFg = dark ? const Color(0xFFF2ECE4) : t.ink;
    final offFg = dark ? const Color(0xFF8C8378) : t.text3;
    Widget seg(int i) {
      final on = i == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            key: segmentKeys?[i],
            onTap: () => onChanged(i),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: dark ? 8 : 9),
              decoration: BoxDecoration(
                color: on ? onBg : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: on && !dark
                    ? [
                        BoxShadow(
                          color: const Color(0xFF2B2622)
                              .withValues(alpha: 0.12),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: on ? onFg : offFg,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              seg(i),
            ],
          ],
        ),
      ),
    );
  }
}
