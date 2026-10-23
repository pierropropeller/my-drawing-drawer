# Debug tools

These exist only in Flutter debug builds (`kDebugMode`), including the
`drawer-debug` APKs published by CI. Release builds neither show nor run them.

## Layout bounds (Android "Show layout bounds" does not work for Flutter)

1. Install a debug build (or `flutter run`).
2. Open 我的 -> 關於 App and scroll to the bottom: **開發者選項**.
3. Switches (each takes effect immediately, no restart):
   - 顯示版面邊界: `debugPaintSizeEnabled` - widget boxes, padding, alignment arrows.
   - 顯示文字基線: `debugPaintBaselinesEnabled` - text baselines.
   - 顯示點擊區域: `debugPaintPointersEnabled` - flashes hit-tested areas on touch.
4. The choice is saved in SharedPreferences (debug builds only) and restored in
   `main()` before `runApp`, so it stays on after a hot restart / app restart.

Code: `lib/debug/layout_bounds.dart`, `lib/debug/dev_options_section.dart`
(strings in `lib/l10n/fragments/devopts.arb`). Input-event overlay:
`lib/debug/input_diagnostics.dart`.

## Measuring exact sizes: Flutter DevTools Inspector

For real pixel measurements, use the DevTools Widget Inspector instead:

1. Connect the phone by USB (USB debugging on).
2. `flutter run` (or, for an app already running a debug build, `flutter attach`).
3. Open DevTools (link printed by the command) -> Inspector. Select a widget on
   the device to see its size, constraints, padding and the "Layout Explorer".
