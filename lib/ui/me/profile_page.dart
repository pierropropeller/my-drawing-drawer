import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/user_avatar.dart';
import 'about_page.dart';
import 'backup_page.dart';
import 'me_widgets.dart';
import 'language_page.dart';
import 'profile_edit_page.dart';
import 'theme_page.dart';
import '../../l10n/l10n.dart';

/// 我的：頭像、暱稱、編輯個人資料、主題色／備份與同步／關於 App 入口。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final modeLabel = switch (s.themeMode) {
      ThemeMode.light => context.l10n.themeModeLight,
      ThemeMode.dark => context.l10n.themeModeDark,
      ThemeMode.system => context.l10n.themeModeSystem,
    };
    final backupLabel = s.accountEmail == null
        ? context.l10n.meBackupNotLinked
        : (sync.lastSyncAt == null
              ? context.l10n.meBackupLinked
              : meTimeLabel(sync.lastSyncAt));
    final chevron = dark ? t.text4 : const Color(0xFFB7ADA0);
    final divider = dark ? t.border : const Color(0xFFF1EADF);

    Widget row({
      required String icon,
      required Color tileBg,
      required Color tileFg,
      required String title,
      String? value,
      required VoidCallback onTap,
      bool last = false,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: SvgIcon(icon, size: 21, color: tileFg, strokeWidth: 1.7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (value != null) ...[
              Text(value, style: TextStyle(fontSize: 13, color: t.text4)),
              const SizedBox(width: 12),
            ],
            SvgIcon(
              AppIcons.chevronRight,
              size: 18,
              color: chevron,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text(
                context.l10n.meTitle,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: 24),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 22),
                    child: Column(
                      children: [
                        UserAvatar(
                          size: 84,
                          serif: true,
                          background: t.accentSoft,
                          foreground: t.accent,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.nickname.isEmpty
                              ? context.l10n.meSetNickname
                              : s.nickname,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileEditPage(),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: t.surface,
                              borderRadius: BorderRadius.circular(Radii.chip),
                              border: Border.all(
                                color: dark
                                    ? t.border
                                    : const Color(0xFFE3D8C9),
                              ),
                            ),
                            child: Text(
                              context.l10n.meEditProfile,
                              style: TextStyle(fontSize: 12.5, color: t.text2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  MePanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          row(
                            icon: AppIcons.palette,
                            tileBg: t.piece.bg,
                            tileFg: t.piece.fg,
                            title: context.l10n.meThemeColor,
                            value: context.l10n.meThemeValue(
                              s.accent.labelOf(context.l10n),
                              modeLabel,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ThemePage(),
                              ),
                            ),
                          ),
                          row(
                            icon: AppIcons.globe,
                            // 設計稿的語言列是固定的綠色底（#E7EFE4／#6B7F5A），深色版沒有畫。
                            tileBg: dark
                                ? const Color(0xFF2E3528)
                                : const Color(0xFFE7EFE4),
                            tileFg: dark
                                ? const Color(0xFFA3B88A)
                                : const Color(0xFF6B7F5A),
                            title: context.l10n.meLanguage,
                            value: s.language.labelOf(context.l10n),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LanguagePage(),
                              ),
                            ),
                          ),
                          row(
                            icon: AppIcons.cloud,
                            tileBg: dark
                                ? t.official.bg
                                : const Color(0xFFEAF0F5),
                            tileFg: t.official.fg,
                            title: context.l10n.meBackupSync,
                            value: backupLabel,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BackupPage(),
                              ),
                            ),
                          ),
                          row(
                            icon: AppIcons.info,
                            tileBg: dark ? t.chipBg : const Color(0xFFEEEAE2),
                            tileFg: t.text3,
                            title: context.l10n.meAbout,
                            last: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AboutPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
