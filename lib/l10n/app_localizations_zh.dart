// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get pitsDeleteTitle => '刪除這個坑？';

  @override
  String get pitsDeleteBody => '坑內的內容也會一併刪除。';

  @override
  String get pitsSelectCover => '選擇封面';

  @override
  String get pitsChangeCover => '更換封面';

  @override
  String get pitsFieldCover => '封面';

  @override
  String get pitsEditTitle => '編輯坑';

  @override
  String get pitsFieldName => '坑名';

  @override
  String get pitsNameRequired => '請輸入坑名';

  @override
  String get pitsFieldDesc => '描述';

  @override
  String get pitsArchive => '封存';

  @override
  String get pitsDeleteThis => '刪除這個坑';

  @override
  String get pitsDeleteHint => '刪除後坑內所有圖片、腦洞、摸魚及成圖將一併移除';

  @override
  String get pitsNewTitle => '開新坑';

  @override
  String get pitsCreate => '建立';

  @override
  String get pitsOfficial => '官方圖冊';

  @override
  String get pitsFanArt => '好看同人圖';

  @override
  String get pitsDrafts => '我的摸魚';

  @override
  String get pitsIdeas => '我的腦洞';

  @override
  String get pitsPieces => '我的成圖';

  @override
  String pitsCountDrafts(int count) {
    return '$count 份';
  }

  @override
  String pitsCountIdeas(int count) {
    return '$count 個';
  }

  @override
  String get pitsPiecesEmpty => '還沒有成圖・開始你的第一張';

  @override
  String get pitsMyPits => '我的坑';

  @override
  String get albumPillNoSource => '無出處';

  @override
  String get pitsActive => '現坑';

  @override
  String get pitsArchived => '封存坑';

  @override
  String pitsLoadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get pitsViewGrid => '田字檢視';

  @override
  String get pitsViewWaterfall => '瀑布檢視';

  @override
  String pitsSyncingImages(int done, int total) {
    return '同步中・圖片 $done / $total';
  }

  @override
  String get pitsSyncing => '同步中';

  @override
  String get pitsOffline => '離線中・恢復網絡後將自動上傳';

  @override
  String get pitsEmptyArchived => '沒有封存的坑';

  @override
  String get pitsEmpty => '還沒有坑';

  @override
  String get pitsNotDownloaded => '尚未下載';

  @override
  String pitsStatsLine(int pieces, int ideas) {
    return '$pieces 成圖 · $ideas 腦洞未孵';
  }

  @override
  String get junkTitle => '雜物';

  @override
  String get junkEmpty => '還沒有雜物';

  @override
  String get tagsScopeNote => 'tag 按坑獨立，不同坑之間不共用';

  @override
  String tagsUsedCount(int count) {
    return '$count 項';
  }

  @override
  String tagsRename(String name) {
    return '重新命名 #$name';
  }

  @override
  String get tagsRenamePrompt => 'Tag 名稱';

  @override
  String tagsDelete(String name) {
    return '刪除 #$name';
  }

  @override
  String tagsDeleteTitle(String name) {
    return '刪除 tag「$name」？';
  }

  @override
  String get tagsDeleteBody => '已使用的內容會一併移除這個 tag。';

  @override
  String get tagsAdd => '新增 tag';

  @override
  String get albumConfirm => '確定';

  @override
  String get albumAddImage => '加圖';

  @override
  String get albumSavedToGallery => '已儲存到相簿';

  @override
  String albumSavedCountToGallery(int count) {
    return '已儲存 $count 張到相簿';
  }

  @override
  String get albumSaveFailed => '儲存失敗';

  @override
  String albumMovedCount(int count, String target) {
    return '已移動 $count 張到$target';
  }

  @override
  String get albumDeleteImageTitle => '刪除這張圖？';

  @override
  String albumDeleteImagesTitle(int count) {
    return '刪除 $count 張圖？';
  }

  @override
  String get albumCancelSelect => '取消選擇';

  @override
  String albumTitleWithPit(String pit, String title) {
    return '$pit · $title';
  }

  @override
  String get albumManageGroups => '管理分組';

  @override
  String get albumCoverSet => '已設為坑的封面';

  @override
  String get albumCoverPickTitle => '選擇坑的封面';

  @override
  String albumCoverHolding(String label) {
    return '長按中：$label 封面';
  }

  @override
  String get albumCoverPickHeading => '選擇封面圖';

  @override
  String get albumCoverNone => '沒有可選的圖';

  @override
  String get albumSetCover => '設為封面';

  @override
  String get albumFanEditTitle => '編輯同人圖';

  @override
  String get albumFieldImage => '圖片';

  @override
  String get albumFieldAuthor => '作者';

  @override
  String get albumFieldSource => '出處';

  @override
  String get albumFanNewTitle => '新增同人圖';

  @override
  String get albumPickImageFirst => '請先選擇圖片';

  @override
  String get albumFanAdd => '加入好看同人圖';

  @override
  String albumGroupDeleteTitle(String name) {
    return '刪除分組「$name」？';
  }

  @override
  String get albumGroupDeleteBody => '組內的圖會移到其他分組。';

  @override
  String get albumGroupKeepOne => '至少要保留一個分組';

  @override
  String get albumGroupNameTitle => '分組名稱';

  @override
  String get albumGroupHintFan => '分組只用於好看同人圖，拖曳可調整次序';

  @override
  String get albumGroupHintOfficial => '分組只用於官方圖冊，拖曳可調整次序';

  @override
  String albumGroupRename(String name) {
    return '重新命名 $name';
  }

  @override
  String albumGroupDelete(String name) {
    return '刪除 $name';
  }

  @override
  String get albumGroupAdd => '新增分組';

  @override
  String get albumGroupLabel => '分組';

  @override
  String get albumRemoveImage => '移除圖片';

  @override
  String get albumPreviewImage => '預覽圖片';

  @override
  String get albumChangeGroup => '更換分組';

  @override
  String get albumGroupChanged => '已更換分組';

  @override
  String get albumCoverSetOfficial => '已設為官方圖冊封面';

  @override
  String get albumMoveTo => '移動到';

  @override
  String get albumOfficialEmpty => '還沒有官方圖';

  @override
  String get albumOfficialNewTitle => '新增官方圖';

  @override
  String get albumOfficialAdd => '加入官方圖冊';

  @override
  String albumPreviewDateAdded(int year, String month, String day) {
    return '$year / $month / $day 加入';
  }

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
  String get appiconTitle => 'App 圖示';

  @override
  String get appiconSanbi => '三筆';

  @override
  String get appiconHuati => '花體';

  @override
  String appiconToast(String name) {
    return '桌面圖示已換成「$name」';
  }

  @override
  String get backupStorageTitle => '儲存空間';

  @override
  String backupStorageOfLimit(String limit) {
    return ' / $limit';
  }

  @override
  String get backupStorageUsedLabel => '已用';

  @override
  String backupStorageDrawer(String size) {
    return '畫匣 $size';
  }

  @override
  String backupStorageOther(String size) {
    return '其他 $size';
  }

  @override
  String backupStorageSemantics(String used, String drawer, String other) {
    return '儲存空間，已用 $used，畫匣 $drawer，其他 $other';
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

  @override
  String get dayflowEmpty => '還沒有紀錄';

  @override
  String get entityRemove => '移除';

  @override
  String get entityRemoveImage => '移除圖片';

  @override
  String get entityAddImage => '加圖';

  @override
  String get entityFieldTitle => '標題';

  @override
  String get entityFieldBody => '內文';

  @override
  String get entityFieldDate => '日期';

  @override
  String get entityTitleRequired => '請輸入標題';

  @override
  String get entityConnectIdea => '關聯腦洞';

  @override
  String get entityConnectDraft => '關聯摸魚';

  @override
  String get entityConnectPiece => '關聯成圖';

  @override
  String get entityConnectSelectIdea => '選擇腦洞';

  @override
  String get entityConnectSelectDraft => '選擇摸魚';

  @override
  String get entityConnectSelectPiece => '選擇成圖';

  @override
  String entityConnectSelectedIdea(int count) {
    return '已選 $count 個';
  }

  @override
  String entityConnectSelectedDraft(int count) {
    return '已選 $count 份';
  }

  @override
  String entityConnectSelectedPiece(int count) {
    return '已選 $count 張';
  }

  @override
  String get entityConnectEmpty => '沒有可選擇的項目';

  @override
  String get entityGallerySaved => '已儲存到相簿';

  @override
  String get entityGallerySaveFailed => '儲存失敗';

  @override
  String get ideaStatusOpen => '未孵';

  @override
  String get ideaStatusHatchingShort => '孵化中';

  @override
  String ideaStatusHatching(int count) {
    return '孵化中 · $count 摸魚';
  }

  @override
  String get ideaStatusHatchedShort => '已孵';

  @override
  String ideaStatusHatched(int count) {
    return '已孵 $count 成圖';
  }

  @override
  String get ideaFormTitleNew => '新增腦洞';

  @override
  String get ideaFormTitleEdit => '編輯腦洞';

  @override
  String get ideaFormImages => '配圖';

  @override
  String get ideaFormCreate => '建立腦洞';

  @override
  String get draftFormMissingImage => '請至少新增一張圖片';

  @override
  String get draftFormTitleNew => '新增摸魚';

  @override
  String get draftFormTitleEdit => '編輯摸魚';

  @override
  String get draftFormImages => '摸魚圖';

  @override
  String get draftFormCreate => '建立摸魚';

  @override
  String get pieceFormMissingImage => '請至少選擇一張圖片';

  @override
  String get pieceFormPublishDate => '發佈日期';

  @override
  String get pieceFormSocialLinks => '社交媒體連結';

  @override
  String get pieceFormAddSocialLink => '加社交連結';

  @override
  String get pieceFormTarget => '目標互動量';

  @override
  String get pieceFormActual => '實際互動量';

  @override
  String get pieceFormClient => '委託人';

  @override
  String get pieceFormAmount => '金額';

  @override
  String get pieceFormCurrency => '幣種';

  @override
  String get pieceFormReceived => '已收金額';

  @override
  String get pieceFormPaidInFull => '已收齊';

  @override
  String get pieceFormDueDate => '交稿日期';

  @override
  String get pieceFormTitleNew => '新增成圖';

  @override
  String get pieceFormTitleEdit => '編輯成圖';

  @override
  String get pieceFormImages => '成品圖';

  @override
  String get pieceFormPublished => '已公開發佈';

  @override
  String get pieceFormCommission => '商稿';

  @override
  String get pieceFormFinishedAt => '完成時間';

  @override
  String get pieceFormCreate => '建立成圖';

  @override
  String get pieceAddImage => '加成品圖';

  @override
  String get pieceDateEmpty => '選擇日期';

  @override
  String get pieceHeartUnit => '紅心';

  @override
  String get piecePaymentUnpaid => '未收';

  @override
  String piecePaymentPartial(String amount) {
    return '已收 $amount';
  }

  @override
  String get piecePaymentPaid => '已收齊';

  @override
  String get entityPlatformTwitter => '推特';

  @override
  String get entityPlatformTwitterFull => '推特（Twitter/X）';

  @override
  String get entityPlatformXiaohongshu => '小紅書';

  @override
  String get entityPlatformLofter => 'Lofter';

  @override
  String get entityPlatformPixiv => 'Pixiv';

  @override
  String get entityPlatformWeibo => '微博';

  @override
  String get entityPlatformInstagram => 'Instagram';

  @override
  String get entityPlatformOther => '其他';

  @override
  String get entityPlatformLink => '連結';

  @override
  String get entityPlatformMarkTwitter => 'X';

  @override
  String get entityPlatformMarkXiaohongshu => '紅';

  @override
  String get entityPlatformMarkLofter => 'Lo';

  @override
  String get entityPlatformMarkPixiv => 'Px';

  @override
  String get entityPlatformMarkWeibo => '微';

  @override
  String get entityPlatformMarkInstagram => 'IG';

  @override
  String get goalsTitle => '目標';

  @override
  String get goalsPrevYear => '上一年';

  @override
  String get goalsNextYear => '下一年';

  @override
  String get goalsModeYear => '年';

  @override
  String get goalsModeMonth => '月';

  @override
  String get goalsModeDay => '日';

  @override
  String get goalsSectionYear => '年度目標';

  @override
  String get goalsSectionMonth => '月度小目標';

  @override
  String get goalsEmptyYear => '還沒有年度目標';

  @override
  String get goalsEmptyMonth => '還沒有月度目標';

  @override
  String get goalsNewGoal => '新增目標';

  @override
  String get goalsPrevItem => '上一個';

  @override
  String get goalsNextItem => '下一個';

  @override
  String get goalsPrevMonth => '上個月';

  @override
  String get goalsNextMonth => '下個月';

  @override
  String get goalsPrevDay => '前一天';

  @override
  String get goalsNextDay => '後一天';

  @override
  String goalsMonthTitle(int month) {
    return '$month 月';
  }

  @override
  String goalsDayTitle(int month, int day) {
    return '$month 月 $day 日';
  }

  @override
  String goalsMonthNum(int month) {
    return '$month月';
  }

  @override
  String goalsMonthCn(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      '1': '一月',
      '2': '二月',
      '3': '三月',
      '4': '四月',
      '5': '五月',
      '6': '六月',
      '7': '七月',
      '8': '八月',
      '9': '九月',
      '10': '十月',
      '11': '十一月',
      '12': '十二月',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String get goalsMonthFormatCn => '一月';

  @override
  String get goalsMonthFormatNum => '1月';

  @override
  String get goalsWeekSun => '日';

  @override
  String get goalsWeekMon => '一';

  @override
  String get goalsWeekTue => '二';

  @override
  String get goalsWeekWed => '三';

  @override
  String get goalsWeekThu => '四';

  @override
  String get goalsWeekFri => '五';

  @override
  String get goalsWeekSat => '六';

  @override
  String get goalsCreatePitFirst => '請先建立一個坑';

  @override
  String get goalsDayEmpty => '這天沒有紀錄';

  @override
  String get goalsTimeline => '時間軸';

  @override
  String get goalsKindIdea => '腦洞';

  @override
  String get goalsKindDraft => '摸魚';

  @override
  String get goalsKindPiece => '成圖';

  @override
  String get goalsUntitled => '（無標題）';

  @override
  String get goalsPickPit => '選擇坑';

  @override
  String get goalsRemove => '移除';

  @override
  String get goalsClear => '清除';

  @override
  String get goalsYearReview => '年度回顧';

  @override
  String goalsReviewSelected(int count) {
    return '已選 $count / 12';
  }

  @override
  String get goalsLayout => '排版';

  @override
  String get goalsIncome => '商稿收入';

  @override
  String get goalsReviewLayoutTitle => '年度回顧排版';

  @override
  String get goalsRatio => '圖片比例';

  @override
  String get goalsMonthFormat => '月份格式';

  @override
  String get goalsMonthPosition => '月份位置';

  @override
  String get goalsOnImage => '圖上';

  @override
  String get goalsBlankSpace => '空白位置';

  @override
  String get goalsMonthAlign => '月份對齊';

  @override
  String get goalsAlignStart => '靠左';

  @override
  String get goalsAlignCenter => '置中';

  @override
  String get goalsAlignEnd => '靠右';

  @override
  String get goalsPreview => '預覽';

  @override
  String get goalsSaveExport => '儲存並匯出圖片';

  @override
  String get goalsSavedToAlbum => '已儲存到相簿';

  @override
  String get goalsExportFailed => '匯出失敗';

  @override
  String get goalsNoPieceThisMonth => '這個月沒有成圖';

  @override
  String goalsReviewMonthSheetTitle(int year, int month) {
    return '$year 年 $month 月';
  }

  @override
  String goalsAutoNameIdea(int count) {
    return '生產 $count 個腦洞';
  }

  @override
  String goalsAutoNameDraft(int count) {
    return '畫 $count 份摸魚';
  }

  @override
  String goalsAutoNamePiece(int count) {
    return '完成 $count 張成圖';
  }

  @override
  String goalsAutoNamePieceLikes(int likes, int count) {
    return '互動量過 $likes 的成圖 $count 張';
  }

  @override
  String get goalsEnterLikes => '請輸入需要達成的互動量';

  @override
  String get goalsNewYearGoal => '新增年度目標';

  @override
  String get goalsNewMonthGoal => '新增月度目標';

  @override
  String get goalsEditYearGoal => '編輯年度目標';

  @override
  String get goalsEditMonthGoal => '編輯月度目標';

  @override
  String get goalsDeleteConfirm => '刪除這個目標？';

  @override
  String get goalsFieldName => '目標名稱';

  @override
  String get goalsNameHint => '留空將自動命名';

  @override
  String get goalsFieldKind => '目標種類';

  @override
  String get goalsFieldCount => '目標數量';

  @override
  String get goalsFieldPit => '目標坑';

  @override
  String get goalsFieldTag => '目標 tag';

  @override
  String get goalsTagHintNoPit => '選擇坑之後才能選 tag';

  @override
  String get goalsTagHintPit => '只顯示所選坑內的 tag';

  @override
  String get goalsAddTag => '新增 tag';

  @override
  String get goalsRequireLikes => '需要達成互動量';

  @override
  String get goalsLikesAtLeast => '互動量 ≥';

  @override
  String get goalsHearts => '紅心';

  @override
  String get goalsCreateGoal => '建立目標';

  @override
  String goalsIncomeYearTitle(int year) {
    return '$year 商稿收入';
  }

  @override
  String goalsIncomeUnpaidCount(int count) {
    return '未收齊 $count 張';
  }

  @override
  String goalsIncomeOwing(String amount) {
    return '尚欠 $amount';
  }

  @override
  String goalsIncomeReceived(String amount) {
    return '已收 $amount';
  }

  @override
  String goalsIncomeReceivedCount(String amount, int count) {
    return '已收 $amount · $count 張';
  }

  @override
  String get goalsIncomeUnpaid => '未收';

  @override
  String get goalsIncomePaid => '已收齊';

  @override
  String goalsCurrencyName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CNY': '人民幣',
      'HKD': '港幣',
      'TWD': '新台幣',
      'USD': '美元',
      'JPY': '日圓',
      'EUR': '歐元',
      'GBP': '英鎊',
      'KRW': '韓元',
      'SGD': '新加坡幣',
      'other': '$code',
    });
    return '$_temp0';
  }

  @override
  String get ipadauditGifLoop => 'GIF · 自動循環';

  @override
  String ipadauditVideoMeta(String duration) {
    return '影片 · $duration · 縮圖取第一格';
  }

  @override
  String get ipadauditGifMeta => 'GIF · 預覽時自動播放';

  @override
  String ipadauditImagesCount(String label, int n) {
    return '$label · $n 張';
  }

  @override
  String get ipadformsFanNewTitle => '加收藏';

  @override
  String get ipadformsFanAdd => '加入同人圖';

  @override
  String ipadformsOfficialGroupNote(int n, String group) {
    return '$n 張圖片將一併加入「$group」，之後可逐張修改分組。';
  }

  @override
  String get ipadformsShareTitle => '加入到畫匣';

  @override
  String get ipadListsReferenceView => '參考檢視';

  @override
  String get ipadListsMultiSelect => '多選';

  @override
  String get ipadListsPreviewEmpty => '選擇一張圖片以預覽';

  @override
  String get ipadListsIdeaEmpty => '選擇一個腦洞以查看詳情';

  @override
  String get ipadListsDraftEmpty => '選擇一份摸魚以查看詳情';

  @override
  String get ipadListsPieceEmpty => '選擇一張成圖以查看詳情';

  @override
  String get ipadListsDraftUntitled => '未命名摸魚';

  @override
  String ipadListsDraftImageN(int n) {
    return '第 $n 張';
  }

  @override
  String ipadListsDraftIdeaLink(String title) {
    return '腦洞：$title';
  }

  @override
  String get ipadListsIdeaFlow => '腦洞 → 摸魚 → 成圖';

  @override
  String get ipadListsStageIdea => '腦洞';

  @override
  String get ipadListsStageDraft => '摸魚';

  @override
  String get ipadListsStagePiece => '成圖';

  @override
  String get ipadListsStartDraftFromIdea => '從這個腦洞開摸魚';

  @override
  String get ipadListsReached => '已達標';

  @override
  String get ipadListsNotReached => '未達標';

  @override
  String get ipadListsViewWaterfall => '瀑布';

  @override
  String get ipadListsOshiSearchHint => '搜尋標題、內文';

  @override
  String get ipadListsOshiSearchLabel => '搜尋推活紀錄';

  @override
  String get ipadListsOshiCharacterTags => '角色 tag';

  @override
  String get ipadListsOshiJumpToMonth => '跳到月份';

  @override
  String get ipadListsOshiEarlier => '更早';

  @override
  String ipadListsMonthShort(int month) {
    return '$month 月';
  }

  @override
  String get ipadmediaMenuLabel => '加圖來源';

  @override
  String get ipadmediaSheetTitle => '加圖';

  @override
  String get ipadmediaSheetHint => '照片可多選，並保留選取順序；檔案支援 CSP 匯出的 PNG／JPG。';

  @override
  String get ipadmediaTilePhotos => '照片';

  @override
  String get ipadmediaTileFiles => '檔案';

  @override
  String get ipadmediaTileMaterials => '素材庫';

  @override
  String get ipadmediaTileCamera => '拍照';

  @override
  String get ipadmediaClipboardTitle => '剪貼簿';

  @override
  String get ipadmediaClipboardSub => '剛剛複製的圖片';

  @override
  String get ipadmediaPhotos => '從「照片」選取';

  @override
  String get ipadmediaPhotosSub => '系統相簿，可多選並保留選取順序';

  @override
  String get ipadmediaFiles => '從「檔案」選取';

  @override
  String get ipadmediaFilesSub => 'iCloud Drive、CSP 匯出的 PNG／JPG';

  @override
  String get ipadmediaMaterials => '從素材庫選取';

  @override
  String get ipadmediaMaterialsSub => '畫匣內已收藏的素材';

  @override
  String get ipadmediaCamera => '拍照';

  @override
  String get ipadmediaPaste => '貼上';

  @override
  String get ipadmediaPasteHasImage => '剪貼簿有 1 張圖';

  @override
  String get ipadmediaPasteEmpty => '剪貼簿裡沒有圖片';

  @override
  String get ipadmediaFilesFailed => '無法讀取所選檔案';

  @override
  String get ipadmediaCameraFailed => '無法開啟相機';

  @override
  String get ipadmediaMaterialsEmpty => '素材庫還沒有素材';

  @override
  String ipadmediaMaterialsAdd(int count) {
    return '加入 $count 張';
  }

  @override
  String get ipadmediaMaterialsFailed => '無法讀取所選素材';

  @override
  String ipadmediaDropTitle(String target) {
    return '放開即可加入「$target」';
  }

  @override
  String ipadmediaDropChooseGroup(int count) {
    return '$count 張 · 放開後選擇分組';
  }

  @override
  String ipadmediaDropCount(int count) {
    return '$count 張';
  }

  @override
  String get ipadmediaDropHint => '分屏時可直接從「照片」或「檔案」拖曳圖片至此';

  @override
  String ipadmediaDropLoading(int done, int total) {
    return '正在載入 $done／$total 張';
  }

  @override
  String ipadmediaDropFailed(int count) {
    return '$count 張無法載入';
  }

  @override
  String get ipadnavMainMenu => '主選單';

  @override
  String get ipadnavCurrentPits => '現坑';

  @override
  String get ipadnavYears => '年份';

  @override
  String get ipadpitChangeCover => '換封面';

  @override
  String get ipadpitPickFromPit => '從坑內選圖';

  @override
  String get ipadpitJunkHint => '在坑內頁顯示雜物入口';

  @override
  String get ipadpitNameHint => '例：原作名稱或 CP 名';

  @override
  String get ipadpitCoverLater => '封面可於建立後在「編輯坑」中選擇。';

  @override
  String get ipadpitSectionsLabel => '坑內分區';

  @override
  String get ipadsyncNetWifi => 'Wi-Fi';

  @override
  String get ipadsyncNetCellular => '行動網絡';

  @override
  String get ipadsyncNetEthernet => '有線網絡';

  @override
  String get ipadsyncSettings => '同步設定';

  @override
  String get ipadsyncPitSyncingMeta => '同步中…';

  @override
  String get ipadsyncConnectHint => '連結後，iPad 與手機會自動同步';

  @override
  String ipadsyncMinutes(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get materialTitle => '素材庫';

  @override
  String get materialLayoutWaterfall => '瀑布';

  @override
  String get materialLayoutGrid => '九宮格';

  @override
  String get materialAddLabel => '加素材';

  @override
  String get materialEmpty => '還沒有素材';

  @override
  String get materialCatClothing => '服裝';

  @override
  String get materialCatPose => '姿勢';

  @override
  String get materialCatBody => '人體';

  @override
  String get materialCatPalette => '色盤';

  @override
  String get materialCatScene => '場景';

  @override
  String get materialCatStyle => '畫風';

  @override
  String get materialCatSticker => '貼圖';

  @override
  String get materialFieldCategory => '分類';

  @override
  String get materialShareDestLabel => '加入到哪裡';

  @override
  String get mediaBadgeGif => 'GIF';

  @override
  String get mediaPlay => '播放';

  @override
  String get mediaPause => '暫停';

  @override
  String get mediaMute => '靜音';

  @override
  String get mediaUnmute => '取消靜音';

  @override
  String get mediaFullscreen => '全螢幕';

  @override
  String get mediaExitFullscreen => '結束全螢幕';

  @override
  String get mediaSeekBar => '播放進度';

  @override
  String get mediaVideoError => '無法播放這個影片';

  @override
  String get moveReviewPitLabel => '坑';

  @override
  String get moveReviewPositionLabel => '位置';

  @override
  String moveReviewMovedToPit(int count, String pit, String target) {
    return '已移動 $count 張到「$pit」的$target';
  }

  @override
  String moveReviewPickTitle(int month) {
    return '選擇 $month 月的圖片';
  }

  @override
  String moveReviewPieceCount(int count) {
    return '$count 張成圖';
  }

  @override
  String get officialtagEditTitle => '編輯官方圖';

  @override
  String get searchCategoryOfficial => '官方圖';

  @override
  String get oshiTitle => '推活';

  @override
  String oshiCountRecords(int count) {
    return '$count 筆';
  }

  @override
  String oshiCountItems(int count) {
    return '$count 項';
  }

  @override
  String oshiMonthHeader(int year, int month) {
    return '$year 年 $month 月';
  }

  @override
  String get oshiWeekdayMon => '週一';

  @override
  String get oshiWeekdayTue => '週二';

  @override
  String get oshiWeekdayWed => '週三';

  @override
  String get oshiWeekdayThu => '週四';

  @override
  String get oshiWeekdayFri => '週五';

  @override
  String get oshiWeekdaySat => '週六';

  @override
  String get oshiWeekdaySun => '週日';

  @override
  String get oshiLayoutTimeline => '時間軸';

  @override
  String get oshiLayoutGrid => '網格';

  @override
  String get oshiEmpty => '還沒有推活紀錄';

  @override
  String get oshiEmptyAction => '新增紀錄';

  @override
  String get oshiAddRecord => '新增推活紀錄';

  @override
  String get oshiFormTitleNew => '新增推活紀錄';

  @override
  String get oshiFormTitleEdit => '編輯推活紀錄';

  @override
  String get oshiFieldImages => '圖片';

  @override
  String get oshiFieldDescription => '描述';

  @override
  String get oshiFieldDate => '日期';

  @override
  String get oshiFormCreate => '建立紀錄';

  @override
  String oshiDetailDate(String date, String weekday) {
    return '$date（$weekday）';
  }

  @override
  String get oshiDeleteTitle => '刪除這筆紀錄？';

  @override
  String get oshiGroupHint => '分組只用於推活，拖曳可調整次序';

  @override
  String get oshiGroupDeleteBody => '組內的紀錄會變成沒有分組。';

  @override
  String oshiSelectedCount(int count) {
    return '已選 $count 筆';
  }

  @override
  String get oshiNoGroup => '不分組';

  @override
  String get oshiPillUngrouped => '無分組';

  @override
  String oshiDeleteSelectedTitle(int count) {
    return '刪除 $count 筆紀錄？';
  }

  @override
  String get pickerTitle => '選擇圖片';

  @override
  String get pickerAlbumAll => '全部';

  @override
  String get pickerAlbumScreenshots => '截圖';

  @override
  String get pickerAlbumCamera => '相機';

  @override
  String pickerDayToday(String date) {
    return '今天 · $date';
  }

  @override
  String pickerDayYesterday(String date) {
    return '昨天 · $date';
  }

  @override
  String pickerDate(int month, int day, String weekday) {
    return '$month月$day日 $weekday';
  }

  @override
  String pickerDateWithYear(int year, int month, int day, String weekday) {
    return '$year年$month月$day日 $weekday';
  }

  @override
  String pickerDayCount(int count) {
    return '$count 張';
  }

  @override
  String get pickerSelectDay => '選取整天';

  @override
  String pickerNext(int count) {
    return '下一步（$count）';
  }

  @override
  String get pickerLimitedNotice => '只開放了部分相片';

  @override
  String get pickerManagePermission => '管理權限';

  @override
  String get pickerDeniedMessage => '需要「讀取相片和影片」的權限，才能從相簿選擇圖片';

  @override
  String get pickerOpenSettings => '去設定';

  @override
  String get pickerEmpty => '這裡沒有相片';

  @override
  String pickerUnselectThumb(int number) {
    return '取消選取第 $number 張';
  }

  @override
  String pitcoverCellSet(String label) {
    return '已設為「$label」的封面';
  }

  @override
  String get pitsCellOshi => '推活';

  @override
  String pitsCellOshiCount(int count) {
    return '$count 筆';
  }

  @override
  String get pitSearchCategoryOshi => '推活';

  @override
  String get refviewEntry => '參考檢視';

  @override
  String get refviewLock => '鎖定縮放';

  @override
  String get refviewLockedLong => '已鎖定縮放';

  @override
  String get refviewLockedShort => '已鎖定';

  @override
  String get refviewUnlockedShort => '未鎖定';

  @override
  String refviewZoomState(int percent, String state) {
    return '$percent% · $state';
  }

  @override
  String get refviewFlip => '左右翻轉';

  @override
  String get refviewGray => '灰階';

  @override
  String get refviewBackground => '背景';

  @override
  String get refviewMore => '更多';

  @override
  String get refviewPanel => '資料面板';

  @override
  String get refviewInfoTitle => '圖片資料';

  @override
  String get refviewFilmstrip => '同冊圖片';

  @override
  String refviewImageN(int n) {
    return '第 $n 張';
  }

  @override
  String get refviewCategory => '分類';

  @override
  String get refviewTags => 'tag';

  @override
  String refviewVideoTitle(String title) {
    return '$title · 影片';
  }

  @override
  String get refviewCapture => '截取此格';

  @override
  String get refviewCaptured => '已截取此格';

  @override
  String get refviewCaptureFailed => '無法截取這一格';

  @override
  String get refviewCaptureNoTarget => '這個來源沒有可以存放截圖的位置';

  @override
  String get refviewTimeline => '時間軸';

  @override
  String get refviewPrevFrame => '上一格';

  @override
  String get refviewNextFrame => '下一格';

  @override
  String get refviewSpeed => '播放速度';

  @override
  String get refviewLoop => '循環';

  @override
  String refviewFrameLabel(String speed, int frame) {
    return '$speed · 第 $frame 格';
  }

  @override
  String get searchCategoryPiece => '成圖';

  @override
  String get searchCategoryFan => '同人圖';

  @override
  String get searchCategoryDraft => '摸魚';

  @override
  String get searchCategoryIdea => '腦洞';

  @override
  String searchHint(String name) {
    return '搜尋$name';
  }

  @override
  String get searchFrequentTags => '常用 tag';

  @override
  String get searchRemoveFilter => '移除篩選';

  @override
  String get searchNoResults => '沒有找到符合的內容';

  @override
  String ideaListDeleteSelected(int count) {
    return '刪除 $count 個腦洞？';
  }

  @override
  String ideaListCountUnhatched(int count, int unhatched) {
    return '$count 個 · $unhatched 未孵';
  }

  @override
  String get ideaListEmpty => '還沒有腦洞';

  @override
  String get ideaListEmptyAction => '記下第一個腦洞';

  @override
  String get ideaDetailTitle => '腦洞詳情';

  @override
  String get ideaDetailDeleteTitle => '刪除這個腦洞？';

  @override
  String ideaDetailCreatedAt(String date) {
    return '建立於 $date';
  }

  @override
  String ideaDetailDraftLabel(int count) {
    return '摸魚（$count 張）';
  }

  @override
  String get ideaLinkedHeading => '關聯的腦洞';

  @override
  String get draftLinkedHeading => '關聯的摸魚';

  @override
  String get pieceLinkedHeading => '關聯的成圖';

  @override
  String get draftListEmpty => '還沒有摸魚';

  @override
  String get draftViewList => '列表';

  @override
  String get draftDetailTitle => '摸魚詳情';

  @override
  String get draftDetailDeleteTitle => '刪除這份摸魚？';

  @override
  String draftDetailImageLabel(int n) {
    return '第 $n 張';
  }

  @override
  String get pieceListEmpty => '還沒有成圖';

  @override
  String get pieceViewWaterfall => '瀑布';

  @override
  String get pieceViewGrid => '田字';

  @override
  String get pieceViewNine => '九宮格';

  @override
  String get pieceDetailUpdateLikes => '更新實際互動量';

  @override
  String get pieceDetailDeleteTitle => '刪除這張成圖？';

  @override
  String get pieceDetailReached => '已達標 ✦';

  @override
  String pieceDetailActualLikes(int count) {
    return '實際互動量 $count';
  }

  @override
  String pieceDetailTarget(int count) {
    return '目標 $count';
  }

  @override
  String get pieceDetailPayment => '收款';

  @override
  String get albumFanEmpty => '還沒有同人圖';

  @override
  String get albumFanCoverSet => '已設為好看同人圖封面';

  @override
  String draftSelectedCount(int count) {
    return '已選 $count 份';
  }

  @override
  String draftDeleteSelectedTitle(int count) {
    return '刪除 $count 份摸魚？';
  }

  @override
  String pieceDeleteSelectedTitle(int count) {
    return '刪除 $count 張成圖？';
  }

  @override
  String get shallowName => '淺坑';

  @override
  String get shallowTypeLabel => '類型';

  @override
  String get shallowTypePit => '坑';

  @override
  String get shallowTypeArchive => '封存';

  @override
  String get shallowNewRow => '開新淺坑';

  @override
  String get shallowFieldSections => '開啟的格子';

  @override
  String get shallowEmptyTitle => '還沒有開啟格子';

  @override
  String get shallowEmptyAction => '開啟格子';

  @override
  String get shallowListEmpty => '還沒有淺坑';

  @override
  String shallowSubtitlePart(String label, String count) {
    return '$label $count';
  }

  @override
  String shallowArchivedSubtitle(int pieces, int drafts) {
    return '成圖 $pieces · 摸魚 $drafts';
  }

  @override
  String shallowCloseTitle(String label) {
    return '關閉「$label」？';
  }

  @override
  String shallowCloseBody(String detail) {
    return '格子裡的 $detail會一併刪除，無法復原。';
  }

  @override
  String shallowCountImages(int count) {
    return '$count 張圖';
  }

  @override
  String shallowCountIdeas(int count) {
    return '$count 個腦洞';
  }

  @override
  String shallowCountDrafts(int count) {
    return '$count 份摸魚';
  }

  @override
  String shallowCountPieces(int count) {
    return '$count 張成圖';
  }

  @override
  String shallowCountOshi(int count) {
    return '$count 筆推活';
  }

  @override
  String get shallowCloseConfirm => '關閉並刪除';

  @override
  String get shareTitle => '加入到';

  @override
  String get shareFieldPit => '坑';

  @override
  String get shareFieldPosition => '位置';

  @override
  String get shareAdd => '加入';

  @override
  String get shareNext => '下一步';

  @override
  String get shareAdded => '已加入';

  @override
  String get shareMoveOshi => '推活';

  @override
  String get shareMoveTag => 'tag';

  @override
  String get shareMoveTagStateAll => '已選的圖片都有';

  @override
  String get shareMoveTagStateSome => '部分圖片有';

  @override
  String get shareMoveTagStateNone => '沒有';

  @override
  String get syncuiSheetLabel => '同步進度';

  @override
  String get syncuiDoneTitle => '同步完成';

  @override
  String get syncuiDoneJustNow => '剛剛';

  @override
  String get syncuiRingChecking => '同步中，正在檢查';

  @override
  String get syncuiRingTransferring => '同步中，查看進度';

  @override
  String syncuiProgress(int done, int total) {
    return '$done / $total';
  }

  @override
  String syncuiUploadCount(int count) {
    return '上傳 $count 張';
  }

  @override
  String syncuiDownloadCount(int count) {
    return '下載 $count 張';
  }

  @override
  String get syncuiUpload => '上傳';

  @override
  String get syncuiDownload => '下載';

  @override
  String syncuiLocation(String pit, String cell) {
    return '$pit · $cell';
  }

  @override
  String syncuiLocationTitled(String pit, String cell, String title) {
    return '$pit · $cell · $title';
  }

  @override
  String syncuiPercent(int percent) {
    return '$percent%';
  }

  @override
  String get syncuiWaiting => '等待中';

  @override
  String syncuiMoreWaiting(int count) {
    return '還有 $count 張等待中';
  }

  @override
  String syncuiBadgeDownloading(int percent) {
    return '下載中 $percent%';
  }

  @override
  String get syncuiListing => '正在列出雲端內容';

  @override
  String syncuiPullProgress(int done, int total) {
    return '資料 $done / $total';
  }

  @override
  String syncuiThumbProgress(int done, int total) {
    return '縮圖 $done / $total';
  }

  @override
  String get syncuiStalled => '同步太久沒有進展，已中止，稍後會自動重試';

  @override
  String syncuiTimeout(String step) {
    return '連線逾時，請檢查網絡後再試（$step）';
  }

  @override
  String syncuiNetworkError(String step, String detail) {
    return '網絡連線失敗（$step）：$detail';
  }

  @override
  String syncuiSkippedDocs(int count) {
    return '有 $count 份雲端資料無法讀取，已略過';
  }

  @override
  String syncuiImagesFailed(int count) {
    return '有 $count 張圖片下載失敗，下次同步會再試';
  }

  @override
  String get videoloopLoop => '循環播放';

  @override
  String get videoloopLoopOn => '循環播放：開';

  @override
  String get videoloopLoopOff => '循環播放：關';
}
