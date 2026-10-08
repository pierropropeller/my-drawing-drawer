import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../common/nav_bar_hidden.dart';
import 'me_widgets.dart';
import '../../l10n/l10n.dart';

/// 語言（LanguagePick）：跟隨系統／繁體中文可選；English 停用，右邊顯示「即將推出」。
/// 沒有導覽列，也沒有說明小字。
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.watch(settingsProvider.select((s) => s.language));
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final muted = dark ? t.text4 : const Color(0xFFB7ADA0);
    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              MeSubHeader(context.l10n.meLanguage, bottom: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    MePanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          children: [
                            for (final (i, l) in AppLanguage.values.indexed)
                              Semantics(
                                inMutuallyExclusiveGroup: true,
                                checked: l.available ? l == current : null,
                                enabled: l.available,
                                child: InkWell(
                                  onTap: l.available
                                      ? () => ref
                                            .read(settingsProvider.notifier)
                                            .setLanguage(l)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      border: i == AppLanguage.values.length - 1
                                          ? null
                                          : Border(
                                              bottom: BorderSide(
                                                color: divider,
                                              ),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            l.labelOf(context.l10n),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: l.available
                                                  ? t.ink
                                                  : muted,
                                            ),
                                          ),
                                        ),
                                        if (!l.available)
                                          Text(
                                            context.l10n.meLanguageComingSoon,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: muted,
                                            ),
                                          )
                                        else
                                          _Radio(selected: l == current),
                                      ],
                                    ),
                                  ),
                                ),
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
      ),
    );
  }
}

/// 單選圓鈕：22px 圓，選中＝主題色 2px 外框＋10px 實心點，未選＝虛線色外框。
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? t.accent : t.dashed, width: 2),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
