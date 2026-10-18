import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'adaptive_modal.dart';

/// 表單 modal 裡的一欄（New* 設計稿：左右（或三）欄，欄間 1px 分隔線，各欄獨立捲動）。
///
/// [width] 為 null＝吃剩餘寬度。
class ModalPane {
  const ModalPane({
    required this.children,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
  });
  final List<Widget> children;
  final double? width;
  final EdgeInsets padding;
}

/// 把 [panes] 並排成 modal 的內容區；每欄各自 `SingleChildScrollView`。
///
/// 可用闊度不夠（固定闊度欄加上每個彈性欄至少 [minFlexPane]）或在 page sheet（＜600，NewXxx400）時，
/// 改成「單欄捲動」：各欄的內容依序疊起來（RespSpec：全部欄位改單欄，可捲動）。
class ModalFormPanes extends StatelessWidget {
  const ModalFormPanes({
    super.key,
    required this.panes,
    this.minFlexPane = 300,
  });
  final List<ModalPane> panes;

  /// 彈性欄（沒指定闊度）的最小闊度。
  final double minFlexPane;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sheet = AdaptiveModalScope.sheetOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final need = panes.fold<double>(
          0,
          (sum, p) => sum + (p.width ?? minFlexPane),
        );
        if (sheet || panes.length < 2 || c.maxWidth < need) {
          final bottom = MediaQuery.paddingOf(context).bottom;
          return SingleChildScrollView(
            padding: sheet
                ? EdgeInsets.fromLTRB(20, 18, 20, 40 + bottom)
                : const EdgeInsets.fromLTRB(28, 22, 28, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < panes.length; i++) ...[
                  if (i > 0) const SizedBox(height: 20),
                  ...panes[i].children,
                ],
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < panes.length; i++)
              _wrap(
                panes[i],
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == panes.length - 1
                        ? null
                        : Border(right: BorderSide(color: t.border)),
                  ),
                  child: SingleChildScrollView(
                    padding: panes[i].padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: panes[i].children,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _wrap(ModalPane p, Widget child) => p.width == null
      ? Expanded(child: child)
      : SizedBox(width: p.width, child: child);
}

/// 表單在 modal 模式下的完整外殼：取消／標題／主動作 ＋ 多欄內容（[loaded] 為 false 時轉圈）。
/// 對話框高度由 [showAdaptiveModal] 的 `height` 決定，這裡 `expandBody` 填滿。
/// [compactActionLabel]：page sheet（＜600）的短主按鈕字（例：「加入」）。
class ModalFormShell extends StatelessWidget {
  const ModalFormShell({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.panes,
    this.compactActionLabel,
    this.extraActions = const [],
    this.loaded = true,
  });
  final String title;
  final String actionLabel;
  final String? compactActionLabel;
  final VoidCallback onAction;
  final List<ModalPane> panes;
  final List<Widget> extraActions;
  final bool loaded;

  @override
  Widget build(BuildContext context) => ModalFormFrame(
    title: title,
    actionLabel: actionLabel,
    compactActionLabel: compactActionLabel,
    onAction: onAction,
    extraActions: extraActions,
    expandBody: true,
    child: loaded
        ? ModalFormPanes(panes: panes)
        : const Center(child: CircularProgressIndicator()),
  );
}
