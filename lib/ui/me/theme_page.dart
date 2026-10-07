import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';

/// 主題：淺色／深色／跟隨系統（每台裝置各自設定，不同步）。
class ThemePage extends ConsumerWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final mode = ref.watch(settingsProvider).themeMode;
    const options = [
      (ThemeMode.light, '淺色', Icons.light_mode_outlined),
      (ThemeMode.dark, '深色', Icons.dark_mode_outlined),
      (ThemeMode.system, '跟隨系統', Icons.brightness_auto_outlined),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('主題')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (m, label, icon) in options)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: mode == m ? t.accent : t.borderCard,
                  width: mode == m ? 2 : 1,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  leading: Icon(icon, color: t.text2),
                  title: Text(label),
                  trailing: mode == m
                      ? Icon(Icons.check_circle, color: t.accent)
                      : null,
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setThemeMode(m),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
