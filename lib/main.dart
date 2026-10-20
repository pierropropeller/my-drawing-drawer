import 'app_name.dart';
import 'l10n/l10n.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'debug/input_diagnostics.dart';
import 'input/ime_shift.dart';
import 'media/player_frame_poster_generator.dart';
import 'share/share_inbox.dart';
import 'state/app_icon.dart';
import 'state/providers.dart';
import 'state/settings.dart';
import 'theme/app_theme.dart';
import 'ui/common/root_overlay_guard.dart';
import 'ui/common/window_top_inset.dart';
import 'ui/shell.dart';

Future<void> main() async {
  if (kDebugMode) {
    DebugDiagBinding.ensureInitialized();
  } else {
    ImeShiftBinding.ensureInitialized();
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const _PosterFixerHost(child: HuaKengApp()),
    ),
  );
}

/// 補影片截圖（D-080）：另一台裝置匯入的影片在本機還沒有 poster，啟動後與同步下載完成後在背景補。
/// 放在 [main] 而不是 [HuaKengApp] 裡，是為了不影響直接 pump [HuaKengApp] 的測試（它們沒有圖庫）。
class _PosterFixerHost extends ConsumerWidget {
  const _PosterFixerHost({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(posterFixerProvider);
    ref.watch(profileBootProvider);
    // 播放器備援擷取影片截圖用的隱形畫布（畫在螢幕外，平常是空的）。
    return PosterCaptureScope(
      slot: ref.watch(posterCaptureSlotProvider),
      child: child,
    );
  }
}

/// 啟動時讓設定裡的暱稱／頭像和資料庫（同步的來源）對齊一次（升級前存的補進資料庫）。
final profileBootProvider = FutureProvider<void>(
  (ref) => ref.read(settingsProvider.notifier).reloadProfile(),
);

const appLocale = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

class HuaKengApp extends ConsumerWidget {
  const HuaKengApp({super.key, this.useGoogleFonts = true});

  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(settingsProvider.select((s) => s.accent));
    // 啟動時就開始接收分享（冷啟動的初始分享、執行中的新分享）。
    ref.watch(shareInboxProvider);
    // 啟動時以平台實際啟用的桌面圖示校正設定（D-086）。
    ref.watch(appIconStartupSyncProvider);
    return RootOverlayHost(
      builder: (context, overlayTracker) => MaterialApp(
        navigatorObservers: [overlayTracker],
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
        // iPad：頁面頂部讓開視窗控制點／狀態列（見 TabletTopInsetGuard）；其他裝置原樣。
        builder: (context, child) => ImeShiftKeyBridge(
          child: TabletTopInsetGuard(
            child: kDebugMode ? InputDiagnosticsOverlay(child: child!) : child!,
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}
