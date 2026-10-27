import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/input/ime_shift.dart';

ByteData legacyMessage(int keyCode, int metaState, {String type = 'keydown'}) {
  return const JSONMessageCodec().encodeMessage(<String, dynamic>{
    'keymap': 'android',
    'type': type,
    'keyCode': keyCode,
    'metaState': metaState,
    'flags': 0,
    'plainCodePoint': 0,
    'codePoint': 0,
    'scanCode': 0,
    'source': 0,
    'vendorId': 0,
    'productId': 0,
    'deviceId': 0,
    'repeatCount': 0,
  })!;
}

/// 模擬舊通道訊息經過 [ImeShiftMessenger] 後的效果。
void feed(int keyCode, int metaState) => ImeShiftState.instance.record(
  LegacyKeyInfo.tryParse(legacyMessage(keyCode, metaState)),
);

class _FakeInner extends BinaryMessenger {
  final handlers = <String, MessageHandler?>{};
  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) async {}
  @override
  Future<ByteData?>? send(String channel, ByteData? message) => null;
  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      handlers[channel] = handler;
}

void main() {
  tearDown(() {
    ImeShiftState.instance.clear();
    debugDefaultTargetPlatformOverride = null;
  });

  group('ImeShiftMessenger', () {
    test('keyevent 入站訊息被旁聽但原封不動交給原 handler；其他通道直通', () async {
      final inner = _FakeInner();
      final m = ImeShiftMessenger(inner);
      ByteData? seen;
      m.setMessageHandler('flutter/keyevent', (d) async {
        seen = d;
        return null;
      });
      Future<ByteData?> other(ByteData? d) async => null;
      m.setMessageHandler('flutter/textinput', other);
      expect(inner.handlers['flutter/textinput'], same(other));

      final msg = legacyMessage(22, 0x41);
      await inner.handlers['flutter/keyevent']!(msg);
      expect(seen, same(msg));
      expect(
        ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowRight),
        isTrue,
      );
    });

    test('解析失敗視為沒有 shift 且不丟例外', () async {
      final inner = _FakeInner();
      ImeShiftMessenger(inner)
          .setMessageHandler('flutter/keyevent', (d) async => null);
      final bad = ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
      await inner.handlers['flutter/keyevent']!(bad);
      expect(
        ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowRight),
        isFalse,
      );
    });
  });

  group('ImeShiftState', () {
    test('三種 shift 位元都算；不同鍵與過期不算；取走後清除', () {
      for (final meta in [0x1, 0x40, 0x80, 0x41]) {
        feed(21, meta);
        expect(
          ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowLeft),
          isTrue,
          reason: 'meta=$meta',
        );
      }
      feed(21, 0x1);
      expect(
        ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowRight),
        isFalse,
      );
      ImeShiftState.instance.record(
        LegacyKeyInfo.tryParse(legacyMessage(21, 0x1)),
        now: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(
        ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowLeft),
        isFalse,
      );
      feed(21, 0);
      expect(
        ImeShiftState.instance.consumeShiftFor(LogicalKeyboardKey.arrowLeft),
        isFalse,
      );
    });
  });

  group('ImeShiftKeyBridge', () {
    Future<TextEditingController> pump(
      WidgetTester t, {
      String text = 'hello',
      int? maxLines = 1,
      int offset = 0,
    }) async {
      final c = TextEditingController(text: text);
      c.selection = TextSelection.collapsed(offset: offset);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => ImeShiftKeyBridge(child: child!),
          home: Scaffold(
            body: TextField(controller: c, maxLines: maxLines, autofocus: true),
          ),
        ),
      );
      await t.pump();
      c.selection = TextSelection.collapsed(offset: offset);
      return c;
    }

    testWidgets('帶 shift 的右鍵由 0 擴到 1，再按擴到 2', (t) async {
      final c = await pump(t);
      feed(22, 0x41);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(c.selection.baseOffset, 0);
      expect(c.selection.extentOffset, 1);
      feed(22, 0x41);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(c.selection.baseOffset, 0);
      expect(c.selection.extentOffset, 2);
    });

    testWidgets('帶 shift 的左鍵向左擴選', (t) async {
      final c = await pump(t, offset: 3);
      feed(21, 0x1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pump();
      expect(c.selection.baseOffset, 3);
      expect(c.selection.extentOffset, 2);
    });

    testWidgets('不帶 shift 只移動游標（折疊）', (t) async {
      final c = await pump(t);
      feed(22, 0);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(c.selection, const TextSelection.collapsed(offset: 1));
    });

    testWidgets('沒有任何 legacy 訊息時維持框架預設', (t) async {
      final c = await pump(t);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(c.selection, const TextSelection.collapsed(offset: 1));
    });

    testWidgets('實體 Shift 按住時不雙重擴選', (t) async {
      final c = await pump(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      feed(22, 0x41);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      expect(c.selection.baseOffset, 0);
      expect(c.selection.extentOffset, 1);
    });

    testWidgets('多行文字：帶 shift 的下鍵擴選到下一行', (t) async {
      final c = await pump(t, text: 'abc\ndef', maxLines: null, offset: 1);
      feed(20, 0x1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(c.selection.baseOffset, 1);
      expect(c.selection.extentOffset, 5);
    });

    testWidgets('Home／End 帶 shift 擴到行首／行尾', (t) async {
      final c = await pump(t, offset: 2);
      feed(123, 0x1);
      await t.sendKeyEvent(LogicalKeyboardKey.end);
      await t.pump();
      expect(c.selection.baseOffset, 2);
      expect(c.selection.extentOffset, 5);
    });

    testWidgets('iOS 不啟用', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = await pump(t);
      feed(22, 0x41);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight, platform: 'ios');
      await t.pump();
      expect(c.selection.isCollapsed, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
