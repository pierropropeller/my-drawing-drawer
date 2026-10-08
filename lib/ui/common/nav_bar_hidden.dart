import 'package:flutter/widgets.dart';

/// 目前有幾個頁面要求隱藏底部導覽列。
///
/// 規則（HANDOFF 第 6 節）：瀏覽用的頁面有導覽列，做事用的頁面（新增／編輯／詳情／
/// 預覽／多選／管理／設定）沒有。這些頁面都走所屬分頁自己的 Navigator，再用這個計數
/// 把導覽列藏起來；若改用最上層 Navigator，Android 返回手勢會連分頁內的上一頁一起退掉。
final navBarHiddenCount = ValueNotifier<int>(0);

mixin HidesNavBar<T extends StatefulWidget> on State<T> {
  bool _navHidden = false;

  /// 開頁時是否就隱藏。多選這種「進入某狀態才隱藏」的頁面覆寫成 false，
  /// 再在狀態改變時呼叫 [setNavBarHidden]。
  bool get hidesNavBarOnOpen => true;

  void setNavBarHidden(bool hidden) {
    if (hidden == _navHidden) return;
    _navHidden = hidden;
    // build 期間不能改 ValueNotifier，延到 microtask。
    Future.microtask(() => navBarHiddenCount.value += hidden ? 1 : -1);
  }

  @override
  void initState() {
    super.initState();
    if (hidesNavBarOnOpen) setNavBarHidden(true);
  }

  @override
  void dispose() {
    setNavBarHidden(false);
    super.dispose();
  }
}

/// 給沒有 State 的頁面用：包住整頁，存在期間隱藏導覽列。
class HideNavBar extends StatefulWidget {
  const HideNavBar({super.key, required this.child});
  final Widget child;

  @override
  State<HideNavBar> createState() => _HideNavBarState();
}

class _HideNavBarState extends State<HideNavBar> with HidesNavBar {
  @override
  Widget build(BuildContext context) => widget.child;
}
