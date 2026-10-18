/// D-090：顏文字用到的冷門字元，主字型（Noto Sans/Serif TC）沒有，
/// 依序往下找 bundled 的 fallback 字型（assets/fonts/，pubspec 註冊）。
/// 不打包 NotoColorEmoji，emoji 交回系統字型。
const List<String> kFontFamilyFallback = [
  'NotoSansTC',
  'NotoSans', // 含 IPA 擴充，例如 ᴗ
  'NotoSansSymbols',
  'NotoSansSymbols2', // ✧ 等符號
  'NotoSansMath', // ≖ 等數學符號
  'NotoSansThai', // ๑
  'NotoSansKannada', // ಠ
  'NotoSansCanadianAboriginal', // ᐛ ᐕ
  'NotoSansYi', // ꒰ ꒱
  // 第二批顏文字：其他文字系統的數字／符號。
  'NotoSansArabic', // ٩ ۶ و
  'NotoSansTelugu', // ౪
  'NotoSansTamil', // இ
  'NotoSansGurmukhi', // ੭
  'NotoSansKhmer', // ៸
  'NotoSansBatak', // ᯫ
  'NotoSansMono', // ⎻ ╤ ╦ ─
];
