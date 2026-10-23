import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';

/// 敏感內容（D-104）的確認視窗，樣式照 artboard `R18SettingsOff`／`OfficialSelectCover`：
/// 白底圓角 20、襯線標題 18／700、內文 14、右下「取消｜（紅色）確認」。回傳 true＝確認。
Future<bool> showSensitiveConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x6B1E1A17),
    builder: (ctx) {
      final t = ctx.tokens;
      return Dialog(
        key: const ValueKey('sensitiveConfirm'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        // iPad 稿（ProfileSensitive）：置中、360 寬。
        constraints: const BoxConstraints(maxWidth: 360),
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(ctx).textTheme.headlineSmall
                    ?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(fontSize: 14, height: 1.65, color: t.text2),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 6,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      ctx.l10n.commonCancel,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: t.text2,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok == true;
}

/// 關閉總開關前的確認（R18SettingsOff）。
Future<bool> confirmSensitiveMasterOff(BuildContext context) =>
    showSensitiveConfirm(
      context,
      title: context.l10n.sensitiveOffTitle,
      body: context.l10n.sensitiveOffBody,
      confirmLabel: context.l10n.sensitiveOffConfirm,
    );

/// 關閉某個坑的敏感內容前的確認（PitEditR18）；[count] 是坑內已標記的張數。
Future<bool> confirmSensitivePitOff(BuildContext context, int count) =>
    showSensitiveConfirm(
      context,
      title: context.l10n.sensitivePitOffTitle,
      body: context.l10n.sensitivePitOffBody(count),
      confirmLabel: context.l10n.sensitiveOffConfirm,
    );

/// 把現任封面標成敏感前的確認（OfficialSelectCover）；[count] 是選中的圖裡屬於封面的張數。
Future<bool> confirmSensitiveCover(BuildContext context, int count) =>
    showSensitiveConfirm(
      context,
      title: context.l10n.sensitiveCoverTitle,
      body: context.l10n.sensitiveCoverBody(count),
      confirmLabel: context.l10n.sensitiveCoverConfirm,
    );
