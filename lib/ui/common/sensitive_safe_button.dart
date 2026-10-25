import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/entity_queries.dart' show ImageRef;
import '../../l10n/l10n.dart';
import '../../state/sensitive.dart';
import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../album/wide_layout.dart' show WideIconButton;
import 'app_icons.dart';
import 'svg_icon.dart';

/// 詳情頁的圖片檔名（影片、GIF 也算：安全模式開時它們顯示模糊的第一格，D-113 ①）。
List<String> flaggableFiles(Iterable<ImageRef> images) => [
  for (final i in images) i.file,
];

/// 詳情頁／圖片預覽頁標題列的「安全模式」快捷鈕（D-110，`DraftDetailSafe`／`ImagePreviewSafe`）。
///
/// 只在這一頁有「有效敏感」的圖（總開關開、坑開、圖片有標記）時才出現：
/// - 安全模式開：眼睛斜線；點一下直接關閉安全模式（同「個人化 → 敏感內容 → 安全模式」，全 App 生效，不確認）。
/// - 安全模式關：眼睛；點一下重新開啟。
/// 總開關關、這一頁沒有標記的圖、或標記清單還沒查完：什麼都不畫。列表頁不放這顆鈕。
class SensitiveSafeToggle extends ConsumerWidget {
  const SensitiveSafeToggle({
    super.key,
    required this.files,
    required this.builder,
  });

  /// 這一頁所有（可能被模糊的）圖檔名。
  final Iterable<String> files;

  /// [safe]＝目前安全模式開（畫眼睛斜線）；[label]＝提示／語意文字；[onTap]＝切換。
  final Widget Function(
    BuildContext context,
    bool safe,
    String label,
    VoidCallback onTap,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsProvider.select((s) => s.sensitiveEnabled))) {
      return const SizedBox.shrink();
    }
    final flagged = ref.watch(sensitiveFilesProvider).value;
    if (flagged == null || !files.any(flagged.contains)) {
      return const SizedBox.shrink();
    }
    final safe = ref.watch(settingsProvider.select((s) => s.safeMode));
    final l = context.l10n;
    return builder(
      context,
      safe,
      safe ? l.sensitiveSafeTurnOff : l.sensitiveSafeTurnOn,
      () => ref.read(settingsProvider.notifier).setSafeMode(!safe),
    );
  }
}

/// 手機標題列用的 40×40 圖示鈕（icon 21、線寬 1.9，`DraftDetailSafe`）。
class SensitiveSafeButton extends StatelessWidget {
  const SensitiveSafeButton({super.key, required this.files, this.color});

  final Iterable<String> files;

  /// icon 顏色；null＝跟著 [IconTheme]／文字色。
  final Color? color;

  @override
  Widget build(BuildContext context) => SensitiveSafeToggle(
    files: files,
    builder: (context, safe, label, onTap) => Semantics(
      button: true,
      toggled: safe,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const ValueKey('sensitiveSafeButton'),
          radius: 24,
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SvgIcon(
                safe ? AppIcons.eyeSlash : AppIcons.eye,
                size: 21,
                strokeWidth: 1.9,
                color: color ?? context.tokens.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// iPad／寬版面板用的 44×44 方鈕（同編輯、刪除的 [WideIconButton]）。
class SensitiveSafeWideButton extends StatelessWidget {
  const SensitiveSafeWideButton({super.key, required this.files, this.gap = 0});

  final Iterable<String> files;

  /// 按鈕右邊的間距（按鈕沒出現時間距也不佔位）。
  final double gap;

  @override
  Widget build(BuildContext context) => SensitiveSafeToggle(
    files: files,
    builder: (context, safe, label, onTap) => Padding(
      padding: EdgeInsets.only(right: gap),
      child: Tooltip(
        message: label,
        child: Tooltip(
          message: label,
          child: WideIconButton(
            key: const ValueKey('sensitiveSafeButton'),
            svg: safe ? AppIcons.eyeSlash : AppIcons.eye,
            label: label,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}

/// 面板沒有標題列時（官方／同人預覽面板、成圖面板）：這一頁有標記的圖才多一列，右上放 [SensitiveSafeWideButton]。
class SensitiveSafePanelBar extends StatelessWidget {
  const SensitiveSafePanelBar({super.key, required this.files});

  final Iterable<String> files;

  @override
  Widget build(BuildContext context) => SensitiveSafeToggle(
    files: files,
    builder: (context, safe, label, onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: label,
          child: WideIconButton(
            key: const ValueKey('sensitiveSafeButton'),
            svg: safe ? AppIcons.eyeSlash : AppIcons.eye,
            label: label,
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
}
