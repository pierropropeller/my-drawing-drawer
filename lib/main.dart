import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'ui/shell.dart';

void main() {
  runApp(const ProviderScope(child: HuaKengApp()));
}

class HuaKengApp extends ConsumerWidget {
  const HuaKengApp({super.key, this.useGoogleFonts = true});

  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '畫坑',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light, useGoogleFonts: useGoogleFonts),
      darkTheme: buildTheme(Brightness.dark, useGoogleFonts: useGoogleFonts),
      themeMode: ref.watch(themeModeProvider),
      home: const AppShell(),
    );
  }
}
