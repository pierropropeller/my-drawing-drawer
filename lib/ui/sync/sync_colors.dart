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
    required this.doneFill,
    required this.doneCheck,
    required this.doneText,
    required this.failedFill,
    required this.failedText,
    required this.failedRowText,
    required this.failedDot,
    required this.fullDot,
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

  /// 同步完成（D-100，SyncSheetDone）：綠色勾圈、全滿進度條 #5c8a5c。
  final Color doneFill;

  /// 勾圈裡的勾。
  final Color doneCheck;

  /// 右上「N / N」綠字 #4E7A4E。
  final Color doneText;

  /// 部分失敗（D-109，SyncSheetPartial）：琥珀圓 #D9A23C、右上「成功 / 總數」字 #8a6a1f、
  /// 列尾「失敗」#B8860B。
  final Color failedFill;
  final Color failedText;
  final Color failedRowText;

  /// 頭像小點：琥珀（有失敗）／紅（Drive 已滿，BackupFull 的 #C0392B）。
  final Color failedDot;
  final Color fullDot;

  static const light = SyncColors._(
    progress: Color(0xFF5B7A99),
    track: Color(0xFFD6E0EA),
    strong: Color(0xFF46627E),
    tagBg: Color(0xFFEAF0F5),
    waitTrack: Color(0xFFEAE4DA),
    waitText: Color(0xFFA49A8C),
    divider: Color(0xFFF1EADF),
    badgeBg: Color(0xF0FFFFFF),
    doneFill: Color(0xFF5C8A5C),
    doneCheck: Color(0xFFFFFFFF),
    doneText: Color(0xFF4E7A4E),
    failedFill: Color(0xFFD9A23C),
    failedText: Color(0xFF8A6A1F),
    failedRowText: Color(0xFFB8860B),
    failedDot: Color(0xFFD9A23C),
    fullDot: Color(0xFFC0392B),
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
    // 設計稿沒有深色完成稿：沿用備份頁深色模式的綠 #8DBB8D，勾用深底色。
    doneFill: Color(0xFF8DBB8D),
    doneCheck: Color(0xFF26221F),
    doneText: Color(0xFF8DBB8D),
    // 設計稿沒有深色部分失敗稿：琥珀圓沿用 #D9A23C（深底上夠亮），文字提亮成 #E3BE6E。
    failedFill: Color(0xFFD9A23C),
    failedText: Color(0xFFE3BE6E),
    failedRowText: Color(0xFFE3BE6E),
    failedDot: Color(0xFFD9A23C),
    fullDot: Color(0xFFE0675A),
  );

  static SyncColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
