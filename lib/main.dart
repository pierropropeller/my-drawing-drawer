import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'ui/shell.dart';

void main() {
  runApp(const ProviderScope(child: HuaKengApp()));
}

class HuaKengApp extends ConsumerWidget {
  const HuaKengApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '畫坑',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const AppShell(),
    );
  }
}
