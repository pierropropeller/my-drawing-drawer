import 'package:flutter/widgets.dart';

/// 記住「最近被按下的加圖格」在螢幕上的位置，讓來源選單（popover）錨在它旁邊。
///
/// 為什麼不讓每個呼叫端傳位置：所有加圖入口都是 `ref.read(imagePickerProvider)(context)`，
/// 選單是在 provider 裡開的（只有一個整合點）；加圖格用 [MediaMenuAnchorTarget] 包起來，
/// 按下時把自己的範圍記在這裡，選單開啟時取用。過了 [maxAge] 沒有新的記錄＝不是從加圖格開的
/// （例如列表頁工具列的「加圖」鈕），選單改置中，不畫箭頭。
class MediaMenuAnchor {
  MediaMenuAnchor._();

  static Rect? _rect;
  static DateTime? _at;
  static const maxAge = Duration(seconds: 3);

  /// 測試用的時間來源。
  static DateTime Function() now = DateTime.now;

  static void record(Rect rect) {
    _rect = rect;
    _at = now();
  }

  /// 取走最近的錨點（用過即清）；太久以前的當作沒有。
  static Rect? take() {
    final rect = _rect;
    final at = _at;
    _rect = null;
    _at = null;
    if (rect == null || at == null) return null;
    return now().difference(at) > maxAge ? null : rect;
  }

  static void clear() {
    _rect = null;
    _at = null;
  }
}

/// 包住加圖格：按下時記錄自己的位置（不攔截點擊）。
class MediaMenuAnchorTarget extends StatelessWidget {
  const MediaMenuAnchorTarget({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      MediaMenuAnchor.record(box.localToGlobal(Offset.zero) & box.size);
    },
    child: child,
  );
}
