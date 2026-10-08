import 'package:flutter/material.dart';

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
    danger: Color(0xFFF08A76),
    official: CategoryColor(Color(0xFF2B323A), Color(0xFF93AECB)),
    fanArt: CategoryColor(Color(0xFF3A2C30), Color(0xFFD99AAB)),
    draft: CategoryColor(Color(0xFF383126), Color(0xFFD6B267)),
    idea: CategoryColor(Color(0xFF37321F), Color(0xFFD9BD55)),
    piece: CategoryColor(Color(0xFF3E2A23), Color(0xFFE8876F)),
  );

  /// 換主題色：只替換 accent／accentStrong，其餘不變。
  AppTokens withAccent(AccentPreset preset, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (preset == AccentPreset.coral) return this;
    final base = HSLColor.fromColor(preset.color);
    // 深色版：提亮一點讓它在深底上仍清楚；Strong 為更深（淺色）或更亮（深色）的版本。
    final a = dark
        ? base.withLightness((base.lightness + 0.08).clamp(0, 1))
        : base;
    final strong = dark
        ? base.withLightness((base.lightness + 0.14).clamp(0, 1))
        : base.withLightness((base.lightness - 0.09).clamp(0, 1));
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
      accent: a.toColor(),
      accentStrong: strong.toColor(),
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

/// 主題色預設（Theme 設計稿）：珊瑚（預設）／霧藍／玫瑰／抹茶。
enum AccentPreset {
  coral('coral', '珊瑚', Color(0xFFD9634E)),
  slate('slate', '霧藍', Color(0xFF5B7A99)),
  rose('rose', '玫瑰', Color(0xFFB76A7C)),
  matcha('matcha', '抹茶', Color(0xFF7A8B5B));

  const AccentPreset(this.key, this.label, this.color);
  final String key;
  final String label;
  final Color color;

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
