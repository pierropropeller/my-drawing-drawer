import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/sensitive_queries.dart';
import 'providers.dart' show databaseProvider, pitProvider;
import 'settings.dart';

/// 敏感內容（D-104）縮圖該怎麼畫。
enum SensitiveDisplay {
  /// 正常顯示，什麼都不加（沒標記、總開關關、坑開關關）。
  none,

  /// 安全模式開：模糊＋中間 34px 圓底「眼睛斜線」。
  blur,

  /// 安全模式關：正常顯示，左上角 22px 圓形敏感小標。
  badge,

  /// 總開關開著、安全模式開，但「哪些圖是敏感的」還沒查完（剛啟動）：先模糊（不畫圖示），
  /// 免得敏感圖在啟動瞬間露出來；查完自動換成 [none] 或 [blur]。
  pending,
}

/// 目前「有效敏感」的圖檔名集合：圖片標記為敏感，且所屬的坑有開敏感內容（素材庫不屬於任何坑，只看標記）。
/// 不含總開關——總開關是裝置設定，由 [sensitiveDisplayProvider] 處理。
final sensitiveFilesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).watchSensitiveFiles(),
);

/// 某個檔名的縮圖該怎麼畫（所有列表類縮圖共用）。
///
/// - 總開關關：一律 [SensitiveDisplay.none]（已標記的圖照常顯示，不模糊、沒有小標）；
/// - 檔名不在 [sensitiveFilesProvider]（沒標記或坑開關關）：[SensitiveDisplay.none]；
/// - 否則依安全模式：開＝[SensitiveDisplay.blur]、關＝[SensitiveDisplay.badge]。
final sensitiveDisplayProvider = Provider.autoDispose
    .family<SensitiveDisplay, String>((ref, file) {
      final master = ref.watch(
        settingsProvider.select((s) => s.sensitiveEnabled),
      );
      if (!master) return SensitiveDisplay.none;
      final safe = ref.watch(settingsProvider.select((s) => s.safeMode));
      final files = ref.watch(sensitiveFilesProvider);
      if (!files.hasValue) {
        return safe ? SensitiveDisplay.pending : SensitiveDisplay.none;
      }
      if (!files.requireValue.contains(file)) return SensitiveDisplay.none;
      return safe ? SensitiveDisplay.blur : SensitiveDisplay.badge;
    });

/// 這個坑現在有沒有敏感內容的標記入口：總開關開著，而且坑有開（[pitId] 為 null＝素材庫，只看總開關）。
/// 表單的「全部標為敏感」列、多選的「敏感」動作、小圖的標記小標都用它決定要不要出現。
final sensitiveMarkingProvider = Provider.autoDispose.family<bool, String?>((
  ref,
  pitId,
) {
  final master = ref.watch(settingsProvider.select((s) => s.sensitiveEnabled));
  if (!master) return false;
  if (pitId == null) return true;
  final Pit? pit = ref.watch(pitProvider(pitId)).value;
  return pit?.sensitiveEnabled ?? false;
});
