import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sensitive_queries.dart';
import '../../state/providers.dart';
import 'sensitive_dialogs.dart';

/// 多選底部的「敏感」動作（D-104，`OfficialSelectR18`）共用邏輯：
/// 選中的有未標記的 → 全部標上；全部已標記 → 全部取消。
///
/// 標上時，若選中的圖有坑封面，先確認（`OfficialSelectCover`）：同意才標記，並把封面改成坑內
/// 最新一張沒標記的圖（沒有就清掉）。回傳 true＝有做事（呼叫端可離開多選）；
/// 使用者取消確認、或選中的沒有任何圖＝false。
Future<bool> applySensitiveToSelection(
  BuildContext context,
  WidgetRef ref,
  SensitiveSource source,
  Iterable<String> ids,
) async {
  final db = ref.read(databaseProvider);
  final next = await db.nextSensitiveValue(source, ids);
  if (next == null) return false;
  if (next) {
    final covers = await db.coverCountAmong(source, ids);
    if (covers > 0) {
      if (!context.mounted || !await confirmSensitiveCover(context, covers)) {
        return false;
      }
    }
  }
  await db.setSensitive(source, ids, next);
  return true;
}
