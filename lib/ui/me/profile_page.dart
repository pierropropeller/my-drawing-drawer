import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/user_avatar.dart';
import 'backup_page.dart';
import 'theme_page.dart';

/// 我的：頭像、暱稱、主題、備份與同步入口。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(imagePickerProvider)();
    if (picked.isEmpty) return;
    final store = await ref.read(imageStoreProvider.future);
    final im = await store.import(picked.first);
    ref.read(settingsProvider.notifier).setAvatar(im.file);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final themeLabel = switch (s.themeMode) {
      ThemeMode.light => '淺色',
      ThemeMode.dark => '深色',
      ThemeMode.system => '跟隨系統',
    };
    Widget row(
      IconData icon,
      String title,
      String? trailing,
      VoidCallback onTap,
    ) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: t.borderCard),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon, color: t.text2),
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                Text(trailing, style: TextStyle(color: t.text3)),
              Icon(Icons.chevron_right, color: t.text4),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () => _pickAvatar(context, ref),
              child: const UserAvatar(size: 88),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                final name = await promptText(
                  context,
                  title: '暱稱',
                  initial: s.nickname,
                );
                if (name != null) {
                  ref.read(settingsProvider.notifier).setNickname(name);
                }
              },
              child: Text(
                s.nickname.isEmpty ? '設定暱稱' : s.nickname,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          row(Icons.palette_outlined, '主題', themeLabel, () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ThemePage()));
          }),
          row(
            Icons.cloud_sync_outlined,
            '備份與同步',
            s.accountEmail == null ? '未連結' : '已連結',
            () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackupPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
