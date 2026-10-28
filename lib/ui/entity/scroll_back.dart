import 'package:flutter/material.dart';

/// 從詳情頁返回列表時，把「最後看的那一篇」捲回畫面內（D-122）。
///
/// 列表的每張卡用 [wrap] 包一層；返回後呼叫 [reveal]。列表是惰性建立的：目標那張還沒建好時，
/// 先把離它最近、已經建好的那張捲到畫面中間，目標就會跟著建好，再逐步靠過去。
///
/// 不用 GlobalKey（惰性列表重新排序時 GlobalKey 搬家會在 layout 中改動 render tree）：
/// 每張卡用 [wrap] 包起來，包裝元件建好時登記自己的 context、拆掉時取消。
class ScrollBackAnchors {
  final Map<String, BuildContext> _ctx = {};

  /// 包住一張卡（以 [id] 登記）。
  Widget wrap(String id, Widget child) =>
      _Anchor(key: ValueKey('anchor:$id'), id: id, anchors: this, child: child);

  /// [order]＝列表目前的次序；[id]＝要顯示的那一篇。
  Future<void> reveal(String id, List<String> order) async {
    final target = order.indexOf(id);
    if (target < 0) return;
    for (var attempt = 0; attempt < 8; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _ctx[id];
      if (ctx != null && ctx.mounted) {
        if (!_inView(ctx)) {
          await Scrollable.ensureVisible(ctx, alignment: 0.3);
        }
        return;
      }
      // 離目標最近、已經建好的那張。
      BuildContext? near;
      var best = 1 << 30;
      for (var i = 0; i < order.length; i++) {
        final c = _ctx[order[i]];
        if (c == null || !c.mounted) continue;
        final d = (i - target).abs();
        if (d < best) {
          best = d;
          near = c;
        }
      }
      if (near == null) return;
      if (!near.mounted) return;
      await Scrollable.ensureVisible(near, alignment: 0.5);
    }
  }

  bool _inView(BuildContext ctx) {
    final ro = ctx.findRenderObject();
    final scrollable = Scrollable.maybeOf(ctx);
    if (ro is! RenderBox || !ro.attached || scrollable == null) return true;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox) return true;
    final top = ro.localToGlobal(Offset.zero, ancestor: box).dy;
    return top >= 0 && top + ro.size.height <= box.size.height;
  }
}

class _Anchor extends StatefulWidget {
  const _Anchor({
    super.key,
    required this.id,
    required this.anchors,
    required this.child,
  });
  final String id;
  final ScrollBackAnchors anchors;
  final Widget child;

  @override
  State<_Anchor> createState() => _AnchorState();
}

class _AnchorState extends State<_Anchor> {
  @override
  void initState() {
    super.initState();
    widget.anchors._ctx[widget.id] = context;
  }

  @override
  void dispose() {
    if (widget.anchors._ctx[widget.id] == context) {
      widget.anchors._ctx.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
