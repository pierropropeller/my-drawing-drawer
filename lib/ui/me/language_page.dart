import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import 'me_widgets.dart';

/// 語言：先預留選項。目前介面只有繁體中文；English 之後補上翻譯才能選。
/// App 在桌面與 Google 登入畫面顯示的名稱，則由系統語言決定（英文系統顯示 Drawer）。
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = ref.watch(settingsProvider.select((s) => s.language));
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MeSubHeader('語言'),
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
                            InkWell(
                              onTap: l.available
                                  ? () => ref
                                        .read(settingsProvider.notifier)
                                        .setLanguage(l)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: i == AppLanguage.values.length - 1
                                      ? null
                                      : Border(
                                          bottom: BorderSide(color: divider),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.label,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: l.available ? t.ink : t.text4,
                                        ),
                                      ),
                                    ),
                                    if (!l.available)
                                      Text(
                                        '即將推出',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.text4,
                                        ),
                                      )
                                    else if (l == current)
                                      SvgIcon(
                                        AppIcons.check,
                                        size: 20,
                                        color: t.accent,
                                        strokeWidth: 2.2,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '目前介面只有繁體中文，English 翻譯完成後會開放。\n'
                    '桌面上的 App 名稱與 Google 登入畫面，會依系統語言顯示（英文系統為 Drawer，中文系統為畫匣）。',
                    style: TextStyle(fontSize: 12, color: t.text3, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
