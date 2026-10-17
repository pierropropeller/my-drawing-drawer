import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'window_class.dart';

/// 新增／編輯表單的容器（iPad 設計稿的置中 modal）。
///
/// 視窗闊度 ≥840（[WindowClass.isWide]）＝置中對話框（預設 880×620，圓角 24，會縮到視窗內）；
/// 其餘＝一般頁面路由（手機行為不變）。內容用 [AdaptiveModalScope.of] 判斷自己是否在對話框裡。
///
/// 對話框掛在最上層 Navigator，遮罩蓋住整個視窗（含側邊導覽）。
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Size size = const Size(880, 620),
}) {
  if (!WindowClass.of(context).isWide) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute<T>(builder: builder));
  }
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x6B1E1A17),
    builder: (ctx) => AdaptiveModalFrame(size: size, child: builder(ctx)),
  );
}

/// 告訴內容「你在置中對話框裡」。
class AdaptiveModalScope extends InheritedWidget {
  const AdaptiveModalScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveModalScope>() != null;

  @override
  bool updateShouldNotify(AdaptiveModalScope oldWidget) => false;
}

/// 對話框外框：大小取 [size] 與視窗（四邊各留 24）的較小值，所以拉窄視窗時不會溢出。
class AdaptiveModalFrame extends StatelessWidget {
  const AdaptiveModalFrame({
    super.key,
    required this.size,
    required this.child,
  });
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: t.ground,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: LayoutBuilder(
        builder: (context, box) => SizedBox(
          width: size.width.clamp(0, box.maxWidth).toDouble(),
          height: size.height.clamp(0, box.maxHeight).toDouble(),
          child: AdaptiveModalScope(child: child),
        ),
      ),
    );
  }
}
