import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../../sync/google_auth.dart';

/// 連結／更換 Google 帳號失敗時給使用者看的文字（D-117 ②）：不直接顯示系統例外文字，
/// 改成寫好的中文提示。使用者自己取消＝null（不用提示）。原始錯誤只寫到 debug log。
String? friendlyAuthError(BuildContext context, Object e) {
  debugPrint('auth error: $e');
  if (e is AuthFailure && e.cancelled) return null;
  final l = context.l10n;
  final text = '$e';
  if (e is SocketException ||
      e is HttpException ||
      text.contains('SocketException') ||
      text.contains('network_error') ||
      text.contains('Failed host lookup')) {
    return l.authOfflineFriendly;
  }
  return l.authLinkFailedFriendly;
}
