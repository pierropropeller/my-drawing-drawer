import '../../app_name.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/user_avatar.dart';
import 'backup_page.dart';
import 'me_widgets.dart';
import 'language_page.dart';
import 'theme_page.dart';

/// 我的：頭像、暱稱、編輯個人資料、主題色／備份與同步／關於 App 入口。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty) return;
    final store = await ref.read(imageStoreProvider.future);
    final im = await store.import(picked.first);
    ref.read(settingsProvider.notifier).setAvatar(im.file);
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await promptText(context, title: '暱稱', initial: current);
    if (name != null) ref.read(settingsProvider.notifier).setNickname(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final modeLabel = switch (s.themeMode) {
      ThemeMode.light => '淺色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟隨系統',
    };
    final backupLabel = s.accountEmail == null
        ? '未連結'
        : (sync.lastSyncAt == null ? '已連結' : meTimeLabel(sync.lastSyncAt));
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
                '我的',
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
                        GestureDetector(
                          onTap: () => _pickAvatar(context, ref),
                          child: UserAvatar(
                            size: 84,
                            serif: true,
                            background: Color.alphaBlend(
                              t.accent.withValues(alpha: dark ? 0.25 : 0.18),
                              t.ground,
                            ),
                            foreground: t.accent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.nickname.isEmpty ? '設定暱稱' : s.nickname,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _editProfile(context, ref, s.nickname),
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
                              '編輯個人資料',
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
                            title: '主題色',
                            value: '${s.accent.label} · $modeLabel',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ThemePage(),
                              ),
                            ),
                          ),
                          row(
                            icon: AppIcons.globe,
                            tileBg: t.draft.bg,
                            tileFg: t.draft.fg,
                            title: '語言',
                            value: s.language.label,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LanguagePage(),
                              ),
                            ),
                          ),
                          row(
                            icon: AppIcons.cloud,
                            tileBg: t.official.bg,
                            tileFg: t.official.fg,
                            title: '備份與同步',
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
                            title: '關於 App',
                            last: true,
                            onTap: () => showAboutDialog(
                              context: context,
                              applicationName: appName,
                              applicationLegalese: '把想畫的、畫好的，都收進坑裡。',
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
