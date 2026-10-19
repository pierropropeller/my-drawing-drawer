import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/heif_size.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/media.dart';
import 'package:huakeng/media/media_import.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/ui/media_source/drop_target_service.dart';
import 'package:huakeng/ui/media_source/media_source_services.dart';
import 'package:image_picker/image_picker.dart';

/// iOS 三條匯入路徑（分享擴充、貼上、分屏拖放）的 Dart 側：
/// 原生碼（Swift）無法在這裡測，這裡驗證 Dart 對原生回傳形狀的處理，以及 HEIC 原檔不被動到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('huakeng_importpaths');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // ---- 合成 HEIC（只有 box 結構，沒有真的像素）。

  Uint8List box(String type, List<int> payload) {
    final size = 8 + payload.length;
    return Uint8List.fromList([
      (size >> 24) & 255,
      (size >> 16) & 255,
      (size >> 8) & 255,
      size & 255,
      ...type.codeUnits,
      ...payload,
    ]);
  }

  List<int> u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];

  Uint8List ispe(int w, int h) => box('ispe', [0, 0, 0, 0, ...u32(w), ...u32(h)]);

  Uint8List fakeHeic({int rotation = 0, int w = 4032, int h = 3024}) {
    final ipco = box('ipco', [
      ...ispe(320, 240), // 縮圖
      ...ispe(w, h), // 主圖
      if (rotation != 0) ...box('irot', [rotation]),
    ]);
    final iprp = box('iprp', ipco);
    final meta = box('meta', [0, 0, 0, 0, ...iprp]);
    final ftyp = box('ftyp', [
      ...'heic'.codeUnits,
      ...u32(0),
      ...'mif1'.codeUnits,
      ...'heic'.codeUnits,
    ]);
    return Uint8List.fromList([...ftyp, ...meta, ...List.filled(64, 7)]);
  }

  group('HEIC 辨識與尺寸備援', () {
    test('sniffImageExtension 認得 HEIC，其餘行為不變', () {
      expect(sniffImageExtension(fakeHeic()), 'heic');
      expect(sniffImageExtension([0xFF, 0xD8, 0xFF, 0xE0]), 'jpg');
      expect(sniffImageExtension('GIF89a'.codeUnits), 'gif');
      expect(sniffImageExtension([0x89, 0x50, 0x4E, 0x47]), 'png');
      expect(sniffImageExtension(List.filled(16, 0)), 'png');
    });

    test('mediaKindFromBytes：HEIC 是圖片不是影片', () {
      expect(mediaKindFromBytes(fakeHeic()), MediaKind.image);
    });

    test('heifDimensions：取最大的 ispe，irot 奇數時寬高對調', () {
      expect(heifDimensions(fakeHeic()), (width: 4032, height: 3024));
      expect(heifDimensions(fakeHeic(rotation: 1)), (width: 3024, height: 4032));
      expect(heifDimensions(fakeHeic(rotation: 2)), (width: 4032, height: 3024));
      expect(heifDimensions(fakeHeic(rotation: 3)), (width: 3024, height: 4032));
    });

    test('heifDimensions：不是 HEIC／被截斷都回 null，不丟例外', () {
      expect(heifDimensions(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), isNull);
      expect(heifDimensions(Uint8List(0)), isNull);
      final full = fakeHeic();
      for (var n = 0; n < full.length; n += 3) {
        heifDimensions(Uint8List.sublistView(full, 0, n));
      }
    });
  });

  group('匯入 HEIC：原檔位元組不變', () {
    Future<(ImageStore, NewImageLike)> importHeic(String name) async {
      final store = ImageStore(Directory('${tmp.path}/images'));
      final src = File('${tmp.path}/$name')..writeAsBytesSync(fakeHeic());
      final out = await importPickedMedia(store, XFile(src.path));
      return (store, NewImageLike(out.file, out.width, out.height, out.kind));
    }

    test('分享進來的 .heic：副檔名保留、位元組一致、尺寸走備援', () async {
      final (store, out) = await importHeic('share_1_0.heic');
      expect(out.file, endsWith('.heic'));
      expect(out.kind, MediaKind.image);
      expect(store.fileOf(out.file).readAsBytesSync(), fakeHeic());
      // 測試環境的解碼器讀不了合成檔，所以尺寸一定是備援讀出來的。
      expect((out.width, out.height), (4032, 3024));
    });

    test('副檔名被改成 .jpg 的 HEIC 仍當圖片、位元組一致', () async {
      final (store, out) = await importHeic('weird.jpg');
      expect(out.kind, MediaKind.image);
      expect(store.fileOf(out.file).readAsBytesSync(), fakeHeic());
    });
  });

  group('分享：HEIC 路徑原樣交給 Dart', () {
    const channel = MethodChannel('io.molly.drawer/share');
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('getInitialShare 回傳 .heic 路徑不被過濾或改名', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => <Object?>[
        '/var/mobile/Library/Caches/share_import/share_1_0.heic',
        '/var/mobile/Library/Caches/share_import/share_1_1.jpg',
      ]);
      final r = await const ShareChannel().getInitialShare();
      expect(r.first, endsWith('share_1_0.heic'));
      expect(r, hasLength(2));
    });
  });

  group('貼上（iOS 原生通道）', () {
    const native = MethodChannel('io.molly.drawer/clipboard');
    const plugin = MethodChannel('pasteboard');
    var pluginCalls = 0;

    setUp(() => pluginCalls = 0);
    tearDown(() {
      messenger.setMockMethodCallHandler(native, null);
      messenger.setMockMethodCallHandler(plugin, null);
    });

    void mockPlugin(Uint8List? png) =>
        messenger.setMockMethodCallHandler(plugin, (call) async {
          pluginCalls++;
          return png;
        });

    test('iOS：probe 不讀剪貼簿（unknown）', () async {
      mockPlugin(Uint8List.fromList([1, 2, 3]));
      const source = PasteboardClipboardSource(isIOS: true);
      expect(await source.probe(), ClipboardProbe.unknown);
      expect(pluginCalls, 0);
    });

    test('iOS：原生回傳原始 HEIC 檔案，原樣當成貼上的檔案', () async {
      final heic = fakeHeic();
      String? dirArg;
      messenger.setMockMethodCallHandler(native, (call) async {
        expect(call.method, 'readImage');
        dirArg = (call.arguments as Map)['dir'] as String;
        final f = File('$dirArg/paste_1.heic')..writeAsBytesSync(heic);
        return {'path': f.path, 'ext': 'heic'};
      });
      mockPlugin(Uint8List.fromList([9, 9, 9]));
      const source = PasteboardClipboardSource(isIOS: true);
      final file = await source.read(tmp);
      expect(dirArg, tmp.path);
      expect(file!.path, endsWith('.heic'));
      expect(File(file.path).readAsBytesSync(), heic);
      expect(pluginCalls, 0, reason: '不可再用 pasteboard 套件讀第二次（會重編 PNG 且再跳貼上提示）');
    });

    test('iOS：原生回 null＝剪貼簿沒有圖；不退回 pasteboard', () async {
      messenger.setMockMethodCallHandler(native, (call) async => null);
      mockPlugin(Uint8List.fromList([9, 9, 9]));
      expect(await const PasteboardClipboardSource(isIOS: true).read(tmp), isNull);
      expect(pluginCalls, 0);
    });

    test('iOS：原生通道不存在或出錯時退回 pasteboard（至少貼得上）', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
      mockPlugin(png);
      // 沒有 native handler → MissingPluginException
      var file = await const PasteboardClipboardSource(isIOS: true).read(tmp);
      expect(file!.path, endsWith('.png'));
      expect(File(file.path).readAsBytesSync(), png);

      messenger.setMockMethodCallHandler(native, (call) async {
        throw PlatformException(code: 'boom');
      });
      file = await const PasteboardClipboardSource(isIOS: true).read(tmp);
      expect(File(file!.path).readAsBytesSync(), png);
      expect(pluginCalls, 2);
    });

    test('非 iOS：不碰原生通道，行為同以前（探測時讀、貼上時用快取）', () async {
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(native, (call) async {
        nativeCalls++;
        return null;
      });
      final gif = Uint8List.fromList('GIF89a....'.codeUnits);
      mockPlugin(gif);
      const source = PasteboardClipboardSource(isIOS: false);
      expect(await source.probe(), ClipboardProbe.image);
      expect(source.previewBytes, gif);
      final file = await source.read(tmp);
      expect(file!.path, endsWith('.gif'));
      expect(nativeCalls, 0);
      expect(pluginCalls, 1, reason: '貼上時用探測時留下的快取，不再讀第二次');
    });
  });

  group('ChannelDropTargetService（拖放）', () {
    const name = 'test/media_drop_ios';
    const channel = MethodChannel(name);
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    Future<void> fromNative(String method, Object? args) =>
        messenger.handlePlatformMessage(
          name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
          (_) {},
        );

    test('start 的結果只問一次（快取），原生回 false＝不支援', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return false;
      });
      final s = ChannelDropTargetService(channel: channel);
      expect(await s.start(), isFalse);
      expect(await s.start(), isFalse);
      expect(calls, 1);
    });

    test('放開：HEIC 項目載入後路徑保留 .heic；缺 id 的項目被忽略；座標是邏輯座標', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') return true;
        if (call.method == 'load') {
          final id = (call.arguments as Map)['id'];
          return id == 'bad' ? null : '/c/drop_import/$id.heic';
        }
        return null;
      });
      final s = ChannelDropTargetService(channel: channel);
      expect(await s.start(), isTrue);
      final events = <DropEvent>[];
      s.events.listen(events.add);

      await fromNative('enter', {'count': 3, 'x': 100.5, 'y': 200});
      await fromNative('drop', {
        'x': 101,
        'y': 201.25,
        'items': [
          {'id': 'a', 'name': 'IMG_0001'},
          {'name': 'no-id'},
          'garbage',
          {'id': 'bad'},
        ],
      });
      await Future<void>.delayed(Duration.zero);

      expect((events[0] as DropEnter).position, const Offset(100.5, 200));
      final drop = events[1] as DropPerform;
      expect(drop.position, const Offset(101, 201.25));
      expect(drop.items.map((i) => i.id), ['a', 'bad']);
      expect((await drop.items[0].load())!.path, '/c/drop_import/a.heic');
      expect(await drop.items[1].load(), isNull);
    });

    test('load 失敗（原生丟錯）→ 例外交給呼叫端（DropZone 當成單項失敗）', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') return true;
        throw PlatformException(code: 'load_failed');
      });
      final s = ChannelDropTargetService(channel: channel);
      await s.start();
      final events = <DropEvent>[];
      s.events.listen(events.add);
      await fromNative('drop', {
        'x': 1,
        'y': 1,
        'items': [
          {'id': 'x'},
        ],
      });
      await Future<void>.delayed(Duration.zero);
      final drop = events.single as DropPerform;
      expect(drop.items.single.load(), throwsA(isA<PlatformException>()));
    });

    test('放開前離開：只有 leave；沒有 items 的 drop 是空清單', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      final s = ChannelDropTargetService(channel: channel);
      await s.start();
      final events = <DropEvent>[];
      s.events.listen(events.add);
      await fromNative('enter', {'count': 1, 'x': 0, 'y': 0});
      await fromNative('leave', null);
      await fromNative('drop', {'x': 5, 'y': 5});
      await Future<void>.delayed(Duration.zero);
      expect(events[1], isA<DropLeave>());
      expect((events[2] as DropPerform).items, isEmpty);
    });
  });
}

/// 測試用：importPickedMedia 結果的精簡版（避免依賴 NewImage 的其他欄位）。
class NewImageLike {
  NewImageLike(this.file, this.width, this.height, this.kind);
  final String file;
  final int width;
  final int height;
  final MediaKind kind;
}
