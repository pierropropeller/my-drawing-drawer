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
  String get goalsKindDraft => '草稿';

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
  String get goalsRatio => '正方格比例';

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
    return '畫 $count 份草稿';
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
}
