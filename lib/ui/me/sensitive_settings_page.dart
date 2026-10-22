import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../common/app_switch.dart';
import '../common/sensitive_dialogs.dart';
import 'me_widgets.dart';

/// 個人化 → 敏感內容（D-104，`R18Settings`／`R18SettingsOn`／`R18SettingsOff`）。
///
/// - 「敏感內容標記」總開關，預設關。關→開不用確認；開→關要確認（`R18SettingsOff`）。
/// - 「安全模式」只在總開關開著時出現（預設開），標題下面一行小字說明。
class SensitiveSettingsPage extends ConsumerWidget {
  const SensitiveSettingsPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final notifier = ref.read(settingsProvider.notifier);

    Future<void> setMaster(bool v) async {
      if (v) {
        notifier.setSensitiveEnabled(true);
        return;
      }
      if (await confirmSensitiveMasterOff(context)) {
        notifier.setSensitiveEnabled(false);
      }
    }

    return MePageFrame(
      title: context.l10n.sensitiveTitle,
      bottom: 12,
      embedded: embedded,
      child: ListView(
        padding: embedded
            ? const EdgeInsets.fromLTRB(0, 8, 0, 24)
            : const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          MePanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: s.sensitiveEnabled
                        ? Border(bottom: BorderSide(color: divider))
                        : null,
                  ),
                  child: Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.sensitiveMasterTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      AppSwitch(
                        key: const ValueKey('sensitiveMasterSwitch'),
                        value: s.sensitiveEnabled,
                        semanticLabel: context.l10n.sensitiveMasterTitle,
                        onChanged: setMaster,
                      ),
                    ],
                  ),
                ),
                if (s.sensitiveEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.sensitiveSafeModeTitle,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                context.l10n.sensitiveSafeModeHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: t.text3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSwitch(
                          key: const ValueKey('sensitiveSafeModeSwitch'),
                          value: s.safeMode,
                          semanticLabel: context.l10n.sensitiveSafeModeTitle,
                          onChanged: notifier.setSafeMode,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
