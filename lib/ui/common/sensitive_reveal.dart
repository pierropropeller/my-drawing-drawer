import 'package:flutter/widgets.dart';

/// iPad 預覽／詳情面板（P-043）：面板裡安全模式關時不加左上角敏感小標（和手機的詳情／預覽頁一致）。
/// 模糊與否照安全模式的規則，沒有「只顯示這一張」（P-038 作廢）。
class SensitivePanelScope extends InheritedWidget {
  const SensitivePanelScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SensitivePanelScope>() != null;

  @override
  bool updateShouldNotify(SensitivePanelScope old) => false;
}
