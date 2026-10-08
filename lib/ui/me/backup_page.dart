import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/svg_icon.dart';
import 'me_widgets.dart';

/// 備份與同步：Google Drive 帳號、自動同步、前台自動刷新間隔、更換帳號。
/// 沒有手動備份按鈕；有網絡時自動上傳到 Google Drive 的 App 專用資料夾。
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  Future<void> _switchAccount(BuildContext context, WidgetRef ref) async {
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
      await ref.read(syncControllerProvider.notifier).switchAccount();
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final linked = s.accountEmail != null;
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final outline = dark ? t.border : const Color(0xFFE3D8C9);
    final green = dark ? const Color(0xFF8DBB8D) : const Color(0xFF5C8A5C);
    final syncing = sync.phase == SyncPhase.syncing;
    final lastBackup = syncing ? '同步中…' : meTimeLabel(sync.lastSyncAt);

    Widget sub(String text) => Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(text, style: TextStyle(fontSize: 11.5, color: t.text3)),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MeSubHeader('備份與同步'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  MePanel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: t.official.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: SvgIcon(
                              linked ? AppIcons.cloud : AppIcons.cloudOff,
                              size: 24,
                              color: t.official.fg,
                              strokeWidth: 1.7,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Google Drive',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                linked ? s.accountEmail! : '尚未連結 Google 帳號',
                                style: TextStyle(fontSize: 12, color: t.text2),
                              ),
                            ],
                          ),
                        ),
                        if (linked)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgIcon(
                                AppIcons.check,
                                size: 15,
                                color: green,
                                strokeWidth: 2.2,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '已連結',
                                style: TextStyle(
                                  color: green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (!linked) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final email = await ref
                              .read(accountServiceProvider)
                              .signIn();
                          notifier.setAccount(email);
                        } catch (e) {
                          if (context.mounted) showSnack(context, '$e');
                        }
                      },
                      child: const Text('連結 Google 帳號'),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    MePanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: divider),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '自動同步',
                                        style: TextStyle(fontSize: 14.5),
                                      ),
                                      sub('上次備份　$lastBackup'),
                                    ],
                                  ),
                                ),
                                AppSwitch(
                                  value: s.autoSync,
                                  onChanged: notifier.setAutoSync,
                                  semanticLabel: '自動同步',
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '前台自動刷新',
                                        style: TextStyle(fontSize: 14.5),
                                      ),
                                      sub('App 開啟時定期同步最新資料（跨設備）'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PopupMenuButton<int>(
                                  tooltip: '刷新間隔',
                                  initialValue: s.refreshMinutes,
                                  onSelected: notifier.setRefreshMinutes,
                                  color: t.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  itemBuilder: (_) => [
                                    for (final m in refreshOptions)
                                      PopupMenuItem(
                                        value: m,
                                        child: Text(
                                          '每 $m 分鐘',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      6,
                                      6,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: outline),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '每 ${s.refreshMinutes} 分鐘',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 2),
                                        SvgIcon(
                                          AppIcons.chevronDown,
                                          size: 16,
                                          color: t.text3,
                                          strokeWidth: 2,
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
                    if (sync.phase == SyncPhase.error &&
                        sync.message != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        sync.message!,
                        style: TextStyle(color: t.danger, fontSize: 13),
                      ),
                    ] else if (sync.lastResult != null &&
                        sync.lastResult!.changed) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${sync.lastResult}',
                        style: TextStyle(color: t.text3, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.button),
                      onTap: () => _switchAccount(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.button),
                          border: Border.all(color: outline, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgIcon(
                              AppIcons.swap,
                              size: 19,
                              color: t.text2,
                              strokeWidth: 1.8,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '更換同步的 Google 帳號',
                              style: TextStyle(
                                color: t.text2,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '上傳圖片時自動儲存至 Drive；離線時會在恢復網絡後立即補傳，無需手動備份。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: t.text3,
                      height: 1.5,
                    ),
                  ),
                  if (linked) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: syncing
                              ? null
                              : () async {
                                  final ran = await ref
                                      .read(syncControllerProvider.notifier)
                                      .syncNow();
                                  if (!ran && context.mounted) {
                                    showSnack(context, '目前離線，恢復網絡後將自動同步');
                                  }
                                },
                          child: Text(
                            '立即同步',
                            style: TextStyle(fontSize: 12.5, color: t.text2),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(syncControllerProvider.notifier)
                              .disconnect(),
                          child: Text(
                            '取消連結',
                            style: TextStyle(fontSize: 12.5, color: t.danger),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
