// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get shellTabPits => '坑';

  @override
  String get shellTabGoals => '目標';

  @override
  String get shellTabMe => '我的';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeAccentCoral => '珊瑚';

  @override
  String get themeAccentSlate => '霧藍';

  @override
  String get themeAccentRose => '玫瑰';

  @override
  String get themeAccentMatcha => '抹茶';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsLanguageZhTw => '繁體中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get meTitle => '我的';

  @override
  String get meAvatarFallback => '畫';

  @override
  String get meSetNickname => '設定暱稱';

  @override
  String get meEditProfile => '編輯個人資料';

  @override
  String get meThemeColor => '主題色';

  @override
  String meThemeValue(String accent, String mode) {
    return '$accent · $mode';
  }

  @override
  String get meLanguage => '語言';

  @override
  String get meLanguageComingSoon => '即將推出';

  @override
  String get meBackupSync => '備份與同步';

  @override
  String get meAbout => '關於 App';

  @override
  String get meBackupNotLinked => '未連結';

  @override
  String get meBackupLinked => '已連結';

  @override
  String get meNotSyncedYet => '尚未同步';

  @override
  String meTimeToday(String time) {
    return '今天 $time';
  }

  @override
  String meTimeYesterday(String time) {
    return '昨天 $time';
  }

  @override
  String meTimeDate(int month, int day, String time) {
    return '$month/$day $time';
  }

  @override
  String get meChangeAvatar => '更換頭像';

  @override
  String get meTapAvatarToChange => '點選頭像更換';

  @override
  String get meNickname => '暱稱';

  @override
  String get meThemeAppearance => '外觀';

  @override
  String get meThemeNote => '每個主題色都有深／淺兩個版本，「跟隨系統」會依照裝置設定自動切換。';

  @override
  String get meThemePreview => '預覽';

  @override
  String get meThemeButton => '按鈕';

  @override
  String get meAboutDataTitle => '資料存放';

  @override
  String get meAboutDataBody => '所有資料只存在你的裝置和你的 Google Drive，不會上傳到其他地方。';

  @override
  String get meAboutLicenses => '開源授權';

  @override
  String meAboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String meAboutVersionBuild(String version, String build) {
    return '版本 $version（$build）';
  }

  @override
  String get meBackupChangeAccountTitle => '更換同步的 Google 帳號？';

  @override
  String get meBackupChangeAccountBody => '本機的資料會整個上傳到新帳號，原帳號的備份不會被刪除。';

  @override
  String get meBackupChange => '更換';

  @override
  String get meBackupUnlinkTitle => '取消連結 Google 帳號？';

  @override
  String get meBackupUnlinkBody => '取消後將停止同步。本機資料會保留，Google Drive 上的資料不會刪除。';

  @override
  String get meBackupUnlinkConfirm => '確認取消連結';

  @override
  String get meBackupSyncing => '同步中…';

  @override
  String get meBackupNoAccount => '尚未連結 Google 帳號';

  @override
  String get meBackupLinkGoogle => '連結 Google 帳號';

  @override
  String get meBackupAutoSync => '自動同步';

  @override
  String meBackupLastBackup(String time) {
    return '上次備份　$time';
  }

  @override
  String get meBackupForegroundRefresh => '前台自動刷新';

  @override
  String get meBackupForegroundRefreshDesc => 'App 開啟時定期同步最新資料（跨設備）';

  @override
  String get meBackupRefreshInterval => '刷新間隔';

  @override
  String meBackupEveryMinutes(int minutes) {
    return '每 $minutes 分鐘';
  }

  @override
  String get meBackupSyncNow => '立即同步';

  @override
  String get meBackupChangeAccount => '更換同步的 Google 帳號';

  @override
  String get meBackupDriveNote => '上傳圖片時自動儲存至 Drive；離線時會在恢復網絡後立即補傳。';

  @override
  String get meBackupUnlink => '取消連結';

  @override
  String get loginTentativeName => '（暫定名稱，可更改）';

  @override
  String get loginTagline => '一個坑一個坑，\n收藏你的同人宇宙';

  @override
  String get loginStartWithGoogle => '用 Google 帳號開始';

  @override
  String get loginOfflineNoSync => '離線使用，暫不同步';

  @override
  String get loginConnectGoogle => '連結 Google 帳號';

  @override
  String get loginConnectHint => '連結後，跨設備自動同步';

  @override
  String get loginUseAnotherAccount => '用另一個帳號';

  @override
  String get loginConnectAndStart => '連結並開始';

  @override
  String get loginOfflineContinue => '離線繼續，暫不同步';

  @override
  String get loginAddGoogleAccount => '加 Google 帳號';

  @override
  String get loginNoAccount => '未連結任何帳號';

  @override
  String get loginDownloading => '正在下載你在 Google Drive 的資料';

  @override
  String get loginSyncing => '正在同步';

  @override
  String loginImagesProgress(int done, int total) {
    return '圖片 $done / $total';
  }

  @override
  String get loginStartNow => '先開始使用';

  @override
  String get loginSyncContinues => '同步會在背景繼續';

  @override
  String get syncOffline => '目前離線，恢復網絡後將自動同步';

  @override
  String get syncFailedShort => '同步失敗';

  @override
  String syncFailed(String error) {
    return '同步失敗：$error';
  }

  @override
  String get syncNeedsAppUpdate => '此備份由較新版本建立，請先更新 App';

  @override
  String get syncAuthExpired => '登入已失效，請重新連結 Google 帳號';

  @override
  String syncAuthExpiredDetail(String detail) {
    return '登入已失效，請重新連結 Google 帳號（$detail）';
  }

  @override
  String syncResultSummary(
    int pushed,
    int pulled,
    int imagesUp,
    int imagesDown,
  ) {
    return '上傳 $pushed／下載 $pulled（圖片 ↑$imagesUp ↓$imagesDown）';
  }

  @override
  String syncDriveForbidden(String body) {
    return 'Drive 拒絕存取（403）：$body';
  }

  @override
  String syncDriveError(int status, String body) {
    return 'Drive 錯誤 $status：$body';
  }

  @override
  String get syncCancelled => '已取消';

  @override
  String syncLinkFailed(String error) {
    return '連結失敗：$error';
  }

  @override
  String get appTagline => '把想畫的、畫好的，都收進坑裡。';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonDone => '完成';

  @override
  String get commonSave => '儲存';

  @override
  String get commonAdd => '新增';

  @override
  String get commonSelect => '選擇';

  @override
  String get commonEdit => '編輯';

  @override
  String get commonDelete => '刪除';

  @override
  String get commonShare => '分享';

  @override
  String get commonDownload => '下載';

  @override
  String get commonMove => '移動';

  @override
  String get commonBack => '返回';

  @override
  String get commonSearch => '搜尋';

  @override
  String get commonAll => '全部';

  @override
  String get commonManage => '管理';

  @override
  String get commonClose => '關閉';

  @override
  String get commonSelectAll => '全選';

  @override
  String get commonDeselectAll => '取消全選';

  @override
  String get commonManageTags => '管理 tag';

  @override
  String get commonNoTitle => '無標題';

  @override
  String get commonRetry => '重試';

  @override
  String get commonOther => '其他';

  @override
  String commonCountImages(int count) {
    return '$count 張';
  }

  @override
  String commonSelectedCount(int count) {
    return '已選 $count 張';
  }
}
