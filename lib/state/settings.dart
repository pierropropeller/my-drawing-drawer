import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_queries.dart';
import '../sync/network_kind.dart';
import 'providers.dart' show databaseProvider;
import '../theme/tokens.dart';
import '../l10n/l10n.dart';

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
    this.accent = AccentPreset.rose,
    this.language = AppLanguage.system,
    this.defaultCurrency = 'CNY',
    this.syncedAccount,
    this.appIcon = 'sanbi',
    this.videoLoop = false,
    this.sensitiveEnabled = false,
    this.safeMode = true,
  });

  /// 敏感內容標記的總開關（D-104，個人化 → 敏感內容）；本機設定，不同步，預設關。
  /// 關閉時整個 App 看不到任何敏感內容相關的東西（開關、標記按鈕、小標、模糊），已標記的圖照常顯示；
  /// 標記保留，重新開啟後自動恢復。
  final bool sensitiveEnabled;

  /// 安全模式（D-104）：總開關開著才有意義；開＝已標記的圖在列表類畫面模糊顯示，
  /// 關＝正常顯示、只在縮圖左上角加敏感小標。本機設定，不同步，預設開。
  final bool safeMode;

  final ThemeMode themeMode;

  /// 影片播放控制列的「循環播放」開關；本機設定，不同步，預設關。
  final bool videoLoop;

  /// 桌面／App 內顯示的圖示 key（D-086，`appIconOptions` 的 key）；本機設定，不同步。
  /// 啟動時會以平台實際啟用的 alias 校正。
  final String appIcon;

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
    String? appIcon,
    bool? videoLoop,
    bool? sensitiveEnabled,
    bool? safeMode,
  }) => AppSettings(
    sensitiveEnabled: sensitiveEnabled ?? this.sensitiveEnabled,
    safeMode: safeMode ?? this.safeMode,
    videoLoop: videoLoop ?? this.videoLoop,
    appIcon: appIcon ?? this.appIcon,
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
  system(true),
  zhTw(true),
  en(false);

  const AppLanguage(this.available);
  final bool available;

  String labelOf(AppLocalizations l) => switch (this) {
    system => l.settingsLanguageSystem,
    zhTw => l.settingsLanguageZhTw,
    en => l.settingsLanguageEn,
  };

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
      appIcon: p.getString('appIcon') ?? 'sanbi',
      videoLoop: p.getBool('videoLoop') ?? false,
      sensitiveEnabled: p.getBool('sensitiveEnabled') ?? false,
      safeMode: p.getBool('safeMode') ?? true,
    );
  }

  void setSensitiveEnabled(bool v) {
    state = state.copyWith(sensitiveEnabled: v);
    _p?.setBool('sensitiveEnabled', v);
  }

  void setSafeMode(bool v) {
    state = state.copyWith(safeMode: v);
    _p?.setBool('safeMode', v);
  }

  void setVideoLoop(bool v) {
    state = state.copyWith(videoLoop: v);
    _p?.setBool('videoLoop', v);
  }

  void setAppIcon(String key) {
    state = state.copyWith(appIcon: key);
    _p?.setString('appIcon', key);
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

  /// 儲存暱稱與頭像（編輯個人資料頁用）：寫進資料庫並把 updatedAt 設成現在，
  /// 之後同步會上傳（暱稱、頭像跟著帳號走）；設定裡的副本供啟動時立刻顯示。
  /// [avatarFile] 不傳＝沿用目前頭像。
  Future<void> saveProfile({
    required String nickname,
    Object? avatarFile = _keep,
  }) async {
    final avatar = identical(avatarFile, _keep)
        ? state.avatarFile
        : avatarFile as String?;
    setNickname(nickname);
    setAvatar(avatar);
    await ref
        .read(databaseProvider)
        .saveProfile(nickname: nickname, avatarFile: avatar);
  }

  /// 讓設定裡的暱稱／頭像和資料庫（同步的來源）一致：
  /// - 資料庫有紀錄：以它為準（同步拉下來的、或本機剛存的），畫面自動更新；
  /// - 沒有紀錄但設定裡有（升級前存的）：補一筆，updatedAt 設為 0（epoch），
  ///   任何裝置之後的編輯或雲端已有的紀錄都會蓋過它，不會誤蓋掉別台裝置較新的資料。
  /// 啟動時與每次同步拉取完成後呼叫。
  Future<void> reloadProfile() async {
    final db = ref.read(databaseProvider);
    final row = await db.getProfile();
    if (row == null) {
      if (state.nickname.isNotEmpty || state.avatarFile != null) {
        await db.saveProfile(
          nickname: state.nickname,
          avatarFile: state.avatarFile,
          at: DateTime.fromMillisecondsSinceEpoch(0),
        );
      }
      return;
    }
    if (row.nickname != state.nickname || row.avatarFile != state.avatarFile) {
      setNickname(row.nickname);
      setAvatar(row.avatarFile);
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
  // 只有「明確斷線」才算離線；vpn／other／空清單都當成在線（見 isExplicitlyOffline）。
  yield !isExplicitlyOffline(await c.checkConnectivity());
  await for (final r in c.onConnectivityChanged) {
    yield !isExplicitlyOffline(r);
  }
});
