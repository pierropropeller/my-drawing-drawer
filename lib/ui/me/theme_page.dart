import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import 'me_widgets.dart';

/// 主題色：四個主題色預設＋外觀（淺色／深色／跟隨系統）＋預覽。每台裝置各自設定，不同步。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    const modes = [
      (ThemeMode.light, '淺色'),
      (ThemeMode.dark, '深色'),
      (ThemeMode.system, '跟隨系統'),
    ];
    const title = TextStyle(fontWeight: FontWeight.w700, fontSize: 14);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MeSubHeader('主題色'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  MePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('主題色', style: title),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final p in AccentPreset.values)
                              Semantics(
                                label: p.label,
                                button: true,
                                child: GestureDetector(
                                  onTap: () => notifier.setAccent(p),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: p.color,
                                          shape: BoxShape.circle,
                                          boxShadow: p == s.accent
                                              ? [
                                                  BoxShadow(
                                                    color: t.ground,
                                                    spreadRadius: 3,
                                                  ),
                                                  BoxShadow(
                                                    color: p.color,
                                                    spreadRadius: 5,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p == s.accent
                                              ? t.ink
                                              : t.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  MePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('外觀', style: title),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (final (i, (m, label)) in modes.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => notifier.setThemeMode(m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: s.themeMode == m
                                          ? t.ink
                                          : t.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.border),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: s.themeMode == m
                                            ? (dark ? t.ground : Colors.white)
                                            : t.text2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '每個主題色都有深／淺兩個版本，「跟隨系統」會依照裝置設定自動切換。',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.text3,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  MePanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '預覽',
                          style: TextStyle(fontSize: 11, color: t.text3),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: t.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: 0.6,
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: t.accent,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FractionallySizedBox(
                                    widthFactor: 0.85,
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: dark
                                            ? t.border
                                            : const Color(0xFFE3D8C9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '按鈕',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
