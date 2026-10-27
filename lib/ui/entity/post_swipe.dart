import 'package:flutter/material.dart';

import '../common/swipe_pager.dart';

/// 詳情頁左右滑換上／下篇（D-122，canvas `SwipePostSpec`）：腦洞、摸魚、推活、成圖詳情共用。
///
/// - 標題列（[header]）固定不動；下面整頁內容（[body]，連大圖）跟手指移動，上／下篇並排滑入，
///   放手規則同 D-118（[SwipePager]：過 30% 或快撥換篇，不夠彈回，250ms ease-out）。
/// - 大圖輪播自己的橫向滑動優先（子層捲動區先收手勢），滑到最後一張再拉只回彈、不跳篇；
///   大圖以下的地方左右滑才換篇。上下捲動與左右滑由手勢競技場鎖定方向，互不干擾。
/// - 次序＝[order]（進來前那個列表的次序）；沒有給、或不含 [initialId] 時只有這一篇，不能滑。
/// - 每篇內容以 id 為 key：換篇後新一篇從頂部開始、大圖回到第 1 張。隔壁兩篇預先建好。
/// - [header] 拿到目前這篇的 id 和 `afterDelete`：刪除成功後呼叫，自動顯示下一篇
///   （沒有下一篇就上一篇，都沒有就返回）。
/// - [onShown]：換到某一篇時通知（列表記住最後看的那一篇）。
class PostSwipeView extends StatefulWidget {
  const PostSwipeView({
    super.key,
    required this.initialId,
    required this.header,
    required this.body,
    this.order,
    this.onShown,
  });

  final String initialId;
  final List<String>? order;
  final Widget Function(
    BuildContext context,
    String id,
    VoidCallback afterDelete,
  )
  header;
  final Widget Function(BuildContext context, String id) body;
  final ValueChanged<String>? onShown;

  @override
  State<PostSwipeView> createState() => _PostSwipeViewState();
}

class _PostSwipeViewState extends State<PostSwipeView> {
  late final List<String> _order = () {
    final o = widget.order;
    if (o == null || !o.contains(widget.initialId)) return [widget.initialId];
    return [...o];
  }();
  late String _id = widget.initialId;

  void _show(String id) {
    setState(() => _id = id);
    widget.onShown?.call(id);
  }

  void _afterDelete() {
    final i = _order.indexOf(_id);
    if (i < 0 || _order.length <= 1) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _order.removeAt(i);
      _id = _order[i < _order.length ? i : _order.length - 1];
    });
    widget.onShown?.call(_id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.header(context, _id, _afterDelete),
        Expanded(
          child: SwipePager<String>(
            order: _order,
            current: _id,
            onChanged: _show,
            itemBuilder: (context, id) => KeyedSubtree(
              key: ValueKey(id),
              child: widget.body(context, id),
            ),
          ),
        ),
      ],
    );
  }
}
