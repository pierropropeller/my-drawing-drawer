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
  // 只有「明確回報斷線」才算 none；空清單、vpn（iOS 開 VPN 時常見）、other、bluetooth 等
  // 都視為有網絡（連線種類不明）。
  if (results.isNotEmpty &&
      results.every((r) => r == ConnectivityResult.none)) {
    return NetworkKind.none;
  }
  return NetworkKind.other;
}

/// 是否「明確斷線」。同步與離線橫條一律只認這個：沒有明確斷線就視為可嘗試，
/// 以實際請求的成敗為準（VPN／未知類型不能被當成離線）。
bool isExplicitlyOffline(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.every((r) => r == ConnectivityResult.none);

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
