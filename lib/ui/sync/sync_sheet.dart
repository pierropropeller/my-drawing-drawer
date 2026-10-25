import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart' show MaterialCategory;
import '../../data/media.dart';
import '../../data/sync_row_info.dart';
import '../../l10n/l10n.dart';
import '../../state/providers.dart';
import '../../state/sync_row_info.dart';
import '../../sync/network_kind.dart';
import '../../sync/sync_controller.dart';
import '../../theme/tokens.dart';
import '../album/album_image.dart';
import '../common/app_icons.dart';
import '../common/svg_icon.dart';
import '../common/themed_sheet.dart';
import '../material/material_icons.dart';
import '../oshi/oshi_icons.dart';
import '../pits/pit_form.dart' show fieldBorderColor;
import '../pits/pits_icons.dart';
import 'sync_colors.dart';
import 'sync_icons.dart';
import 'sync_time_text.dart';
import '../common/sensitive_gate.dart';

/// 打開「同步進度」bottom sheet（SyncSheet，D-052）。
///
/// 傳完**不自動關**：原地變成完成狀態（D-100，SyncSheetDone），按「完成」、下拉或點外面才關。
///
/// 設計稿的 sheet 蓋住底部導覽列，所以用最上層 Navigator（全域 sheet）。
///
/// 從頭像上的琥珀點／紅點打開（D-113 ③）時沒有傳輸也不會關，直接顯示「同步完成・有失敗」
/// （SyncSheetPartial）或「Drive 已滿」狀態；[onManageStorage] 是「管理儲存空間」的動作（前往備份頁）。
Future<void> showSyncSheet(
  BuildContext context, {
  VoidCallback? onManageStorage,
}) {
  return showThemedSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => SyncSheet(onManageStorage: onManageStorage),
  );
}

/// 最多列出幾張（其餘寫「還有 N 張等待中」）。
const syncSheetMaxRows = 4;

/// 同時最多顯示幾張「傳輸中」（各自顯示百分比）。
const syncSheetMaxActive = 3;

/// 剛傳完那一次同步的結果（完成／部分失敗狀態顯示用；新變更進來切回同步中就丟掉）。
///
/// [total]＝這次處理完的張數（成功＋失敗）；[failed] 非空＝部分失敗狀態（D-109，SyncSheetPartial）。
class SyncDoneSummary {
  const SyncDoneSummary({
    required this.total,
    required this.uploaded,
    required this.downloaded,
    required this.completedAt,
    this.failed = const [],
  });
  final int total;

  /// 成功的上傳／下載張數。
  final int uploaded;
  final int downloaded;
  final DateTime completedAt;

  /// 重試後仍失敗的傳輸（留在佇列，下次同步再試）。
  final List<SyncTransfer> failed;

  bool get isPartial => failed.isNotEmpty;
  int get succeeded => total - failed.length;
}

/// sheet／popover 對同步狀態變化的反應。
enum SyncSheetAction { keep, show, clear, close }

class SyncSheetTransition {
  const SyncSheetTransition(this.action, [this.summary]);
  final SyncSheetAction action;
  final SyncDoneSummary? summary;
}

SyncDoneSummary? _summaryOf(SyncState prev, SyncState next) {
  final at = next.lastSyncAt ?? DateTime.now();
  final r = next.lastResult;
  final settled = r == null
      ? const <SyncTransfer>[]
      : [
          for (final t in r.transfers)
            if (t.isSettled) t,
        ];
  if (settled.isNotEmpty) {
    return SyncDoneSummary(
      total: settled.length,
      uploaded: settled.where((t) => t.isUpload && t.isDone).length,
      downloaded: settled.where((t) => t.isDownload && t.isDone).length,
      completedAt: at,
      failed: [
        for (final t in settled)
          if (t.isFailed) t,
      ],
    );
  }
  // 沒有引擎結果（只有進度快照）：把剛才的清單都當成傳完。
  if (prev.transferTotal == 0) return null;
  return SyncDoneSummary(
    total: prev.transferTotal,
    uploaded: prev.uploadCount,
    downloaded: prev.downloadCount,
    completedAt: at,
  );
}

/// 同步 sheet（手機）與頭像 popover（iPad）共用的狀態轉換（D-100／D-109）：
/// - 傳完（phase 回到 idle）→ 原地變成完成（全部成功）或部分失敗狀態，不自動關；
/// - 完成／部分失敗狀態下又有新的傳輸 → 切回同步中；
/// - 完成／部分失敗狀態下重試（或新一次同步）結束時沒有傳輸 → 依結果更新；
/// - 其他情況（失敗、取消連結…）關閉。
SyncSheetTransition syncSheetTransition(
  SyncState prev,
  SyncState next,
  SyncDoneSummary? current,
) {
  if (prev.isTransferring && !next.isTransferring) {
    if (next.phase == SyncPhase.idle) {
      final s = _summaryOf(prev, next);
      if (s != null) return SyncSheetTransition(SyncSheetAction.show, s);
    }
    return const SyncSheetTransition(SyncSheetAction.close);
  }
  if (!prev.isTransferring && next.isTransferring && current != null) {
    return const SyncSheetTransition(SyncSheetAction.clear);
  }
  if (current != null && prev.isSyncing && next.phase == SyncPhase.idle) {
    return SyncSheetTransition(
      SyncSheetAction.show,
      _summaryOf(prev, next) ??
          SyncDoneSummary(
            total: current.total,
            uploaded: current.uploaded,
            downloaded: current.downloaded,
            completedAt: next.lastSyncAt ?? DateTime.now(),
          ),
    );
  }
  return const SyncSheetTransition(SyncSheetAction.keep);
}

class SyncSheet extends ConsumerStatefulWidget {
  const SyncSheet({super.key, this.onManageStorage});

  /// 「管理儲存空間」按鈕的動作（Drive 已滿時）；null＝不處理（只關閉）。
  final VoidCallback? onManageStorage;

  @override
  ConsumerState<SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<SyncSheet>
    with SyncPanelMixin<SyncSheet> {
  @override
  void initState() {
    super.initState();
    initPanel();
  }

  @override
  Widget build(BuildContext context) {
    listenPanel();
    return SyncSheetBody(
      done: done,
      fullStatic: fullStatic,
      onDone: closePanel,
      onManageStorage: () => manageStorage(widget.onManageStorage),
    );
  }
}

/// 從頭像的琥珀點／紅點打開時，狀態來自上一次同步的結果（沒有進行中的傳輸）：
/// - 紅點（Drive 已滿）→ [fullStatic]：「Drive 已滿」、等空間的上傳行、「管理儲存空間」；
/// - 琥珀點（有失敗）→ [done] 是部分失敗摘要（SyncSheetPartial，有「重試」）。
/// 這種 sheet／popover 一直開著，直到使用者關掉；不會因為「現在沒有在傳」而立刻關閉。
mixin SyncPanelMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  SyncDoneSummary? done;
  bool fullStatic = false;
  bool _closing = false;

  void closePanel() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  /// 「管理儲存空間」：先關掉 sheet／popover，再做 [go]。
  void manageStorage(VoidCallback? go) {
    closePanel();
    go?.call();
  }

  void initPanel() {
    final s = ref.read(syncControllerProvider);
    if (!s.isSyncing) {
      if (s.quotaFull) {
        fullStatic = true;
      } else if (s.hasFailures) {
        done = _summaryOf(s, s);
      }
    }
    // 打開的瞬間沒有在傳、也不是從小點打開的（剛好傳完或根本沒東西傳）：直接關。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          done == null &&
          !fullStatic &&
          !ref.read(syncControllerProvider).isTransferring) {
        closePanel();
      }
    });
  }

  void listenPanel() {
    ref.listen(syncControllerProvider, (prev, next) {
      if (prev == null) return;
      if (fullStatic) {
        // Drive 還是滿的：面板留著（一輪同步結束也一樣）；有空間了才回到一般流程。
        if (next.quotaFull || next.isSyncing) return;
        setState(() => fullStatic = false);
        // 剛好把排隊的傳完（空間回來了）或還有失敗 → 顯示結果；其他情況關閉。
        final sum = prev.isSyncing ? _summaryOf(prev, next) : null;
        if (sum != null || next.hasFailures) {
          setState(() => done = sum ?? _summaryOf(next, next));
        } else {
          closePanel();
        }
        return;
      }
      final tr = syncSheetTransition(prev, next, done);
      switch (tr.action) {
        case SyncSheetAction.show:
          setState(() => done = tr.summary);
        case SyncSheetAction.clear:
          setState(() => done = null);
        case SyncSheetAction.close:
          closePanel();
        case SyncSheetAction.keep:
          break;
      }
    });
  }
}

/// bottom sheet 的內容（把手、標頭、清單）；關閉邏輯由外層負責。
///
/// [done] 非 null＝同步結束狀態：全部成功＝完成（D-100）：標題勾＋「同步完成」、全滿綠色進度條、
/// 張數與完成時間、底部「完成」按鈕（[onDone]）；有失敗＝部分失敗（D-109）：琥珀「!」＋
/// 「同步完成，N 張失敗」、失敗清單、底部「重試」「完成」。都沒有清單。
class SyncSheetBody extends StatelessWidget {
  const SyncSheetBody({
    super.key,
    this.done,
    this.onDone,
    this.fullStatic = false,
    this.onManageStorage,
  });

  final SyncDoneSummary? done;
  final VoidCallback? onDone;

  /// 從紅點打開、沒有傳輸中：顯示「Drive 已滿」（見 [SyncPanelContent]）。
  final bool fullStatic;
  final VoidCallback? onManageStorage;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final done = this.done;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: done != null
          ? (done.isPartial
                ? l.syncuiPartialTitle(done.failed.length)
                : l.syncuiDoneTitle)
          : fullStatic
          ? l.backupFullTitle
          : l.syncuiSheetLabel,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SyncPanelContent(
                done: done,
                fullStatic: fullStatic,
                onDone: onDone,
                onManageStorage: onManageStorage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// sheet 與 iPad popover 共用的內容（依狀態選一種）：
/// 1. [done] 非 null：完成／部分失敗（[SyncFinalPanel]）；
/// 2. [fullStatic] 且沒有傳輸中：Drive 已滿的靜態狀態（[SyncFullPanel]，標題「Drive 已滿」）；
/// 3. 同步中且剩下的全是等空間的上傳：SyncPopoverFull 版面（標題照舊「同步中」）＋「管理儲存空間」；
/// 4. 其他：一般的同步進度。
class SyncPanelContent extends ConsumerWidget {
  const SyncPanelContent({
    super.key,
    this.done,
    this.fullStatic = false,
    this.onDone,
    this.onManageStorage,
    this.onOpenSettings,
    this.popover = false,
  });

  final SyncDoneSummary? done;
  final bool fullStatic;
  final VoidCallback? onDone;
  final VoidCallback? onManageStorage;

  /// 一般進度底下的「同步設定」連結（popover 才有）。
  final VoidCallback? onOpenSettings;
  final bool popover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = this.done;
    if (done != null) {
      return SyncFinalPanel(summary: done, onDone: onDone, popover: popover);
    }
    final transferring = ref.watch(
      syncControllerProvider.select((s) => s.isTransferring),
    );
    final waiting = ref.watch(
      syncControllerProvider.select(syncIsWaitingForSpace),
    );
    if (fullStatic && !transferring) {
      return SyncFullPanel(
        popover: popover,
        onManageStorage: onManageStorage,
        titled: true,
      );
    }
    if (waiting) {
      return SyncFullPanel(popover: popover, onManageStorage: onManageStorage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SyncProgressHeader(popover: popover),
        SyncProgressRows(onOpenSettings: popover ? onOpenSettings : null),
      ],
    );
  }
}

/// Drive 已滿的版面（D-103／D-113 ③）：等空間的上傳行（灰字「等待空間」）＋底部「管理儲存空間」。
///
/// [titled]＝從紅點打開、沒有在傳：標題「Drive 已滿」（紅字）＋右邊「N 張未上傳」；
/// 否則（同步中、剩下的都在等空間）沿用 SyncPopoverFull 的標頭（標題「同步中」＋進度＋進度條）。
class SyncFullPanel extends ConsumerWidget {
  const SyncFullPanel({
    super.key,
    this.popover = false,
    this.onManageStorage,
    this.titled = false,
  });

  final bool popover;
  final VoidCallback? onManageStorage;
  final bool titled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final pending = ref.watch(
      syncControllerProvider.select((s) => syncWaitingRows(s).length),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titled)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l.backupFullTitle,
                    key: const Key('sync-full-title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: popover ? 19 : 18,
                      fontWeight: FontWeight.w700,
                      color: colors.fullDot,
                    ),
                  ),
                ),
                if (pending > 0)
                  Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 13.5, color: t.text2),
                      children: [
                        TextSpan(
                          text: l.backupFullCount(pending),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: l.backupFullUnuploaded),
                      ],
                    ),
                  ),
              ],
            ),
          )
        else
          SyncProgressHeader(popover: popover, showCounts: false),
        const SyncFullRows(),
        Padding(
          padding: EdgeInsets.only(top: popover ? 16 : 18),
          child: SizedBox(
            height: popover ? 46 : 48,
            child: FilledButton(
              key: const Key('sync-manage-storage-button'),
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onManageStorage,
              child: Text(
                l.syncuiManageStorage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 結束狀態的內容與底部按鈕（sheet 與 iPad popover 共用）：全部成功＝[SyncDoneContent]＋「完成」；
/// 有失敗＝[SyncPartialContent]＋「重試」（外框，只重跑失敗的）＋「完成」（主色）。
class SyncFinalPanel extends ConsumerWidget {
  const SyncFinalPanel({
    super.key,
    required this.summary,
    required this.onDone,
    this.popover = false,
  });
  final SyncDoneSummary summary;
  final VoidCallback? onDone;
  final bool popover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final syncing = ref.watch(
      syncControllerProvider.select((s) => s.isSyncing),
    );
    final done = SizedBox(
      height: popover ? 46 : 48,
      child: FilledButton(
        key: const Key('sync-done-button'),
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onDone,
        child: Text(
          l.commonDone,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isPartial)
          SyncPartialContent(summary: summary, popover: popover)
        else
          SyncDoneContent(summary: summary, popover: popover),
        Padding(
          // iPad popover（SyncPopoverDone／Partial）：按鈕高 46，上方留 18／16。
          padding: EdgeInsets.only(
            top: popover
                ? (summary.isPartial ? 16 : 18)
                : (summary.isPartial ? 18 : 22),
          ),
          child: summary.isPartial
              ? Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: popover ? 46 : 48,
                        child: OutlinedButton(
                          key: const Key('sync-retry-button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.ink,
                            side: BorderSide(
                              color: fieldBorderColor(context),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          // 重試＝再同步一次；成功的早就同步完了，剩下要做的就只有失敗的那幾張。
                          onPressed: syncing
                              ? null
                              : () => unawaited(
                                  ref
                                      .read(syncControllerProvider.notifier)
                                      .syncNowByUser(),
                                ),
                          child: Text(
                            l.syncuiRetry,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: done),
                  ],
                )
              : done,
        ),
      ],
    );
  }
}

/// 完成狀態的標頭（SyncSheetDone）：綠勾圈＋「同步完成」、右邊「N / N」綠字、全滿綠色進度條、
/// 「上傳 N 張　下載 N 張」＋右邊完成時間（相對時間，每分鐘更新，D-109 ②）。
class SyncDoneContent extends StatelessWidget {
  const SyncDoneContent({
    super.key,
    required this.summary,
    this.popover = false,
  });
  final SyncDoneSummary summary;
  final bool popover;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.doneFill,
                    shape: BoxShape.circle,
                  ),
                  child: SvgIcon(
                    SyncIcons.check,
                    size: 15,
                    strokeWidth: 3,
                    color: colors.doneCheck,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.syncuiDoneTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: popover ? 19 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              l.syncuiProgress(summary.total, summary.total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.doneText,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            key: const Key('sync-done-bar'),
            height: 6,
            decoration: BoxDecoration(
              color: colors.doneFill,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        _CountsRow(summary: summary, color: t.text2),
      ],
    );
  }
}

/// 「上傳 N 張　下載 N 張」＋右邊完成時間。
class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.summary, required this.color});
  final SyncDoneSummary summary;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = TextStyle(fontSize: 13, color: color);
    return Row(
      children: [
        Text(l.syncuiUploadCount(summary.uploaded), style: style),
        const SizedBox(width: 16),
        Text(l.syncuiDownloadCount(summary.downloaded), style: style),
        const Spacer(),
        SyncRelativeTimeText(at: summary.completedAt, style: style),
      ],
    );
  }
}

/// 最多列出幾張失敗的（其餘寫「還有 N 張失敗」）。
const syncPartialMaxRows = 4;

/// 部分失敗狀態（SyncSheetPartial，D-109）：琥珀「!」圓＋「同步完成，N 張失敗」、右邊「成功 / 總數」
/// 琥珀字、進度條（綠＝成功，尾端琥珀＝失敗）、張數與時間、失敗的每一張（縮圖、上傳／下載標籤、
/// 位置、右邊琥珀「失敗」；最多 [syncPartialMaxRows] 張，其餘「還有 N 張失敗」）。
class SyncPartialContent extends ConsumerWidget {
  const SyncPartialContent({
    super.key,
    required this.summary,
    this.popover = false,
  });
  final SyncDoneSummary summary;
  final bool popover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final shown = summary.failed.take(syncPartialMaxRows).toList();
    final more = summary.failed.length - shown.length;
    final files = [for (final x in shown) x.file];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ref.read(syncRowInfoProvider.notifier).ensure(files);
    });
    final ok = summary.total == 0 ? 0.0 : summary.succeeded / summary.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const Key('sync-partial-mark'),
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.failedFill,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l.syncuiPartialTitle(summary.failed.length),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: popover ? 19 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l.syncuiProgress(summary.succeeded, summary.total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.failedText,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              key: const Key('sync-partial-bar'),
              height: 6,
              color: colors.failedFill,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ok,
                child: Container(
                  key: const Key('sync-partial-bar-ok'),
                  color: colors.doneFill,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _CountsRow(summary: summary, color: t.text2),
        ),
        for (var i = 0; i < shown.length; i++)
          _FailedRow(
            x: shown[i],
            last: i == shown.length - 1 && more == 0,
            popover: popover,
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l.syncuiMoreFailed(more),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.text3),
            ),
          ),
      ],
    );
  }
}

/// 失敗的一行：縮圖、上傳／下載標籤、位置、右邊琥珀「失敗」（沒有進度條）。
class _FailedRow extends ConsumerWidget {
  const _FailedRow({required this.x, required this.last, this.popover = false});
  final SyncTransfer x;
  final bool last;

  /// iPad popover：標籤沒有箭頭 icon（SyncPopoverPartial）。
  final bool popover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final info = ref.watch(syncRowInfoProvider.select((m) => m[x.file]));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SyncRowThumb(file: x.file, info: info),
          const SizedBox(width: 12),
          SyncDirectionTag(upload: x.isUpload, showIcon: !popover),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              syncLocationText(l, info) ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l.syncuiFailed,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.failedRowText,
            ),
          ),
        ],
      ),
    );
  }
}

/// 標題、已完成 / 總數、總進度條、上傳與下載張數。
///
/// [popover]＝iPad 頭像 popover（SyncPopover 稿）：標題 19、進度條上下留白較多，
/// 張數列右側多一個連線種類（Wi-Fi）。
class SyncProgressHeader extends ConsumerWidget {
  const SyncProgressHeader({
    super.key,
    this.popover = false,
    this.showCounts = true,
  });
  final bool popover;

  /// false＝不畫「上傳／下載張數」那一列（SyncPopoverFull：Drive 已滿時的標頭只有標題、進度、進度條）。
  final bool showCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    // 只取數字，傳輸清單裡逐位元組的變動不會讓標頭重建。
    final (done, total, up, down) = ref.watch(
      syncControllerProvider.select(
        (s) => (
          s.transferSettled,
          s.transferTotal,
          s.uploadCount,
          s.downloadCount,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.pitsSyncing,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: popover ? 19 : 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              l.syncuiProgress(done, total),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.strong,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 12, bottom: popover ? 8 : 6),
          child: SyncBar(
            height: 6,
            fraction: total == 0 ? 0 : done / total,
            track: colors.track,
            color: colors.progress,
          ),
        ),
        if (showCounts)
          Padding(
            padding: EdgeInsets.only(bottom: popover ? 4 : 6),
            child: Row(
              children: [
                Text(
                  l.syncuiUploadCount(up),
                  style: TextStyle(fontSize: 13, color: t.text2),
                ),
                const SizedBox(width: 16),
                Text(
                  l.syncuiDownloadCount(down),
                  style: TextStyle(fontSize: 13, color: t.text2),
                ),
                if (popover) ...[const Spacer(), const _NetworkLabel()],
              ],
            ),
          ),
      ],
    );
  }
}

/// 目前連線種類（只有 Wi-Fi／行動網絡／有線會顯示，其餘不畫）。
class _NetworkLabel extends ConsumerWidget {
  const _NetworkLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final kind = ref.watch(networkKindProvider).value;
    final label = switch (kind) {
      NetworkKind.wifi => l.ipadsyncNetWifi,
      NetworkKind.cellular => l.ipadsyncNetCellular,
      NetworkKind.ethernet => l.ipadsyncNetEthernet,
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      style: TextStyle(fontSize: 13, color: context.tokens.text3),
    );
  }
}

/// 逐張列出要顯示的傳輸（D-099）：**傳輸中的排最上**（同時最多 [syncSheetMaxActive] 張），
/// 接著是下幾張「等待中」，合計最多 [syncSheetMaxRows] 行；其餘由呼叫端寫成「還有 N 張等待中」。
/// 已完成的不列。同一類內保持傳輸清單的順序。
List<SyncTransfer> pickSyncRows(List<SyncTransfer> transfers) {
  final active = <SyncTransfer>[];
  final waiting = <SyncTransfer>[];
  for (final x in transfers) {
    if (x.isSettled) continue;
    (x.isActive ? active : waiting).add(x);
  }
  final out = [...active.take(syncSheetMaxActive)];
  // 超過上限的 active 排在 waiting 前面補位，不會消失。
  final rest = [...active.skip(syncSheetMaxActive), ...waiting];
  out.addAll(rest.take(syncSheetMaxRows - out.length));
  return out;
}

String _rowKey(SyncTransfer x) => '${x.direction.name}:${x.file}';

/// 逐張列出尚未完成的圖片（傳輸中在前，最多 [syncSheetMaxRows] 張）＋「還有 N 張等待中」。
/// 傳完的那一行會淡出，下面的行補上來。
///
/// [onOpenSettings] 非 null＝popover 版：底下一列左「還有 N 張等待中」、右「同步設定」連結；
/// null＝bottom sheet 版：置中的「還有 N 張等待中」。
class SyncProgressRows extends ConsumerStatefulWidget {
  const SyncProgressRows({super.key, this.onOpenSettings});
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<SyncProgressRows> createState() => _SyncProgressRowsState();
}

class _Leaving {
  _Leaving(this.index, this.x);
  final int index;
  final SyncTransfer x;
}

class _SyncProgressRowsState extends ConsumerState<SyncProgressRows> {
  /// 淡出中的行（key → 原本的位置與最後狀態）。
  final _leaving = <String, _Leaving>{};
  final _timers = <String, Timer>{};
  static const fadeDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    ref.listenManual(syncControllerProvider.select((s) => s.transfers), (
      prev,
      next,
    ) {
      final before = pickSyncRows(prev ?? const []);
      final after = {for (final x in pickSyncRows(next)) _rowKey(x)};
      for (var i = 0; i < before.length; i++) {
        final key = _rowKey(before[i]);
        if (after.contains(key) || _leaving.containsKey(key)) continue;
        // 離開畫面的行：傳完的才淡出（定格在 100%）；其他情況（整次同步結束）直接消失。
        final now = next.where((n) => _rowKey(n) == key).firstOrNull;
        if (now == null || !now.isDone) continue;
        setState(() => _leaving[key] = _Leaving(i, now.copyWith(progress: 1)));
        _timers[key] = Timer(
          fadeDuration + const Duration(milliseconds: 40),
          () {
            _timers.remove(key);
            if (mounted) setState(() => _leaving.remove(key));
          },
        );
      }
    });
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final transfers = ref.watch(
      syncControllerProvider.select((s) => s.transfers),
    );
    final shown = pickSyncRows(transfers);
    final pendingCount = transfers.where((x) => !x.isSettled).length;
    final more = pendingCount - shown.length;
    // 一次批次查可見幾行的位置資料（不逐張查）。
    final files = [for (final x in shown) x.file];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncRowInfoProvider.notifier).ensure(files);
      }
    });
    final rows = <Widget>[
      for (final x in shown) _TransferRow(key: ValueKey(_rowKey(x)), x: x),
    ];
    final leaving = _leaving.entries.toList()
      ..sort((a, b) => a.value.index.compareTo(b.value.index));
    for (final e in leaving) {
      rows.insert(
        e.value.index.clamp(0, rows.length),
        _TransferRow(
          key: ValueKey('leaving:${e.key}'),
          x: e.value.x,
          leaving: true,
        ),
      );
    }
    final onOpenSettings = widget.onOpenSettings;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          if (onOpenSettings != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  if (more > 0)
                    Text(
                      context.l10n.syncuiMoreWaiting(more),
                      style: TextStyle(fontSize: 13, color: t.text3),
                    ),
                  const Spacer(),
                  _SettingsLink(onTap: onOpenSettings),
                ],
              ),
            )
          else if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                context.l10n.syncuiMoreWaiting(more),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// 「同步設定」連結（觸控範圍 ≥44 高）。
class _SettingsLink extends StatelessWidget {
  const _SettingsLink({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              widthFactor: 1,
              child: Text(
                context.l10n.ipadsyncSettings,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.strong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 一行：縮圖（或分類占位）＋「上傳／下載」標籤＋位置＋百分比／等待中＋進度條。
class _TransferRow extends ConsumerWidget {
  const _TransferRow({super.key, required this.x, this.leaving = false});
  final SyncTransfer x;

  /// 傳完、淡出中。
  final bool leaving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final info = ref.watch(syncRowInfoProvider.select((m) => m[x.file]));
    final waiting = !x.isActive && !x.isSettled;
    // Drive 已滿（D-103）：排隊中的上傳寫「等待空間」（灰字），不是「等待中」。
    final waitingSpace =
        waiting &&
        x.isUpload &&
        ref.watch(syncControllerProvider.select((s) => s.quotaFull));
    final percent = (x.isActive || x.isDone) && x.progress != null
        ? (x.progress! * 100).round().clamp(0, 100)
        : null;
    final locationText = syncLocationText(l, info);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          SyncRowThumb(file: x.file, info: info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SyncDirectionTag(upload: x.isUpload),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locationText ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (waiting)
                      Text(
                        waitingSpace ? l.syncuiWaitingSpace : l.syncuiWaiting,
                        key: waitingSpace
                            ? const Key('sync-waiting-space')
                            : null,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.waitText,
                        ),
                      )
                    else if (percent != null)
                      Text(
                        l.syncuiPercent(percent),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colors.strong,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: waiting
                      ? SyncBar(
                          height: 5,
                          fraction: 0,
                          track: colors.waitTrack,
                          color: colors.progress,
                        )
                      : SyncBar(
                          height: 5,
                          // 進行中但不知道大小：不確定進度條。
                          fraction: x.isDone ? 1 : x.progress,
                          track: colors.track,
                          color: colors.progress,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!leaving) return row;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('syncRowFade'),
      tween: Tween(begin: 1, end: 0),
      duration: _SyncProgressRowsState.fadeDuration,
      curve: Curves.easeIn,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: row,
    );
  }
}

/// 一行的位置文字（D-099）：「坑B · 好看同人圖」；腦洞／摸魚／成圖／推活有標題的再加標題
/// 「坑A · 摸魚 · 天台煙花」；素材庫「素材庫 · 服裝」。資料還沒查到回傳 null。
String? syncLocationText(AppLocalizations l, SyncRowInfo? info) {
  if (info == null) return null;
  final cell = switch (info.kind) {
    SyncRowKind.official => l.pitsOfficial,
    SyncRowKind.fan => l.pitsFanArt,
    SyncRowKind.junk => l.junkTitle,
    SyncRowKind.draft => l.goalsKindDraft,
    SyncRowKind.idea => l.goalsKindIdea,
    SyncRowKind.piece => l.goalsKindPiece,
    SyncRowKind.oshi => l.oshiTitle,
    SyncRowKind.material => l.materialTitle,
    SyncRowKind.cover => l.pitsFieldCover,
  };
  if (info.kind == SyncRowKind.material) {
    final cat = switch (info.materialCategory) {
      MaterialCategory.clothing => l.materialCatClothing,
      MaterialCategory.pose => l.materialCatPose,
      MaterialCategory.body => l.materialCatBody,
      MaterialCategory.palette => l.materialCatPalette,
      MaterialCategory.scene => l.materialCatScene,
      MaterialCategory.style => l.materialCatStyle,
      MaterialCategory.sticker => l.materialCatSticker,
      null => null,
    };
    return cat == null ? cell : l.syncuiLocation(cell, cat);
  }
  final pit = info.pitName;
  if (pit == null || pit.isEmpty) return cell;
  final title = info.title;
  if (title != null && title.isNotEmpty) {
    return l.syncuiLocationTitled(pit, cell, title);
  }
  return l.syncuiLocation(pit, cell);
}

/// 一行左邊 44×44 的縮圖（D-099）：本機原圖（或列表縮圖）→ 模糊占位圖 → 該分類的底色＋分類 icon。
/// 影片用它的 poster。資料還沒查到時是沒有 icon 的中性底色，不用通用的灰色圖片 icon。
class SyncRowThumb extends ConsumerWidget {
  const SyncRowThumb({super.key, required this.file, required this.info});
  final String file;
  final SyncRowInfo? info;

  static const size = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = _CategoryPlaceholder(kind: info?.kind);
    final store = ref.watch(imageStoreProvider).value;
    final isVideo = mediaKindFromExtension(file).isVideo;
    final shownFile = isVideo ? info?.posterFile : file;
    Widget child = placeholder;
    if (store != null && shownFile != null) {
      ref.watch(thumbVersionProvider(shownFile)); // 占位圖到了重建
      if (ref.watch(imageExistsProvider(shownFile)).value ?? false) {
        child = SensitiveGate(
          file: file,
          badgeInset: 2,
          child: StoredImage(
            shownFile,
            cacheWidth: 150,
            showDownloadBadge: false,
          ),
        );
      } else {
        // 原圖還沒到：模糊占位圖（沒有就維持分類底色＋icon）。
        final ph = store.placeholderFileFor(shownFile);
        if (ph != null) child = BlurredPlaceholder(ph);
      }
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// 縮圖還沒到時的格子：該分類的底色＋分類 icon（官方圖冊＝書本、同人圖＝愛心圖框、摸魚＝筆、
/// 成圖＝圖片、推活＝星、雜物＝箱子、素材庫＝素材；分類色見 HANDOFF 第 7 節）。
class _CategoryPlaceholder extends StatelessWidget {
  const _CategoryPlaceholder({required this.kind});
  final SyncRowKind? kind;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final neutral = CategoryColor(t.chipBg, t.text3);
    final (CategoryColor color, String? icon) = switch (kind) {
      SyncRowKind.official => (t.official, AppIcons.pitOfficial),
      SyncRowKind.fan => (t.fanArt, AppIcons.pitFanArt),
      SyncRowKind.draft => (t.draft, AppIcons.edit),
      SyncRowKind.idea => (t.idea, AppIcons.bulb),
      SyncRowKind.piece => (t.piece, AppIcons.image),
      SyncRowKind.oshi => (t.oshi, OshiIcons.star),
      SyncRowKind.junk => (neutral, PitsIcons.junk),
      SyncRowKind.material => (neutral, MaterialLibIcons.library),
      SyncRowKind.cover => (neutral, AppIcons.setCover),
      null => (neutral, null),
    };
    return ColoredBox(
      key: ValueKey('syncThumbPlaceholder:${kind?.name ?? 'none'}'),
      color: color.bg,
      child: icon == null
          ? null
          : Center(
              child: SvgIcon(icon, size: 22, strokeWidth: 1.6, color: color.fg),
            ),
    );
  }
}

class SyncDirectionTag extends StatelessWidget {
  const SyncDirectionTag({
    super.key,
    required this.upload,
    this.showIcon = true,
  });
  final bool upload;

  /// iPad popover 的失敗／等待空間行（SyncPopoverPartial／Full）標籤只有字，沒有箭頭。
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    return Container(
      padding: EdgeInsets.fromLTRB(showIcon ? 5 : 7, 2, 7, 2),
      decoration: BoxDecoration(
        color: colors.tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            SvgIcon(
              upload ? SyncIcons.upload : SyncIcons.download,
              size: 14,
              strokeWidth: 2.2,
              color: colors.progress,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            upload ? l.syncuiUpload : l.syncuiDownload,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.progress,
            ),
          ),
        ],
      ),
    );
  }
}

/// 圓角進度條；[fraction] 為 null＝不確定進度。
class SyncBar extends StatelessWidget {
  const SyncBar({
    super.key,
    required this.height,
    required this.fraction,
    required this.track,
    required this.color,
  });
  final double height;
  final double? fraction;
  final Color track;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: height,
        child: fraction == null
            ? LinearProgressIndicator(
                minHeight: height,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation(color),
              )
            : TweenAnimationBuilder<double>(
                tween: Tween(end: fraction!.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 200),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: height,
                  backgroundColor: track,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
      ),
    );
  }
}

/// 最多列出幾張（SyncPopoverFull 稿畫 3 張，其餘寫「還有 N 張等待空間」）。
const syncFullMaxRows = 3;

/// Drive 已滿、剩下的全是排隊等空間的上傳（沒有任何傳輸中）：iPad popover 用 SyncPopoverFull 的
/// 版面（[SyncProgressHeader] 不畫張數列＋[SyncFullRows]）。還有下載或傳輸中的就維持一般版面。
bool syncIsWaitingForSpace(SyncState s) {
  if (!s.quotaFull) return false;
  final pending = [
    for (final x in s.transfers)
      if (!x.isSettled) x,
  ];
  return pending.isNotEmpty && pending.every((x) => x.isUpload && !x.isActive);
}

/// 「等待空間」要列的上傳：同步中＝還沒處理完的傳輸；同步結束後（傳輸清單已清空，從紅點打開時）＝
/// 上一次結果裡沒上傳成功的上傳。
List<SyncTransfer> syncWaitingRows(SyncState s) {
  if (s.transfers.isNotEmpty) {
    return [
      for (final x in s.transfers)
        if (!x.isSettled) x,
    ];
  }
  return [
    for (final x in s.lastResult?.transfers ?? const <SyncTransfer>[])
      if (x.isUpload && !x.isDone) x,
  ];
}

/// SyncPopoverFull 的列：縮圖、只有字的「上傳」標籤、位置、灰字「等待空間」（沒有進度條）；
/// 超過 [syncFullMaxRows] 張，底下置中寫「還有 N 張等待空間」。
class SyncFullRows extends ConsumerWidget {
  const SyncFullRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    final pending = ref.watch(syncControllerProvider.select(syncWaitingRows));
    final shown = pending.take(syncFullMaxRows).toList();
    final more = pending.length - shown.length;
    final files = [for (final x in shown) x.file];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) ref.read(syncRowInfoProvider.notifier).ensure(files);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          Consumer(
            builder: (context, ref, _) {
              final info = ref.watch(
                syncRowInfoProvider.select((m) => m[shown[i].file]),
              );
              final last = i == shown.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: last
                      ? null
                      : Border(bottom: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  children: [
                    SyncRowThumb(file: shown[i].file, info: info),
                    const SizedBox(width: 12),
                    SyncDirectionTag(
                      upload: shown[i].isUpload,
                      showIcon: false,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        syncLocationText(l, info) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.syncuiWaitingSpace,
                      key: const Key('sync-waiting-space'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.waitText,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l.ipadsyncMoreWaitingSpace(more),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: t.text3),
            ),
          ),
      ],
    );
  }
}
