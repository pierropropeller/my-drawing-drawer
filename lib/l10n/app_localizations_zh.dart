// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
