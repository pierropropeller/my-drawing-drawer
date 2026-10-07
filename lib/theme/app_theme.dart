import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// [useGoogleFonts] 僅供測試關閉（測試環境不能下載字型）。
ThemeData buildTheme(Brightness brightness, {bool useGoogleFonts = true}) {
  final t = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;
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
    extensions: [t],
  );
}
