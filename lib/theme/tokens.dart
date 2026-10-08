import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 分類色（底色／前景）。
class CategoryColor {
  const CategoryColor(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

/// 設計 tokens，對應 HANDOFF 第 7 節。以 ThemeExtension 掛在 ThemeData 上。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ground,
    required this.surface,
    required this.nav,
    required this.ink,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.border,
    required this.borderCard,
    required this.chipBg,
    required this.dashed,
    required this.dashedText,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.danger,
    required this.official,
    required this.fanArt,
    required this.draft,
    required this.idea,
    required this.piece,
  });

  final Color ground;
  final Color surface;
  final Color nav;
  final Color ink;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color border;
  final Color borderCard;
  final Color chipBg;
  final Color dashed;
  final Color dashedText;
  final Color accent;
  final Color accentStrong;

  /// 頭像底、淡色強調底（ColorSystem 的 soft）。
  final Color accentSoft;
  final Color danger;
  final CategoryColor official;
  final CategoryColor fanArt;
  final CategoryColor draft;
  final CategoryColor idea;
  final CategoryColor piece;

  static const light = AppTokens(
    ground: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    nav: Color(0xFFFDFBF8),
    ink: Color(0xFF2B2622),
    text2: Color(0xFF6E655B),
    text3: Color(0xFF8A8073),
    text4: Color(0xFF9A9086),
    border: Color(0xFFEAE1D5),
    borderCard: Color(0xFFEEE5D9),
    chipBg: Color(0xFFEFE7DC),
    dashed: Color(0xFFCDBFAE),
    dashedText: Color(0xFFA58C6A),
    accent: Color(0xFFD9634E),
    accentStrong: Color(0xFFB84B38),
    accentSoft: Color(0xFFF6E3DC),
    danger: Color(0xFFC0392B),
    official: CategoryColor(Color(0xFFE7ECF2), Color(0xFF5B7A99)),
    fanArt: CategoryColor(Color(0xFFF6E7EA), Color(0xFFB76A7C)),
    draft: CategoryColor(Color(0xFFF1EAD9), Color(0xFFA9812F)),
    idea: CategoryColor(Color(0xFFF5EFCF), Color(0xFFA98A1E)),
    piece: CategoryColor(Color(0xFFFBE7E0), Color(0xFFC25436)),
  );

  static const dark = AppTokens(
    ground: Color(0xFF1B1816),
    surface: Color(0xFF26221F),
    nav: Color(0xFF211D1A),
    ink: Color(0xFFF2ECE4),
    text2: Color(0xFFB3A99C),
    text3: Color(0xFF9C9286),
    text4: Color(0xFF8C8378),
    border: Color(0xFF3A332D),
    borderCard: Color(0xFF35302B),
    chipBg: Color(0xFF332D28),
    dashed: Color(0xFF5A5047),
    dashedText: Color(0xFFB39A78),
    accent: Color(0xFFE27560),
    accentStrong: Color(0xFFE8876F),
    accentSoft: Color(0xFF3D2A24),
    danger: Color(0xFFF08A76),
    official: CategoryColor(Color(0xFF2B323A), Color(0xFF93AECB)),
    fanArt: CategoryColor(Color(0xFF3A2C30), Color(0xFFD99AAB)),
    draft: CategoryColor(Color(0xFF383126), Color(0xFFD6B267)),
    idea: CategoryColor(Color(0xFF37321F), Color(0xFFD9BD55)),
    piece: CategoryColor(Color(0xFF3E2A23), Color(0xFFE8876F)),
  );

  /// 換主題色：只替換 accent／strong／soft 三色（ColorSystem 色值表，淺／深各一組），其餘不變。
  AppTokens withAccent(AccentPreset preset, Brightness brightness) {
    if (preset == AccentPreset.coral) return this;
    final c = preset.colors(brightness);
    return AppTokens(
      ground: ground,
      surface: surface,
      nav: nav,
      ink: ink,
      text2: text2,
      text3: text3,
      text4: text4,
      border: border,
      borderCard: borderCard,
      chipBg: chipBg,
      dashed: dashed,
      dashedText: dashedText,
      accent: c.accent,
      accentStrong: c.strong,
      accentSoft: c.soft,
      danger: danger,
      official: official,
      fanArt: fanArt,
      draft: draft,
      idea: idea,
      piece: piece,
    );
  }

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 ? this : (other as AppTokens? ?? this);
}

/// 一個主題色在某個亮度下的三色。
class AccentColors {
  const AccentColors(this.accent, this.strong, this.soft);
  final Color accent;
  final Color strong;
  final Color soft;
}

/// 主題色預設（ColorSystem／HANDOFF 第 7 節）：珊瑚（預設）／霧藍／玫瑰／抹茶。
enum AccentPreset {
  coral(
    'coral',
    AccentColors(Color(0xFFD9634E), Color(0xFFB84B38), Color(0xFFF6E3DC)),
    AccentColors(Color(0xFFE27560), Color(0xFFE8876F), Color(0xFF3D2A24)),
  ),
  slate(
    'slate',
    AccentColors(Color(0xFF5B7A99), Color(0xFF46627E), Color(0xFFE3EAF1)),
    AccentColors(Color(0xFF7F9DBB), Color(0xFF93AECB), Color(0xFF26303A)),
  ),
  rose(
    'rose',
    AccentColors(Color(0xFFB76A7C), Color(0xFF9A5264), Color(0xFFF3E2E6)),
    AccentColors(Color(0xFFCF8A9B), Color(0xFFD99AAB), Color(0xFF3A2A2F)),
  ),
  matcha(
    'matcha',
    AccentColors(Color(0xFF7A8B5B), Color(0xFF627248), Color(0xFFE6EBDC)),
    AccentColors(Color(0xFF9AAB79), Color(0xFFADBD8C), Color(0xFF2D3324)),
  );

  const AccentPreset(this.key, this.light, this.dark);
  final String key;

  /// 顯示名稱（有 context 的地方用 [labelOf]）。
  String labelOf(AppLocalizations l) => switch (this) {
    coral => l.themeAccentCoral,
    slate => l.themeAccentSlate,
    rose => l.themeAccentRose,
    matcha => l.themeAccentMatcha,
  };

  String get label => labelOf(l10nStatic);
  final AccentColors light;
  final AccentColors dark;

  /// 淺色版 accent（色票圓點用）。
  Color get color => light.accent;

  AccentColors colors(Brightness b) => b == Brightness.dark ? dark : light;

  static AccentPreset fromKey(String? key) =>
      values.firstWhere((p) => p.key == key, orElse: () => coral);
}

/// 圓角規格（HANDOFF 第 6 節）。
abstract final class Radii {
  static const double card = 16;
  static const double image = 12;
  static const double chip = 999;
  static const double button = 14;

  /// 我的／主題色／備份頁的大卡片（設計稿 18）。
  static const double panel = 18;
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
