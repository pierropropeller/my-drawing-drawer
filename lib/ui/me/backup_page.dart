import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import '../login/sync_first_page.dart';
import '../pits/pit_form.dart';
import 'me_icons.dart';
import 'me_widgets.dart';
import '../../l10n/l10n.dart';

/// 備份與同步（Backup）：Google Drive 帳號、自動同步、前台自動刷新間隔、
/// 立即同步（主按鈕）、更換同步的 Google 帳號、取消連結。沒有導覽列。
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    try {
      final email = await ref.read(accountServiceProvider).signIn();
      ref.read(settingsProvider.notifier).setAccount(email);
      if (context.mounted) SyncFirstPage.open(context, ref);
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  Future<void> _switchAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.meBackupChangeAccountTitle),
        content: Text(ctx.l10n.meBackupChangeAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.meBackupChange),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(syncControllerProvider.notifier).switchAccount();
      // 新帳號也是首次同步。
      if (context.mounted && ref.read(firstSyncPendingProvider)) {
        SyncFirstPage.open(context, ref);
      }
    } catch (e) {
      if (context.mounted) showSnack(context, '$e');
    }
  }

  /// 取消連結只要一個確認視窗（BackupUnlink）：說明後果＋「取消」「確認取消連結」。
  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6B1E1A17),
      builder: (ctx) {
        final t = ctx.tokens;
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: t.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.meBackupUnlinkTitle,
                  style: Theme.of(ctx).textTheme.headlineSmall
                      ?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  ctx.l10n.meBackupUnlinkBody,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: dark ? t.text2 : const Color(0xFF4A453F),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: _dialogButton,
                      child: Text(
                        ctx.l10n.commonCancel,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: t.text2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: _dialogButton,
                      child: Text(
                        ctx.l10n.meBackupUnlinkConfirm,
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
    if (ok == true) {
      await ref.read(syncControllerProvider.notifier).disconnect();
    }
  }

  static final _dialogButton = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = ref.watch(settingsProvider);
    final sync = ref.watch(syncControllerProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final linked = s.accountEmail != null;
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final outline = fieldBorderColor(context);
    final green = dark ? const Color(0xFF8DBB8D) : const Color(0xFF5C8A5C);
    final syncing = sync.isSyncing;
    final lastBackup = syncing
        ? context.l10n.meBackupSyncing
        : meTimeLabel(sync.lastSyncAt);
    // 較新版本建立的備份：同步丟出的訊息就是「此備份由較新版本建立，請先更新 App」。
    final error = sync.phase == SyncPhase.error
        ? (sync.message ??
              (sync.needsAppUpdate
                  ? context.l10n.syncNeedsAppUpdate
                  : context.l10n.syncFailedShort))
        : null;

    Widget sub(String text) => Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(text, style: TextStyle(fontSize: 11.5, color: t.text3)),
    );

    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              MeSubHeader(context.l10n.meBackupSync),
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
                              color: dark
                                  ? t.official.bg
                                  : const Color(0xFFEAF0F5),
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
                                Text(
                                  'Google Drive',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  linked
                                      ? s.accountEmail!
                                      : context.l10n.meBackupNoAccount,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.text2,
                                  ),
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
                                  context.l10n.meBackupLinked,
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
                        onPressed: () => _link(context, ref),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(context.l10n.meBackupLinkGoogle),
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
                                        Text(
                                          context.l10n.meBackupAutoSync,
                                          style: TextStyle(fontSize: 14.5),
                                        ),
                                        sub(
                                          context.l10n.meBackupLastBackup(
                                            lastBackup,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppSwitch(
                                    value: s.autoSync,
                                    onChanged: notifier.setAutoSync,
                                    semanticLabel:
                                        context.l10n.meBackupAutoSync,
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
                                        Text(
                                          context
                                              .l10n
                                              .meBackupForegroundRefresh,
                                          style: TextStyle(fontSize: 14.5),
                                        ),
                                        sub(
                                          context
                                              .l10n
                                              .meBackupForegroundRefreshDesc,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  PopupMenuButton<int>(
                                    tooltip:
                                        context.l10n.meBackupRefreshInterval,
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
                                            context.l10n.meBackupEveryMinutes(
                                              m,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
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
                                            context.l10n.meBackupEveryMinutes(
                                              s.refreshMinutes,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
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
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error,
                          style: TextStyle(color: t.danger, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: syncing
                            ? null
                            : () async {
                                final ran = await ref
                                    .read(syncControllerProvider.notifier)
                                    .syncNow();
                                if (!ran && context.mounted) {
                                  showSnack(
                                    context,
                                    context.l10n.syncOffline,
                                    offline: true,
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const SvgIcon(
                          MeIcons.refresh,
                          size: 19,
                          strokeWidth: 1.9,
                          color: Colors.white,
                        ),
                        label: Text(context.l10n.meBackupSyncNow),
                      ),
                      const SizedBox(height: 10),
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
                                context.l10n.meBackupChangeAccount,
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
                    if (linked) ...[
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.meBackupDriveNote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: t.text3,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (linked)
                      Padding(
                        padding: const EdgeInsets.only(top: 34),
                        child: InkWell(
                          onTap: () => _unlink(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              context.l10n.meBackupUnlink,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.danger,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
