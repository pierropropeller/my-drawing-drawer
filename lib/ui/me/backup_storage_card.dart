import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';
import '../../sync/byte_size.dart';
import '../../sync/storage_usage.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import 'me_icons.dart';
import 'me_widgets.dart';

/// 管理 Google 儲存空間（D-103）。
final googleStorageUri = Uri.parse('https://one.google.com/storage');

/// 開啟 [googleStorageUri]；測試可覆寫。失敗（沒有瀏覽器）不報錯。
final openGoogleStorageProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    try {
      await launchUrl(googleStorageUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  },
);

/// 備份與同步頁的「儲存空間」卡（Backup 稿，D-101）：右上「已用 / 總量」、一條分段進度條
/// （深藍＝畫匣、淺藍＝Drive 其他、米色＝剩餘）、下面兩個圖例。
///
/// 進入頁面時更新一次（之後同步結束由 [storageUsageProvider] 自己更新）。還沒有數字
/// （第一次載入中、離線、失敗）時整張卡不佔位；有過數字之後一律顯示上一次的值。
/// 帳號沒有上限時只顯示「已用 8.3 GB」，不畫進度條和圖例。
///
/// Drive 已滿（D-103，BackupFull 稿）：紅框、標題「Drive 已滿」、數字和進度條變紅；卡片下方
/// 一行「N 張未上傳」＋右邊「管理 Google 儲存空間 ↗」。已滿但還沒有用量數字（上傳被拒絕、
/// 用量讀不到）時，卡片只有標題和下方那一行。
class BackupStorageCard extends ConsumerStatefulWidget {
  const BackupStorageCard({super.key});

  @override
  ConsumerState<BackupStorageCard> createState() => _BackupStorageCardState();
}

class _BackupStorageCardState extends ConsumerState<BackupStorageCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(storageUsageProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(storageUsageProvider);
    final full = ref.watch(driveFullProvider);
    final unuploaded = ref.watch(
      syncControllerProvider.select((s) => s.unuploadedCount),
    );
    if (info == null && !full) return const SizedBox.shrink();
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    // 深藍／淺藍：稿的 #5B7A99／#C9D6E3；深色模式沒有畫，取官方圖分類的深色前景＋同色半透明。
    // 已滿：紅 #C0392B／淺紅 #E7B9AE（深色模式沒有畫，取 danger token＋同色半透明）。
    final drawerColor = full
        ? t.danger
        : dark
        ? t.official.fg
        : const Color(0xFF5B7A99);
    final otherColor = full
        ? (dark ? t.danger.withValues(alpha: 0.38) : const Color(0xFFE7B9AE))
        : dark
        ? t.official.fg.withValues(alpha: 0.38)
        : const Color(0xFFC9D6E3);
    final limit = info?.limit;
    final used = info == null ? '' : formatByteSize(info.usage);
    final drawer = info == null ? '' : formatByteSize(info.drawerBytes);
    final other = info == null ? '' : formatByteSize(info.otherBytes);

    final usedStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: full ? t.danger : t.ink,
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          full ? l10n.backupFullTitle : l10n.backupStorageTitle,
          style: full
              ? TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: t.danger,
                )
              : const TextStyle(fontSize: 14.5),
        ),
        if (info != null)
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, color: t.text2),
              children: [
                if (limit == null)
                  TextSpan(text: '${l10n.backupStorageUsedLabel} '),
                TextSpan(text: used, style: usedStyle),
                if (limit != null)
                  TextSpan(
                    text: l10n.backupStorageOfLimit(formatByteSize(limit)),
                  ),
              ],
            ),
          ),
      ],
    );

    Widget legend(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: dark ? t.text2 : const Color(0xFF4A453F),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Semantics(
        container: true,
        label: info == null
            ? l10n.backupFullTitle
            : l10n.backupStorageSemantics(used, drawer, other),
        child: ExcludeSemantics(
          excluding: !full,
          child: MePanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            borderColor: full
                ? (dark
                      ? t.danger.withValues(alpha: 0.5)
                      : const Color(0xFFE7B9AE))
                : null,
            borderWidth: full ? 1.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (info != null && limit != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      key: const ValueKey('storageBar'),
                      height: 8,
                      color: t.chipBg,
                      child: LayoutBuilder(
                        builder: (_, c) => Row(
                          children: [
                            Container(
                              key: const ValueKey('storageBarDrawer'),
                              width: c.maxWidth * info.drawerFraction,
                              color: drawerColor,
                            ),
                            Container(
                              key: const ValueKey('storageBarOther'),
                              width: c.maxWidth * info.otherFraction,
                              color: otherColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      legend(drawerColor, l10n.backupStorageDrawer(drawer)),
                      legend(otherColor, l10n.backupStorageOther(other)),
                    ],
                  ),
                ],
                if (full) _FullFooter(unuploaded: unuploaded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 已滿時卡片下方：左「N 張未上傳」（N 粗體；不知道張數時不寫），右「管理 Google 儲存空間 ↗」。
class _FullFooter extends ConsumerWidget {
  const _FullFooter({required this.unuploaded});
  final int unuploaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final linkColor = dark ? t.accent : const Color(0xFFC25436);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: dark ? t.border : const Color(0xFFF1EADF)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (unuploaded > 0)
            Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 14, color: t.ink),
                children: [
                  TextSpan(
                    text: l10n.backupFullCount(unuploaded),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: l10n.backupFullUnuploaded),
                ],
              ),
            )
          else
            const SizedBox.shrink(),
          Semantics(
            button: true,
            child: InkWell(
              key: const Key('drive-full-manage'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => ref.read(openGoogleStorageProvider)(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.backupFullManage,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: linkColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    SvgIcon(
                      MeIcons.externalLink,
                      size: 14,
                      strokeWidth: 2,
                      color: linkColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
