// Gboard「文本編輯」面板的「選擇」模式（及面板上的 Shift＋方向）在 Android 上是用
// InputConnection.sendKeyEvent 送 DPAD 按鍵，並在 metaState 帶 META_SHIFT_ON，
// 而不是另外送 Shift 鍵。Flutter 的新 HardwareKeyboard／KeyEvent 路徑不採用這個
// metaState，框架會以為沒按 Shift，只移動游標、不擴選。
//
// 舊通道 `flutter/keyevent`（JSON，含 metaState）仍會送給 Dart，所以：
//  1. [ImeShiftMessenger] 只「旁聽」該通道的入站訊息（原封不動轉交原 handler），
//     把方向鍵 keydown 是否帶 shift 記進 [ImeShiftState]；
//  2. [ImeShiftKeyBridge] 在 App 外層收到方向鍵時，若框架不認為 Shift 已按下、
//     但 [ImeShiftState] 說這次帶 shift，就改叫出「擴選」的 Intent。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android `KeyEvent` 的 keyCode／metaState 常數。
class AndroidKeys {
  static const int dpadUp = 19;
  static const int dpadDown = 20;
  static const int dpadLeft = 21;
  static const int dpadRight = 22;
  static const int moveHome = 122;
  static const int moveEnd = 123;
  static const int metaShiftOn = 0x1;
  static const int metaShiftLeftOn = 0x40;
  static const int metaShiftRightOn = 0x80;
  static const int metaShiftMask =
      metaShiftOn | metaShiftLeftOn | metaShiftRightOn;

  static final Map<int, LogicalKeyboardKey> navigation = {
    dpadUp: LogicalKeyboardKey.arrowUp,
    dpadDown: LogicalKeyboardKey.arrowDown,
    dpadLeft: LogicalKeyboardKey.arrowLeft,
    dpadRight: LogicalKeyboardKey.arrowRight,
    moveHome: LogicalKeyboardKey.home,
    moveEnd: LogicalKeyboardKey.end,
  };
}

/// 舊通道 `flutter/keyevent` 訊息中我們關心的欄位。
class LegacyKeyInfo {
  const LegacyKeyInfo({
    required this.isDown,
    required this.keyCode,
    required this.metaState,
  });
  final bool isDown;
  final int keyCode;
  final int metaState;

  bool get hasShift => (metaState & AndroidKeys.metaShiftMask) != 0;

  /// 解析失敗回傳 null（呼叫端一律當作沒有 shift）。
  static LegacyKeyInfo? tryParse(ByteData? data) {
    if (data == null) return null;
    try {
      final msg = const JSONMessageCodec().decodeMessage(data);
      if (msg is! Map) return null;
      final type = msg['type'];
      final keyCode = msg['keyCode'];
      final meta = msg['metaState'];
      if (type is! String || keyCode is! int) return null;
      return LegacyKeyInfo(
        isDown: type == 'keydown',
        keyCode: keyCode,
        metaState: meta is int ? meta : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 最近一次「導覽鍵（方向／Home／End）keydown」是否帶 shift。
class ImeShiftState {
  ImeShiftState();
  static final ImeShiftState instance = ImeShiftState();

  /// 記錄超過這段時間就視為過期（避免舊資料影響之後的其他按鍵事件）。
  static const Duration maxAge = Duration(milliseconds: 1000);

  int? _keyCode;
  bool _shift = false;
  DateTime? _at;

  void record(LegacyKeyInfo? info, {DateTime? now}) {
    if (info == null || !info.isDown) return;
    if (!AndroidKeys.navigation.containsKey(info.keyCode)) {
      clear(); // 其他按鍵的 keydown：清掉待處理的狀態。
      return;
    }
    _keyCode = info.keyCode;
    _shift = info.hasShift;
    _at = now ?? DateTime.now();
  }

  /// 取走並清除：[key] 這次按鍵是否帶 shift。沒有紀錄、不同鍵、過期都回傳 false。
  bool consumeShiftFor(LogicalKeyboardKey key, {DateTime? now}) {
    final code = _keyCode;
    final at = _at;
    final shift = _shift;
    clear();
    if (code == null || at == null || !shift) return false;
    if (AndroidKeys.navigation[code] != key) return false;
    return (now ?? DateTime.now()).difference(at) <= maxAge;
  }

  void clear() {
    _keyCode = null;
    _shift = false;
    _at = null;
  }
}

/// 只旁聽 `flutter/keyevent` 入站訊息的 BinaryMessenger 包裝；其他通道與所有
/// 出站訊息完全直通。訊息本身不改動、不吞掉。
class ImeShiftMessenger extends BinaryMessenger {
  ImeShiftMessenger(this._inner, {ImeShiftState? state})
    : _state = state ?? ImeShiftState.instance;
  final BinaryMessenger _inner;
  final ImeShiftState _state;

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    // ignore: deprecated_member_use
    return _inner.handlePlatformMessage(channel, data, callback);
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) =>
      _inner.send(channel, message);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null || channel != 'flutter/keyevent') {
      _inner.setMessageHandler(channel, handler);
      return;
    }
    _inner.setMessageHandler(channel, (ByteData? data) {
      try {
        _state.record(LegacyKeyInfo.tryParse(data));
      } catch (_) {}
      return handler(data);
    });
  }
}

/// 正式版使用的 binding：只多包一層 [ImeShiftMessenger]。
class ImeShiftBinding extends WidgetsFlutterBinding {
  static WidgetsBinding ensureInitialized() {
    ImeShiftBinding();
    return WidgetsBinding.instance;
  }

  @override
  BinaryMessenger createBinaryMessenger() =>
      ImeShiftMessenger(super.createBinaryMessenger());
}

/// 放在 MaterialApp.builder 外層：Android 上，IME 帶 shift 的方向鍵改成擴選。
class ImeShiftKeyBridge extends StatelessWidget {
  const ImeShiftKeyBridge({super.key, required this.child, this.state});
  final Widget child;

  /// 測試可注入；預設用全域 [ImeShiftState.instance]。
  final ImeShiftState? state;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (!AndroidKeys.navigation.containsValue(key)) {
      return KeyEventResult.ignored;
    }
    final s = state ?? ImeShiftState.instance;
    // 框架已認為 Shift 按著（實體鍵盤）：維持預設行為，避免雙重擴選。
    if (HardwareKeyboard.instance.isShiftPressed) {
      s.clear();
      return KeyEventResult.ignored;
    }
    if (!s.consumeShiftFor(key)) return KeyEventResult.ignored;
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null || !ctx.mounted) return KeyEventResult.ignored;
    if (ctx.findAncestorStateOfType<EditableTextState>() == null) {
      return KeyEventResult.ignored;
    }
    final intent = _intentFor(key);
    // Action 的回傳值常為 null（例如更新選取範圍），不能用它判斷有沒有處理。
    final action = Actions.maybeFind<Intent>(ctx, intent: intent);
    if (action == null || !action.isEnabled(intent)) {
      return KeyEventResult.ignored;
    }
    Actions.invoke<Intent>(ctx, intent);
    return KeyEventResult.handled;
  }

  static Intent _intentFor(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      return ExtendSelectionByCharacterIntent(
        forward: k == LogicalKeyboardKey.arrowRight,
        collapseSelection: false,
      );
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      return ExtendSelectionVerticallyToAdjacentLineIntent(
        forward: k == LogicalKeyboardKey.arrowDown,
        collapseSelection: false,
      );
    }
    return ExtendSelectionToLineBreakIntent(
      forward: k == LogicalKeyboardKey.end,
      collapseSelection: false,
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _onKey,
    child: child,
  );
}

/// 診斷面板用：把 legacy keyevent 解析結果寫成一行文字。
String describeLegacyKey(ByteData? data) {
  final info = LegacyKeyInfo.tryParse(data);
  if (info == null) return 'unparsed';
  return 'meta=0x${info.metaState.toRadixString(16)} key=${info.keyCode} '
      '${info.isDown ? "down" : "up"} shift=${info.hasShift}';
}
