/// D-090：顏文字用到的冷門字元，主字型（Noto Sans/Serif TC）沒有，
/// 往下找 bundled 的 fallback 字型（assets/fonts/，pubspec 註冊）。
///
/// 只有**單一** family：Flutter 切字型時，「底字＋組合字元」（例如 ก̀、(ᯫ᳐、▪͈）
/// 必須由同一個 family 同時涵蓋，否則整個 cluster 變豆腐。所以所有 Noto subset
/// （Latin／符號／數學／泰／坎那達／加拿大原住民／彝／阿拉伯／泰盧固／坦米爾／
/// 古木基／高棉／巴塔克／Mono）由 tool/merge_fonts.py 合併成 DrawerSymbols。
/// 不打包 NotoColorEmoji，emoji 交回系統字型。
const List<String> kFontFamilyFallback = ['DrawerSymbols'];
