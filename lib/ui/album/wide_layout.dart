import '../common/top_toast.dart';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../common/svg_icon.dart';
import '../common/window_class.dart';

/// 平板寬版（≥840）列表頁共用的尺寸規格（RespSpec／FanArt／Finished／Oshi 設計稿）。
///
/// 稿中的 340／350／290 是 1194 寬時的值，實作用視窗闊度夾在範圍內，不寫死。
class WideSpec {
  const WideSpec({required this.hpad, required this.gap, required this.panel});

  /// 內容區左右邊距（稿：1194 為 32，窄一點的視窗 24）。
  final double hpad;

  /// 列表與右側面板之間的間距。
  final double gap;

  /// 右側面板闊度。
  final double panel;

  /// [windowWidth] 為整個視窗的闊度；[expanded]／[large] 為各級別的面板範圍。
  factory WideSpec.of(
    double windowWidth, {
    (double, double) expanded = (300, 340),
    (double, double) large = (340, 380),
  }) {
    final isLarge = windowWidth >= WindowClass.largeMin;
    final range = isLarge ? large : expanded;
    return WideSpec(
      hpad: windowWidth >= 1100 ? 32 : 24,
      gap: windowWidth >= 1100 ? 24 : 20,
      panel: panelWidthFor(
        windowWidth,
        min: range.$1,
        max: range.$2,
        fraction: isLarge ? 0.265 : 0.3,
      ),
    );
  }
}

/// 右側面板的外框：白底、細框、上方圓角 20、貼底（稿：`border-radius:20px 20px 0 0`）。
class SidePanelFrame extends StatelessWidget {
  const SidePanelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 10),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ToastRegion(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? t.surface,
          border: Border(
            top: BorderSide(color: t.border),
            left: BorderSide(color: t.border),
            right: BorderSide(color: t.border),
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: child,
      ),
    );
  }
}

/// 面板／詳情區沒有選取項目時的提示。
class WideEmptyHint extends StatelessWidget {
  const WideEmptyHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.tokens.text3, fontSize: 13.5),
      ),
    ),
  );
}

/// 面板底部的一個動作（icon＋文字，觸控目標 ≥ 44）。
class PanelAction {
  const PanelAction(this.svg, this.label, this.onTap, {this.color});
  final String svg;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

/// 面板底部的動作列（稿：頂端細線、每格 icon 20＋11.5 文字、高 58）。
class PanelActionBar extends StatelessWidget {
  const PanelActionBar({super.key, required this.actions});
  final List<PanelAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: Semantics(
                button: true,
                label: a.label,
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: a.onTap,
                  child: SizedBox(
                    height: 58,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgIcon(
                          a.svg,
                          size: 20,
                          strokeWidth: 1.7,
                          color: a.color ?? t.text2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: a.color ?? t.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 頂欄的 44×44 方形 icon 鈕（稿 `.ib`：白底細框圓角 12）。
class WideIconButton extends StatelessWidget {
  const WideIconButton({
    super.key,
    required this.svg,
    required this.label,
    required this.onTap,
    this.color,
    this.selected = false,
  });
  final String svg;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? t.ink : t.surface,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SvgIcon(
              svg,
              size: 20,
              strokeWidth: 1.8,
              color: selected ? t.surface : (color ?? t.ink),
            ),
          ),
        ),
      ),
    );
  }
}
