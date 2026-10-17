import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'settings.dart';

/// 一款 App 圖示（D-086）。清單驅動：新增圖示＝
/// 1. 產一套 `ic_launcher_{key}` 資源、AndroidManifest 加一個 `activity-alias`（預設 enabled=false）；
/// 2. [appIconOptions] 加一筆；名稱字串放 `lib/l10n/fragments/appicon.arb`。
/// 選擇畫面、「我的」那一列、關於／開頭頁都會自動跟上。
class AppIconOption {
  const AppIconOption({
    required this.key,
    required this.name,
    required this.alias,
    required this.asset,
  });

  /// 存在裝置設定的值（不同步）。
  final String key;

  /// 顯示名稱（ARB）：`(l) => l.appiconSanbi`。
  final String Function(AppLocalizations l) name;

  /// AndroidManifest 裡 `activity-alias` 的簡短名稱（`.IconSanbi` → `IconSanbi`）。
  final String alias;

  /// App 內顯示用的預覽圖（256px）。
  final String asset;
}

/// 第一筆是預設（三筆）。
final appIconOptions = <AppIconOption>[
  AppIconOption(
    key: 'sanbi',
    name: (l) => l.appiconSanbi,
    alias: 'IconSanbi',
    asset: 'assets/appicon/icon-sanbi-256.png',
  ),
  AppIconOption(
    key: 'huati',
    name: (l) => l.appiconHuati,
    alias: 'IconHuati',
    asset: 'assets/appicon/icon-huati-256.png',
  ),
];

AppIconOption get defaultAppIcon => appIconOptions.first;

/// 依 key 找圖示；找不到（舊資料、未知值）回預設。
AppIconOption appIconByKey(String? key) => appIconOptions.firstWhere(
  (o) => o.key == key,
  orElse: () => defaultAppIcon,
);

AppIconOption? _byAlias(String? alias) {
  for (final o in appIconOptions) {
    if (o.alias == alias) return o;
  }
  return null;
}

/// 桌面圖示的平台介面（Android `activity-alias`）。
abstract class AppIconService {
  /// 目前啟用的 alias 簡短名稱；不在 Android、查不到＝null。
  Future<String?> currentAlias();

  /// 啟用 [alias]、停用其他；失敗丟例外。
  Future<void> setAlias(String alias);
}

/// 正式實作：`io.molly.drawer/appicon` channel（見 MainActivity.kt）。
/// 不在 Android 上（測試、桌面）時 [currentAlias] 回 null、[setAlias] 什麼都不做。
class ChannelAppIconService implements AppIconService {
  const ChannelAppIconService();

  static const _channel = MethodChannel('io.molly.drawer/appicon');

  @override
  Future<String?> currentAlias() async {
    try {
      return await _channel.invokeMethod<String>('currentIcon');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> setAlias(String alias) async {
    try {
      await _channel.invokeMethod<void>('setIcon', {'alias': alias});
    } on MissingPluginException {
      // 沒有原生端（測試、桌面）：只記設定。
    }
  }
}

/// 測試用：記憶體裡的「桌面」，不碰平台。
class MemoryAppIconService implements AppIconService {
  MemoryAppIconService([this.alias]);

  /// 目前啟用的 alias。
  String? alias;

  /// 每次 [setAlias] 的紀錄。
  final calls = <String>[];

  /// 設成 true 讓 [setAlias] 丟例外。
  bool failing = false;

  @override
  Future<String?> currentAlias() async => alias;

  @override
  Future<void> setAlias(String alias) async {
    if (failing) throw PlatformException(code: 'set_failed');
    calls.add(alias);
    this.alias = alias;
  }
}

final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const ChannelAppIconService(),
);

/// 目前選的圖示（來自裝置設定）。
final currentAppIconProvider = Provider<AppIconOption>(
  (ref) => appIconByKey(ref.watch(settingsProvider.select((s) => s.appIcon))),
);

/// 啟動時向平台問一次目前啟用哪個 alias，設定值對不上就以平台為準（避免漂移，例如重裝或被系統還原）。
/// 查不到（不在 Android）時不動設定。
final appIconStartupSyncProvider = FutureProvider<void>((ref) async {
  final alias = await ref.read(appIconServiceProvider).currentAlias();
  final actual = _byAlias(alias);
  if (actual == null) return;
  if (ref.read(settingsProvider).appIcon != actual.key) {
    ref.read(settingsProvider.notifier).setAppIcon(actual.key);
  }
});

/// 換桌面圖示：平台成功才記設定。失敗（例外）回 false，設定維持原樣。
Future<bool> selectAppIcon(WidgetRef ref, AppIconOption option) async {
  try {
    await ref.read(appIconServiceProvider).setAlias(option.alias);
  } catch (_) {
    return false;
  }
  ref.read(settingsProvider.notifier).setAppIcon(option.key);
  return true;
}
