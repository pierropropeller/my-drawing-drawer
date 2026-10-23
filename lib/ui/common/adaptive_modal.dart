import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import 'device_class.dart';
import 'window_class.dart';

/// 表單／編輯頁的「自適應 modal」（iPad 設計稿：NewPit、PitEdit、New*，RespSpec「彈出頁」）。
///
/// - 視窗闊度 ≥ [minWindowWidth]（預設 600，即 [WindowClass.medium] 以上）：在畫面正中央開一個
///   圓角 24 的 form sheet（[width]×[height]，會縮到不超出視窗），蓋住 rail／sidebar
///   （走最上層 Navigator，設計稿的 modal 也是整個畫面變暗）。窄於內容所需時，欄位自動改單欄
///   （見 `ModalFormShell`）。
/// - 較窄（＜600）且是 iPad（[isTabletDevice]，例如分屏約 400 寬）：全闊 page sheet
///   （NewXxx400：頂部留 12 露出底層、抓握條、52 高標題列、單欄、主按鈕縮短成「建立」／「加入」）。
///   [sheetBelowMedium] 傳 false＝這個表單沒有 400 稿，窄視窗仍開整頁。
/// - 其餘（手機）：照舊 `Navigator.of(context).push(MaterialPageRoute)` 開整頁，行為與手機版完全一樣。
///
/// 彈出期間視窗闊度跨過 600，樣式即時在 form sheet ↔ page sheet 之間切換，
/// 表單的 State（已填內容、捲動位置）不會丟（內容用 GlobalKey 搬家）。
///
/// [builder] 的 `asModal` 告訴表單現在是哪一種：
/// - `asModal == false`：畫整頁（Scaffold＋原本的標題列），並照舊用 `HidesNavBar` 藏導覽列。
/// - `asModal == true`：只畫彈出內容（建議用 [ModalFormFrame]／`ModalFormShell` 包：取消／標題／主動作），
///   **不要**再用 `HidesNavBar`（彈出頁本來就蓋住導覽）。目前是 form sheet 還是 page sheet，
///   用 [AdaptiveModalScope.sheetOf] 讀（`ModalFormFrame` 已自動處理）。
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
  double minWindowWidth = WindowClass.mediumMin,
  bool sheetBelowMedium = true,
  bool barrierDismissible = false,
  Color barrierColor = const Color(0x731E1B18),
  bool sheetChrome = true,
  ValueListenable<double>? widthListenable,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final popup =
      w >= minWindowWidth || (sheetBelowMedium && isTabletDevice(context));
  if (!popup) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute<T>(builder: (ctx) => builder(ctx, false)));
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(
    _AdaptiveFormRoute<T>(
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (ctx) => AdaptiveFormSurface(
        width: width,
        widthListenable: widthListenable,
        height: height,
        sheetChrome: sheetChrome,
        sheetBelowMedium: sheetBelowMedium,
        minWindowWidth: minWindowWidth,
        child: Builder(builder: (ctx) => builder(ctx, true)),
      ),
    ),
  );
}

class _AdaptiveFormRoute<T> extends PopupRoute<T> {
  _AdaptiveFormRoute({
    required this.pageBuilder,
    required this.themes,
    required this.barrierDismissible,
    required this.barrierLabel,
    required this.barrierColor,
  });

  final WidgetBuilder pageBuilder;
  final CapturedThemes themes;

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  final Color barrierColor;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: themes.wrap(pageBuilder(context)),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final sheet = MediaQuery.sizeOf(context).width < WindowClass.mediumMin;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    if (!sheet) return FadeTransition(opacity: curved, child: child);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

/// 彈出表單的外殼：視窗 ≥600 是置中 form sheet，＜600 是 page sheet（NewXxx400）。
/// 兩種外殼共用同一份內容（GlobalKey），拉窗跨過 600 時內容的 State 不會丟。
class AdaptiveFormSurface extends StatefulWidget {
  const AdaptiveFormSurface({
    super.key,
    required this.child,
    this.width = 600,
    this.widthListenable,
    this.height,
    this.sheetBelowMedium = true,
    this.sheetChrome = true,
    this.minWindowWidth = WindowClass.mediumMin,
  });
  final Widget child;
  final double width;

  /// 內容要在開著的時候改對話框寬度時用（例如開新坑選淺坑變兩欄 880）；null＝固定 [width]。
  final ValueListenable<double>? widthListenable;
  final double? height;
  final bool sheetBelowMedium;

  /// page sheet 要不要畫「露出底層的灰條」和抓握條（New* 稿有；ShareImport400／MediaPicker400 沒有）。
  final bool sheetChrome;
  final double minWindowWidth;

  @override
  State<AdaptiveFormSurface> createState() => _AdaptiveFormSurfaceState();
}

class _AdaptiveFormSurfaceState extends State<AdaptiveFormSurface> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < widget.minWindowWidth;
    final sheet = narrow && widget.sheetBelowMedium;
    final content = AdaptiveModalScope(
      key: _contentKey,
      sheet: sheet,
      child: widget.child,
    );
    if (sheet) {
      return _FormSheetFrame(chrome: widget.sheetChrome, child: content);
    }
    final listenable = widget.widthListenable;
    if (listenable == null) {
      return AdaptiveModalDialog(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      child: content,
      builder: (_, w, child) =>
          AdaptiveModalDialog(width: w, height: widget.height, child: child!),
    );
  }
}

/// 告訴內容「你在彈出的對話框／sheet 裡」（[showAdaptiveModal] 的 modal 模式會自動包上）。
class AdaptiveModalScope extends InheritedWidget {
  const AdaptiveModalScope({
    super.key,
    this.sheet = false,
    required super.child,
  });

  /// true＝page sheet（＜600，NewXxx400）；false＝置中 form sheet。
  final bool sheet;

  /// 目前是否在彈出頁裡。
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdaptiveModalScope>() != null;

  /// 目前是否在 page sheet（窄視窗）裡；會跟著視窗闊度重建。
  static bool sheetOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveModalScope>()?.sheet ??
      false;

  @override
  bool updateShouldNotify(AdaptiveModalScope oldWidget) =>
      oldWidget.sheet != sheet;
}

/// page sheet 外框（NewXxx400）：頂部留 12 露出底層（16 高的灰條）、圓角 14、抓握條，
/// 鍵盤彈出時整張往上縮。
class _FormSheetFrame extends StatelessWidget {
  const _FormSheetFrame({required this.child, this.chrome = true});
  final Widget child;
  final bool chrome;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final mq = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Stack(
            children: [
              if (chrome)
                Positioned(
                  left: 14,
                  right: 14,
                  top: mq.padding.top,
                  height: 16,
                  child: DecoratedBox(
                    key: const ValueKey('form-sheet-peek'),
                    decoration: BoxDecoration(
                      color: dark ? t.surface : const Color(0xFFA39C96),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: mq.padding.top + 12,
                bottom: 0,
                child: DecoratedBox(
                  key: const ValueKey('form-sheet'),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x2E1E1B18),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: t.ground,
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (chrome)
                          Center(
                            child: Container(
                              width: 36,
                              height: 5,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: dark
                                    ? t.border
                                    : const Color(0xFFD8CFC3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

/// modal 內的表單外框：標題列（取消／襯線標題／主動作）＋內容。
///
/// - form sheet（≥600）：64 高標題列，主動作用 [actionLabel]（例：「加入官方圖冊」）。
/// - page sheet（＜600，`AdaptiveModalScope.sheetOf`）：52 高標題列、字略小，
///   主動作縮短成 [compactActionLabel]（例：「加入」／「建立」；省略＝沿用 [actionLabel]）。
///
/// [expandBody] 為 true（對話框有固定高度）時內容填滿剩餘高度；false 時依內容高度。
/// [extraActions]：主動作左邊的額外按鈕（例如編輯時的刪除）。
class ModalFormFrame extends StatelessWidget {
  const ModalFormFrame({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
    this.compactActionLabel,
    this.expandBody = false,
    this.onCancel,
    this.extraActions = const [],
  });
  final String title;
  final String actionLabel;
  final String? compactActionLabel;
  final VoidCallback onAction;
  final VoidCallback? onCancel;
  final Widget child;
  final bool expandBody;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sheet = AdaptiveModalScope.sheetOf(context);
    final header = Container(
      height: sheet ? 52 : 64,
      padding: EdgeInsets.symmetric(horizontal: sheet ? 6 : 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel ?? () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              minimumSize: Size(sheet ? 56 : 44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundColor: t.text2,
              textStyle: TextStyle(fontSize: sheet ? 16 : 15),
            ),
            child: Text(context.l10n.commonCancel),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: sheet ? 17 : 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...extraActions,
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: Size(44, sheet ? 36 : 40),
              padding: EdgeInsets.symmetric(horizontal: sheet ? 14 : 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sheet ? 10 : 12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              sheet ? (compactActionLabel ?? actionLabel) : actionLabel,
              maxLines: 1,
              softWrap: false,
            ),
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
