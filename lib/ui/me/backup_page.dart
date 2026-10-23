import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../sync/storage_usage.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import '../login/sync_first_page.dart';
import '../pits/pit_form.dart';
import 'backup_storage_card.dart';
import 'me_icons.dart';
import 'me_widgets.dart';
import '../../l10n/l10n.dart';

/// 備份與同步（Backup）：Google Drive 帳號、自動同步、前台自動刷新間隔、
/// 立即同步（主按鈕）、更換同步的 Google 帳號、取消連結。沒有導覽列。
class BackupPage extends ConsumerWidget {
  const BackupPage({super.key, this.embedded = false});

  /// 在 iPad「我的」右側面板裡顯示（沒有返回列、不藏導覽）。
  final bool embedded;

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
        // ≥600（iPad）：BackupUnlink 稿的置中 alert（340 寬、底部左右兩個全寬按鈕）；
        // 彈出期間拉窗跨過 600 會即時換樣式。
        if (WindowClass.of(ctx).hasSideNav) return const _UnlinkAlertWide();
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
    // iPad 右側面板（Backup 稿 1194）：卡片較寬、開關 51×31、間隔改分段、兩顆按鈕並排。
    final wide = embedded;
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final outline = fieldBorderColor(context);
    final green = dark ? const Color(0xFF8DBB8D) : const Color(0xFF5C8A5C);
    final syncing = sync.isSyncing;
    // Drive 已滿（D-103）：自動同步下面的小字改成紅色「上傳暫停　下載正常」。
    final driveFull = ref.watch(driveFullProvider);
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

    Widget sub(String text, {Color? color}) => Padding(
      padding: EdgeInsets.only(top: wide ? 2 : 1),
      child: Text(
        text,
        style: TextStyle(fontSize: wide ? 12.5 : 11.5, color: color ?? t.text3),
      ),
    );

    final syncNowButton = FilledButton.icon(
      onPressed: syncing
          ? null
          : () async {
              final ran = await ref
                  .read(syncControllerProvider.notifier)
                  .syncNow();
              if (!ran && context.mounted) {
                showSnack(context, context.l10n.syncOffline, offline: true);
              }
            },
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: wide ? 0 : 13),
        minimumSize: wide ? const Size.fromHeight(48) : null,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      // 不指定顏色：icon 跟著按鈕的前景色走，可按時白、同步中（停用）時和文字同一個灰
      // （之前寫死白色，停用時 icon 比文字亮）。
      icon: const SvgIcon(MeIcons.refresh, size: 19, strokeWidth: 1.9),
      label: Text(context.l10n.meBackupSyncNow),
    );
    final switchButton = InkWell(
      borderRadius: BorderRadius.circular(Radii.button),
      onTap: () => _switchAccount(context, ref),
      child: Container(
        height: wide ? 48 : null,
        alignment: wide ? Alignment.center : null,
        padding: EdgeInsets.symmetric(vertical: wide ? 0 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: outline, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgIcon(AppIcons.swap, size: 19, color: t.text2, strokeWidth: 1.8),
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
    );

    return MePageFrame(
      title: context.l10n.meBackupSync,
      bottom: 12,
      embedded: embedded,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          MePanel(
            padding: wide
                ? const EdgeInsets.symmetric(horizontal: 20, vertical: 18)
                : const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: wide ? 46 : 44,
                  height: wide ? 46 : 44,
                  decoration: BoxDecoration(
                    color: dark ? t.official.bg : const Color(0xFFEAF0F5),
                    borderRadius: BorderRadius.circular(wide ? 13 : 12),
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
                SizedBox(width: wide ? 14 : 12),
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
                          fontSize: wide ? 13 : 12,
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
                          fontSize: wide ? 13 : 12,
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
            SizedBox(height: wide ? 16 : 14),
            BackupStorageCard(wide: wide),
            MePanel(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 20 : 16,
                vertical: wide ? 4 : 2,
              ),
              child: Column(
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: wide ? 64 : 0),
                    padding: EdgeInsets.symmetric(vertical: wide ? 10 : 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: divider)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.meBackupAutoSync,
                                style: TextStyle(fontSize: wide ? 15 : 14.5),
                              ),
                              if (driveFull)
                                sub(
                                  context.l10n.meBackupUploadPaused,
                                  color: t.danger,
                                )
                              else
                                sub(
                                  context.l10n.meBackupLastBackup(lastBackup),
                                ),
                            ],
                          ),
                        ),
                        AppSwitch(
                          large: wide,
                          value: s.autoSync,
                          onChanged: notifier.setAutoSync,
                          semanticLabel: context.l10n.meBackupAutoSync,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(minHeight: wide ? 64 : 0),
                    padding: EdgeInsets.symmetric(vertical: wide ? 10 : 14),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.meBackupForegroundRefresh,
                                style: TextStyle(fontSize: wide ? 15 : 14.5),
                              ),
                              sub(context.l10n.meBackupForegroundRefreshDesc),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (wide)
                          _IntervalSegments(
                            value: s.refreshMinutes,
                            onChanged: notifier.setRefreshMinutes,
                          )
                        else
                          PopupMenuButton<int>(
                            tooltip: context.l10n.meBackupRefreshInterval,
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
                                    context.l10n.meBackupEveryMinutes(m),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
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
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error, style: TextStyle(color: t.danger, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                children: [
                  Expanded(child: syncNowButton),
                  const SizedBox(width: 12),
                  Expanded(child: switchButton),
                ],
              )
            else ...[
              syncNowButton,
              const SizedBox(height: 10),
              switchButton,
            ],
          ],
          if (linked) ...[
            SizedBox(height: wide ? 12 : 10),
            Text(
              context.l10n.meBackupDriveNote,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(
                fontSize: wide ? 12.5 : 11.5,
                color: t.text3,
                height: wide ? 1.6 : 1.5,
              ),
            ),
          ],
          if (linked)
            Padding(
              padding: EdgeInsets.only(top: wide ? 28 : 34),
              child: Align(
                alignment: wide ? Alignment.centerLeft : Alignment.center,
                widthFactor: wide ? 1 : null,
                child: InkWell(
                  onTap: () => _unlink(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.l10n.meBackupUnlink,
                      textAlign: wide ? TextAlign.start : TextAlign.center,
                      style: TextStyle(
                        fontSize: wide ? 14.5 : 14,
                        fontWeight: FontWeight.w600,
                        color: t.danger,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 前台自動刷新間隔的分段選擇（Backup 稿 1194）：1／5／15／30 分鐘。
class _IntervalSegments extends StatelessWidget {
  const _IntervalSegments({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      container: true,
      label: context.l10n.meBackupRefreshInterval,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: dark ? t.chipBg : const Color(0xFFF3EDE4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            for (final m in refreshOptions)
              Semantics(
                button: true,
                selected: m == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(m),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(
                      widthFactor: 1,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m == value ? t.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: m == value
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          context.l10n.ipadsyncMinutes(m),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: m == value
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ≥600 的取消連結確認（BackupUnlink 稿）：置中 alert，340 寬，文字置中，
/// 底部「取消」「確認取消連結」兩個全寬按鈕（50 高）以細線分隔。回傳 true＝確認。
class _UnlinkAlertWide extends StatelessWidget {
  const _UnlinkAlertWide();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? t.border : const Color(0xFFEEE5D9);
    Widget action(String label, bool confirm) => Expanded(
      child: InkWell(
        onTap: () => Navigator.pop(context, confirm),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: confirm ? null : Border(right: BorderSide(color: line)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: confirm ? FontWeight.w700 : FontWeight.w600,
              color: confirm ? t.danger : t.text2,
            ),
          ),
        ),
      ),
    );
    return Dialog(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.meBackupUnlinkTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.meBackupUnlinkBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: dark ? t.text2 : const Color(0xFF4A453F),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            Row(
              children: [
                action(context.l10n.commonCancel, false),
                action(context.l10n.meBackupUnlinkConfirm, true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
