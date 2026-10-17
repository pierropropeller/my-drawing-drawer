import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// 從其他 App 拖放圖片／影片進來（MediaDrop，iPadOS Split View／Slide Over、Android 多視窗）。
///
/// 只收「接收端」。不做由畫匣拖出到其他 App（設計稿沒畫）。
///
/// ## 為什麼是自己的抽象，不是 `super_drag_and_drop`
/// `super_drag_and_drop`／`super_clipboard`（同一個原生核心 `super_native_extensions`）在 Flutter 3.47.6
/// 的專案裡無法安全加入：
/// - 目前版本（0.9.x）要 `device_info_plus <12` → `win32 <6`，和專案已用的 `share_plus ^13`（`win32 ^6`）互斥，
///   `pub get` 解不出來；
/// - 能解出來的只有 0.1.x（2023 年版），和現在的 Flutter／AGP 9／Kotlin 2.4 不相容，
///   而且它需要在 Android／iOS 建置時編譯 Rust（cargokit），CI 的 APK 建置會多一個無法在這台機器驗證的風險。
///
/// 所以只做 Dart 側：[DropTargetService] 提供一串拖放事件，[DropZone] 負責落點判斷、提示條與載入狀態，
/// 全部可用 [FakeDropTargetService] 測試。**原生側還沒做**，預設的 [ChannelDropTargetService]
/// 在沒有原生實作時 `start()` 回傳 false，整個功能安靜地不啟用（不顯示拖曳提示文字，也不會出錯）。
///
/// ## 原生側待做（契約）
/// MethodChannel 名稱 [ChannelDropTargetService.channelName]。座標一律是 Flutter 視圖內的邏輯座標
/// （iOS：UIKit point；Android：px ÷ density）。
/// - Dart → 原生 `start`：註冊整個 Flutter view 為落點（iOS `UIDropInteraction`，接受 `public.image`／`public.movie`；
///   Android `View.setOnDragListener`＋`DropHelper`／`requestDragAndDropPermissions`），回傳 `true`。
/// - 原生 → Dart `enter {count, x, y}`、`move {x, y}`、`leave {}`、
///   `drop {x, y, items: [{id, name}]}`（`id` 由原生產生，之後用來載入）。
/// - Dart → 原生 `load {id}`：把該項目轉成 App 可讀的暫存檔（iOS 用
///   `NSItemProvider.loadFileRepresentation`，HEIC 照原樣；iCloud 照片會先下載，可能很久），回傳路徑字串，失敗回傳 null 或丟錯。
/// - Dart → 原生 `cancel {id}`：放棄載入（目前 Dart 側不會呼叫，保留）。
abstract class DropTargetService {
  /// 啟動（可重複呼叫，結果相同）。回傳這個平台是否支援拖放接收。
  Future<bool> start();

  /// 拖放事件串流（廣播）。
  Stream<DropEvent> get events;
}

/// 拖放事件。座標是 Flutter 視圖內的邏輯座標（全域，和 `RenderBox.localToGlobal` 同一個座標系）。
sealed class DropEvent {
  const DropEvent();
}

/// 拖曳進入視窗，[count] 為拖曳中的項目數。
class DropEnter extends DropEvent {
  const DropEnter(this.count, this.position);
  final int count;
  final Offset position;
}

class DropMove extends DropEvent {
  const DropMove(this.position);
  final Offset position;
}

/// 拖曳離開視窗或被取消。
class DropLeave extends DropEvent {
  const DropLeave();
}

/// 放開。
class DropPerform extends DropEvent {
  const DropPerform(this.items, this.position);
  final List<DropItem> items;
  final Offset position;
}

/// 放開的一個項目。[load] 會把它變成本機檔案；照片可能是 HEIC、iCloud 還沒下載，所以是非同步、可能很久。
/// 載入失敗回傳 null（或丟例外，視同失敗）。
class DropItem {
  const DropItem({required this.id, required this.load, this.name});
  final String id;
  final String? name;
  final Future<XFile?> Function() load;
}

/// MethodChannel 版（原生側待做，見 [DropTargetService] 說明）。
class ChannelDropTargetService implements DropTargetService {
  ChannelDropTargetService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'huakeng/media_drop';

  final MethodChannel _channel;
  final StreamController<DropEvent> _events = StreamController.broadcast();
  Future<bool>? _started;

  @override
  Stream<DropEvent> get events => _events.stream;

  @override
  Future<bool> start() => _started ??= () async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } catch (_) {
      // MissingPluginException（原生還沒實作）或平台不支援。
      return false;
    }
  }();

  Future<Object?> _onCall(MethodCall call) async {
    final a = call.arguments is Map ? call.arguments as Map : const {};
    Offset pos() => Offset(
      (a['x'] as num?)?.toDouble() ?? 0,
      (a['y'] as num?)?.toDouble() ?? 0,
    );
    switch (call.method) {
      case 'enter':
        _events.add(DropEnter((a['count'] as num?)?.toInt() ?? 0, pos()));
      case 'move':
        _events.add(DropMove(pos()));
      case 'leave':
        _events.add(const DropLeave());
      case 'drop':
        final items = <DropItem>[
          for (final raw in (a['items'] as List? ?? const []))
            if (raw is Map && raw['id'] is String)
              DropItem(
                id: raw['id'] as String,
                name: raw['name'] as String?,
                load: () async {
                  final path = await _channel.invokeMethod<String>('load', {
                    'id': raw['id'],
                  });
                  return path == null ? null : XFile(path);
                },
              ),
        ];
        _events.add(DropPerform(items, pos()));
    }
    return null;
  }
}

/// 測試用：手動送事件。
class FakeDropTargetService implements DropTargetService {
  FakeDropTargetService({this.supported = true});

  final bool supported;
  final StreamController<DropEvent> _events = StreamController.broadcast(
    sync: true,
  );
  int startCalls = 0;

  @override
  Future<bool> start() async {
    startCalls++;
    return supported;
  }

  @override
  Stream<DropEvent> get events => _events.stream;

  void enter(int count, Offset position) =>
      _events.add(DropEnter(count, position));
  void move(Offset position) => _events.add(DropMove(position));
  void leave() => _events.add(const DropLeave());
  void drop(List<DropItem> items, Offset position) =>
      _events.add(DropPerform(items, position));
}

final dropTargetServiceProvider = Provider<DropTargetService>(
  (ref) => ChannelDropTargetService(),
);

/// 這個平台有沒有拖放接收（決定要不要顯示「可拖曳至此」的提示文字）。
final dropSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(dropTargetServiceProvider).start(),
);
