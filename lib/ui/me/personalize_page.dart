import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/app_icon.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import 'app_icon_image.dart';
import 'app_icon_page.dart';
import 'language_page.dart';
import 'me_widgets.dart';
import 'sensitive_settings_page.dart';
import 'theme_page.dart';

/// 主題色那一列右邊的字：「珊瑚 · 跟隨系統」。
String themeValueLabel(BuildContext context, AppSettings s) {
  final modeLabel = switch (s.themeMode) {
    ThemeMode.light => context.l10n.themeModeLight,
    ThemeMode.dark => context.l10n.themeModeDark,
    ThemeMode.system => context.l10n.themeModeSystem,
  };
  return context.l10n.meThemeValue(s.accent.labelOf(context.l10n), modeLabel);
}

/// 個人化（D-106，`Personalize`）：主題色、App 圖示、語言、敏感內容四列。
/// 「我的」→ 這裡 → 各子頁，子頁的返回都回到這一頁。沒有導覽列。
///
/// 個人化底下的四個子頁。
enum PersonalizeSub { theme, appIcon, language, sensitive }

/// [embedded]＝iPad「我的」右側內容面板（P-031）：點列時不 push，而是呼叫 [onOpen]，
/// 由「我的」把右欄換成那一頁（頂部有「‹ 個人化」返回，左欄仍亮「個人化」）。
class PersonalizePage extends ConsumerWidget {
  const PersonalizePage({super.key, this.embedded = false, this.onOpen});
  final bool embedded;
  final ValueChanged<PersonalizeSub>? onOpen;

  void _open(BuildContext context, PersonalizeSub sub, Widget page) {
    if (embedded && onOpen != null) {
      onOpen!(sub);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final appIcon = ref.watch(currentAppIconProvider);
    return MePageFrame(
      title: context.l10n.personalizeTitle,
      embedded: embedded,
      child: ListView(
        // 並排版的外框已留 20（標題另外縮進 40），內容與其他右欄頁一致。
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          MePanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  MeListRow(
                    icon: AppIcons.palette,
                    tileBg: t.piece.bg,
                    tileFg: t.piece.fg,
                    title: context.l10n.meThemeColor,
                    value: themeValueLabel(context, s),
                    onTap: () =>
                        _open(context, PersonalizeSub.theme, const ThemePage()),
                  ),
                  // App 圖示（D-086）：左邊是目前那款的小圖（不跟主題色），右邊是名稱。
                  MeListRow(
                    leading: AppIconImage(
                      appIcon,
                      size: 38,
                      radius: 11,
                      shadow: false,
                    ),
                    title: context.l10n.appiconTitle,
                    value: appIcon.name(context.l10n),
                    onTap: () => _open(
                      context,
                      PersonalizeSub.appIcon,
                      const AppIconPickPage(),
                    ),
                  ),
                  MeListRow(
                    icon: AppIcons.globe,
                    tileBg: dark
                        ? const Color(0xFF2E3528)
                        : const Color(0xFFE7EFE4),
                    tileFg: dark
                        ? const Color(0xFFA3B88A)
                        : const Color(0xFF6B7F5A),
                    title: context.l10n.meLanguage,
                    value: s.language.labelOf(context.l10n),
                    onTap: () => _open(
                      context,
                      PersonalizeSub.language,
                      const LanguagePage(),
                    ),
                  ),
                  MeListRow(
                    key: const ValueKey('personalizeSensitive'),
                    icon: AppIcons.eyeSlash,
                    tileBg: t.fanArt.bg,
                    tileFg: t.fanArt.fg,
                    iconSize: 20,
                    iconStroke: 1.9,
                    title: context.l10n.sensitiveTitle,
                    value: s.sensitiveEnabled
                        ? context.l10n.sensitiveValueOn
                        : context.l10n.sensitiveValueOff,
                    last: true,
                    onTap: () => _open(
                      context,
                      PersonalizeSub.sensitive,
                      const SensitiveSettingsPage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
