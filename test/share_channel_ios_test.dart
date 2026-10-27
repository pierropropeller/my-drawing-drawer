import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/share/share_inbox.dart';

/// iOS 的分享（Share Extension → 剪貼簿 → AppDelegate）和 Android 共用同一套 Dart 介面：
/// MethodChannel `io.molly.drawer/share` 的 `getInitialShare`（Dart → 原生）與 `onShare`（原生 → Dart）。
/// 這裡用假的原生端驗證 iOS AppDelegate 會送出的各種形狀都能被 ShareChannel／ShareInbox 正確處理。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('io.molly.drawer/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// 模擬原生端呼叫 Dart（AppDelegate 的 `invokeMethod("onShare", arguments:)`）。
  Future<void> nativeCall(String method, Object? args) {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, args)),
      (_) => done.complete(),
    );
    return done.future;
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('ShareChannel.getInitialShare', () {
    test('原生回傳路徑陣列（冷啟動帶著一批分享）', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInitialShare');
        return <Object?>[
          '/var/mobile/Containers/Data/Application/X/Library/Caches/share_import/share_1_0.jpg',
          '/var/mobile/Containers/Data/Application/X/Library/Caches/share_import/share_1_1.png',
        ];
      });
      final r = await const ShareChannel().getInitialShare();
      expect(r, hasLength(2));
      expect(r.first, endsWith('share_1_0.jpg'));
    });

    test('原生回傳 nil（沒有待處理的分享）→ 空陣列', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await const ShareChannel().getInitialShare(), isEmpty);
    });

    test('原生端沒實作（例如測試環境、桌面）→ 空陣列', () async {
      expect(await const ShareChannel().getInitialShare(), isEmpty);
    });

    test('原生丟 PlatformException → 空陣列，不拋出', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      expect(await const ShareChannel().getInitialShare(), isEmpty);
    });
  });

  group('ShareChannel.setOnShare', () {
    test('onShare 把路徑交給 callback；空陣列與其他方法名忽略', () async {
      final got = <List<String>>[];
      const ShareChannel().setOnShare(got.add);
      await nativeCall('onShare', <Object?>['/a/1.jpg', '/a/2.jpg']);
      await nativeCall('onShare', <Object?>[]);
      await nativeCall('somethingElse', <Object?>['/x.jpg']);
      expect(got, [
        ['/a/1.jpg', '/a/2.jpg'],
      ]);
    });

    test('傳 null 取消監聽', () async {
      final got = <List<String>>[];
      const ShareChannel().setOnShare(got.add);
      const ShareChannel().setOnShare(null);
      // 沒有 handler 時 handlePlatformMessage 會直接回覆，不會呼叫 callback。
      await nativeCall('onShare', <Object?>['/a/1.jpg']);
      expect(got, isEmpty);
    });
  });

  group('ShareInbox（iOS 事件順序）', () {
    ProviderContainer make() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    Future<void> pump() =>
        Future<void>.delayed(const Duration(milliseconds: 10));

    test('冷啟動：getInitialShare 的那一批排進佇列，依序取出', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <Object?>['/c/1.jpg'];
      });
      final c = make();
      c.read(shareInboxProvider);
      await pump();
      expect(c.read(shareInboxProvider), [
        ['/c/1.jpg'],
      ]);
      expect(c.read(shareInboxProvider.notifier).take(), ['/c/1.jpg']);
      expect(c.read(shareInboxProvider), isEmpty);
      expect(c.read(shareInboxProvider.notifier).take(), isNull);
    });

    test('熱啟動：App 回到前景時原生推 onShare，一次一批、保持順序', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final c = make();
      c.read(shareInboxProvider);
      await pump();
      expect(c.read(shareInboxProvider), isEmpty);

      await nativeCall('onShare', <Object?>['/h/1.jpg']);
      await nativeCall('onShare', <Object?>['/h/2.jpg', '/h/3.jpg']);
      expect(c.read(shareInboxProvider), [
        ['/h/1.jpg'],
        ['/h/2.jpg', '/h/3.jpg'],
      ]);
      expect(c.read(shareInboxProvider.notifier).take(), ['/h/1.jpg']);
      expect(c.read(shareInboxProvider.notifier).take(), [
        '/h/2.jpg',
        '/h/3.jpg',
      ]);
    });

    test('冷啟動有一批、之後又推一批（getInitialShare 之後的 onShare）', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <Object?>['/c/1.jpg'];
      });
      final c = make();
      c.read(shareInboxProvider);
      await pump();
      await nativeCall('onShare', <Object?>['/h/1.jpg']);
      expect(c.read(shareInboxProvider), [
        ['/c/1.jpg'],
        ['/h/1.jpg'],
      ]);
    });
  });
}
