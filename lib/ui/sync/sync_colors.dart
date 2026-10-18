import 'package:flutter/material.dart';

/// 同步狀態的藍色系（D-052 指定固定色，沒有對應 token）；深色模式另給一組。
class SyncColors {
  const SyncColors._({
    required this.progress,
    required this.track,
    required this.strong,
    required this.tagBg,
    required this.waitTrack,
    required this.waitText,
    required this.divider,
    required this.badgeBg,
  });

  /// 進度（深藍 #5B7A99）。
  final Color progress;

  /// 底圈／進度條底（淺藍）。
  final Color track;

  /// 百分比、「已完成 / 總數」的文字藍。
  final Color strong;

  /// 上傳／下載標籤底色。
  final Color tagBg;

  /// 等待中的進度條底。
  final Color waitTrack;
  final Color waitText;

  /// 列與列之間的分隔線。
  final Color divider;

  /// 未下載角標的白色圓底。
  final Color badgeBg;

  static const light = SyncColors._(
    progress: Color(0xFF5B7A99),
    track: Color(0xFFD6E0EA),
    strong: Color(0xFF46627E),
    tagBg: Color(0xFFEAF0F5),
    waitTrack: Color(0xFFEAE4DA),
    waitText: Color(0xFFA49A8C),
    divider: Color(0xFFF1EADF),
    badgeBg: Color(0xF0FFFFFF),
  );

  /// 深色（P-022，SyncPopoverDark）：環 #7F9DBB、軌道 #2E3A46、文字 #93AECB。
  static const dark = SyncColors._(
    progress: Color(0xFF7F9DBB),
    track: Color(0xFF2E3A46),
    strong: Color(0xFF93AECB),
    tagBg: Color(0xFF26303A),
    waitTrack: Color(0xFF332D28),
    waitText: Color(0xFF8C8378),
    divider: Color(0xFF332D28),
    badgeBg: Color(0xF026221F),
  );

  static SyncColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
