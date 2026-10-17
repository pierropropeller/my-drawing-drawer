import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'window_class.dart';

/// 表單／編輯頁的「自適應 modal」（iPad 設計稿：NewPit、PitEdit、New*）。
///
/// - 視窗闊度 ≥ [minWindowWidth]（預設 840，即 [WindowClass.expanded] 以上）：在畫面正中央開一個
///   圓角 24 的對話框（[width]×[height]，會縮到不超出視窗），蓋住 rail／sidebar（走最上層 Navigator，
///   設計稿的 modal 也是整個畫面變暗）。
/// - 較窄（含手機）：照舊 `Navigator.of(context).push(MaterialPageRoute)` 開整頁，行為與手機版完全一樣。
///
/// [builder] 的 `asModal` 告訴表單現在是哪一種：
/// - `asModal == false`：畫整頁（Scaffold＋原本的標題列），並照舊用 `HidesNavBar` 藏導覽列。
/// - `asModal == true`：只畫對話框內容（建議用 [ModalFormFrame] 包：取消／標題／主動作），
///   **不要**再用 `HidesNavBar`（對話框本來就蓋住導覽）。
///
/// 回傳值：表單用 `Navigator.of(context).pop(value)` 關閉，兩種模式都一樣。
/// 注意：modal 模式下表單的 `Navigator.of(context)` 是最上層 Navigator，所以「刪除後回到主頁」這類
/// 要動到分頁 Navigator 的事，請回傳結果給呼叫端處理（見 `openPitEdit`）。
///
/// 用法：
/// ```dart
/// final id = await showAdaptiveModal<String>(
///   context,
///   width: 600,
///   builder: (_, asModal) => PitNewPage(asModal: asModal),
/// );
/// ```
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, bool asModal) builder,
  double width = 600,
  double? height,
  double minWindowWidth = WindowClass.expandedMin,
  bool barrierDismissible = false,
}) {
  final wide = MediaQuery.sizeOf(context).width >= minWindowWidth;
  if (!wide) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute<T>(builder: (ctx) => builder(ctx, false)));
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x731E1B18),
    builder: (ctx) => AdaptiveModalDialog(
      width: width,
      height: height,
      child: AdaptiveModalScope(child: builder(ctx, true)),
    ),
  );
}

/// 告訴內容「你在置中對話框裡」（[showAdaptiveModal] 的 modal 模式會自動包上）。
class AdaptiveModalScope extends InheritedWidget {
  const AdaptiveModalScope({super.key, required super.child});

  /// 目前是否在對話框裡。
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdaptiveModalScope>() != null;

  @override
  bool updateShouldNotify(AdaptiveModalScope oldWidget) => false;
}

/// 置中的圓角對話框外殼：寬高不超出視窗（四邊各留 24），[height] 為 null 時依內容。
class AdaptiveModalDialog extends StatelessWidget {
  const AdaptiveModalDialog({
    super.key,
    required this.child,
    this.width = 600,
    this.height,
  });
  final Widget child;
  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: t.ground,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x4D1E1B18),
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = math.min(width, c.maxWidth);
          final h = height == null ? null : math.min(height!, c.maxHeight);
          return SizedBox(width: w, height: h, child: child);
        },
      ),
    );
  }
}

/// modal 內的表單外框：64 高標題列（取消／襯線標題／主動作）＋內容。
/// [expandBody] 為 true（對話框有固定高度）時內容填滿剩餘高度；false 時依內容高度。
class ModalFormFrame extends StatelessWidget {
  const ModalFormFrame({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
    this.expandBody = false,
    this.onCancel,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onCancel;
  final Widget child;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final header = Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: t.text2,
              textStyle: const TextStyle(fontSize: 15),
            ),
            child: Text(context.l10n.commonCancel),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (expandBody) Expanded(child: child) else Flexible(child: child),
      ],
    );
  }
}
