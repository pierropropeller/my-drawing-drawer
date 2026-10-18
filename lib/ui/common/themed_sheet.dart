import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 開 modal bottom sheet，外殼（底色、圓角）在 sheet 自己的 context 裡才解析主題。
///
/// 為什麼不直接用 `showModalBottomSheet(backgroundColor: t.ground)`：`t` 是開啟當下算的，
/// sheet 開著時系統切換深淺色（例如省電模式），內容會跟著新主題重建，外殼卻停在舊顏色，
/// 變成「淺色底＋深色內容」。這裡讓 route 的底色透明，改由 [ThemedSheetSurface] 在 builder
/// 的 context 裡讀 `context.tokens.ground`，跟著主題即時變。
Future<T?> showThemedSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  bool isScrollControlled = true,
  bool enableDrag = true,
  double radius = 22,
  BoxConstraints? constraints,
  Color barrierColor = const Color(0x6B1E1A17), // rgba(30,26,23,.42)
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: constraints,
    barrierColor: barrierColor,
    builder: (ctx) => ThemedSheetSurface(radius: radius, child: builder(ctx)),
  );
}

/// bottom sheet 的底板：`context.tokens.ground` ＋上方圓角，隨主題即時變色。
class ThemedSheetSurface extends StatelessWidget {
  const ThemedSheetSurface({super.key, required this.child, this.radius = 22});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.ground,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
      child: child,
    );
  }
}
