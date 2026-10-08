import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @shellTabPits.
  ///
  /// In zh, this message translates to:
  /// **'坑'**
  String get shellTabPits;

  /// No description provided for @shellTabGoals.
  ///
  /// In zh, this message translates to:
  /// **'目標'**
  String get shellTabGoals;

  /// No description provided for @shellTabMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get shellTabMe;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'淺色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟隨系統'**
  String get themeModeSystem;

  /// No description provided for @themeAccentCoral.
  ///
  /// In zh, this message translates to:
  /// **'珊瑚'**
  String get themeAccentCoral;

  /// No description provided for @themeAccentSlate.
  ///
  /// In zh, this message translates to:
  /// **'霧藍'**
  String get themeAccentSlate;

  /// No description provided for @themeAccentRose.
  ///
  /// In zh, this message translates to:
  /// **'玫瑰'**
  String get themeAccentRose;

  /// No description provided for @themeAccentMatcha.
  ///
  /// In zh, this message translates to:
  /// **'抹茶'**
  String get themeAccentMatcha;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟隨系統'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageZhTw.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get settingsLanguageZhTw;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @meTitle.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get meTitle;

  /// No description provided for @meAvatarFallback.
  ///
  /// In zh, this message translates to:
  /// **'畫'**
  String get meAvatarFallback;

  /// No description provided for @meSetNickname.
  ///
  /// In zh, this message translates to:
  /// **'設定暱稱'**
  String get meSetNickname;

  /// No description provided for @meEditProfile.
  ///
  /// In zh, this message translates to:
  /// **'編輯個人資料'**
  String get meEditProfile;

  /// No description provided for @meThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'主題色'**
  String get meThemeColor;

  /// No description provided for @meThemeValue.
  ///
  /// In zh, this message translates to:
  /// **'{accent} · {mode}'**
  String meThemeValue(String accent, String mode);

  /// No description provided for @meLanguage.
  ///
  /// In zh, this message translates to:
  /// **'語言'**
  String get meLanguage;

  /// No description provided for @meLanguageComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即將推出'**
  String get meLanguageComingSoon;

  /// No description provided for @meBackupSync.
  ///
  /// In zh, this message translates to:
  /// **'備份與同步'**
  String get meBackupSync;

  /// No description provided for @meAbout.
  ///
  /// In zh, this message translates to:
  /// **'關於 App'**
  String get meAbout;

  /// No description provided for @meBackupNotLinked.
  ///
  /// In zh, this message translates to:
  /// **'未連結'**
  String get meBackupNotLinked;

  /// No description provided for @meBackupLinked.
  ///
  /// In zh, this message translates to:
  /// **'已連結'**
  String get meBackupLinked;

  /// No description provided for @meNotSyncedYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get meNotSyncedYet;

  /// No description provided for @meTimeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String meTimeToday(String time);

  /// No description provided for @meTimeYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天 {time}'**
  String meTimeYesterday(String time);

  /// No description provided for @meTimeDate.
  ///
  /// In zh, this message translates to:
  /// **'{month}/{day} {time}'**
  String meTimeDate(int month, int day, String time);

  /// No description provided for @meChangeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'更換頭像'**
  String get meChangeAvatar;

  /// No description provided for @meTapAvatarToChange.
  ///
  /// In zh, this message translates to:
  /// **'點選頭像更換'**
  String get meTapAvatarToChange;

  /// No description provided for @meNickname.
  ///
  /// In zh, this message translates to:
  /// **'暱稱'**
  String get meNickname;

  /// No description provided for @meThemeAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外觀'**
  String get meThemeAppearance;

  /// No description provided for @meThemeNote.
  ///
  /// In zh, this message translates to:
  /// **'每個主題色都有深／淺兩個版本，「跟隨系統」會依照裝置設定自動切換。'**
  String get meThemeNote;

  /// No description provided for @meThemePreview.
  ///
  /// In zh, this message translates to:
  /// **'預覽'**
  String get meThemePreview;

  /// No description provided for @meThemeButton.
  ///
  /// In zh, this message translates to:
  /// **'按鈕'**
  String get meThemeButton;

  /// No description provided for @meAboutDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'資料存放'**
  String get meAboutDataTitle;

  /// No description provided for @meAboutDataBody.
  ///
  /// In zh, this message translates to:
  /// **'所有資料只存在你的裝置和你的 Google Drive，不會上傳到其他地方。'**
  String get meAboutDataBody;

  /// No description provided for @meAboutLicenses.
  ///
  /// In zh, this message translates to:
  /// **'開源授權'**
  String get meAboutLicenses;

  /// No description provided for @meAboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String meAboutVersion(String version);

  /// No description provided for @meAboutVersionBuild.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}（{build}）'**
  String meAboutVersionBuild(String version, String build);

  /// No description provided for @meBackupChangeAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'更換同步的 Google 帳號？'**
  String get meBackupChangeAccountTitle;

  /// No description provided for @meBackupChangeAccountBody.
  ///
  /// In zh, this message translates to:
  /// **'本機的資料會整個上傳到新帳號，原帳號的備份不會被刪除。'**
  String get meBackupChangeAccountBody;

  /// No description provided for @meBackupChange.
  ///
  /// In zh, this message translates to:
  /// **'更換'**
  String get meBackupChange;

  /// No description provided for @meBackupUnlinkTitle.
  ///
  /// In zh, this message translates to:
  /// **'取消連結 Google 帳號？'**
  String get meBackupUnlinkTitle;

  /// No description provided for @meBackupUnlinkBody.
  ///
  /// In zh, this message translates to:
  /// **'取消後將停止同步。本機資料會保留，Google Drive 上的資料不會刪除。'**
  String get meBackupUnlinkBody;

  /// No description provided for @meBackupUnlinkConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認取消連結'**
  String get meBackupUnlinkConfirm;

  /// No description provided for @meBackupSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get meBackupSyncing;

  /// No description provided for @meBackupNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'尚未連結 Google 帳號'**
  String get meBackupNoAccount;

  /// No description provided for @meBackupLinkGoogle.
  ///
  /// In zh, this message translates to:
  /// **'連結 Google 帳號'**
  String get meBackupLinkGoogle;

  /// No description provided for @meBackupAutoSync.
  ///
  /// In zh, this message translates to:
  /// **'自動同步'**
  String get meBackupAutoSync;

  /// No description provided for @meBackupLastBackup.
  ///
  /// In zh, this message translates to:
  /// **'上次備份　{time}'**
  String meBackupLastBackup(String time);

  /// No description provided for @meBackupForegroundRefresh.
  ///
  /// In zh, this message translates to:
  /// **'前台自動刷新'**
  String get meBackupForegroundRefresh;

  /// No description provided for @meBackupForegroundRefreshDesc.
  ///
  /// In zh, this message translates to:
  /// **'App 開啟時定期同步最新資料（跨設備）'**
  String get meBackupForegroundRefreshDesc;

  /// No description provided for @meBackupRefreshInterval.
  ///
  /// In zh, this message translates to:
  /// **'刷新間隔'**
  String get meBackupRefreshInterval;

  /// No description provided for @meBackupEveryMinutes.
  ///
  /// In zh, this message translates to:
  /// **'每 {minutes} 分鐘'**
  String meBackupEveryMinutes(int minutes);

  /// No description provided for @meBackupSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get meBackupSyncNow;

  /// No description provided for @meBackupChangeAccount.
  ///
  /// In zh, this message translates to:
  /// **'更換同步的 Google 帳號'**
  String get meBackupChangeAccount;

  /// No description provided for @meBackupDriveNote.
  ///
  /// In zh, this message translates to:
  /// **'上傳圖片時自動儲存至 Drive；離線時會在恢復網絡後立即補傳。'**
  String get meBackupDriveNote;

  /// No description provided for @meBackupUnlink.
  ///
  /// In zh, this message translates to:
  /// **'取消連結'**
  String get meBackupUnlink;

  /// No description provided for @loginTentativeName.
  ///
  /// In zh, this message translates to:
  /// **'（暫定名稱，可更改）'**
  String get loginTentativeName;

  /// No description provided for @loginTagline.
  ///
  /// In zh, this message translates to:
  /// **'一個坑一個坑，\n收藏你的同人宇宙'**
  String get loginTagline;

  /// No description provided for @loginStartWithGoogle.
  ///
  /// In zh, this message translates to:
  /// **'用 Google 帳號開始'**
  String get loginStartWithGoogle;

  /// No description provided for @loginOfflineNoSync.
  ///
  /// In zh, this message translates to:
  /// **'離線使用，暫不同步'**
  String get loginOfflineNoSync;

  /// No description provided for @loginConnectGoogle.
  ///
  /// In zh, this message translates to:
  /// **'連結 Google 帳號'**
  String get loginConnectGoogle;

  /// No description provided for @loginConnectHint.
  ///
  /// In zh, this message translates to:
  /// **'連結後，跨設備自動同步'**
  String get loginConnectHint;

  /// No description provided for @loginUseAnotherAccount.
  ///
  /// In zh, this message translates to:
  /// **'用另一個帳號'**
  String get loginUseAnotherAccount;

  /// No description provided for @loginConnectAndStart.
  ///
  /// In zh, this message translates to:
  /// **'連結並開始'**
  String get loginConnectAndStart;

  /// No description provided for @loginOfflineContinue.
  ///
  /// In zh, this message translates to:
  /// **'離線繼續，暫不同步'**
  String get loginOfflineContinue;

  /// No description provided for @loginAddGoogleAccount.
  ///
  /// In zh, this message translates to:
  /// **'加 Google 帳號'**
  String get loginAddGoogleAccount;

  /// No description provided for @loginNoAccount.
  ///
  /// In zh, this message translates to:
  /// **'未連結任何帳號'**
  String get loginNoAccount;

  /// No description provided for @loginDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下載你在 Google Drive 的資料'**
  String get loginDownloading;

  /// No description provided for @loginSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步'**
  String get loginSyncing;

  /// No description provided for @loginImagesProgress.
  ///
  /// In zh, this message translates to:
  /// **'圖片 {done} / {total}'**
  String loginImagesProgress(int done, int total);

  /// No description provided for @loginStartNow.
  ///
  /// In zh, this message translates to:
  /// **'先開始使用'**
  String get loginStartNow;

  /// No description provided for @loginSyncContinues.
  ///
  /// In zh, this message translates to:
  /// **'同步會在背景繼續'**
  String get loginSyncContinues;

  /// No description provided for @syncOffline.
  ///
  /// In zh, this message translates to:
  /// **'目前離線，恢復網絡後將自動同步'**
  String get syncOffline;

  /// No description provided for @syncFailedShort.
  ///
  /// In zh, this message translates to:
  /// **'同步失敗'**
  String get syncFailedShort;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失敗：{error}'**
  String syncFailed(String error);

  /// No description provided for @syncNeedsAppUpdate.
  ///
  /// In zh, this message translates to:
  /// **'此備份由較新版本建立，請先更新 App'**
  String get syncNeedsAppUpdate;

  /// No description provided for @syncAuthExpired.
  ///
  /// In zh, this message translates to:
  /// **'登入已失效，請重新連結 Google 帳號'**
  String get syncAuthExpired;

  /// No description provided for @syncAuthExpiredDetail.
  ///
  /// In zh, this message translates to:
  /// **'登入已失效，請重新連結 Google 帳號（{detail}）'**
  String syncAuthExpiredDetail(String detail);

  /// No description provided for @syncResultSummary.
  ///
  /// In zh, this message translates to:
  /// **'上傳 {pushed}／下載 {pulled}（圖片 ↑{imagesUp} ↓{imagesDown}）'**
  String syncResultSummary(
    int pushed,
    int pulled,
    int imagesUp,
    int imagesDown,
  );

  /// No description provided for @syncDriveForbidden.
  ///
  /// In zh, this message translates to:
  /// **'Drive 拒絕存取（403）：{body}'**
  String syncDriveForbidden(String body);

  /// No description provided for @syncDriveError.
  ///
  /// In zh, this message translates to:
  /// **'Drive 錯誤 {status}：{body}'**
  String syncDriveError(int status, String body);

  /// No description provided for @syncCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get syncCancelled;

  /// No description provided for @syncLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'連結失敗：{error}'**
  String syncLinkFailed(String error);

  /// 關於 App 的標語
  ///
  /// In zh, this message translates to:
  /// **'把想畫的、畫好的，都收進坑裡。'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確認'**
  String get commonConfirm;

  /// No description provided for @commonDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get commonSave;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get commonAdd;

  /// No description provided for @commonSelect.
  ///
  /// In zh, this message translates to:
  /// **'選擇'**
  String get commonSelect;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除'**
  String get commonDelete;

  /// No description provided for @commonShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get commonShare;

  /// No description provided for @commonDownload.
  ///
  /// In zh, this message translates to:
  /// **'下載'**
  String get commonDownload;

  /// No description provided for @commonMove.
  ///
  /// In zh, this message translates to:
  /// **'移動'**
  String get commonMove;

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜尋'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get commonAll;

  /// No description provided for @commonManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get commonManage;

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get commonClose;

  /// No description provided for @commonSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全選'**
  String get commonSelectAll;

  /// No description provided for @commonDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全選'**
  String get commonDeselectAll;

  /// No description provided for @commonManageTags.
  ///
  /// In zh, this message translates to:
  /// **'管理 tag'**
  String get commonManageTags;

  /// No description provided for @commonNoTitle.
  ///
  /// In zh, this message translates to:
  /// **'無標題'**
  String get commonNoTitle;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get commonRetry;

  /// No description provided for @commonOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get commonOther;

  /// No description provided for @commonCountImages.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張'**
  String commonCountImages(int count);

  /// No description provided for @commonSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 張'**
  String commonSelectedCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
