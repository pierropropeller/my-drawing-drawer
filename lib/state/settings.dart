import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';

/// 由 main() 在啟動時覆蓋；測試或尚未載入時為 null，設定只存記憶體。
final sharedPrefsProvider = Provider<SharedPreferences?>((ref) => null);

/// 本機設定（跟裝置走，不同步）與使用者資料。
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.refreshMinutes = 5,
    this.autoSync = true,
    this.nickname = '',
    this.avatarFile,
    this.onboarded = false,
    this.accountEmail,
    this.accent = AccentPreset.coral,
    this.language = AppLanguage.system,
    this.defaultCurrency = 'CNY',
    this.syncedAccount,
  });

  final ThemeMode themeMode;

  /// 新增商稿時預設的幣種（D-047），每張商稿仍可各自選；本機設定，不同步。
  final String defaultCurrency;

  /// 已完成過首次同步的帳號；和 [accountEmail] 不同＝這個帳號還沒做過首次同步。
  final String? syncedAccount;

  /// App 介面語言（預留）：目前只有繁體中文，英文介面之後再補。
  final AppLanguage language;

  /// 主題色預設（珊瑚／霧藍／玫瑰／抹茶），每台裝置各自設定。
  final AccentPreset accent;

  /// 前台自動刷新間隔（分鐘）：1／5／15／30，預設 5。
  final int refreshMinutes;
  final bool autoSync;
  final String nickname;
  final String? avatarFile;
  final bool onboarded;

  /// 已連結的 Google 帳號（Drive 同步用）；null＝尚未連結。
  final String? accountEmail;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? refreshMinutes,
    bool? autoSync,
    String? nickname,
    Object? avatarFile = _keep,
    bool? onboarded,
    Object? accountEmail = _keep,
    AccentPreset? accent,
    AppLanguage? language,
    String? defaultCurrency,
    Object? syncedAccount = _keep,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    language: language ?? this.language,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    syncedAccount: identical(syncedAccount, _keep)
        ? this.syncedAccount
        : syncedAccount as String?,
    refreshMinutes: refreshMinutes ?? this.refreshMinutes,
    autoSync: autoSync ?? this.autoSync,
    nickname: nickname ?? this.nickname,
    avatarFile: identical(avatarFile, _keep)
        ? this.avatarFile
        : avatarFile as String?,
    onboarded: onboarded ?? this.onboarded,
    accountEmail: identical(accountEmail, _keep)
        ? this.accountEmail
        : accountEmail as String?,
  );
}

/// 介面語言選項。[available] 為 false 的尚未翻譯，選了也不會生效。
enum AppLanguage {
  system('跟隨系統', true),
  zhTw('繁體中文', true),
  en('English', false);

  const AppLanguage(this.label, this.available);
  final String label;
  final bool available;

  static AppLanguage fromKey(String? key) => AppLanguage.values.firstWhere(
    (l) => l.name == key,
    orElse: () => AppLanguage.system,
  );
}

const _keep = Object();
const refreshOptions = [1, 5, 15, 30];

class SettingsNotifier extends Notifier<AppSettings> {
  SharedPreferences? get _p => ref.read(sharedPrefsProvider);

  @override
  AppSettings build() {
    final p = ref.watch(sharedPrefsProvider);
    // 沒有持久化（測試、尚未載入）時視為已完成開頭畫面。
    if (p == null) return const AppSettings(onboarded: true);
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == p.getString('themeMode'),
        orElse: () => ThemeMode.system,
      ),
      accent: AccentPreset.fromKey(p.getString('accent')),
      language: AppLanguage.fromKey(p.getString('language')),
      refreshMinutes: p.getInt('refreshMinutes') ?? 5,
      autoSync: p.getBool('autoSync') ?? true,
      nickname: p.getString('nickname') ?? '',
      avatarFile: p.getString('avatarFile'),
      onboarded: p.getBool('onboarded') ?? false,
      accountEmail: p.getString('accountEmail'),
      defaultCurrency: p.getString('defaultCurrency') ?? 'CNY',
      syncedAccount: p.getString('syncedAccount'),
    );
  }

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    _p?.setString('themeMode', m.name);
  }

  void setAccent(AccentPreset a) {
    state = state.copyWith(accent: a);
    _p?.setString('accent', a.key);
  }

  void setLanguage(AppLanguage l) {
    state = state.copyWith(language: l);
    _p?.setString('language', l.name);
  }

  void setDefaultCurrency(String code) {
    state = state.copyWith(defaultCurrency: code);
    _p?.setString('defaultCurrency', code);
  }

  /// 記錄這個帳號已完成首次同步（null＝清除）。
  void setSyncedAccount(String? email) {
    state = state.copyWith(syncedAccount: email);
    if (email == null) {
      _p?.remove('syncedAccount');
    } else {
      _p?.setString('syncedAccount', email);
    }
  }

  void setRefreshMinutes(int v) {
    state = state.copyWith(refreshMinutes: v);
    _p?.setInt('refreshMinutes', v);
  }

  void setAutoSync(bool v) {
    state = state.copyWith(autoSync: v);
    _p?.setBool('autoSync', v);
  }

  void setNickname(String v) {
    state = state.copyWith(nickname: v);
    _p?.setString('nickname', v);
  }

  void setAvatar(String? file) {
    state = state.copyWith(avatarFile: file);
    if (file == null) {
      _p?.remove('avatarFile');
    } else {
      _p?.setString('avatarFile', file);
    }
  }

  void setOnboarded(bool v) {
    state = state.copyWith(onboarded: v);
    _p?.setBool('onboarded', v);
  }

  void setAccount(String? email) {
    state = state.copyWith(accountEmail: email);
    if (email == null) {
      _p?.remove('accountEmail');
    } else {
      _p?.setString('accountEmail', email);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// 已連結帳號但還沒完成首次同步。
final firstSyncPendingProvider = Provider<bool>((ref) {
  final s = ref.watch(settingsProvider);
  return s.accountEmail != null && s.syncedAccount != s.accountEmail;
});

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider).themeMode,
);

/// 網絡狀態：離線時主頁顯示橫條。
final onlineProvider = StreamProvider<bool>((ref) async* {
  // 以 connectivity_plus 監聽；任何非 none 視為在線。
  final c = Connectivity();
  yield !(await c.checkConnectivity()).contains(ConnectivityResult.none);
  await for (final r in c.onConnectivityChanged) {
    yield !r.contains(ConnectivityResult.none);
  }
});
