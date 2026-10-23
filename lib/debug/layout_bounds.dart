// Debug-only layout inspection switches (never active when kDebugMode is false).
//
// Android's "Show layout bounds" does not work for Flutter, so this wraps the
// rendering library's own debug paint flags:
//  * [DebugPaintOption.sizes]    -> debugPaintSizeEnabled (boxes, padding, arrows)
//  * [DebugPaintOption.baselines] -> debugPaintBaselinesEnabled
//  * [DebugPaintOption.pointers] -> debugPaintPointersEnabled
// The choice is stored in SharedPreferences (debug builds only) so it survives
// a hot restart; [LayoutBoundsDebug.restore] is called from main() before runApp.
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DebugPaintOption {
  sizes('debug_paint_sizes'),
  baselines('debug_paint_baselines'),
  pointers('debug_paint_pointers');

  const DebugPaintOption(this.prefsKey);
  final String prefsKey;
}

class LayoutBoundsDebug {
  LayoutBoundsDebug._();

  /// Current state of the three switches (listen to rebuild the switch UI).
  static final ValueNotifier<Map<DebugPaintOption, bool>> state =
      ValueNotifier<Map<DebugPaintOption, bool>>({
        for (final o in DebugPaintOption.values) o: false,
      });

  static bool isOn(DebugPaintOption o) => state.value[o] ?? false;

  /// Reads the saved choice and applies it. Call before runApp. No-op in release.
  static Future<void> restore([SharedPreferences? prefs]) async {
    if (!kDebugMode) return;
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      for (final o in DebugPaintOption.values) {
        _apply(o, p.getBool(o.prefsKey) ?? false);
      }
    } catch (_) {
      // Persistence is a convenience only.
    }
    _publish();
  }

  /// Flips one switch: sets the rendering flag, repaints the whole tree now,
  /// then persists it.
  static Future<void> set(
    DebugPaintOption o,
    bool on, {
    SharedPreferences? prefs,
  }) async {
    if (!kDebugMode) return;
    _apply(o, on);
    _publish();
    repaintAll();
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      await p.setBool(o.prefsKey, on);
    } catch (_) {}
  }

  static void _apply(DebugPaintOption o, bool on) {
    switch (o) {
      case DebugPaintOption.sizes:
        debugPaintSizeEnabled = on;
      case DebugPaintOption.baselines:
        debugPaintBaselinesEnabled = on;
      case DebugPaintOption.pointers:
        debugPaintPointersEnabled = on;
    }
  }

  static void _publish() {
    state.value = {
      DebugPaintOption.sizes: debugPaintSizeEnabled,
      DebugPaintOption.baselines: debugPaintBaselinesEnabled,
      DebugPaintOption.pointers: debugPaintPointersEnabled,
    };
  }

  /// Marks every render object dirty for paint (same approach as the
  /// framework's own debug-paint service extensions).
  static void repaintAll() {
    if (!kDebugMode) return;
    void visit(RenderObject r) {
      r.markNeedsPaint();
      r.visitChildren(visit);
    }

    for (final view in RendererBinding.instance.renderViews) {
      visit(view);
    }
    WidgetsBinding.instance.rootElement?.markNeedsBuild();
  }
}
