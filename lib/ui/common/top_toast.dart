import 'package:flutter/material.dart';

import '../../theme/font_fallback.dart';
import '../../theme/tokens.dart';
import 'app_icons.dart';
import 'svg_icon.dart';

/// 全 App 的提示條（D-114，Snackbar）：留在螢幕**下方**，但永遠浮在固定的底部元件**上面**，不蓋住按鈕：
/// - 有底部導覽列的頁面：導覽列上方 12；有底部操作列（多選）或固定底部按鈕：那一列上方 12
///   （這些元件用 [BottomInsetAnchor] 登記）；
/// - 其他：螢幕底部（含系統手勢區）上方 16；
/// - 鍵盤打開時浮在鍵盤上方 12。
/// 樣式反白：淺色模式深底（#2B2622）白字、深色模式淺底（#F2ECE4）深字；圓角 14、左右各 16、
/// 內距 12×16、可選 18px 前置圖示（[success]＝勾）、可選右側文字按鈕（[actionLabel]，如「復原」）。
/// 3 秒後自動收起（有按鈕 5 秒）；往下滑可收掉；一次只有一條，新的取代舊的。
///
/// 使用時機：動作已經生效、使用者**留在這一頁**才用（預覽頁設為封面、多選批次操作…）。
/// 表單（新增／編輯頁）中途的操作、或會跳到別頁的動作，不要用。
///
/// 實作：直接插一個 [OverlayEntry] 到最上層的 [Overlay]（比任何頁面、sheet 都高）；
/// 動畫用 AnimationController 計時，沒有額外的 Timer。
const kTopToastDuration = Duration(seconds: 3);
const kTopToastActionDuration = Duration(seconds: 5);

/// 預設離螢幕底部的距離（再加系統安全區）。
const kToastBottomGap = 16.0;

/// 浮在固定底部元件上方時的距離。
const kToastAboveGap = 12.0;

_ToastHandle? _current;

/// 目前提示條的頂端離螢幕底部多遠（沒有提示條＝0）。右下「＋」用 [ToastLift] 聽它往上推。
final ValueNotifier<double> topToastTopFromBottom = ValueNotifier<double>(0);

class _ToastHandle {
  _ToastHandle(this.entry);
  final OverlayEntry entry;
}

/// 目前有沒有提示條在顯示（測試用）。
bool get topToastShowing => _current != null;

/// 立刻收掉目前的提示條（沒有動畫）。
void hideTopToast() {
  final c = _current;
  if (c == null) return;
  _current = null;
  topToastTopFromBottom.value = 0;
  // 舊的提示條所在的 Overlay 可能已經隨頁面／整棵樹一起拆掉了：移除與釋放都要容錯。
  try {
    c.entry.remove();
  } catch (_) {}
  try {
    c.entry.dispose();
  } catch (_) {}
}

/// 登記「貼在螢幕底部的固定元件」（底部導覽列、多選操作列、固定底部按鈕）。
/// 提示條會浮在所有**目前頁面**登記的元件的上面。包住該元件即可，不用傳高度（自己量位置）。
class BottomInsetAnchor extends StatefulWidget {
  const BottomInsetAnchor({super.key, required this.child});
  final Widget child;

  static final _anchors = <_BottomInsetAnchorState>{};

  /// 目前所有可見登記元件的頂端距離螢幕底部多少（沒有就 0）。[viewHeight]＝螢幕高度。
  static double topFromBottom(double viewHeight) {
    var best = 0.0;
    for (final a in _anchors) {
      final ctx = a.context;
      if (!a.mounted) continue;
      // 被別的頁面蓋住（不是目前的路由）的不算。
      final route = ModalRoute.of(ctx);
      if (route != null && !route.isCurrent) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      if (ro.size.height <= 0) continue;
      final top = ro.localToGlobal(Offset.zero).dy;
      // 捲出畫面上方的（例如跟著內容捲動的按鈕）不算。
      if (top < 0) continue;
      final v = viewHeight - top;
      if (v > best) best = v;
    }
    return best;
  }

  @override
  State<BottomInsetAnchor> createState() => _BottomInsetAnchorState();
}

class _BottomInsetAnchorState extends State<BottomInsetAnchor> {
  @override
  void initState() {
    super.initState();
    BottomInsetAnchor._anchors.add(this);
  }

  @override
  void dispose() {
    BottomInsetAnchor._anchors.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 顯示一條提示條。[success]＝前面加勾，[offline]＝前面加離線雲。
void showTopToast(
  BuildContext context,
  String text, {
  bool success = false,
  bool offline = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final tokens = context.tokens;
  final dark = Theme.of(context).brightness == Brightness.dark;
  hideTopToast();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      text: text,
      success: success,
      offline: offline,
      actionLabel: actionLabel,
      onAction: onAction,
      tokens: tokens,
      dark: dark,
      onDone: () {
        if (_current?.entry == entry) hideTopToast();
      },
    ),
  );
  _current = _ToastHandle(entry);
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.text,
    required this.success,
    required this.offline,
    required this.actionLabel,
    required this.onAction,
    required this.tokens,
    required this.dark,
    required this.onDone,
  });

  final String text;
  final bool success;
  final bool offline;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppTokens tokens;
  final bool dark;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  static const _inMs = 200; // 滑入／滑出
  late final Duration _hold = widget.actionLabel != null
      ? kTopToastActionDuration
      : kTopToastDuration;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _hold + const Duration(milliseconds: _inMs * 2),
  );
  bool _reduce = false;
  double _drag = 0;
  bool _dismissing = false;
  final _barKey = GlobalKey();

  /// 量提示條頂端的位置，給 [ToastLift]（「＋」停在提示條上方 12）。
  void _publishTop() {
    if (!mounted || _dismissing || _current == null) return;
    final ro = _barKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final h = MediaQuery.sizeOf(context).height;
    final top = h - ro.localToGlobal(Offset.zero).dy + _drag;
    // 只在滑入完成後量（動畫中的位移不算）。
    if ((top - topToastTopFromBottom.value).abs() > 0.5) {
      topToastTopFromBottom.value = top;
    }
  }

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0～1：滑入階段 0→1、停留 1、滑出階段 1→0。
  double get _shown {
    final total = _c.duration!.inMilliseconds;
    final ms = _c.value * total;
    if (_reduce) return ms < total ? 1 : 0;
    if (ms < _inMs) return Curves.easeOut.transform(ms / _inMs);
    if (ms > total - _inMs) {
      return Curves.easeIn.transform((total - ms) / _inMs);
    }
    return 1;
  }

  void _dismissNow() {
    if (_dismissing) return;
    _dismissing = true;
    topToastTopFromBottom.value = 0;
    widget.onDone();
  }

  void _action() {
    widget.onAction?.call();
    _dismissNow();
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final t = widget.tokens;
    final dark = widget.dark;
    // 反白：淺色模式深底白字，深色模式淺底深字。
    final bg = dark ? const Color(0xFFF2ECE4) : const Color(0xFF2B2622);
    final fg = dark ? const Color(0xFF2B2622) : Colors.white;
    final actionColor = dark ? t.accent : const Color(0xFFE9A58F);
    final icon = widget.success
        ? SvgIcon(
            AppIcons.check,
            size: 18,
            strokeWidth: 2.2,
            color: dark ? const Color(0xFF4F7A4F) : const Color(0xFF8FD19E),
          )
        : widget.offline
        ? SvgIcon(
            AppIcons.cloudOff,
            size: 18,
            strokeWidth: 1.9,
            color: dark ? const Color(0xFF8A6D2F) : const Color(0xFFE6C98F),
          )
        : null;
    final hasAction = widget.actionLabel != null;
    final bar = Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: fg,
                  fontSize: 13.5,
                  fontFamilyFallback: kFontFamilyFallback,
                ),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _action,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    widget.actionLabel!,
                    style: TextStyle(
                      color: actionColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: kFontFamilyFallback,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final mq = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final p = _shown;
        final total = _c.duration!.inMilliseconds;
        final ms = _c.value * total;
        if (ms >= _inMs && ms <= total - _inMs) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _publishTop());
        } else if (ms > total - _inMs && topToastTopFromBottom.value != 0) {
          // 開始滑出：「＋」同時滑回。
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => topToastTopFromBottom.value = 0,
          );
        }
        // 位置：預設螢幕底上方 16（加安全區）；有固定底部元件就在它上方 12；鍵盤打開浮在鍵盤上方 12。
        final anchor = BottomInsetAnchor.topFromBottom(mq.size.height);
        var bottom = mq.padding.bottom + kToastBottomGap;
        if (anchor > 0) bottom = anchor + kToastAboveGap;
        if (mq.viewInsets.bottom > 0) {
          final k = mq.viewInsets.bottom + kToastAboveGap;
          if (k > bottom) bottom = k;
        }
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Opacity(
                opacity: p,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - p) + _drag),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Semantics(
        liveRegion: true,
        container: true,
        // 往下滑收掉（提示條浮在固定底部元件上方，不會蓋住按鈕）。
        child: GestureDetector(
          key: _barKey,
          onVerticalDragUpdate: (d) =>
              setState(() => _drag = (_drag + d.delta.dy).clamp(0.0, 200.0)),
          onVerticalDragEnd: (d) {
            if (_drag > 24 || (d.primaryVelocity ?? 0) > 300) {
              _dismissNow();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: bar,
        ),
      ),
    );
  }
}

/// 包住右下「＋」浮動按鈕：提示條出現時往上推，停在提示條上方 12，提示條收起後滑回（D-114）。
class ToastLift extends StatefulWidget {
  const ToastLift({super.key, required this.child});
  final Widget child;

  @override
  State<ToastLift> createState() => _ToastLiftState();
}

class _ToastLiftState extends State<ToastLift> {
  double _lift = 0;

  @override
  void initState() {
    super.initState();
    topToastTopFromBottom.addListener(_update);
  }

  @override
  void dispose() {
    topToastTopFromBottom.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final toastTop = topToastTopFromBottom.value;
    var lift = 0.0;
    if (toastTop > 0) {
      final ro = context.findRenderObject();
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        // 按鈕原本（未位移）的底邊離螢幕底部多遠（自己的 Transform 不影響自己的位置）。
        final h = MediaQuery.sizeOf(context).height;
        final bottom = h - ro.localToGlobal(Offset(0, ro.size.height)).dy;
        final need = toastTop + kToastAboveGap - bottom;
        if (need > 0) lift = need;
      }
    }
    if ((lift - _lift).abs() > 0.5) setState(() => _lift = lift);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _lift),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, v, child) =>
          Transform.translate(offset: Offset(0, -v), child: child),
      child: widget.child,
    );
  }
}
