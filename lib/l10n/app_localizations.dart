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
  /// **'坑內所有內容會一併移到最近刪除'**
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
  /// **'我的摸魚'**
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

  /// No description provided for @pitsCountPieces.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份'**
  String pitsCountPieces(int count);

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
  /// **'還沒有成圖・開始你的第一份'**
  String get pitsPiecesEmpty;

  /// No description provided for @pitsMyPits.
  ///
  /// In zh, this message translates to:
  /// **'我的坑'**
  String get pitsMyPits;

  /// No description provided for @albumPillNoSource.
  ///
  /// In zh, this message translates to:
  /// **'無出處'**
  String get albumPillNoSource;

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

  /// No description provided for @albumPreviewImage.
  ///
  /// In zh, this message translates to:
  /// **'預覽圖片'**
  String get albumPreviewImage;

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
  /// **'時間軸'**
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

  /// No description provided for @appiconTitle.
  ///
  /// In zh, this message translates to:
  /// **'App 圖示'**
  String get appiconTitle;

  /// No description provided for @appiconSanbi.
  ///
  /// In zh, this message translates to:
  /// **'三筆'**
  String get appiconSanbi;

  /// No description provided for @appiconHuati.
  ///
  /// In zh, this message translates to:
  /// **'花體'**
  String get appiconHuati;

  /// No description provided for @appiconToast.
  ///
  /// In zh, this message translates to:
  /// **'桌面圖示已換成「{name}」'**
  String appiconToast(String name);

  /// No description provided for @backupStorageTitle.
  ///
  /// In zh, this message translates to:
  /// **'儲存空間'**
  String get backupStorageTitle;

  /// No description provided for @backupStorageOfLimit.
  ///
  /// In zh, this message translates to:
  /// **' / {limit}'**
  String backupStorageOfLimit(String limit);

  /// No description provided for @backupStorageUsedLabel.
  ///
  /// In zh, this message translates to:
  /// **'已用'**
  String get backupStorageUsedLabel;

  /// No description provided for @backupStorageDrawer.
  ///
  /// In zh, this message translates to:
  /// **'畫匣 {size}'**
  String backupStorageDrawer(String size);

  /// No description provided for @backupStorageOther.
  ///
  /// In zh, this message translates to:
  /// **'其他 {size}'**
  String backupStorageOther(String size);

  /// No description provided for @backupStorageSemantics.
  ///
  /// In zh, this message translates to:
  /// **'儲存空間，已用 {used}，畫匣 {drawer}，其他 {other}'**
  String backupStorageSemantics(String used, String drawer, String other);

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

  /// No description provided for @dayflowEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有紀錄'**
  String get dayflowEmpty;

  /// No description provided for @devOptsTitle.
  ///
  /// In zh, this message translates to:
  /// **'開發者選項'**
  String get devOptsTitle;

  /// No description provided for @devOptsLayoutBounds.
  ///
  /// In zh, this message translates to:
  /// **'顯示版面邊界'**
  String get devOptsLayoutBounds;

  /// No description provided for @devOptsBaselines.
  ///
  /// In zh, this message translates to:
  /// **'顯示文字基線'**
  String get devOptsBaselines;

  /// No description provided for @devOptsPointers.
  ///
  /// In zh, this message translates to:
  /// **'顯示點擊區域'**
  String get devOptsPointers;

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

  /// No description provided for @entityFieldDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get entityFieldDate;

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
  /// **'關聯摸魚'**
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
  /// **'選擇摸魚'**
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

  /// No description provided for @entityUntitledName.
  ///
  /// In zh, this message translates to:
  /// **'{date} {kind}'**
  String entityUntitledName(String date, String kind);

  /// No description provided for @entityConnectSelectedPiece.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 份'**
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
  /// **'孵化中 · {count} 摸魚'**
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
  /// **'新增摸魚'**
  String get draftFormTitleNew;

  /// No description provided for @draftFormTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯摸魚'**
  String get draftFormTitleEdit;

  /// No description provided for @draftFormImages.
  ///
  /// In zh, this message translates to:
  /// **'摸魚圖'**
  String get draftFormImages;

  /// No description provided for @draftFormCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立摸魚'**
  String get draftFormCreate;

  /// No description provided for @pieceFormMissingImage.
  ///
  /// In zh, this message translates to:
  /// **'請至少選擇一張圖片'**
  String get pieceFormMissingImage;

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

  /// No description provided for @formNumberInvalid.
  ///
  /// In zh, this message translates to:
  /// **'請輸入數字'**
  String get formNumberInvalid;

  /// No description provided for @authLinkFailedFriendly.
  ///
  /// In zh, this message translates to:
  /// **'連結失敗，請稍後再試'**
  String get authLinkFailedFriendly;

  /// No description provided for @authOfflineFriendly.
  ///
  /// In zh, this message translates to:
  /// **'連不上網絡，請檢查網絡後再試'**
  String get authOfflineFriendly;

  /// No description provided for @goalsNoPitTitle.
  ///
  /// In zh, this message translates to:
  /// **'還沒有坑'**
  String get goalsNoPitTitle;

  /// No description provided for @formImageLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'這張圖讀取失敗'**
  String get formImageLoadFailed;

  /// No description provided for @globalSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋全部坑'**
  String get globalSearchHint;

  /// No description provided for @globalSearchTagsHeading.
  ///
  /// In zh, this message translates to:
  /// **'tag'**
  String get globalSearchTagsHeading;

  /// No description provided for @globalSearchPitSemantics.
  ///
  /// In zh, this message translates to:
  /// **'{name}，{count} 筆'**
  String globalSearchPitSemantics(String name, int count);

  /// No description provided for @globalSearchClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get globalSearchClear;

  /// No description provided for @searchUntagged.
  ///
  /// In zh, this message translates to:
  /// **'未加 tag'**
  String get searchUntagged;

  /// No description provided for @searchSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 筆'**
  String searchSelectedCount(int count);

  /// No description provided for @goalsTitle.
  ///
  /// In zh, this message translates to:
  /// **'時間軸'**
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
  /// **'摸魚'**
  String get goalsKindDraft;

  /// No description provided for @goalsKindPiece.
  ///
  /// In zh, this message translates to:
  /// **'成圖'**
  String get goalsKindPiece;

  /// No description provided for @goalsPickPit.
  ///
  /// In zh, this message translates to:
  /// **'選擇坑'**
  String get goalsPickPit;

  /// No description provided for @goalsPitAllHint.
  ///
  /// In zh, this message translates to:
  /// **'不選＝所有坑'**
  String get goalsPitAllHint;

  /// No description provided for @goalsPitSheetDone.
  ///
  /// In zh, this message translates to:
  /// **'完成（{count}）'**
  String goalsPitSheetDone(int count);

  /// No description provided for @goalsTagWithPit.
  ///
  /// In zh, this message translates to:
  /// **'{tag}｜{pit}'**
  String goalsTagWithPit(String tag, String pit);

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
  /// **'畫 {count} 份摸魚'**
  String goalsAutoNameDraft(int count);

  /// No description provided for @goalsAutoNamePiece.
  ///
  /// In zh, this message translates to:
  /// **'完成 {count} 份成圖'**
  String goalsAutoNamePiece(int count);

  /// No description provided for @goalsAutoNamePieceLikes.
  ///
  /// In zh, this message translates to:
  /// **'互動量過 {likes} 的成圖 {count} 份'**
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
  /// **'未收齊 {count} 份'**
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
  /// **'已收 {amount} · {count} 份'**
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

  /// No description provided for @ipadauditGifLoop.
  ///
  /// In zh, this message translates to:
  /// **'GIF · 自動循環'**
  String get ipadauditGifLoop;

  /// No description provided for @ipadauditVideoMeta.
  ///
  /// In zh, this message translates to:
  /// **'影片 · {duration} · 縮圖取第一格'**
  String ipadauditVideoMeta(String duration);

  /// No description provided for @ipadauditGifMeta.
  ///
  /// In zh, this message translates to:
  /// **'GIF · 預覽時自動播放'**
  String get ipadauditGifMeta;

  /// No description provided for @ipadauditImagesCount.
  ///
  /// In zh, this message translates to:
  /// **'{label} · {n} 張'**
  String ipadauditImagesCount(String label, int n);

  /// No description provided for @sensitiveRevealThis.
  ///
  /// In zh, this message translates to:
  /// **'顯示這張'**
  String get sensitiveRevealThis;

  /// No description provided for @sensitiveReblur.
  ///
  /// In zh, this message translates to:
  /// **'重新模糊'**
  String get sensitiveReblur;

  /// No description provided for @ipadformsFanNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'加收藏'**
  String get ipadformsFanNewTitle;

  /// No description provided for @ipadformsFanAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入同人圖'**
  String get ipadformsFanAdd;

  /// No description provided for @ipadformsOfficialGroupNote.
  ///
  /// In zh, this message translates to:
  /// **'{n} 張圖片將一併加入「{group}」，之後可逐張修改分組。'**
  String ipadformsOfficialGroupNote(int n, String group);

  /// No description provided for @ipadformsShareTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入到畫匣'**
  String get ipadformsShareTitle;

  /// No description provided for @ipadListsReferenceView.
  ///
  /// In zh, this message translates to:
  /// **'參考檢視'**
  String get ipadListsReferenceView;

  /// No description provided for @ipadListsMultiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多選'**
  String get ipadListsMultiSelect;

  /// No description provided for @ipadListsPreviewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'選擇一張圖片以預覽'**
  String get ipadListsPreviewEmpty;

  /// No description provided for @ipadListsIdeaEmpty.
  ///
  /// In zh, this message translates to:
  /// **'選擇一個腦洞以查看詳情'**
  String get ipadListsIdeaEmpty;

  /// No description provided for @ipadListsDraftEmpty.
  ///
  /// In zh, this message translates to:
  /// **'選擇一份摸魚以查看詳情'**
  String get ipadListsDraftEmpty;

  /// No description provided for @ipadListsPieceEmpty.
  ///
  /// In zh, this message translates to:
  /// **'選擇一份成圖以查看詳情'**
  String get ipadListsPieceEmpty;

  /// No description provided for @ipadListsDraftImageN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 張'**
  String ipadListsDraftImageN(int n);

  /// No description provided for @ipadListsDraftIdeaLink.
  ///
  /// In zh, this message translates to:
  /// **'腦洞：{title}'**
  String ipadListsDraftIdeaLink(String title);

  /// No description provided for @ipadListsIdeaFlow.
  ///
  /// In zh, this message translates to:
  /// **'腦洞 → 摸魚 → 成圖'**
  String get ipadListsIdeaFlow;

  /// No description provided for @ipadListsStageIdea.
  ///
  /// In zh, this message translates to:
  /// **'腦洞'**
  String get ipadListsStageIdea;

  /// No description provided for @ipadListsStageDraft.
  ///
  /// In zh, this message translates to:
  /// **'摸魚'**
  String get ipadListsStageDraft;

  /// No description provided for @ipadListsStagePiece.
  ///
  /// In zh, this message translates to:
  /// **'成圖'**
  String get ipadListsStagePiece;

  /// No description provided for @ipadListsStartDraftFromIdea.
  ///
  /// In zh, this message translates to:
  /// **'從這個腦洞開摸魚'**
  String get ipadListsStartDraftFromIdea;

  /// No description provided for @ipadListsReached.
  ///
  /// In zh, this message translates to:
  /// **'已達標'**
  String get ipadListsReached;

  /// No description provided for @ipadListsNotReached.
  ///
  /// In zh, this message translates to:
  /// **'未達標'**
  String get ipadListsNotReached;

  /// No description provided for @ipadListsViewWaterfall.
  ///
  /// In zh, this message translates to:
  /// **'瀑布'**
  String get ipadListsViewWaterfall;

  /// No description provided for @ipadListsOshiSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋標題、內文'**
  String get ipadListsOshiSearchHint;

  /// No description provided for @ipadListsOshiSearchLabel.
  ///
  /// In zh, this message translates to:
  /// **'搜尋推活紀錄'**
  String get ipadListsOshiSearchLabel;

  /// No description provided for @ipadListsOshiCharacterTags.
  ///
  /// In zh, this message translates to:
  /// **'角色 tag'**
  String get ipadListsOshiCharacterTags;

  /// No description provided for @ipadListsOshiJumpToMonth.
  ///
  /// In zh, this message translates to:
  /// **'跳到月份'**
  String get ipadListsOshiJumpToMonth;

  /// No description provided for @ipadListsOshiEarlier.
  ///
  /// In zh, this message translates to:
  /// **'更早'**
  String get ipadListsOshiEarlier;

  /// No description provided for @ipadListsMonthShort.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月'**
  String ipadListsMonthShort(int month);

  /// No description provided for @ipadmediaMenuLabel.
  ///
  /// In zh, this message translates to:
  /// **'加圖來源'**
  String get ipadmediaMenuLabel;

  /// No description provided for @ipadmediaSheetTitle.
  ///
  /// In zh, this message translates to:
  /// **'加圖'**
  String get ipadmediaSheetTitle;

  /// No description provided for @ipadmediaSheetHint.
  ///
  /// In zh, this message translates to:
  /// **'照片可多選，並保留選取順序；檔案支援 CSP 匯出的 PNG／JPG。'**
  String get ipadmediaSheetHint;

  /// No description provided for @ipadmediaTilePhotos.
  ///
  /// In zh, this message translates to:
  /// **'照片'**
  String get ipadmediaTilePhotos;

  /// No description provided for @ipadmediaTileFiles.
  ///
  /// In zh, this message translates to:
  /// **'檔案'**
  String get ipadmediaTileFiles;

  /// No description provided for @ipadmediaTileMaterials.
  ///
  /// In zh, this message translates to:
  /// **'素材庫'**
  String get ipadmediaTileMaterials;

  /// No description provided for @ipadmediaTileCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get ipadmediaTileCamera;

  /// No description provided for @ipadmediaClipboardTitle.
  ///
  /// In zh, this message translates to:
  /// **'剪貼簿'**
  String get ipadmediaClipboardTitle;

  /// No description provided for @ipadmediaClipboardSub.
  ///
  /// In zh, this message translates to:
  /// **'剛剛複製的圖片'**
  String get ipadmediaClipboardSub;

  /// No description provided for @ipadmediaPhotos.
  ///
  /// In zh, this message translates to:
  /// **'從「照片」選取'**
  String get ipadmediaPhotos;

  /// No description provided for @ipadmediaPhotosSub.
  ///
  /// In zh, this message translates to:
  /// **'系統相簿，可多選並保留選取順序'**
  String get ipadmediaPhotosSub;

  /// No description provided for @ipadmediaFiles.
  ///
  /// In zh, this message translates to:
  /// **'從「檔案」選取'**
  String get ipadmediaFiles;

  /// No description provided for @ipadmediaFilesSub.
  ///
  /// In zh, this message translates to:
  /// **'iCloud Drive、CSP 匯出的 PNG／JPG'**
  String get ipadmediaFilesSub;

  /// No description provided for @ipadmediaMaterials.
  ///
  /// In zh, this message translates to:
  /// **'從素材庫選取'**
  String get ipadmediaMaterials;

  /// No description provided for @ipadmediaMaterialsSub.
  ///
  /// In zh, this message translates to:
  /// **'畫匣內已收藏的素材'**
  String get ipadmediaMaterialsSub;

  /// No description provided for @ipadmediaCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get ipadmediaCamera;

  /// No description provided for @ipadmediaPaste.
  ///
  /// In zh, this message translates to:
  /// **'貼上'**
  String get ipadmediaPaste;

  /// No description provided for @ipadmediaPasteHasImage.
  ///
  /// In zh, this message translates to:
  /// **'剪貼簿有 1 張圖'**
  String get ipadmediaPasteHasImage;

  /// No description provided for @ipadmediaPasteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪貼簿裡沒有圖片'**
  String get ipadmediaPasteEmpty;

  /// No description provided for @ipadmediaFilesFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法讀取所選檔案'**
  String get ipadmediaFilesFailed;

  /// No description provided for @ipadmediaCameraFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法開啟相機'**
  String get ipadmediaCameraFailed;

  /// No description provided for @ipadmediaMaterialsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'素材庫還沒有素材'**
  String get ipadmediaMaterialsEmpty;

  /// No description provided for @ipadmediaMaterialsAdd.
  ///
  /// In zh, this message translates to:
  /// **'加入 {count} 張'**
  String ipadmediaMaterialsAdd(int count);

  /// No description provided for @ipadmediaMaterialsFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法讀取所選素材'**
  String get ipadmediaMaterialsFailed;

  /// No description provided for @ipadmediaDropTitle.
  ///
  /// In zh, this message translates to:
  /// **'放開即可加入「{target}」'**
  String ipadmediaDropTitle(String target);

  /// No description provided for @ipadmediaDropChooseGroup.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張 · 放開後選擇分組'**
  String ipadmediaDropChooseGroup(int count);

  /// No description provided for @ipadmediaDropCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張'**
  String ipadmediaDropCount(int count);

  /// No description provided for @ipadmediaDropHint.
  ///
  /// In zh, this message translates to:
  /// **'分屏時可直接從「照片」或「檔案」拖曳圖片至此'**
  String get ipadmediaDropHint;

  /// No description provided for @ipadmediaDropLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在載入 {done}／{total} 張'**
  String ipadmediaDropLoading(int done, int total);

  /// No description provided for @ipadmediaDropFailed.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張無法載入'**
  String ipadmediaDropFailed(int count);

  /// No description provided for @ipadnavMainMenu.
  ///
  /// In zh, this message translates to:
  /// **'主選單'**
  String get ipadnavMainMenu;

  /// No description provided for @ipadnavCurrentPits.
  ///
  /// In zh, this message translates to:
  /// **'現坑'**
  String get ipadnavCurrentPits;

  /// No description provided for @ipadnavYears.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get ipadnavYears;

  /// No description provided for @ipadpitChangeCover.
  ///
  /// In zh, this message translates to:
  /// **'換封面'**
  String get ipadpitChangeCover;

  /// No description provided for @ipadpitPickFromPit.
  ///
  /// In zh, this message translates to:
  /// **'從坑內選圖'**
  String get ipadpitPickFromPit;

  /// No description provided for @ipadpitPickFromAlbum.
  ///
  /// In zh, this message translates to:
  /// **'從相簿選擇'**
  String get ipadpitPickFromAlbum;

  /// No description provided for @ipadpitCoverLater.
  ///
  /// In zh, this message translates to:
  /// **'封面可於建立後在「編輯坑」中選擇。'**
  String get ipadpitCoverLater;

  /// No description provided for @ipadpitSectionsLabel.
  ///
  /// In zh, this message translates to:
  /// **'坑內分區'**
  String get ipadpitSectionsLabel;

  /// No description provided for @ipadsearchAlbums.
  ///
  /// In zh, this message translates to:
  /// **'相冊'**
  String get ipadsearchAlbums;

  /// No description provided for @ipadsearchArchivedBadge.
  ///
  /// In zh, this message translates to:
  /// **'封存'**
  String get ipadsearchArchivedBadge;

  /// No description provided for @ipadsearchAddTag.
  ///
  /// In zh, this message translates to:
  /// **'加 tag'**
  String get ipadsearchAddTag;

  /// No description provided for @ipadsearchSelectedItems.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 項'**
  String ipadsearchSelectedItems(int count);

  /// No description provided for @ipadsearchMoreSemantics.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get ipadsearchMoreSemantics;

  /// No description provided for @ipadsyncNetWifi.
  ///
  /// In zh, this message translates to:
  /// **'Wi-Fi'**
  String get ipadsyncNetWifi;

  /// No description provided for @ipadsyncNetCellular.
  ///
  /// In zh, this message translates to:
  /// **'行動網絡'**
  String get ipadsyncNetCellular;

  /// No description provided for @ipadsyncNetEthernet.
  ///
  /// In zh, this message translates to:
  /// **'有線網絡'**
  String get ipadsyncNetEthernet;

  /// No description provided for @ipadsyncSettings.
  ///
  /// In zh, this message translates to:
  /// **'同步設定'**
  String get ipadsyncSettings;

  /// No description provided for @ipadsyncPitSyncingMeta.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get ipadsyncPitSyncingMeta;

  /// No description provided for @ipadsyncConnectHint.
  ///
  /// In zh, this message translates to:
  /// **'連結後，iPad 與手機會自動同步'**
  String get ipadsyncConnectHint;

  /// No description provided for @ipadsyncMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分鐘'**
  String ipadsyncMinutes(int minutes);

  /// No description provided for @ipadsyncFullLabel.
  ///
  /// In zh, this message translates to:
  /// **'同步中，Drive 已滿'**
  String get ipadsyncFullLabel;

  /// No description provided for @ipadsyncMoreWaitingSpace.
  ///
  /// In zh, this message translates to:
  /// **'還有 {count} 張等待空間'**
  String ipadsyncMoreWaitingSpace(int count);

  /// No description provided for @materialTitle.
  ///
  /// In zh, this message translates to:
  /// **'素材庫'**
  String get materialTitle;

  /// No description provided for @materialLayoutWaterfall.
  ///
  /// In zh, this message translates to:
  /// **'瀑布'**
  String get materialLayoutWaterfall;

  /// No description provided for @materialLayoutGrid.
  ///
  /// In zh, this message translates to:
  /// **'九宮格'**
  String get materialLayoutGrid;

  /// No description provided for @materialAddLabel.
  ///
  /// In zh, this message translates to:
  /// **'加素材'**
  String get materialAddLabel;

  /// No description provided for @materialEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有素材'**
  String get materialEmpty;

  /// No description provided for @materialCatClothing.
  ///
  /// In zh, this message translates to:
  /// **'服裝'**
  String get materialCatClothing;

  /// No description provided for @materialCatPose.
  ///
  /// In zh, this message translates to:
  /// **'姿勢'**
  String get materialCatPose;

  /// No description provided for @materialCatBody.
  ///
  /// In zh, this message translates to:
  /// **'人體'**
  String get materialCatBody;

  /// No description provided for @materialCatPalette.
  ///
  /// In zh, this message translates to:
  /// **'色盤'**
  String get materialCatPalette;

  /// No description provided for @materialCatScene.
  ///
  /// In zh, this message translates to:
  /// **'場景'**
  String get materialCatScene;

  /// No description provided for @materialCatStyle.
  ///
  /// In zh, this message translates to:
  /// **'畫風'**
  String get materialCatStyle;

  /// No description provided for @materialCatSticker.
  ///
  /// In zh, this message translates to:
  /// **'貼圖'**
  String get materialCatSticker;

  /// No description provided for @materialFieldCategory.
  ///
  /// In zh, this message translates to:
  /// **'分類'**
  String get materialFieldCategory;

  /// No description provided for @materialShareDestLabel.
  ///
  /// In zh, this message translates to:
  /// **'加入到哪裡'**
  String get materialShareDestLabel;

  /// No description provided for @mediaBadgeGif.
  ///
  /// In zh, this message translates to:
  /// **'GIF'**
  String get mediaBadgeGif;

  /// No description provided for @mediaPlay.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get mediaPlay;

  /// No description provided for @mediaPause.
  ///
  /// In zh, this message translates to:
  /// **'暫停'**
  String get mediaPause;

  /// No description provided for @mediaMute.
  ///
  /// In zh, this message translates to:
  /// **'靜音'**
  String get mediaMute;

  /// No description provided for @mediaUnmute.
  ///
  /// In zh, this message translates to:
  /// **'取消靜音'**
  String get mediaUnmute;

  /// No description provided for @mediaFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'全螢幕'**
  String get mediaFullscreen;

  /// No description provided for @mediaExitFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'結束全螢幕'**
  String get mediaExitFullscreen;

  /// No description provided for @mediaSeekBar.
  ///
  /// In zh, this message translates to:
  /// **'播放進度'**
  String get mediaSeekBar;

  /// No description provided for @mediaVideoError.
  ///
  /// In zh, this message translates to:
  /// **'無法播放這個影片'**
  String get mediaVideoError;

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
  /// **'{count} 份成圖'**
  String moveReviewPieceCount(int count);

  /// No description provided for @officialtagEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'編輯官方圖'**
  String get officialtagEditTitle;

  /// No description provided for @searchCategoryOfficial.
  ///
  /// In zh, this message translates to:
  /// **'官方圖'**
  String get searchCategoryOfficial;

  /// No description provided for @oshiTitle.
  ///
  /// In zh, this message translates to:
  /// **'推活'**
  String get oshiTitle;

  /// No description provided for @oshiCountRecords.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆'**
  String oshiCountRecords(int count);

  /// No description provided for @oshiCountItems.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String oshiCountItems(int count);

  /// No description provided for @oshiMonthHeader.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年 {month} 月'**
  String oshiMonthHeader(int year, int month);

  /// No description provided for @oshiWeekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'週一'**
  String get oshiWeekdayMon;

  /// No description provided for @oshiWeekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'週二'**
  String get oshiWeekdayTue;

  /// No description provided for @oshiWeekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'週三'**
  String get oshiWeekdayWed;

  /// No description provided for @oshiWeekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'週四'**
  String get oshiWeekdayThu;

  /// No description provided for @oshiWeekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'週五'**
  String get oshiWeekdayFri;

  /// No description provided for @oshiWeekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'週六'**
  String get oshiWeekdaySat;

  /// No description provided for @oshiWeekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'週日'**
  String get oshiWeekdaySun;

  /// No description provided for @oshiLayoutTimeline.
  ///
  /// In zh, this message translates to:
  /// **'時間軸'**
  String get oshiLayoutTimeline;

  /// No description provided for @oshiLayoutGrid.
  ///
  /// In zh, this message translates to:
  /// **'網格'**
  String get oshiLayoutGrid;

  /// No description provided for @oshiEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有推活紀錄'**
  String get oshiEmpty;

  /// No description provided for @oshiEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'新增紀錄'**
  String get oshiEmptyAction;

  /// No description provided for @oshiAddRecord.
  ///
  /// In zh, this message translates to:
  /// **'新增推活紀錄'**
  String get oshiAddRecord;

  /// No description provided for @oshiFormTitleNew.
  ///
  /// In zh, this message translates to:
  /// **'新增推活紀錄'**
  String get oshiFormTitleNew;

  /// No description provided for @oshiFormTitleEdit.
  ///
  /// In zh, this message translates to:
  /// **'編輯推活紀錄'**
  String get oshiFormTitleEdit;

  /// No description provided for @oshiFieldImages.
  ///
  /// In zh, this message translates to:
  /// **'圖片'**
  String get oshiFieldImages;

  /// No description provided for @oshiFieldDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get oshiFieldDescription;

  /// No description provided for @oshiFieldDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get oshiFieldDate;

  /// No description provided for @oshiFormCreate.
  ///
  /// In zh, this message translates to:
  /// **'建立紀錄'**
  String get oshiFormCreate;

  /// No description provided for @oshiDetailDate.
  ///
  /// In zh, this message translates to:
  /// **'{date}（{weekday}）'**
  String oshiDetailDate(String date, String weekday);

  /// No description provided for @oshiDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這筆紀錄？'**
  String get oshiDeleteTitle;

  /// No description provided for @oshiGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'分組只用於推活，拖曳可調整次序'**
  String get oshiGroupHint;

  /// No description provided for @oshiGroupDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'組內的紀錄會變成沒有分組。'**
  String get oshiGroupDeleteBody;

  /// No description provided for @oshiSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 筆'**
  String oshiSelectedCount(int count);

  /// No description provided for @oshiNoGroup.
  ///
  /// In zh, this message translates to:
  /// **'不分組'**
  String get oshiNoGroup;

  /// No description provided for @oshiPillUngrouped.
  ///
  /// In zh, this message translates to:
  /// **'無分組'**
  String get oshiPillUngrouped;

  /// No description provided for @oshiDeleteSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 筆紀錄？'**
  String oshiDeleteSelectedTitle(int count);

  /// No description provided for @pickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇圖片'**
  String get pickerTitle;

  /// No description provided for @pickerAlbumAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get pickerAlbumAll;

  /// No description provided for @pickerAlbumScreenshots.
  ///
  /// In zh, this message translates to:
  /// **'截圖'**
  String get pickerAlbumScreenshots;

  /// No description provided for @pickerAlbumCamera.
  ///
  /// In zh, this message translates to:
  /// **'相機'**
  String get pickerAlbumCamera;

  /// No description provided for @pickerDayToday.
  ///
  /// In zh, this message translates to:
  /// **'今天 · {date}'**
  String pickerDayToday(String date);

  /// No description provided for @pickerDayYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天 · {date}'**
  String pickerDayYesterday(String date);

  /// No description provided for @pickerDate.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日 {weekday}'**
  String pickerDate(int month, int day, String weekday);

  /// No description provided for @pickerDateWithYear.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月{day}日 {weekday}'**
  String pickerDateWithYear(int year, int month, int day, String weekday);

  /// No description provided for @pickerDayCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張'**
  String pickerDayCount(int count);

  /// No description provided for @pickerSelectDay.
  ///
  /// In zh, this message translates to:
  /// **'選取整天'**
  String get pickerSelectDay;

  /// No description provided for @pickerNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步（{count}）'**
  String pickerNext(int count);

  /// No description provided for @pickerLimitedNotice.
  ///
  /// In zh, this message translates to:
  /// **'只開放了部分相片'**
  String get pickerLimitedNotice;

  /// No description provided for @pickerManagePermission.
  ///
  /// In zh, this message translates to:
  /// **'管理權限'**
  String get pickerManagePermission;

  /// No description provided for @pickerDeniedMessage.
  ///
  /// In zh, this message translates to:
  /// **'需要「讀取相片和影片」的權限，才能從相簿選擇圖片'**
  String get pickerDeniedMessage;

  /// No description provided for @pickerOpenSettings.
  ///
  /// In zh, this message translates to:
  /// **'去設定'**
  String get pickerOpenSettings;

  /// No description provided for @pickerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'這裡沒有相片'**
  String get pickerEmpty;

  /// No description provided for @pickerUnselectThumb.
  ///
  /// In zh, this message translates to:
  /// **'取消選取第 {number} 張'**
  String pickerUnselectThumb(int number);

  /// No description provided for @pitcoverCellSet.
  ///
  /// In zh, this message translates to:
  /// **'已設為「{label}」的封面'**
  String pitcoverCellSet(String label);

  /// No description provided for @pitsCellOshi.
  ///
  /// In zh, this message translates to:
  /// **'推活'**
  String get pitsCellOshi;

  /// No description provided for @pitsCellOshiCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆'**
  String pitsCellOshiCount(int count);

  /// No description provided for @pitSearchCategoryOshi.
  ///
  /// In zh, this message translates to:
  /// **'推活'**
  String get pitSearchCategoryOshi;

  /// No description provided for @refviewEntry.
  ///
  /// In zh, this message translates to:
  /// **'參考檢視'**
  String get refviewEntry;

  /// No description provided for @refviewLock.
  ///
  /// In zh, this message translates to:
  /// **'鎖定縮放'**
  String get refviewLock;

  /// No description provided for @refviewLockedLong.
  ///
  /// In zh, this message translates to:
  /// **'已鎖定縮放'**
  String get refviewLockedLong;

  /// No description provided for @refviewLockedShort.
  ///
  /// In zh, this message translates to:
  /// **'已鎖定'**
  String get refviewLockedShort;

  /// No description provided for @refviewUnlockedShort.
  ///
  /// In zh, this message translates to:
  /// **'未鎖定'**
  String get refviewUnlockedShort;

  /// No description provided for @refviewZoomState.
  ///
  /// In zh, this message translates to:
  /// **'{percent}% · {state}'**
  String refviewZoomState(int percent, String state);

  /// No description provided for @refviewFlip.
  ///
  /// In zh, this message translates to:
  /// **'左右翻轉'**
  String get refviewFlip;

  /// No description provided for @refviewGray.
  ///
  /// In zh, this message translates to:
  /// **'灰階'**
  String get refviewGray;

  /// No description provided for @refviewBackground.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get refviewBackground;

  /// No description provided for @refviewMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get refviewMore;

  /// No description provided for @refviewPanel.
  ///
  /// In zh, this message translates to:
  /// **'資料面板'**
  String get refviewPanel;

  /// No description provided for @refviewInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'圖片資料'**
  String get refviewInfoTitle;

  /// No description provided for @refviewFilmstrip.
  ///
  /// In zh, this message translates to:
  /// **'同冊圖片'**
  String get refviewFilmstrip;

  /// No description provided for @refviewImageN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 張'**
  String refviewImageN(int n);

  /// No description provided for @refviewCategory.
  ///
  /// In zh, this message translates to:
  /// **'分類'**
  String get refviewCategory;

  /// No description provided for @refviewTags.
  ///
  /// In zh, this message translates to:
  /// **'tag'**
  String get refviewTags;

  /// No description provided for @refviewVideoTitle.
  ///
  /// In zh, this message translates to:
  /// **'{title} · 影片'**
  String refviewVideoTitle(String title);

  /// No description provided for @refviewCapture.
  ///
  /// In zh, this message translates to:
  /// **'截取此格'**
  String get refviewCapture;

  /// No description provided for @refviewCaptured.
  ///
  /// In zh, this message translates to:
  /// **'已截取此格'**
  String get refviewCaptured;

  /// No description provided for @refviewCaptureFailed.
  ///
  /// In zh, this message translates to:
  /// **'無法截取這一格'**
  String get refviewCaptureFailed;

  /// No description provided for @refviewCaptureNoTarget.
  ///
  /// In zh, this message translates to:
  /// **'這個來源沒有可以存放截圖的位置'**
  String get refviewCaptureNoTarget;

  /// No description provided for @refviewTimeline.
  ///
  /// In zh, this message translates to:
  /// **'時間軸'**
  String get refviewTimeline;

  /// No description provided for @refviewPrevFrame.
  ///
  /// In zh, this message translates to:
  /// **'上一格'**
  String get refviewPrevFrame;

  /// No description provided for @refviewNextFrame.
  ///
  /// In zh, this message translates to:
  /// **'下一格'**
  String get refviewNextFrame;

  /// No description provided for @refviewSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get refviewSpeed;

  /// No description provided for @refviewLoop.
  ///
  /// In zh, this message translates to:
  /// **'循環'**
  String get refviewLoop;

  /// No description provided for @refviewFrameLabel.
  ///
  /// In zh, this message translates to:
  /// **'{speed} · 第 {frame} 格'**
  String refviewFrameLabel(String speed, int frame);

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
  /// **'摸魚'**
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
  /// **'摸魚（{count} 張）'**
  String ideaDetailDraftLabel(int count);

  /// No description provided for @ideaLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的腦洞'**
  String get ideaLinkedHeading;

  /// No description provided for @draftLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的摸魚'**
  String get draftLinkedHeading;

  /// No description provided for @pieceLinkedHeading.
  ///
  /// In zh, this message translates to:
  /// **'關聯的成圖'**
  String get pieceLinkedHeading;

  /// No description provided for @draftListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有摸魚'**
  String get draftListEmpty;

  /// No description provided for @draftViewList.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get draftViewList;

  /// No description provided for @draftDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'摸魚詳情'**
  String get draftDetailTitle;

  /// No description provided for @draftDetailDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除這份摸魚？'**
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
  /// **'刪除這份成圖？'**
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

  /// No description provided for @draftSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 份'**
  String draftSelectedCount(int count);

  /// No description provided for @draftDeleteSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 份摸魚？'**
  String draftDeleteSelectedTitle(int count);

  /// No description provided for @pieceDeleteSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 份成圖？'**
  String pieceDeleteSelectedTitle(int count);

  /// No description provided for @personalizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'個人化'**
  String get personalizeTitle;

  /// No description provided for @sensitiveTitle.
  ///
  /// In zh, this message translates to:
  /// **'敏感內容'**
  String get sensitiveTitle;

  /// No description provided for @sensitiveValueOff.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get sensitiveValueOff;

  /// No description provided for @sensitiveValueOn.
  ///
  /// In zh, this message translates to:
  /// **'開啟'**
  String get sensitiveValueOn;

  /// No description provided for @sensitiveBadgeLabel.
  ///
  /// In zh, this message translates to:
  /// **'敏感'**
  String get sensitiveBadgeLabel;

  /// No description provided for @sensitiveMasterTitle.
  ///
  /// In zh, this message translates to:
  /// **'敏感內容標記'**
  String get sensitiveMasterTitle;

  /// No description provided for @sensitiveSafeModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全模式'**
  String get sensitiveSafeModeTitle;

  /// No description provided for @sensitiveSafeModeHint.
  ///
  /// In zh, this message translates to:
  /// **'開啟後會模糊顯示已標記的圖片，關閉則正常顯示'**
  String get sensitiveSafeModeHint;

  /// No description provided for @sensitiveOffTitle.
  ///
  /// In zh, this message translates to:
  /// **'關閉敏感內容標記？'**
  String get sensitiveOffTitle;

  /// No description provided for @sensitiveOffBody.
  ///
  /// In zh, this message translates to:
  /// **'已標記的圖片會照常顯示，不再模糊，所有敏感內容選項也會隱藏。重新開啟後，標記會自動恢復。'**
  String get sensitiveOffBody;

  /// No description provided for @sensitiveOffConfirm.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get sensitiveOffConfirm;

  /// No description provided for @sensitivePitOffTitle.
  ///
  /// In zh, this message translates to:
  /// **'關閉這個坑的敏感內容？'**
  String get sensitivePitOffTitle;

  /// No description provided for @sensitivePitOffBody.
  ///
  /// In zh, this message translates to:
  /// **'坑內已標記的 {count} 張圖會照常顯示。重新開啟後，標記會自動恢復。'**
  String sensitivePitOffBody(int count);

  /// No description provided for @sensitiveMarkAll.
  ///
  /// In zh, this message translates to:
  /// **'全部標為敏感'**
  String get sensitiveMarkAll;

  /// No description provided for @sensitiveMarkedCount.
  ///
  /// In zh, this message translates to:
  /// **'{marked} / {total}'**
  String sensitiveMarkedCount(int marked, int total);

  /// No description provided for @sensitiveMarkImage.
  ///
  /// In zh, this message translates to:
  /// **'標為敏感'**
  String get sensitiveMarkImage;

  /// No description provided for @sensitiveMarkedImage.
  ///
  /// In zh, this message translates to:
  /// **'已標為敏感'**
  String get sensitiveMarkedImage;

  /// No description provided for @sensitiveAction.
  ///
  /// In zh, this message translates to:
  /// **'敏感'**
  String get sensitiveAction;

  /// No description provided for @sensitiveCoverTitle.
  ///
  /// In zh, this message translates to:
  /// **'標為敏感內容？'**
  String get sensitiveCoverTitle;

  /// No description provided for @sensitiveCoverBody.
  ///
  /// In zh, this message translates to:
  /// **'選中的圖片裡有 {count} 張是這個坑的封面，標記後會從封面移除。'**
  String sensitiveCoverBody(int count);

  /// No description provided for @sensitiveCoverConfirm.
  ///
  /// In zh, this message translates to:
  /// **'標記並移除封面'**
  String get sensitiveCoverConfirm;

  /// No description provided for @sensitiveSafeTurnOff.
  ///
  /// In zh, this message translates to:
  /// **'關閉安全模式'**
  String get sensitiveSafeTurnOff;

  /// No description provided for @sensitiveSafeTurnOn.
  ///
  /// In zh, this message translates to:
  /// **'開啟安全模式'**
  String get sensitiveSafeTurnOn;

  /// No description provided for @shallowName.
  ///
  /// In zh, this message translates to:
  /// **'淺坑'**
  String get shallowName;

  /// No description provided for @shallowTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'類型'**
  String get shallowTypeLabel;

  /// No description provided for @shallowTypePit.
  ///
  /// In zh, this message translates to:
  /// **'坑'**
  String get shallowTypePit;

  /// No description provided for @shallowTypeArchive.
  ///
  /// In zh, this message translates to:
  /// **'封存'**
  String get shallowTypeArchive;

  /// No description provided for @shallowNewRow.
  ///
  /// In zh, this message translates to:
  /// **'開新淺坑'**
  String get shallowNewRow;

  /// No description provided for @shallowFieldSections.
  ///
  /// In zh, this message translates to:
  /// **'開啟的格子'**
  String get shallowFieldSections;

  /// No description provided for @shallowEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'還沒有開啟格子'**
  String get shallowEmptyTitle;

  /// No description provided for @shallowEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'開啟格子'**
  String get shallowEmptyAction;

  /// No description provided for @shallowListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'還沒有淺坑'**
  String get shallowListEmpty;

  /// No description provided for @shallowSubtitlePart.
  ///
  /// In zh, this message translates to:
  /// **'{label} {count}'**
  String shallowSubtitlePart(String label, String count);

  /// No description provided for @shallowArchivedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'成圖 {pieces} · 摸魚 {drafts}'**
  String shallowArchivedSubtitle(int pieces, int drafts);

  /// No description provided for @shallowCloseTitle.
  ///
  /// In zh, this message translates to:
  /// **'關閉「{label}」？'**
  String shallowCloseTitle(String label);

  /// No description provided for @shallowCloseBody.
  ///
  /// In zh, this message translates to:
  /// **'格子裡的 {detail}會移到「最近刪除」，30 天內可以還原；還原時這個格子會自動重新開啟。'**
  String shallowCloseBody(String detail);

  /// No description provided for @shallowCountImages.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張圖'**
  String shallowCountImages(int count);

  /// No description provided for @shallowCountIdeas.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個腦洞'**
  String shallowCountIdeas(int count);

  /// No description provided for @shallowCountDrafts.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份摸魚'**
  String shallowCountDrafts(int count);

  /// No description provided for @shallowCountPieces.
  ///
  /// In zh, this message translates to:
  /// **'{count} 份成圖'**
  String shallowCountPieces(int count);

  /// No description provided for @shallowCountOshi.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆推活'**
  String shallowCountOshi(int count);

  /// No description provided for @shallowCloseConfirm.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get shallowCloseConfirm;

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

  /// No description provided for @shareMoveOshi.
  ///
  /// In zh, this message translates to:
  /// **'推活'**
  String get shareMoveOshi;

  /// No description provided for @shareMoveTag.
  ///
  /// In zh, this message translates to:
  /// **'tag'**
  String get shareMoveTag;

  /// No description provided for @shareMoveTagStateAll.
  ///
  /// In zh, this message translates to:
  /// **'已選的圖片都有'**
  String get shareMoveTagStateAll;

  /// No description provided for @shareMoveTagStateSome.
  ///
  /// In zh, this message translates to:
  /// **'部分圖片有'**
  String get shareMoveTagStateSome;

  /// No description provided for @shareMoveTagStateNone.
  ///
  /// In zh, this message translates to:
  /// **'沒有'**
  String get shareMoveTagStateNone;

  /// No description provided for @syncuiRingFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步完成，有圖片失敗'**
  String get syncuiRingFailed;

  /// No description provided for @syncuiPartialTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步完成，{count} 張失敗'**
  String syncuiPartialTitle(int count);

  /// No description provided for @syncuiFailed.
  ///
  /// In zh, this message translates to:
  /// **'失敗'**
  String get syncuiFailed;

  /// No description provided for @syncuiRetry.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get syncuiRetry;

  /// No description provided for @syncuiMoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'還有 {count} 張失敗'**
  String syncuiMoreFailed(int count);

  /// No description provided for @syncuiWaitingSpace.
  ///
  /// In zh, this message translates to:
  /// **'等待空間'**
  String get syncuiWaitingSpace;

  /// No description provided for @syncuiTimeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分鐘前'**
  String syncuiTimeMinutesAgo(int minutes);

  /// No description provided for @backupFullTitle.
  ///
  /// In zh, this message translates to:
  /// **'Drive 已滿'**
  String get backupFullTitle;

  /// No description provided for @backupFullCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 張'**
  String backupFullCount(int count);

  /// No description provided for @backupFullUnuploaded.
  ///
  /// In zh, this message translates to:
  /// **'未上傳'**
  String get backupFullUnuploaded;

  /// No description provided for @syncuiManageStorage.
  ///
  /// In zh, this message translates to:
  /// **'管理儲存空間'**
  String get syncuiManageStorage;

  /// No description provided for @backupFullManage.
  ///
  /// In zh, this message translates to:
  /// **'管理 Google 儲存空間'**
  String get backupFullManage;

  /// No description provided for @meBackupUploadPaused.
  ///
  /// In zh, this message translates to:
  /// **'上傳暫停　下載正常'**
  String get meBackupUploadPaused;

  /// No description provided for @syncuiSheetLabel.
  ///
  /// In zh, this message translates to:
  /// **'同步進度'**
  String get syncuiSheetLabel;

  /// No description provided for @syncuiDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get syncuiDoneTitle;

  /// No description provided for @syncuiDoneJustNow.
  ///
  /// In zh, this message translates to:
  /// **'剛剛'**
  String get syncuiDoneJustNow;

  /// No description provided for @syncuiRingChecking.
  ///
  /// In zh, this message translates to:
  /// **'同步中，正在檢查'**
  String get syncuiRingChecking;

  /// No description provided for @syncuiRingTransferring.
  ///
  /// In zh, this message translates to:
  /// **'同步中，查看進度'**
  String get syncuiRingTransferring;

  /// No description provided for @syncuiProgress.
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total}'**
  String syncuiProgress(int done, int total);

  /// No description provided for @syncuiUploadCount.
  ///
  /// In zh, this message translates to:
  /// **'上傳 {count} 張'**
  String syncuiUploadCount(int count);

  /// No description provided for @syncuiDownloadCount.
  ///
  /// In zh, this message translates to:
  /// **'下載 {count} 張'**
  String syncuiDownloadCount(int count);

  /// No description provided for @syncuiUpload.
  ///
  /// In zh, this message translates to:
  /// **'上傳'**
  String get syncuiUpload;

  /// No description provided for @syncuiDownload.
  ///
  /// In zh, this message translates to:
  /// **'下載'**
  String get syncuiDownload;

  /// No description provided for @syncuiLocation.
  ///
  /// In zh, this message translates to:
  /// **'{pit} · {cell}'**
  String syncuiLocation(String pit, String cell);

  /// No description provided for @syncuiLocationTitled.
  ///
  /// In zh, this message translates to:
  /// **'{pit} · {cell} · {title}'**
  String syncuiLocationTitled(String pit, String cell, String title);

  /// No description provided for @syncuiPercent.
  ///
  /// In zh, this message translates to:
  /// **'{percent}%'**
  String syncuiPercent(int percent);

  /// No description provided for @syncuiWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get syncuiWaiting;

  /// No description provided for @syncuiMoreWaiting.
  ///
  /// In zh, this message translates to:
  /// **'還有 {count} 張等待中'**
  String syncuiMoreWaiting(int count);

  /// No description provided for @syncuiBadgeDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下載中 {percent}%'**
  String syncuiBadgeDownloading(int percent);

  /// No description provided for @syncuiListing.
  ///
  /// In zh, this message translates to:
  /// **'正在列出雲端內容'**
  String get syncuiListing;

  /// No description provided for @syncuiPullProgress.
  ///
  /// In zh, this message translates to:
  /// **'資料 {done} / {total}'**
  String syncuiPullProgress(int done, int total);

  /// No description provided for @syncuiThumbProgress.
  ///
  /// In zh, this message translates to:
  /// **'縮圖 {done} / {total}'**
  String syncuiThumbProgress(int done, int total);

  /// No description provided for @syncuiStalled.
  ///
  /// In zh, this message translates to:
  /// **'同步太久沒有進展，已中止，稍後會自動重試'**
  String get syncuiStalled;

  /// No description provided for @syncuiTimeout.
  ///
  /// In zh, this message translates to:
  /// **'連線逾時，請檢查網絡後再試（{step}）'**
  String syncuiTimeout(String step);

  /// No description provided for @syncuiNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'網絡連線失敗（{step}）：{detail}'**
  String syncuiNetworkError(String step, String detail);

  /// No description provided for @syncuiSkippedDocs.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 份雲端資料無法讀取，已略過'**
  String syncuiSkippedDocs(int count);

  /// No description provided for @syncuiImagesFailed.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 張圖片下載失敗，下次同步會再試'**
  String syncuiImagesFailed(int count);

  /// No description provided for @trashTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近刪除'**
  String get trashTitle;

  /// No description provided for @trashSelect.
  ///
  /// In zh, this message translates to:
  /// **'選擇'**
  String get trashSelect;

  /// No description provided for @trashSectionPits.
  ///
  /// In zh, this message translates to:
  /// **'坑'**
  String get trashSectionPits;

  /// No description provided for @trashDaysLeft.
  ///
  /// In zh, this message translates to:
  /// **'剩 {days} 天'**
  String trashDaysLeft(int days);

  /// No description provided for @trashItemCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String trashItemCount(int count);

  /// No description provided for @trashSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已選 {count} 項'**
  String trashSelectedCount(int count);

  /// No description provided for @trashSelectTitle.
  ///
  /// In zh, this message translates to:
  /// **'選擇項目'**
  String get trashSelectTitle;

  /// No description provided for @trashRestore.
  ///
  /// In zh, this message translates to:
  /// **'還原'**
  String get trashRestore;

  /// No description provided for @trashPurge.
  ///
  /// In zh, this message translates to:
  /// **'永久刪除'**
  String get trashPurge;

  /// No description provided for @trashRestoreAll.
  ///
  /// In zh, this message translates to:
  /// **'全部還原'**
  String get trashRestoreAll;

  /// No description provided for @trashClearAll.
  ///
  /// In zh, this message translates to:
  /// **'全部清空'**
  String get trashClearAll;

  /// No description provided for @trashClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空最近刪除？'**
  String get trashClearTitle;

  /// No description provided for @trashClearBodyPits.
  ///
  /// In zh, this message translates to:
  /// **'{pits} 個坑和 {items} 項內容會永久刪除，無法復原。'**
  String trashClearBodyPits(int pits, int items);

  /// No description provided for @trashClearBodyItems.
  ///
  /// In zh, this message translates to:
  /// **'{items} 項內容會永久刪除，無法復原。'**
  String trashClearBodyItems(int items);

  /// No description provided for @trashPurgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久刪除 {count} 項？'**
  String trashPurgeTitle(int count);

  /// No description provided for @trashPurgeBody.
  ///
  /// In zh, this message translates to:
  /// **'刪除後無法復原。'**
  String get trashPurgeBody;

  /// No description provided for @trashPitRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」'**
  String trashPitRestoreTitle(String name);

  /// No description provided for @trashPitRestoreBody.
  ///
  /// In zh, this message translates to:
  /// **'坑內 {count} 項會跟坑一起還原。'**
  String trashPitRestoreBody(int count);

  /// No description provided for @trashDeletedOn.
  ///
  /// In zh, this message translates to:
  /// **'{year} / {month} / {day} 刪除'**
  String trashDeletedOn(int year, String month, String day);

  /// No description provided for @trashMovedSnack.
  ///
  /// In zh, this message translates to:
  /// **'已移到最近刪除'**
  String get trashMovedSnack;

  /// No description provided for @trashRestoredSnack.
  ///
  /// In zh, this message translates to:
  /// **'已還原'**
  String get trashRestoredSnack;

  /// No description provided for @trashDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'30 天內可以在「最近刪除」還原。'**
  String get trashDeleteBody;

  /// No description provided for @trashDeleteItemsTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除 {count} 項？'**
  String trashDeleteItemsTitle(int count);

  /// No description provided for @trashPitDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'刪除「{name}」？'**
  String trashPitDeleteTitle(String name);

  /// No description provided for @trashPitDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'坑內所有內容會移到「最近刪除」，30 天內可以還原。'**
  String get trashPitDeleteBody;

  /// No description provided for @trashPurgePitTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久刪除「{name}」？'**
  String trashPurgePitTitle(String name);

  /// No description provided for @videoloopLoop.
  ///
  /// In zh, this message translates to:
  /// **'循環播放'**
  String get videoloopLoop;

  /// No description provided for @videoloopLoopOn.
  ///
  /// In zh, this message translates to:
  /// **'循環播放：開'**
  String get videoloopLoopOn;

  /// No description provided for @videoloopLoopOff.
  ///
  /// In zh, this message translates to:
  /// **'循環播放：關'**
  String get videoloopLoopOff;
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
