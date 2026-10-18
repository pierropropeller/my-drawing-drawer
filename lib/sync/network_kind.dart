import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 目前連線種類（iPad 同步進度 popover 右上角的「Wi-Fi」，SyncPopover 稿）。
enum NetworkKind { wifi, cellular, ethernet, other, none }

NetworkKind networkKindOf(List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.wifi)) return NetworkKind.wifi;
  if (results.contains(ConnectivityResult.ethernet)) {
    return NetworkKind.ethernet;
  }
  if (results.contains(ConnectivityResult.mobile)) return NetworkKind.cellular;
  if (results.isEmpty || results.contains(ConnectivityResult.none)) {
    return NetworkKind.none;
  }
  return NetworkKind.other;
}

/// 連線種類；讀不到（外掛不可用）時當成 [NetworkKind.other]，介面就不顯示。
final networkKindProvider = StreamProvider<NetworkKind>((ref) async* {
  final c = Connectivity();
  try {
    yield networkKindOf(await c.checkConnectivity());
    await for (final r in c.onConnectivityChanged) {
      yield networkKindOf(r);
    }
  } catch (_) {
    yield NetworkKind.other;
  }
});
