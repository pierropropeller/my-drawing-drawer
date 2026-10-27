import 'package:flutter/material.dart';

/// 打字時點空白處＝收起鍵盤（全 App）。
///
/// 放在 MaterialApp.builder 外層。點擊辨識器在最外層，只有點到「沒有其他東西要接」的地方
/// （空白處、純文字）才會觸發；點按鈕、另一個輸入框、列表項目照常由它們處理。
/// 拖曳捲動不算點擊，所以捲動時鍵盤不會被收起。
class TapOutsideUnfocus extends StatelessWidget {
  const TapOutsideUnfocus({super.key, required this.child});
  final Widget child;

  static void _unfocusTextField() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (focus == null || ctx == null) return;
    // 只收輸入框的焦點；其他焦點（例如 iPad 鍵盤快捷鍵）不動。
    if (ctx.widget is! EditableText &&
        ctx.findAncestorWidgetOfExactType<EditableText>() == null) {
      return;
    }
    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: _unfocusTextField,
    child: child,
  );
}
