import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../sync/sync_controller.dart';
import 'ring_painter.dart';
import 'sync_colors.dart';

/// 最多查幾張待下載圖片屬於哪個坑（逐張查資料庫，不要為了小圖示查上百次）。
/// 清單依處理順序排，前面的先下載，所以只看最前面這幾張就足以標出「正在下載的坑」。
const pitSyncLookahead = 24;

/// 還沒下載完的圖片檔名（最前面 [pitSyncLookahead] 張）。用 [listEquals] 比較，
/// 進度逐位元組變動時不會讓依賴它的 provider 重算。
final _pendingDownloadFilesProvider = Provider<List<String>>((ref) {
  final files = ref.watch(
    syncControllerProvider.select(
      (s) => _Files(
        [
          for (final t in s.transfers)
            if (t.isDownload && !t.isDone) t.file,
        ].take(pitSyncLookahead).toList(),
      ),
    ),
  );
  return files.list;
});

class _Files {
  const _Files(this.list);
  final List<String> list;
  @override
  bool operator ==(Object other) =>
      other is _Files && listEquals(list, other.list);
  @override
  int get hashCode => Object.hashAll(list);
}

/// 本次同步正在（或排隊）下載圖片的坑 id（iPad sidebar 的小轉圈、坑卡片「同步中…」，MainSyncing 稿）。
final syncingPitIdsProvider = FutureProvider<Set<String>>((ref) async {
  final files = ref.watch(_pendingDownloadFilesProvider);
  final ids = <String>{};
  for (final f in files) {
    final loc = await ref.watch(imageLocationProvider(f).future);
    if (loc != null) ids.add(loc.pitId);
  }
  return ids;
});

/// 這個坑現在有沒有圖片在下載。
final pitSyncingProvider = Provider.family<bool, String>(
  (ref, pitId) =>
      ref.watch(syncingPitIdsProvider).value?.contains(pitId) ?? false,
);

/// 16px 小轉圈（sidebar 現坑列，取代成圖數）：底圈＋一段轉動的弧。
class PitSyncSpinner extends StatefulWidget {
  const PitSyncSpinner({super.key, this.size = 16});
  final double size;

  @override
  State<PitSyncSpinner> createState() => _PitSyncSpinnerState();
}

class _PitSyncSpinnerState extends State<PitSyncSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final k = widget.size / 16;
    return Semantics(
      label: context.l10n.pitsSyncing,
      child: ExcludeSemantics(
        child: RotationTransition(
          turns: _spin,
          child: CustomPaint(
            size: Size.square(widget.size),
            // 稿：r=6、線寬 2、弧 10／37.7。
            painter: RingPainter(
              radius: 6 * k,
              strokeWidth: 2 * k,
              track: colors.track,
              color: colors.progress,
              fraction: 10 / 37.7,
            ),
          ),
        ),
      ),
    );
  }
}
