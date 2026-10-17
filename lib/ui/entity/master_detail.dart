import 'package:flutter/material.dart';

import '../common/window_class.dart';

/// 列表＋詳情並排（腦洞、摸魚）的「選中項目」狀態，掛在列表頁的 State 上。
///
/// 規則（RespSpec）：
/// - ≥840 並排，選中的項目顯示在右側詳情區；
/// - 拉窄到 ＜840 時，若有選中項目，直接停在詳情頁（[syncMasterDetail] 偵測由寬變窄的那一刻 push）；
/// - 詳情頁（[PopWhenWide] 包住的那一層）發現視窗又變寬，會自己退回列表，列表保留選中。
/// 選中的 id 放在 State（不隨視窗級別重建），所以拉窗不會丟。
mixin MasterDetailState<T extends StatefulWidget> on State<T> {
  /// 目前選中的項目 id。
  String? selectedId;

  bool? _wasWide;

  /// 在 build 開頭呼叫：[wide] 為目前是否並排。由寬變窄且有選中項目時，開詳情頁。
  void syncMasterDetail(bool wide, void Function(String id) pushDetail) {
    final was = _wasWide;
    _wasWide = wide;
    final id = selectedId;
    if (was == true && !wide && id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 上面已經蓋著別的頁（例如編輯表單）就不插隊。
        if (ModalRoute.of(context)?.isCurrent != true) return;
        pushDetail(id);
      });
    }
  }
}

/// 包住由列表開出來的詳情頁：視窗變寬（≥840）時自己退回列表（列表改成並排顯示同一項）。
class PopWhenWide extends StatefulWidget {
  const PopWhenWide({super.key, required this.child});
  final Widget child;

  @override
  State<PopWhenWide> createState() => _PopWhenWideState();
}

class _PopWhenWideState extends State<PopWhenWide> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    if (WindowClass.of(context).isWide && !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted) return;
        final route = ModalRoute.of(context);
        if (route != null &&
            route.isCurrent &&
            WindowClass.of(context).isWide) {
          Navigator.of(context).pop();
        }
      });
    }
    return widget.child;
  }
}
