import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// [useGoogleFonts] 僅供測試關閉（測試環境不能下載字型）。
ThemeData buildTheme(
  Brightness brightness, {
  bool useGoogleFonts = true,
  AccentPreset accent = AccentPreset.coral,
}) {
  final t = (brightness == Brightness.light ? AppTokens.light : AppTokens.dark)
      .withAccent(accent, brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: t.accent,
        brightness: brightness,
      ).copyWith(
        primary: t.accent,
        surface: t.surface,
        onSurface: t.ink,
        error: t.danger,
        outline: t.border,
      );

  final sans =
      (useGoogleFonts
              ? GoogleFonts.notoSansTcTextTheme()
              : ThemeData(brightness: brightness).textTheme)
          .apply(bodyColor: t.ink, displayColor: t.ink);
  TextStyle serif(TextStyle? base, FontWeight w) => useGoogleFonts
      ? GoogleFonts.notoSerifTc(textStyle: base, fontWeight: w, color: t.ink)
      : (base ?? const TextStyle()).copyWith(fontWeight: w, color: t.ink);
  final textTheme = sans.copyWith(
    headlineLarge: serif(sans.headlineLarge, FontWeight.w700),
    headlineMedium: serif(sans.headlineMedium, FontWeight.w700),
    headlineSmall: serif(sans.headlineSmall, FontWeight.w700),
    titleLarge: serif(sans.titleLarge, FontWeight.w600),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.ground,
    textTheme: textTheme,
    dividerColor: t.border,
    appBarTheme: AppBarTheme(
      backgroundColor: t.ground,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    ),
    // 開關：設計稿是 46x28 軌道＋22 白圓鈕（見 AppSwitch，三處開關都用它）。
    // 這裡是萬一還有原生 Switch 時的近似：同樣的顏色，沒有描邊。
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? t.accent
            : (brightness == Brightness.light
                  ? const Color(0xFFD8CFC3)
                  : const Color(0xFF4A423B)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(color: t.ground, fontSize: 13.5),
      actionTextColor: const Color(0xFFE9A58F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    extensions: [t],
  );
}
