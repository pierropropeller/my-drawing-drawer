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

  /// No description provided for @pitsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這個坑？'**
  String get pitsDeleteTitle;

  /// No description provided for @pitsDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'坑內的內容也會一併刪除。'**
  String get pitsDeleteBody;

  /// No description provided for @pitsSelectCover.
  ///
  /// In zh, this message translates to:
  /// **'選擇封面'**
  String get pitsSelectCover;

  /// No description provided for @pitsChangeCover.
  ///
  /// In zh, this message translates to:
  /// **'更換封面'**
  String get pitsChangeCover;

  /// No description provided for @pitsFieldCover.
  ///
  /// In zh, this message translates to:
  /// **'封面'**
  String get pitsFieldCover;

  /// No description provided for @pitsEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯坑'**
  String get pitsEditTitle;

  /// No description provided for @pitsFieldName.
  ///
  /// In zh, this message translates to:
  /// **'坑名'**
  String get pitsFieldName;

  /// No description provided for @pitsNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'請輸入坑名'**
  String get pitsNameRequired;

  /// No description provided for @pitsFieldDesc.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get pitsFieldDesc;

  /// No description provided for @pitsArchive.
  ///
  /// In zh, this message translates to:
  /// **'封存'**
  String get pitsArchive;

  /// No description provided for @pitsDeleteThis.
  ///
  /// In zh, this message translates to:
  /// **'刪除這個坑'**
  String get pitsDeleteThis;

  /// No description provided for @pitsDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'刪除後坑內所有圖片、腦洞、草稿及成圖將一併移除'**
  String get pitsDeleteHint;

  /// No description provided for @pitsNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'開新坑'**
  String get pitsNewTitle;

  /// No description provided for @pitsCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立'**
  String get pitsCreate;

  /// No description provided for @pitsOfficial.
  ///
  /// In zh, this message translates to:
  /// **'官方圖冊'**
  String get pitsOfficial;

  /// No description provided for @pitsFanArt.
  ///
  /// In zh, this message translates to:
  /// **'好看同人圖'**
  String get pitsFanArt;

  /// No description provided for @pitsDrafts.
  ///
  /// In zh, this message translates to:
  /// **'我的草稿'**
  String get pitsDrafts;

  /// No description provided for @pitsIdeas.
  ///
  /// In zh, this message translates to:
  /// **'我的腦洞'**
  String get pitsIdeas;

  /// No description provided for @pitsPieces.
  ///
  /// In zh, this message translates to:
  /// **'我的成圖'**
  String get pitsPieces;

  /// No description provided for @pitsCountDrafts.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份'**
  String pitsCountDrafts(int count);

  /// No description provided for @pitsCountIdeas.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個'**
  String pitsCountIdeas(int count);

  /// No description provided for @pitsPiecesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有成圖・開始你的第一張'**
  String get pitsPiecesEmpty;

  /// No description provided for @pitsMyPits.
  ///
  /// In zh, this message translates to:
  /// **'我的坑'**
  String get pitsMyPits;

  /// No description provided for @pitsActive.
  ///
  /// In zh, this message translates to:
  /// **'現坑'**
  String get pitsActive;

  /// No description provided for @pitsArchived.
  ///
  /// In zh, this message translates to:
  /// **'封存坑'**
  String get pitsArchived;

  /// No description provided for @pitsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'載入失敗：{error}'**
  String pitsLoadFailed(String error);

  /// No description provided for @pitsViewGrid.
  ///
  /// In zh, this message translates to:
  /// **'田字檢視'**
  String get pitsViewGrid;

  /// No description provided for @pitsViewWaterfall.
  ///
  /// In zh, this message translates to:
  /// **'瀑布檢視'**
  String get pitsViewWaterfall;

  /// No description provided for @pitsSyncingImages.
  ///
  /// In zh, this message translates to:
  /// **'同步中・圖片 {done} / {total}'**
  String pitsSyncingImages(int done, int total);

  /// No description provided for @pitsSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中'**
  String get pitsSyncing;

  /// No description provided for @pitsOffline.
  ///
  /// In zh, this message translates to:
  /// **'離線中・恢復網絡後將自動上傳'**
  String get pitsOffline;

  /// No description provided for @pitsEmptyArchived.
  ///
  /// In zh, this message translates to:
  /// **'沒有封存的坑'**
  String get pitsEmptyArchived;

  /// No description provided for @pitsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有坑'**
  String get pitsEmpty;

  /// No description provided for @pitsNotDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'尚未下載'**
  String get pitsNotDownloaded;

  /// No description provided for @pitsStatsLine.
  ///
  /// In zh, this message translates to:
  /// **'{pieces} 成圖 · {ideas} 腦洞未孵'**
  String pitsStatsLine(int pieces, int ideas);

  /// No description provided for @junkTitle.
  ///
  /// In zh, this message translates to:
  /// **'雜物'**
  String get junkTitle;

  /// No description provided for @junkEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有雜物'**
  String get junkEmpty;

  /// No description provided for @tagsScopeNote.
  ///
  /// In zh, this message translates to:
  /// **'tag 按坑獨立，不同坑之間不共用'**
  String get tagsScopeNote;

  /// No description provided for @tagsUsedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String tagsUsedCount(int count);

  /// No description provided for @tagsRename.
  ///
  /// In zh, this message translates to:
  /// **'重新命名 #{name}'**
  String tagsRename(String name);

  /// No description provided for @tagsRenamePrompt.
  ///
  /// In zh, this message translates to:
  /// **'Tag 名稱'**
  String get tagsRenamePrompt;

  /// No description provided for @tagsDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除 #{name}'**
  String tagsDelete(String name);

  /// No description provided for @tagsDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 tag「{name}」？'**
  String tagsDeleteTitle(String name);

  /// No description provided for @tagsDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'已使用的內容會一併移除這個 tag。'**
  String get tagsDeleteBody;

  /// No description provided for @tagsAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增 tag'**
  String get tagsAdd;

  /// No description provided for @albumConfirm.
  ///
  /// In zh, this message translates to:
  /// **'確定'**
  String get albumConfirm;

  /// No description provided for @albumAddImage.
  ///
  /// In zh, this message translates to:
  /// **'加圖'**
  String get albumAddImage;

  /// No description provided for @albumSavedToGallery.
  ///
  /// In zh, this message translates to:
  /// **'已儲存到相簿'**
  String get albumSavedToGallery;

  /// No description provided for @albumSavedCountToGallery.
  ///
  /// In zh, this message translates to:
  /// **'已儲存 {count} 張到相簿'**
  String albumSavedCountToGallery(int count);

  /// No description provided for @albumSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'儲存失敗'**
  String get albumSaveFailed;

  /// No description provided for @albumMovedCount.
  ///
  /// In zh, this message translates to:
  /// **'已移動 {count} 張到{target}'**
  String albumMovedCount(int count, String target);

  /// No description provided for @albumDeleteImageTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這張圖？'**
  String get albumDeleteImageTitle;

  /// No description provided for @albumDeleteImagesTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 張圖？'**
  String albumDeleteImagesTitle(int count);

  /// No description provided for @albumCancelSelect.
  ///
  /// In zh, this message translates to:
  /// **'取消選擇'**
  String get albumCancelSelect;

  /// No description provided for @albumTitleWithPit.
  ///
  /// In zh, this message translates to:
  /// **'{pit} · {title}'**
  String albumTitleWithPit(String pit, String title);

  /// No description provided for @albumManageGroups.
  ///
  /// In zh, this message translates to:
  /// **'管理分組'**
  String get albumManageGroups;

  /// No description provided for @albumCoverSet.
  ///
  /// In zh, this message translates to:
  /// **'已設為坑的封面'**
  String get albumCoverSet;

  /// No description provided for @albumCoverPickTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇坑的封面'**
  String get albumCoverPickTitle;

  /// No description provided for @albumCoverHolding.
  ///
  /// In zh, this message translates to:
  /// **'長按中：{label} 封面'**
  String albumCoverHolding(String label);

  /// No description provided for @albumCoverPickHeading.
  ///
  /// In zh, this message translates to:
  /// **'選擇封面圖'**
  String get albumCoverPickHeading;

  /// No description provided for @albumCoverNone.
  ///
  /// In zh, this message translates to:
  /// **'沒有可選的圖'**
  String get albumCoverNone;

  /// No description provided for @albumSetCover.
  ///
  /// In zh, this message translates to:
  /// **'設為封面'**
  String get albumSetCover;

  /// No description provided for @albumFanEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯同人圖'**
  String get albumFanEditTitle;

  /// No description provided for @albumFieldImage.
  ///
  /// In zh, this message translates to:
  /// **'圖片'**
  String get albumFieldImage;

  /// No description provided for @albumFieldAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get albumFieldAuthor;

  /// No description provided for @albumFieldSource.
  ///
  /// In zh, this message translates to:
  /// **'出處'**
  String get albumFieldSource;

  /// No description provided for @albumFanNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增同人圖'**
  String get albumFanNewTitle;

  /// No description provided for @albumPickImageFirst.
  ///
  /// In zh, this message translates to:
  /// **'請先選擇圖片'**
  String get albumPickImageFirst;

  /// No description provided for @albumFanAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入好看同人圖'**
  String get albumFanAdd;

  /// No description provided for @albumGroupDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除分組「{name}」？'**
  String albumGroupDeleteTitle(String name);

  /// No description provided for @albumGroupDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'組內的圖會移到其他分組。'**
  String get albumGroupDeleteBody;

  /// No description provided for @albumGroupKeepOne.
  ///
  /// In zh, this message translates to:
  /// **'至少要保留一個分組'**
  String get albumGroupKeepOne;

  /// No description provided for @albumGroupNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'分組名稱'**
  String get albumGroupNameTitle;

  /// No description provided for @albumGroupHintFan.
  ///
  /// In zh, this message translates to:
  /// **'分組只用於好看同人圖，拖曳可調整次序'**
  String get albumGroupHintFan;

  /// No description provided for @albumGroupHintOfficial.
  ///
  /// In zh, this message translates to:
  /// **'分組只用於官方圖冊，拖曳可調整次序'**
  String get albumGroupHintOfficial;

  /// No description provided for @albumGroupRename.
  ///
  /// In zh, this message translates to:
  /// **'重新命名 {name}'**
  String albumGroupRename(String name);

  /// No description provided for @albumGroupDelete.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {name}'**
  String albumGroupDelete(String name);

  /// No description provided for @albumGroupAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增分組'**
  String get albumGroupAdd;

  /// No description provided for @albumGroupLabel.
  ///
  /// In zh, this message translates to:
  /// **'分組'**
  String get albumGroupLabel;

  /// No description provided for @albumRemoveImage.
  ///
  /// In zh, this message translates to:
  /// **'移除圖片'**
  String get albumRemoveImage;

  /// No description provided for @albumChangeGroup.
  ///
  /// In zh, this message translates to:
  /// **'更換分組'**
  String get albumChangeGroup;

  /// No description provided for @albumGroupChanged.
  ///
  /// In zh, this message translates to:
  /// **'已更換分組'**
  String get albumGroupChanged;

  /// No description provided for @albumCoverSetOfficial.
  ///
  /// In zh, this message translates to:
  /// **'已設為官方圖冊封面'**
  String get albumCoverSetOfficial;

  /// No description provided for @albumMoveTo.
  ///
  /// In zh, this message translates to:
  /// **'移動到'**
  String get albumMoveTo;

  /// No description provided for @albumOfficialEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有官方圖'**
  String get albumOfficialEmpty;

  /// No description provided for @albumOfficialNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新增官方圖'**
  String get albumOfficialNewTitle;

  /// No description provided for @albumOfficialAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入官方圖冊'**
  String get albumOfficialAdd;

  /// No description provided for @albumPreviewDateAdded.
  ///
  /// In zh, this message translates to:
  /// **'{year} / {month} / {day} 加入'**
  String albumPreviewDateAdded(int year, String month, String day);

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

  /// No description provided for @entityRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get entityRemove;

  /// No description provided for @entityRemoveImage.
  ///
  /// In zh, this message translates to:
  /// **'移除圖片'**
  String get entityRemoveImage;

  /// No description provided for @entityAddImage.
  ///
  /// In zh, this message translates to:
  /// **'加圖'**
  String get entityAddImage;

  /// No description provided for @entityFieldTitle.
  ///
  /// In zh, this message translates to:
  /// **'標題'**
  String get entityFieldTitle;

  /// No description provided for @entityFieldBody.
  ///
  /// In zh, this message translates to:
  /// **'內文'**
  String get entityFieldBody;

  /// No description provided for @entityTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'請輸入標題'**
  String get entityTitleRequired;

  /// No description provided for @entityConnectIdea.
  ///
  /// In zh, this message translates to:
  /// **'關聯腦洞'**
  String get entityConnectIdea;

  /// No description provided for @entityConnectDraft.
  ///
  /// In zh, this message translates to:
  /// **'關聯草稿'**
  String get entityConnectDraft;

  /// No description provided for @entityConnectPiece.
  ///
  /// In zh, this message translates to:
  /// **'關聯成圖'**
  String get entityConnectPiece;

  /// No description provided for @entityConnectSelectIdea.
  ///
  /// In zh, this message translates to:
  /// **'選擇腦洞'**
  String get entityConnectSelectIdea;

  /// No description provided for @entityConnectSelectDraft.
  ///
  /// In zh, this message translates to:
  /// **'選擇草稿'**
  String get entityConnectSelectDraft;

  /// No description provided for @entityConnectSelectPiece.
  ///
  /// In zh, this message translates to:
  /// **'選擇成圖'**
  String get entityConnectSelectPiece;

  /// No description provided for @entityConnectSelectedIdea.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 個'**
  String entityConnectSelectedIdea(int count);

  /// No description provided for @entityConnectSelectedDraft.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 份'**
  String entityConnectSelectedDraft(int count);

  /// No description provided for @entityConnectSelectedPiece.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 張'**
  String entityConnectSelectedPiece(int count);

  /// No description provided for @entityConnectEmpty.
  ///
  /// In zh, this message translates to:
  /// **'沒有可選擇的項目'**
  String get entityConnectEmpty;

  /// No description provided for @entityGallerySaved.
  ///
  /// In zh, this message translates to:
  /// **'已儲存到相簿'**
  String get entityGallerySaved;

  /// No description provided for @entityGallerySaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'儲存失敗'**
  String get entityGallerySaveFailed;

  /// No description provided for @ideaStatusOpen.
  ///
  /// In zh, this message translates to:
  /// **'未孵'**
  String get ideaStatusOpen;

  /// No description provided for @ideaStatusHatchingShort.
  ///
  /// In zh, this message translates to:
  /// **'孵化中'**
  String get ideaStatusHatchingShort;

  /// No description provided for @ideaStatusHatching.
  ///
  /// In zh, this message translates to:
  /// **'孵化中 · {count} 草稿'**
  String ideaStatusHatching(int count);

  /// No description provided for @ideaStatusHatchedShort.
  ///
  /// In zh, this message translates to:
  /// **'已孵'**
  String get ideaStatusHatchedShort;

  /// No description provided for @ideaStatusHatched.
  ///
  /// In zh, this message translates to:
  /// **'已孵 {count} 成圖'**
  String ideaStatusHatched(int count);

  /// No description provided for @ideaFormTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新增腦洞'**
  String get ideaFormTitleNew;

  /// No description provided for @ideaFormTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯腦洞'**
  String get ideaFormTitleEdit;

  /// No description provided for @ideaFormTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'用一句話記下想法'**
  String get ideaFormTitleHint;

  /// No description provided for @ideaFormBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'文字版的圖 —— 想畫什麼、哪個場景、什麼感覺…'**
  String get ideaFormBodyHint;

  /// No description provided for @ideaFormImages.
  ///
  /// In zh, this message translates to:
  /// **'配圖'**
  String get ideaFormImages;

  /// No description provided for @ideaFormCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立腦洞'**
  String get ideaFormCreate;

  /// No description provided for @draftFormMissingImage.
  ///
  /// In zh, this message translates to:
  /// **'請至少新增一張圖片'**
  String get draftFormMissingImage;

  /// No description provided for @draftFormTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新增草稿'**
  String get draftFormTitleNew;

  /// No description provided for @draftFormTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯草稿'**
  String get draftFormTitleEdit;

  /// No description provided for @draftFormImages.
  ///
  /// In zh, this message translates to:
  /// **'草稿圖'**
  String get draftFormImages;

  /// No description provided for @draftFormTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'為這張草稿命名'**
  String get draftFormTitleHint;

  /// No description provided for @draftFormBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'正在畫什麼、嘗試什麼構圖…'**
  String get draftFormBodyHint;

  /// No description provided for @draftFormCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立草稿'**
  String get draftFormCreate;

  /// No description provided for @pieceFormMissingImage.
  ///
  /// In zh, this message translates to:
  /// **'請至少選擇一張圖片'**
  String get pieceFormMissingImage;

  /// No description provided for @pieceFormLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'貼上連結網址'**
  String get pieceFormLinkHint;

  /// No description provided for @pieceFormPublishDate.
  ///
  /// In zh, this message translates to:
  /// **'發佈日期'**
  String get pieceFormPublishDate;

  /// No description provided for @pieceFormSocialLinks.
  ///
  /// In zh, this message translates to:
  /// **'社交媒體連結'**
  String get pieceFormSocialLinks;

  /// No description provided for @pieceFormAddSocialLink.
  ///
  /// In zh, this message translates to:
  /// **'加社交連結'**
  String get pieceFormAddSocialLink;

  /// No description provided for @pieceFormTarget.
  ///
  /// In zh, this message translates to:
  /// **'目標互動量'**
  String get pieceFormTarget;

  /// No description provided for @pieceFormActual.
  ///
  /// In zh, this message translates to:
  /// **'實際互動量'**
  String get pieceFormActual;

  /// No description provided for @pieceFormClient.
  ///
  /// In zh, this message translates to:
  /// **'委託人'**
  String get pieceFormClient;

  /// No description provided for @pieceFormAmount.
  ///
  /// In zh, this message translates to:
  /// **'金額'**
  String get pieceFormAmount;

  /// No description provided for @pieceFormCurrency.
  ///
  /// In zh, this message translates to:
  /// **'幣種'**
  String get pieceFormCurrency;

  /// No description provided for @pieceFormReceived.
  ///
  /// In zh, this message translates to:
  /// **'已收金額'**
  String get pieceFormReceived;

  /// No description provided for @pieceFormPaidInFull.
  ///
  /// In zh, this message translates to:
  /// **'已收齊'**
  String get pieceFormPaidInFull;

  /// No description provided for @pieceFormDueDate.
  ///
  /// In zh, this message translates to:
  /// **'交稿日期'**
  String get pieceFormDueDate;

  /// No description provided for @pieceFormTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新增成圖'**
  String get pieceFormTitleNew;

  /// No description provided for @pieceFormTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯成圖'**
  String get pieceFormTitleEdit;

  /// No description provided for @pieceFormImages.
  ///
  /// In zh, this message translates to:
  /// **'成品圖'**
  String get pieceFormImages;

  /// No description provided for @pieceFormTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'為這張成圖命名'**
  String get pieceFormTitleHint;

  /// No description provided for @pieceFormBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'想說的話、創作筆記…'**
  String get pieceFormBodyHint;

  /// No description provided for @pieceFormPublished.
  ///
  /// In zh, this message translates to:
  /// **'已公開發佈'**
  String get pieceFormPublished;

  /// No description provided for @pieceFormCommission.
  ///
  /// In zh, this message translates to:
  /// **'商稿'**
  String get pieceFormCommission;

  /// No description provided for @pieceFormFinishedAt.
  ///
  /// In zh, this message translates to:
  /// **'完成時間'**
  String get pieceFormFinishedAt;

  /// No description provided for @pieceFormCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立成圖'**
  String get pieceFormCreate;

  /// No description provided for @pieceAddImage.
  ///
  /// In zh, this message translates to:
  /// **'加成品圖'**
  String get pieceAddImage;

  /// No description provided for @pieceDateEmpty.
  ///
  /// In zh, this message translates to:
  /// **'選擇日期'**
  String get pieceDateEmpty;

  /// No description provided for @pieceHeartUnit.
  ///
  /// In zh, this message translates to:
  /// **'紅心'**
  String get pieceHeartUnit;

  /// No description provided for @piecePaymentUnpaid.
  ///
  /// In zh, this message translates to:
  /// **'未收'**
  String get piecePaymentUnpaid;

  /// No description provided for @piecePaymentPartial.
  ///
  /// In zh, this message translates to:
  /// **'已收 {amount}'**
  String piecePaymentPartial(String amount);

  /// No description provided for @piecePaymentPaid.
  ///
  /// In zh, this message translates to:
  /// **'已收齊'**
  String get piecePaymentPaid;

  /// No description provided for @entityPlatformTwitter.
  ///
  /// In zh, this message translates to:
  /// **'推特'**
  String get entityPlatformTwitter;

  /// No description provided for @entityPlatformTwitterFull.
  ///
  /// In zh, this message translates to:
  /// **'推特（Twitter/X）'**
  String get entityPlatformTwitterFull;

  /// No description provided for @entityPlatformXiaohongshu.
  ///
  /// In zh, this message translates to:
  /// **'小紅書'**
  String get entityPlatformXiaohongshu;

  /// No description provided for @entityPlatformLofter.
  ///
  /// In zh, this message translates to:
  /// **'Lofter'**
  String get entityPlatformLofter;

  /// No description provided for @entityPlatformPixiv.
  ///
  /// In zh, this message translates to:
  /// **'Pixiv'**
  String get entityPlatformPixiv;

  /// No description provided for @entityPlatformWeibo.
  ///
  /// In zh, this message translates to:
  /// **'微博'**
  String get entityPlatformWeibo;

  /// No description provided for @entityPlatformInstagram.
  ///
  /// In zh, this message translates to:
  /// **'Instagram'**
  String get entityPlatformInstagram;

  /// No description provided for @entityPlatformOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get entityPlatformOther;

  /// No description provided for @entityPlatformLink.
  ///
  /// In zh, this message translates to:
  /// **'連結'**
  String get entityPlatformLink;

  /// No description provided for @entityPlatformMarkTwitter.
  ///
  /// In zh, this message translates to:
  /// **'X'**
  String get entityPlatformMarkTwitter;

  /// No description provided for @entityPlatformMarkXiaohongshu.
  ///
  /// In zh, this message translates to:
  /// **'紅'**
  String get entityPlatformMarkXiaohongshu;

  /// No description provided for @entityPlatformMarkLofter.
  ///
  /// In zh, this message translates to:
  /// **'Lo'**
  String get entityPlatformMarkLofter;

  /// No description provided for @entityPlatformMarkPixiv.
  ///
  /// In zh, this message translates to:
  /// **'Px'**
  String get entityPlatformMarkPixiv;

  /// No description provided for @entityPlatformMarkWeibo.
  ///
  /// In zh, this message translates to:
  /// **'微'**
  String get entityPlatformMarkWeibo;

  /// No description provided for @entityPlatformMarkInstagram.
  ///
  /// In zh, this message translates to:
  /// **'IG'**
  String get entityPlatformMarkInstagram;

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
  /// **'圖片比例'**
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

  /// No description provided for @moveReviewPitLabel.
  ///
  /// In zh, this message translates to:
  /// **'坑'**
  String get moveReviewPitLabel;

  /// No description provided for @moveReviewPositionLabel.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get moveReviewPositionLabel;

  /// No description provided for @moveReviewMovedToPit.
  ///
  /// In zh, this message translates to:
  /// **'已移動 {count} 張到「{pit}」的{target}'**
  String moveReviewMovedToPit(int count, String pit, String target);

  /// No description provided for @moveReviewPickTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇 {month} 月的圖片'**
  String moveReviewPickTitle(int month);

  /// No description provided for @moveReviewPieceCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張成圖'**
  String moveReviewPieceCount(int count);

  /// No description provided for @searchCategoryPiece.
  ///
  /// In zh, this message translates to:
  /// **'成圖'**
  String get searchCategoryPiece;

  /// No description provided for @searchCategoryFan.
  ///
  /// In zh, this message translates to:
  /// **'同人圖'**
  String get searchCategoryFan;

  /// No description provided for @searchCategoryDraft.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get searchCategoryDraft;

  /// No description provided for @searchCategoryIdea.
  ///
  /// In zh, this message translates to:
  /// **'腦洞'**
  String get searchCategoryIdea;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋{name}'**
  String searchHint(String name);

  /// No description provided for @searchFrequentTags.
  ///
  /// In zh, this message translates to:
  /// **'常用 tag'**
  String get searchFrequentTags;

  /// No description provided for @searchRemoveFilter.
  ///
  /// In zh, this message translates to:
  /// **'移除篩選'**
  String get searchRemoveFilter;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'沒有找到符合的內容'**
  String get searchNoResults;

  /// No description provided for @ideaListDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 個腦洞？'**
  String ideaListDeleteSelected(int count);

  /// No description provided for @ideaListCountUnhatched.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個 · {unhatched} 未孵'**
  String ideaListCountUnhatched(int count, int unhatched);

  /// No description provided for @ideaListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有腦洞'**
  String get ideaListEmpty;

  /// No description provided for @ideaListEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'記下第一個腦洞'**
  String get ideaListEmptyAction;

  /// No description provided for @ideaDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'腦洞詳情'**
  String get ideaDetailTitle;

  /// No description provided for @ideaDetailDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這個腦洞？'**
  String get ideaDetailDeleteTitle;

  /// No description provided for @ideaDetailCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'建立於 {date}'**
  String ideaDetailCreatedAt(String date);

  /// No description provided for @ideaDetailDraftLabel.
  ///
  /// In zh, this message translates to:
  /// **'草稿（{count} 張）'**
  String ideaDetailDraftLabel(int count);

  /// No description provided for @ideaLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的腦洞'**
  String get ideaLinkedHeading;

  /// No description provided for @draftLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的草稿'**
  String get draftLinkedHeading;

  /// No description provided for @pieceLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的成圖'**
  String get pieceLinkedHeading;

  /// No description provided for @draftListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有草稿'**
  String get draftListEmpty;

  /// No description provided for @draftViewList.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get draftViewList;

  /// No description provided for @draftDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'草稿詳情'**
  String get draftDetailTitle;

  /// No description provided for @draftDetailDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這份草稿？'**
  String get draftDetailDeleteTitle;

  /// No description provided for @draftDetailImageLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 張'**
  String draftDetailImageLabel(int n);

  /// No description provided for @pieceListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有成圖'**
  String get pieceListEmpty;

  /// No description provided for @pieceViewWaterfall.
  ///
  /// In zh, this message translates to:
  /// **'瀑布'**
  String get pieceViewWaterfall;

  /// No description provided for @pieceViewGrid.
  ///
  /// In zh, this message translates to:
  /// **'田字'**
  String get pieceViewGrid;

  /// No description provided for @pieceViewNine.
  ///
  /// In zh, this message translates to:
  /// **'九宮格'**
  String get pieceViewNine;

  /// No description provided for @pieceDetailUpdateLikes.
  ///
  /// In zh, this message translates to:
  /// **'更新實際互動量'**
  String get pieceDetailUpdateLikes;

  /// No description provided for @pieceDetailDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這張成圖？'**
  String get pieceDetailDeleteTitle;

  /// No description provided for @pieceDetailReached.
  ///
  /// In zh, this message translates to:
  /// **'已達標 ✦'**
  String get pieceDetailReached;

  /// No description provided for @pieceDetailActualLikes.
  ///
  /// In zh, this message translates to:
  /// **'實際互動量 {count}'**
  String pieceDetailActualLikes(int count);

  /// No description provided for @pieceDetailTarget.
  ///
  /// In zh, this message translates to:
  /// **'目標 {count}'**
  String pieceDetailTarget(int count);

  /// No description provided for @pieceDetailPayment.
  ///
  /// In zh, this message translates to:
  /// **'收款'**
  String get pieceDetailPayment;

  /// No description provided for @albumFanEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有同人圖'**
  String get albumFanEmpty;

  /// No description provided for @albumFanCoverSet.
  ///
  /// In zh, this message translates to:
  /// **'已設為好看同人圖封面'**
  String get albumFanCoverSet;

  /// No description provided for @shareTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入到'**
  String get shareTitle;

  /// No description provided for @shareFieldPit.
  ///
  /// In zh, this message translates to:
  /// **'坑'**
  String get shareFieldPit;

  /// No description provided for @shareFieldPosition.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get shareFieldPosition;

  /// No description provided for @shareAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get shareAdd;

  /// No description provided for @shareNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get shareNext;

  /// No description provided for @shareAdded.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get shareAdded;
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
