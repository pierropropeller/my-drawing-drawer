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
  });

  final ThemeMode themeMode;

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
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
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
      refreshMinutes: p.getInt('refreshMinutes') ?? 5,
      autoSync: p.getBool('autoSync') ?? true,
      nickname: p.getString('nickname') ?? '',
      avatarFile: p.getString('avatarFile'),
      onboarded: p.getBool('onboarded') ?? false,
      accountEmail: p.getString('accountEmail'),
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
