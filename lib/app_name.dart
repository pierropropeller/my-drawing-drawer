import 'dart:ui';

/// App 名稱：中文系統顯示「畫匣」，其他語言（英文等）顯示 Drawer。
/// 與 Android 的 `app_name` 資源（桌面、Google 登入畫面）規則一致。
String get appName =>
    PlatformDispatcher.instance.locale.languageCode == 'zh' ? '畫匣' : 'Drawer';
