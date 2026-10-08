import 'package:flutter/widgets.dart';

/// 目前有幾個全螢幕頁（看圖預覽）要求隱藏底部導覽列。
///
/// 預覽頁走所屬分頁自己的 Navigator（和其他子頁一樣），再用這個計數把導覽列藏起來；
/// 若改用最上層 Navigator，Android 返回手勢會連分頁內的上一頁一起退掉。
final navBarHiddenCount = ValueNotifier<int>(0);

mixin HidesNavBar<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // build 期間不能改 ValueNotifier，延到 microtask。
    Future.microtask(() => navBarHiddenCount.value++);
  }

  @override
  void dispose() {
    Future.microtask(() => navBarHiddenCount.value--);
    super.dispose();
  }
}
