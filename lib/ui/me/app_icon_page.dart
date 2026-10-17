import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/app_icon.dart';
import '../../theme/tokens.dart';
import '../album/album_actions.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'app_icon_image.dart';
import 'me_widgets.dart';

/// App 圖示（AppIconPick）：兩欄大卡，選中＝主題色框＋右上勾；撳一下即換桌面圖示，
/// 底部提示「桌面圖示已換成「三筆」」。沒有導覽列。卡片由 [appIconOptions] 清單產生。
class AppIconPickPage extends ConsumerWidget {
  const AppIconPickPage({super.key, this.embedded = false});

  /// 在 iPad「我的」右側面板裡顯示（沒有返回列、不藏導覽）。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentAppIconProvider);
    return MePageFrame(
      title: context.l10n.appiconTitle,
      bottom: 8,
      embedded: embedded,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 14.0;
              final w = (box.maxWidth - gap) / 2;
              return Semantics(
                container: true,
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final o in appIconOptions)
                      SizedBox(
                        width: w,
                        child: _IconCard(
                          option: o,
                          selected: o.key == current.key,
                          onTap: () async {
                            if (o.key == current.key) return;
                            final l = context.l10n;
                            final ok = await selectAppIcon(ref, o);
                            if (ok && context.mounted) {
                              showSnack(context, l.appiconToast(o.name(l)));
                            }
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = option.name(context.l10n);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            // 選中＝2px 主題色框，未選＝1px 卡片邊（設計稿用 box-shadow 畫框，不佔版面）。
            boxShadow: [
              BoxShadow(
                color: selected ? t.accent : t.borderCard,
                spreadRadius: selected ? 2 : 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 10,
                top: -12,
                child: selected
                    ? Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SvgIcon(
                            AppIcons.check,
                            size: 13,
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: t.dashed, width: 2),
                        ),
                      ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconImage(option, size: 96, radius: 21),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
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
