// Debug-only input diagnostics (never referenced when kDebugMode is false).
//
// Shows the last events seen on the Dart side so we can tell whether a
// keyboard "text editing" panel (arrows / select / cut / copy / paste)
// reaches Flutter at all:
//  * KeyEvents from HardwareKeyboard
//  * selection / text-length changes of the focused EditableText controller
//  * platform messages on flutter/textinput (both directions) and
//    flutter/keyevent, via a wrapping BinaryMessenger installed by
//    [DebugDiagBinding].
// All diagnostic text is English and intentionally not in ARB.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Global ring buffer of diagnostic lines.
class InputDiagLog extends ChangeNotifier {
  InputDiagLog._();
  static final InputDiagLog instance = InputDiagLog._();

  static const int maxLines = 12;
  final List<String> lines = <String>[];
  bool _pending = false;

  void add(String kind, String text) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts =
        '${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    lines.add('$ts $kind $text');
    while (lines.length > maxLines) {
      lines.removeAt(0);
    }
    _notifySafely();
  }

  void clear() {
    lines.clear();
    _notifySafely();
  }

  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_pending) return;
      _pending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}

String _clip(String s, [int n = 110]) =>
    s.length <= n ? s : '${s.substring(0, n)}...';

/// Binding that wraps the default BinaryMessenger so inbound platform
/// messages on text-input channels can be logged without replacing the
/// framework's own handlers. Use only when [kDebugMode].
class DebugDiagBinding extends WidgetsFlutterBinding {
  /// Creates the binding if none exists yet (call first thing in main()).
  static WidgetsBinding ensureInitialized() {
    DebugDiagBinding();
    return WidgetsBinding.instance;
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      _LoggingMessenger(super.createBinaryMessenger());
}

class _LoggingMessenger extends BinaryMessenger {
  _LoggingMessenger(this._inner);
  final BinaryMessenger _inner;

  static const _json = JSONMethodCodec();

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    // Inbound traffic normally bypasses this (engine -> channelBuffers); it is
    // logged in [setMessageHandler] instead.
    // ignore: deprecated_member_use
    return _inner.handlePlatformMessage(channel, data, callback);
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    try {
      if (channel == 'flutter/textinput' && message != null) {
        final call = _json.decodeMethodCall(message);
        if (call.method != 'TextInput.setCaretRect' &&
            call.method != 'TextInput.setEditableSizeAndTransform' &&
            call.method != 'TextInput.setStyle') {
          InputDiagLog.instance.add(
            'OUT',
            '${call.method} ${_clip(jsonEncode(call.arguments), 90)}',
          );
        }
      }
    } catch (_) {}
    return _inner.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null ||
        (channel != 'flutter/textinput' && channel != 'flutter/keyevent')) {
      _inner.setMessageHandler(channel, handler);
      return;
    }
    _inner.setMessageHandler(channel, (ByteData? data) {
      try {
        if (channel == 'flutter/textinput' && data != null) {
          final call = _json.decodeMethodCall(data);
          InputDiagLog.instance.add(
            'IN ',
            '${call.method} ${_clip(jsonEncode(call.arguments))}',
          );
        } else {
          InputDiagLog.instance.add('IN ', '$channel ${data?.lengthInBytes}B');
        }
      } catch (e) {
        InputDiagLog.instance.add('IN ', 'decode error on $channel: $e');
      }
      return handler(data);
    });
  }
}

/// Wraps the app and draws the event panel at the top right.
class InputDiagnosticsOverlay extends StatefulWidget {
  const InputDiagnosticsOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<InputDiagnosticsOverlay> createState() =>
      _InputDiagnosticsOverlayState();
}

class _InputDiagnosticsOverlayState extends State<InputDiagnosticsOverlay> {
  final _log = InputDiagLog.instance;
  bool _visible = true;
  TextEditingController? _ctl;
  TextSelection? _lastSel;
  int _lastLen = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    FocusManager.instance.removeListener(_onFocus);
    _ctl?.removeListener(_onCtl);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    final type = switch (e) {
      KeyDownEvent() => 'down',
      KeyUpEvent() => 'up',
      KeyRepeatEvent() => 'repeat',
      _ => '?',
    };
    final key = e.logicalKey.keyLabel.isEmpty
        ? e.logicalKey.debugName
        : e.logicalKey.keyLabel;
    _log.add(
      'KEY',
      '$type $key phys=${e.physicalKey.debugName}'
          ' char=${e.character == null ? "null" : jsonEncode(e.character)}',
    );
    return false; // never consume
  }

  void _onFocus() {
    TextEditingController? next;
    try {
      final ctx = FocusManager.instance.primaryFocus?.context;
      next = ctx
          ?.findAncestorStateOfType<EditableTextState>()
          ?.widget
          .controller;
    } catch (_) {}
    if (identical(next, _ctl)) return;
    _ctl?.removeListener(_onCtl);
    _ctl = next;
    if (next == null) {
      _log.add('FOC', 'no text field focused');
      return;
    }
    next.addListener(_onCtl);
    _lastSel = next.selection;
    _lastLen = next.text.length;
    _log.add('FOC', 'text field len=$_lastLen sel=${_sel(next.selection)}');
  }

  String _sel(TextSelection s) => '${s.baseOffset}..${s.extentOffset}';

  void _onCtl() {
    final c = _ctl;
    if (c == null) return;
    if (c.selection != _lastSel) {
      _log.add('SEL', _sel(c.selection));
      _lastSel = c.selection;
    }
    if (c.text.length != _lastLen) {
      _log.add('TXT', 'len $_lastLen->${c.text.length}');
      _lastLen = c.text.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        if (_visible)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            right: 4,
            width: 300,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  IgnorePointer(
                    child: ListenableBuilder(
                      listenable: _log,
                      builder: (_, _) => Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 22, 4),
                        color: const Color(0xCC000000),
                        child: Text(
                          _log.lines.isEmpty
                              ? 'input diag (debug) - waiting for events'
                              : _log.lines.join('\n'),
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 9,
                            height: 1.2,
                            fontFamily: 'monospace',
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      key: const ValueKey('inputDiagClose'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _visible = false),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: Text(
                            'x',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
