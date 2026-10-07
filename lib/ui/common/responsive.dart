import 'package:flutter/material.dart';

/// 依寬度決定瀑布流／格狀欄數：手機 2 欄，平板（iPad）3～4 欄。
int columnsForWidth(double width, {int phone = 2}) {
  if (width >= 1000) return phone + 2;
  if (width >= 600) return phone + 1;
  return phone;
}

/// 平板上把內容限制在易讀寬度並置中。
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 920});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
