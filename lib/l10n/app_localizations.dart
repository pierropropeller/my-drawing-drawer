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

  /// No description provided for @goalsTitle.
  ///
  /// In zh, this message translates to:
  /// **'目標'**
  String get goalsTitle;

  /// No description provided for @goalsPrevYear.
  ///
  /// In zh, this message translates to:
  /// **'上一年'**
  String get goalsPrevYear;

  /// No description provided for @goalsNextYear.
  ///
  /// In zh, this message translates to:
  /// **'下一年'**
  String get goalsNextYear;

  /// No description provided for @goalsModeYear.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get goalsModeYear;

  /// No description provided for @goalsModeMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get goalsModeMonth;

  /// No description provided for @goalsModeDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get goalsModeDay;

  /// No description provided for @goalsSectionYear.
  ///
  /// In zh, this message translates to:
  /// **'年度目標'**
  String get goalsSectionYear;

  /// No description provided for @goalsSectionMonth.
  ///
  /// In zh, this message translates to:
  /// **'月度小目標'**
  String get goalsSectionMonth;

  /// No description provided for @goalsEmptyYear.
  ///
  /// In zh, this message translates to:
  /// **'還沒有年度目標'**
  String get goalsEmptyYear;

  /// No description provided for @goalsEmptyMonth.
  ///
  /// In zh, this message translates to:
  /// **'還沒有月度目標'**
  String get goalsEmptyMonth;

  /// No description provided for @goalsNewGoal.
  ///
  /// In zh, this message translates to:
  /// **'新增目標'**
  String get goalsNewGoal;

  /// No description provided for @goalsPrevItem.
  ///
  /// In zh, this message translates to:
  /// **'上一個'**
  String get goalsPrevItem;

  /// No description provided for @goalsNextItem.
  ///
  /// In zh, this message translates to:
  /// **'下一個'**
  String get goalsNextItem;

  /// No description provided for @goalsPrevMonth.
  ///
  /// In zh, this message translates to:
  /// **'上個月'**
  String get goalsPrevMonth;

  /// No description provided for @goalsNextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下個月'**
  String get goalsNextMonth;

  /// No description provided for @goalsPrevDay.
  ///
  /// In zh, this message translates to:
  /// **'前一天'**
  String get goalsPrevDay;

  /// No description provided for @goalsNextDay.
  ///
  /// In zh, this message translates to:
  /// **'後一天'**
  String get goalsNextDay;

  /// No description provided for @goalsMonthTitle.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月'**
  String goalsMonthTitle(int month);

  /// No description provided for @goalsDayTitle.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月 {day} 日'**
  String goalsDayTitle(int month, int day);

  /// No description provided for @goalsMonthNum.
  ///
  /// In zh, this message translates to:
  /// **'{month}月'**
  String goalsMonthNum(int month);

  /// No description provided for @goalsMonthCn.
  ///
  /// In zh, this message translates to:
  /// **'{month, select, 1{一月} 2{二月} 3{三月} 4{四月} 5{五月} 6{六月} 7{七月} 8{八月} 9{九月} 10{十月} 11{十一月} 12{十二月} other{}}'**
  String goalsMonthCn(String month);

  /// No description provided for @goalsMonthFormatCn.
  ///
  /// In zh, this message translates to:
  /// **'一月'**
  String get goalsMonthFormatCn;

  /// No description provided for @goalsMonthFormatNum.
  ///
  /// In zh, this message translates to:
  /// **'1月'**
  String get goalsMonthFormatNum;

  /// No description provided for @goalsWeekSun.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get goalsWeekSun;

  /// No description provided for @goalsWeekMon.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get goalsWeekMon;

  /// No description provided for @goalsWeekTue.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get goalsWeekTue;

  /// No description provided for @goalsWeekWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get goalsWeekWed;

  /// No description provided for @goalsWeekThu.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get goalsWeekThu;

  /// No description provided for @goalsWeekFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get goalsWeekFri;

  /// No description provided for @goalsWeekSat.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get goalsWeekSat;

  /// No description provided for @goalsCreatePitFirst.
  ///
  /// In zh, this message translates to:
  /// **'請先建立一個坑'**
  String get goalsCreatePitFirst;

  /// No description provided for @goalsDayEmpty.
  ///
  /// In zh, this message translates to:
  /// **'這天沒有紀錄'**
  String get goalsDayEmpty;

  /// No description provided for @goalsTimeline.
  ///
  /// In zh, this message translates to:
  /// **'時間軸'**
  String get goalsTimeline;

  /// No description provided for @goalsKindIdea.
  ///
  /// In zh, this message translates to:
  /// **'腦洞'**
  String get goalsKindIdea;

  /// No description provided for @goalsKindDraft.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get goalsKindDraft;

  /// No description provided for @goalsKindPiece.
  ///
  /// In zh, this message translates to:
  /// **'成圖'**
  String get goalsKindPiece;

  /// No description provided for @goalsUntitled.
  ///
  /// In zh, this message translates to:
  /// **'（無標題）'**
  String get goalsUntitled;

  /// No description provided for @goalsPickPit.
  ///
  /// In zh, this message translates to:
  /// **'選擇坑'**
  String get goalsPickPit;

  /// No description provided for @goalsRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get goalsRemove;

  /// No description provided for @goalsClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get goalsClear;

  /// No description provided for @goalsYearReview.
  ///
  /// In zh, this message translates to:
  /// **'年度回顧'**
  String get goalsYearReview;

  /// No description provided for @goalsReviewSelected.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} / 12'**
  String goalsReviewSelected(int count);

  /// No description provided for @goalsLayout.
  ///
  /// In zh, this message translates to:
  /// **'排版'**
  String get goalsLayout;

  /// No description provided for @goalsIncome.
  ///
  /// In zh, this message translates to:
  /// **'商稿收入'**
  String get goalsIncome;

  /// No description provided for @goalsReviewLayoutTitle.
  ///
  /// In zh, this message translates to:
  /// **'年度回顧排版'**
  String get goalsReviewLayoutTitle;

  /// No description provided for @goalsRatio.
  ///
  /// In zh, this message translates to:
  /// **'正方格比例'**
  String get goalsRatio;

  /// No description provided for @goalsMonthFormat.
  ///
  /// In zh, this message translates to:
  /// **'月份格式'**
  String get goalsMonthFormat;

  /// No description provided for @goalsMonthPosition.
  ///
  /// In zh, this message translates to:
  /// **'月份位置'**
  String get goalsMonthPosition;

  /// No description provided for @goalsOnImage.
  ///
  /// In zh, this message translates to:
  /// **'圖上'**
  String get goalsOnImage;

  /// No description provided for @goalsBlankSpace.
  ///
  /// In zh, this message translates to:
  /// **'空白位置'**
  String get goalsBlankSpace;

  /// No description provided for @goalsMonthAlign.
  ///
  /// In zh, this message translates to:
  /// **'月份對齊'**
  String get goalsMonthAlign;

  /// No description provided for @goalsAlignStart.
  ///
  /// In zh, this message translates to:
  /// **'靠左'**
  String get goalsAlignStart;

  /// No description provided for @goalsAlignCenter.
  ///
  /// In zh, this message translates to:
  /// **'置中'**
  String get goalsAlignCenter;

  /// No description provided for @goalsAlignEnd.
  ///
  /// In zh, this message translates to:
  /// **'靠右'**
  String get goalsAlignEnd;

  /// No description provided for @goalsPreview.
  ///
  /// In zh, this message translates to:
  /// **'預覽'**
  String get goalsPreview;

  /// No description provided for @goalsSaveExport.
  ///
  /// In zh, this message translates to:
  /// **'儲存並匯出圖片'**
  String get goalsSaveExport;

  /// No description provided for @goalsSavedToAlbum.
  ///
  /// In zh, this message translates to:
  /// **'已儲存到相簿'**
  String get goalsSavedToAlbum;

  /// No description provided for @goalsExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'匯出失敗'**
  String get goalsExportFailed;

  /// No description provided for @goalsNoPieceThisMonth.
  ///
  /// In zh, this message translates to:
  /// **'這個月沒有成圖'**
  String get goalsNoPieceThisMonth;

  /// No description provided for @goalsReviewMonthSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年 {month} 月'**
  String goalsReviewMonthSheetTitle(int year, int month);

  /// No description provided for @goalsAutoNameIdea.
  ///
  /// In zh, this message translates to:
  /// **'生產 {count} 個腦洞'**
  String goalsAutoNameIdea(int count);

  /// No description provided for @goalsAutoNameDraft.
  ///
  /// In zh, this message translates to:
  /// **'畫 {count} 份草稿'**
  String goalsAutoNameDraft(int count);

  /// No description provided for @goalsAutoNamePiece.
  ///
  /// In zh, this message translates to:
  /// **'完成 {count} 張成圖'**
  String goalsAutoNamePiece(int count);

  /// No description provided for @goalsAutoNamePieceLikes.
  ///
  /// In zh, this message translates to:
  /// **'互動量過 {likes} 的成圖 {count} 張'**
  String goalsAutoNamePieceLikes(int likes, int count);

  /// No description provided for @goalsEnterLikes.
  ///
  /// In zh, this message translates to:
  /// **'請輸入需要達成的互動量'**
  String get goalsEnterLikes;

  /// No description provided for @goalsNewYearGoal.
  ///
  /// In zh, this message translates to:
  /// **'新增年度目標'**
  String get goalsNewYearGoal;

  /// No description provided for @goalsNewMonthGoal.
  ///
  /// In zh, this message translates to:
  /// **'新增月度目標'**
  String get goalsNewMonthGoal;

  /// No description provided for @goalsEditYearGoal.
  ///
  /// In zh, this message translates to:
  /// **'編輯年度目標'**
  String get goalsEditYearGoal;

  /// No description provided for @goalsEditMonthGoal.
  ///
  /// In zh, this message translates to:
  /// **'編輯月度目標'**
  String get goalsEditMonthGoal;

  /// No description provided for @goalsDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'刪除這個目標？'**
  String get goalsDeleteConfirm;

  /// No description provided for @goalsFieldName.
  ///
  /// In zh, this message translates to:
  /// **'目標名稱'**
  String get goalsFieldName;

  /// No description provided for @goalsNameHint.
  ///
  /// In zh, this message translates to:
  /// **'留空將自動命名'**
  String get goalsNameHint;

  /// No description provided for @goalsFieldKind.
  ///
  /// In zh, this message translates to:
  /// **'目標種類'**
  String get goalsFieldKind;

  /// No description provided for @goalsFieldCount.
  ///
  /// In zh, this message translates to:
  /// **'目標數量'**
  String get goalsFieldCount;

  /// No description provided for @goalsFieldPit.
  ///
  /// In zh, this message translates to:
  /// **'目標坑'**
  String get goalsFieldPit;

  /// No description provided for @goalsFieldTag.
  ///
  /// In zh, this message translates to:
  /// **'目標 tag'**
  String get goalsFieldTag;

  /// No description provided for @goalsTagHintNoPit.
  ///
  /// In zh, this message translates to:
  /// **'選擇坑之後才能選 tag'**
  String get goalsTagHintNoPit;

  /// No description provided for @goalsTagHintPit.
  ///
  /// In zh, this message translates to:
  /// **'只顯示所選坑內的 tag'**
  String get goalsTagHintPit;

  /// No description provided for @goalsAddTag.
  ///
  /// In zh, this message translates to:
  /// **'新增 tag'**
  String get goalsAddTag;

  /// No description provided for @goalsRequireLikes.
  ///
  /// In zh, this message translates to:
  /// **'需要達成互動量'**
  String get goalsRequireLikes;

  /// No description provided for @goalsLikesAtLeast.
  ///
  /// In zh, this message translates to:
  /// **'互動量 ≥'**
  String get goalsLikesAtLeast;

  /// No description provided for @goalsHearts.
  ///
  /// In zh, this message translates to:
  /// **'紅心'**
  String get goalsHearts;

  /// No description provided for @goalsCreateGoal.
  ///
  /// In zh, this message translates to:
  /// **'建立目標'**
  String get goalsCreateGoal;

  /// No description provided for @goalsIncomeYearTitle.
  ///
  /// In zh, this message translates to:
  /// **'{year} 商稿收入'**
  String goalsIncomeYearTitle(int year);

  /// No description provided for @goalsIncomeUnpaidCount.
  ///
  /// In zh, this message translates to:
  /// **'未收齊 {count} 張'**
  String goalsIncomeUnpaidCount(int count);

  /// No description provided for @goalsIncomeOwing.
  ///
  /// In zh, this message translates to:
  /// **'尚欠 {amount}'**
  String goalsIncomeOwing(String amount);

  /// No description provided for @goalsIncomeReceived.
  ///
  /// In zh, this message translates to:
  /// **'已收 {amount}'**
  String goalsIncomeReceived(String amount);

  /// No description provided for @goalsIncomeReceivedCount.
  ///
  /// In zh, this message translates to:
  /// **'已收 {amount} · {count} 張'**
  String goalsIncomeReceivedCount(String amount, int count);

  /// No description provided for @goalsIncomeUnpaid.
  ///
  /// In zh, this message translates to:
  /// **'未收'**
  String get goalsIncomeUnpaid;

  /// No description provided for @goalsIncomePaid.
  ///
  /// In zh, this message translates to:
  /// **'已收齊'**
  String get goalsIncomePaid;

  /// No description provided for @goalsCurrencyName.
  ///
  /// In zh, this message translates to:
  /// **'{code, select, CNY{人民幣} HKD{港幣} TWD{新台幣} USD{美元} JPY{日圓} EUR{歐元} GBP{英鎊} KRW{韓元} SGD{新加坡幣} other{{code}}}'**
  String goalsCurrencyName(String code);
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
