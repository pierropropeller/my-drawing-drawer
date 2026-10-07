import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../album/album_view.dart';
import '../entity/entity_widgets.dart';

/// 備份與同步：Google 帳號、自動同步、前台自動刷新間隔、更換帳號。
/// 沒有手動備份按鈕；有網絡時自動上傳到 Google Drive 的 App 專用資料夾。
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  String _ago(DateTime? t) {
    if (t == null) return '尚未同步';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '剛剛';
    if (d.inHours < 1) return '${d.inMinutes} 分鐘前';
    if (d.inDays < 1) return '${d.inHours} 小時前';
    return '${d.inDays} 天前';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final linked = s.accountEmail != null;
    return Scaffold(
      appBar: AppBar(title: const Text('備份與同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EntityCard(
            child: Row(
              children: [
                Icon(
                  linked ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: linked ? t.accent : t.text3,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linked ? '已連結' : '尚未連結 Google 帳號',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (linked)
                        Text(s.accountEmail!, style: TextStyle(color: t.text2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!linked)
            FilledButton(
              onPressed: () async {
                try {
                  final email = await ref.read(accountServiceProvider).signIn();
                  notifier.setAccount(email);
                } catch (e) {
                  if (context.mounted) showSnack(context, '$e');
                }
              },
              child: const Text('連結 Google 帳號'),
            )
          else ...[
            EntityCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '上次同步',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        sync.phase == SyncPhase.syncing
                            ? '同步中…'
                            : _ago(sync.lastSyncAt),
                        style: TextStyle(color: t.text2),
                      ),
                    ],
                  ),
                  if (sync.phase == SyncPhase.error &&
                      sync.message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      sync.message!,
                      style: TextStyle(color: t.danger, fontSize: 13),
                    ),
                  ] else if (sync.lastResult != null &&
                      sync.lastResult!.changed) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${sync.lastResult}',
                      style: TextStyle(color: t.text3, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自動同步'),
              value: s.autoSync,
              onChanged: notifier.setAutoSync,
            ),
            const SizedBox(height: 8),
            const FormLabel('前台自動刷新間隔'),
            ChipRow(
              padding: EdgeInsets.zero,
              allLabel: null,
              options: [for (final m in refreshOptions) ('$m', '每 $m 分鐘')],
              selected: '${s.refreshMinutes}',
              onSelected: (v) => notifier.setRefreshMinutes(int.parse(v!)),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: sync.phase == SyncPhase.syncing
                  ? null
                  : () async {
                      final ran = await ref
                          .read(syncControllerProvider.notifier)
                          .syncNow();
                      if (!ran && context.mounted) {
                        showSnack(context, '目前離線，恢復網絡後將自動同步');
                      }
                    },
              child: const Text('立即同步'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('更換同步的 Google 帳號？'),
                    content: const Text('本機的資料會整個上傳到新帳號，原帳號的備份不會被刪除。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('更換'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref
                      .read(syncControllerProvider.notifier)
                      .switchAccount();
                } catch (e) {
                  if (context.mounted) showSnack(context, '$e');
                }
              },
              child: const Text('更換帳號'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(syncControllerProvider.notifier).disconnect(),
              child: Text('取消連結', style: TextStyle(color: t.danger)),
            ),
          ],
        ],
      ),
    );
  }
}
