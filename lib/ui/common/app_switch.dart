import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 設計稿（Backup）的開關：46×28 膠囊軌道、22px 白圓鈕（距邊 3px、淡陰影）；
/// 開＝主題色，關＝#D8CFC3（深色模式用較深的灰褐）。
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final off = dark ? const Color(0xFF4A423B) : const Color(0xFFD8CFC3);
    const d = Duration(milliseconds: 160);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: d,
          width: 46,
          height: 28,
          decoration: BoxDecoration(
            color: value ? t.accent : off,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: d,
                curve: Curves.easeOut,
                top: 3,
                left: value ? 21 : 3,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
