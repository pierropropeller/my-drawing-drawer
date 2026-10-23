import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/sensitive.dart';
import '../album/wide_layout.dart' show WideIconButton;
import 'app_icons.dart';
import 'svg_icon.dart';

/// iPad 預覽／詳情面板的「顯示這張」（P-038，`FanArtSensitive`）。
///
/// 面板（[SensitiveReveal] 包住的範圍）裡的敏感圖：
/// - 安全模式開：照常模糊（52px 眼睛斜線圓）；面板上的眼睛鈕撳一下＝只顯示**這一張**
///   （icon 變成睜開的眼睛），換到別張（[SensitiveReveal.current] 變了）自動重新模糊。
///   這不是「安全模式」總開關，不會影響列表或其他畫面。
/// - 安全模式關：什麼都不加（面板不放左上角小標）。
///
/// `SensitiveGate` 偵測到自己在這個範圍內就依上面處理。
class SensitiveReveal extends StatefulWidget {
  const SensitiveReveal({
    super.key,
    required this.current,
    required this.child,
  });

  /// 面板現在顯示的圖檔名；null＝沒有可模糊的圖（沒圖、影片）。換了就自動重新模糊。
  final String? current;
  final Widget child;

  /// 附近的範圍；不在面板裡回傳 null。
  static SensitiveRevealScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SensitiveRevealScope>();

  @override
  State<SensitiveReveal> createState() => _SensitiveRevealState();
}

class _SensitiveRevealState extends State<SensitiveReveal> {
  String? _revealed;

  @override
  void didUpdateWidget(SensitiveReveal old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _revealed = null;
  }

  void _toggle() => setState(
    () => _revealed = _revealed == widget.current ? null : widget.current,
  );

  @override
  Widget build(BuildContext context) => SensitiveRevealScope(
    current: widget.current,
    revealed: _revealed,
    toggle: _toggle,
    child: widget.child,
  );
}

class SensitiveRevealScope extends InheritedWidget {
  const SensitiveRevealScope({
    super.key,
    required this.current,
    required this.revealed,
    required this.toggle,
    required super.child,
  });

  final String? current;

  /// 目前被撳開的那一張（null＝都沒撳）。
  final String? revealed;
  final VoidCallback toggle;

  bool isRevealed(String file) => revealed != null && revealed == file;

  @override
  bool updateShouldNotify(SensitiveRevealScope old) =>
      old.current != current || old.revealed != revealed;
}

/// 眼睛鈕的共同判斷：在面板範圍內、這張現在是模糊的（總開關開、安全模式開、有標記）才畫。
class _RevealToggle extends ConsumerWidget {
  const _RevealToggle({required this.builder});

  /// [shown]＝這張已被撳開（icon 睜開眼睛）。
  final Widget Function(
    BuildContext context,
    bool shown,
    String label,
    VoidCallback onTap,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = SensitiveReveal.maybeOf(context);
    final file = scope?.current;
    if (scope == null || file == null) return const SizedBox.shrink();
    if (ref.watch(sensitiveDisplayProvider(file)) != SensitiveDisplay.blur) {
      return const SizedBox.shrink();
    }
    final shown = scope.isRevealed(file);
    final l = context.l10n;
    return builder(
      context,
      shown,
      shown ? l.sensitiveReblur : l.sensitiveRevealThis,
      scope.toggle,
    );
  }
}

/// 沒有標題列的面板：封面左上角的 40px 圓形鈕（放在 [Stack] 裡，離邊 10）。
/// `rgba(30,27,24,.72)` 底、米白 icon，和右下「參考檢視」同一款。
class SensitiveRevealOverlayButton extends StatelessWidget {
  const SensitiveRevealOverlayButton({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
    left: 10,
    top: 10,
    child: _RevealToggle(
      builder: (context, shown, label, onTap) => Semantics(
        button: true,
        toggled: shown,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            key: const ValueKey('sensitiveRevealButton'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xB81E1B18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgIcon(
                shown ? AppIcons.eye : AppIcons.eyeSlash,
                size: 19,
                strokeWidth: 1.9,
                color: const Color(0xFFF5F0E8),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 有標題列的詳情面板：標題列「編輯」左邊的 44×44 方鈕（同編輯、刪除的 [WideIconButton]）。
/// 沒出現時不佔位；出現時右邊留 [gap]。
class SensitiveRevealTitleButton extends StatelessWidget {
  const SensitiveRevealTitleButton({super.key, this.gap = 0});

  final double gap;

  @override
  Widget build(BuildContext context) => _RevealToggle(
    builder: (context, shown, label, onTap) => Padding(
      padding: EdgeInsets.only(right: gap),
      child: Tooltip(
        message: label,
        child: WideIconButton(
          key: const ValueKey('sensitiveRevealButton'),
          svg: shown ? AppIcons.eye : AppIcons.eyeSlash,
          label: label,
          onTap: onTap,
        ),
      ),
    ),
  );
}
