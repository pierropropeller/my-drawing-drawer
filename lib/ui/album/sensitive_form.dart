import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/media.dart';
import '../../l10n/l10n.dart';
import '../../state/sensitive.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/app_switch.dart';
import '../common/sensitive_gate.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';
import 'image_picker_field.dart';

/// 表單的敏感內容標記（D-104）共用元件：新增／編輯頁的圖片欄（官方圖、同人圖、腦洞、摸魚、成圖、推活）
/// 與表單內預覽頁都用這幾個。總開關＋該坑開關都開了才出現（見 [sensitiveMarkingProvider]）。

/// 圖片列下面一行：「全部標為敏感」＋已標張數「1 / 2」＋開關（OfficialNewR18）。
/// 全部都標了才是開；按開＝全部標、按關＝全部取消。沒有圖時不顯示。
class SensitiveMarkAllRow extends ConsumerWidget {
  const SensitiveMarkAllRow({super.key, required this.items, this.pitId});

  final List<ImageItem> items;

  /// 表單所在的坑；null＝不處理（不出現）。
  final String? pitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pitId == null || !ref.watch(sensitiveMarkingProvider(pitId))) {
      return const SizedBox.shrink();
    }
    if (items.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return ListenableBuilder(
      listenable: Listenable.merge(items),
      builder: (context, _) {
        final marked = items.where((i) => i.sensitive).length;
        final all = marked == items.length;
        return Container(
          key: const ValueKey('sensitiveMarkAll'),
          // iPad（NewOfficialSensitive）離圖片格 16，手機 12。
          margin: EdgeInsets.only(
            top: WindowClass.of(context).isCompact ? 12 : 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.borderCard),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.sensitiveMarkAll,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                context.l10n.sensitiveMarkedCount(marked, items.length),
                key: const ValueKey('sensitiveMarkedCount'),
                style: TextStyle(fontSize: 13, color: t.text3),
              ),
              const SizedBox(width: 10),
              AppSwitch(
                value: all,
                semanticLabel: context.l10n.sensitiveMarkAll,
                onChanged: (v) {
                  for (final i in items) {
                    i.sensitive = v;
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 表單裡小縮圖的敏感小標（不模糊，只在左下角顯示，方便看清楚自己在標哪張）。
/// 影片／GIF 的左下角已有媒體小標，這種放左上角。
/// 在縮圖的 Stack 裡用 `Positioned.fill(child: IgnorePointer(child: FormSensitiveBadge(...)))`。
class FormSensitiveBadge extends ConsumerWidget {
  const FormSensitiveBadge({
    super.key,
    required this.item,
    required this.pitId,
    this.inset = 6,
  });

  final ImageItem item;
  final String? pitId;
  final double inset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pitId == null || !ref.watch(sensitiveMarkingProvider(pitId))) {
      return const SizedBox.shrink();
    }
    final path = item.stored?.file ?? item.picked!.path;
    final kind = item.stored?.kind ?? mediaKindFromExtension(path);
    final top = kind != MediaKind.image;
    return ListenableBuilder(
      listenable: item,
      builder: (context, _) => item.sensitive
          ? Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: inset,
                  bottom: top ? null : inset,
                  top: top ? inset : null,
                  child: const SensitiveBadge(),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

/// 表單內預覽右上角的逐張標記鈕（FormImagePreviewR18／FormImagePreviewR18Off）：
/// 未標記＝淡色外框＋「眼睛」＋「標為敏感」；已標記＝主色實心＋「眼睛斜線」＋「已標為敏感」。
class SensitivePreviewToggle extends StatelessWidget {
  const SensitivePreviewToggle({
    super.key,
    required this.marked,
    required this.onTap,
  });

  final bool marked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const fg = Color(0xFFF5F0E8);
    final label = marked
        ? context.l10n.sensitiveMarkedImage
        : context.l10n.sensitiveMarkImage;
    return Semantics(
      button: true,
      toggled: marked,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: const ValueKey('sensitivePreviewToggle'),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: marked ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: marked ? t.accent : fg.withValues(alpha: .45),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              SvgIcon(
                marked ? AppIcons.eyeSlash : AppIcons.eye,
                size: 15,
                strokeWidth: marked ? 2.2 : 2,
                color: marked ? Colors.white : fg,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: marked ? FontWeight.w700 : FontWeight.w600,
                  color: marked ? Colors.white : fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
