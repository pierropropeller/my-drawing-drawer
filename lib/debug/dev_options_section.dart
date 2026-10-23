// Debug-only "developer options" block for the About page. The caller must
// guard it with kDebugMode; it renders nothing otherwise.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import '../ui/common/app_switch.dart';
import '../ui/me/me_widgets.dart';
import 'layout_bounds.dart';

class DevOptionsSection extends StatelessWidget {
  const DevOptionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final t = context.tokens;
    final l = context.l10n;
    final labels = {
      DebugPaintOption.sizes: l.devOptsLayoutBounds,
      DebugPaintOption.baselines: l.devOptsBaselines,
      DebugPaintOption.pointers: l.devOptsPointers,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              l.devOptsTitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.text3,
              ),
            ),
          ),
          MePanel(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<Map<DebugPaintOption, bool>>(
              valueListenable: LayoutBoundsDebug.state,
              builder: (context, state, _) => Column(
                children: [
                  for (final o in DebugPaintOption.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labels[o]!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          AppSwitch(
                            key: ValueKey('devOpt_${o.name}'),
                            value: state[o] ?? false,
                            semanticLabel: labels[o],
                            onChanged: (v) => LayoutBoundsDebug.set(o, v),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
