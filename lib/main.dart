import 'app_name.dart';
import 'l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'share/share_inbox.dart';
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

const appLocale = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

class HuaKengApp extends ConsumerWidget {
  const HuaKengApp({super.key, this.useGoogleFonts = true});

  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    // 啟動時就開始接收分享（冷啟動的初始分享、執行中的新分享）。
    ref.watch(shareInboxProvider);
    return MaterialApp(
      onGenerateTitle: (_) => appName,
      // 目前只有繁體中文；English 之後補 app_en.arb 再開放（D-040）。
      locale: appLocale,
      supportedLocales: const [appLocale],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
        Brightness.light,
        useGoogleFonts: useGoogleFonts,
        accent: accent,
      ),
      darkTheme: buildTheme(
        Brightness.dark,
        useGoogleFonts: useGoogleFonts,
        accent: accent,
      ),
      themeMode: ref.watch(themeModeProvider),
      home: const AppShell(),
    );
  }
}
