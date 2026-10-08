import '../../app_name.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/tokens.dart';
import '../common/app_icons.dart';
import '../common/nav_bar_hidden.dart';
import '../common/svg_icon.dart';
import 'me_icons.dart';
import 'me_widgets.dart';
import '../../l10n/l10n.dart';

/// 真正的 App 版本與建置號（取不到時為 null，頁面就不顯示版本）。
final appPackageInfoProvider = FutureProvider<PackageInfo?>((ref) async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
});

/// 「版本 1.0.0（12）」；沒有建置號就只有版本。
String versionLabel(PackageInfo? info) {
  if (info == null || info.version.isEmpty) return '';
  final build = info.buildNumber;
  return build.isEmpty
      ? l10nStatic.meAboutVersion(info.version)
      : l10nStatic.meAboutVersionBuild(info.version, build);
}

/// 關於 App（About）：圖示、名稱、版本、資料存放說明、開源授權。沒有導覽列。
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final info = ref.watch(appPackageInfoProvider).value;
    final version = versionLabel(info);
    final divider = dark ? t.border : const Color(0xFFF1EADF);
    final chevron = dark ? t.text4 : const Color(0xFFB7ADA0);
    return HideNavBar(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              MeSubHeader(context.l10n.meAbout, bottom: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 18, 0, 26),
                      child: Column(
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: t.accent.withValues(alpha: .3),
                                  offset: const Offset(0, 6),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: SvgIcon(
                                MeIcons.appDrawer,
                                size: 42,
                                strokeWidth: 1.6,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            appName,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontSize: 22),
                          ),
                          if (version.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              version,
                              style: TextStyle(fontSize: 13, color: t.text3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    MePanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: divider),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.meAboutDataTitle,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.l10n.meAboutDataBody,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.55,
                                      color: t.text3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => showLicensePage(
                                context: context,
                                applicationName: appName,
                                applicationVersion: version.isEmpty
                                    ? null
                                    : info!.version,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.l10n.meAboutLicenses,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    SvgIcon(
                                      AppIcons.chevronRight,
                                      size: 18,
                                      color: chevron,
                                      strokeWidth: 2,
                                    ),
                                  ],
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
