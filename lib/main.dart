import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const HuaKengApp(),
    ),
  );
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
