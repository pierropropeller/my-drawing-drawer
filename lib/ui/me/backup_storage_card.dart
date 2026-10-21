import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../sync/byte_size.dart';
import '../../sync/storage_usage.dart';
import '../../theme/tokens.dart';
import 'me_widgets.dart';

/// 備份與同步頁的「儲存空間」卡（Backup 稿，D-101）：右上「已用 / 總量」、一條分段進度條
/// （深藍＝畫匣、淺藍＝Drive 其他、米色＝剩餘）、下面兩個圖例。
///
/// 進入頁面時更新一次（之後同步結束由 [storageUsageProvider] 自己更新）。還沒有數字
/// （第一次載入中、離線、失敗）時整張卡不佔位；有過數字之後一律顯示上一次的值。
/// 帳號沒有上限時只顯示「已用 8.3 GB」，不畫進度條和圖例。
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
    if (info == null) return const SizedBox.shrink();
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    // 深藍／淺藍：稿的 #5B7A99／#C9D6E3；深色模式沒有畫，取官方圖分類的深色前景＋同色半透明。
    final drawerColor = dark ? t.official.fg : const Color(0xFF5B7A99);
    final otherColor = dark
        ? t.official.fg.withValues(alpha: 0.38)
        : const Color(0xFFC9D6E3);
    final limit = info.limit;
    final used = formatByteSize(info.usage);
    final drawer = formatByteSize(info.drawerBytes);
    final other = formatByteSize(info.otherBytes);

    final usedStyle = TextStyle(fontWeight: FontWeight.w700, color: t.ink);
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.backupStorageTitle, style: const TextStyle(fontSize: 14.5)),
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
        label: l10n.backupStorageSemantics(used, drawer, other),
        child: ExcludeSemantics(
          child: MePanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (limit != null) ...[
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
