import 'package:flutter/foundation.dart';

import '../debug/input_diagnostics.dart';

/// 同步的診斷日誌：只在 debug 版輸出（debugPrint＋診斷面板的 [InputDiagLog]），release 完全不輸出。
/// 只記步驟與錯誤，**不得**帶入 token、標頭或檔案內容。
void syncLog(String message) {
  if (!kDebugMode) return;
  debugPrint('[sync] $message');
  try {
    InputDiagLog.instance.add('sync', message);
  } catch (_) {
    // 還沒有 Flutter binding（純 Dart 測試）時略過診斷面板。
  }
}
