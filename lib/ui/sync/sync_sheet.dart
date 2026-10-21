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
import '../pits/pits_icons.dart';
import 'sync_colors.dart';
import 'sync_icons.dart';

/// 打開「同步進度」bottom sheet（SyncSheet，D-052）。
///
/// 傳完**不自動關**：原地變成完成狀態（D-100，SyncSheetDone），按「完成」、下拉或點外面才關。
///
/// 設計稿的 sheet 蓋住底部導覽列，所以用最上層 Navigator（全域 sheet）。
Future<void> showSyncSheet(BuildContext context) {
  return showThemedSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const SyncSheet(),
  );
}

/// 最多列出幾張（其餘寫「還有 N 張等待中」）。
const syncSheetMaxRows = 4;

/// 同時最多顯示幾張「傳輸中」（各自顯示百分比）。
const syncSheetMaxActive = 3;

/// 剛傳完那一次同步的張數（完成狀態顯示用；新變更進來切回同步中就丟掉）。
class SyncDoneSummary {
  const SyncDoneSummary({
    required this.total,
    required this.uploaded,
    required this.downloaded,
  });
  final int total;
  final int uploaded;
  final int downloaded;
}

class SyncSheet extends ConsumerStatefulWidget {
  const SyncSheet({super.key});

  @override
  ConsumerState<SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends ConsumerState<SyncSheet> {
  bool _closing = false;
  SyncDoneSummary? _done;

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    // 打開的瞬間沒有在傳（剛好傳完或根本沒東西傳）：直接關。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !ref.read(syncControllerProvider).isTransferring) {
        _close();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(syncControllerProvider, (prev, next) {
      if (prev == null) return;
      if (prev.isTransferring && !next.isTransferring) {
        // 正常傳完（phase 回到 idle）→ 原地變完成狀態；失敗等其他情況照舊關閉。
        if (next.phase == SyncPhase.idle && prev.transferTotal > 0) {
          setState(
            () => _done = SyncDoneSummary(
              total: prev.transferTotal,
              uploaded: prev.uploadCount,
              downloaded: prev.downloadCount,
            ),
          );
        } else {
          _close();
        }
      } else if (!prev.isTransferring && next.isTransferring && _done != null) {
        // 完成狀態下又有新的變更要同步：切回同步中。
        setState(() => _done = null);
      }
    });
    return SyncSheetBody(done: _done, onDone: _close);
  }
}

/// bottom sheet 的內容（把手、標頭、清單）；關閉邏輯由外層負責。
///
/// [done] 非 null＝同步完成狀態（D-100）：標題勾＋「同步完成」、全滿綠色進度條、張數與完成時間、
/// 底部「完成」按鈕（[onDone]），沒有清單。
class SyncSheetBody extends StatelessWidget {
  const SyncSheetBody({super.key, this.done, this.onDone});

  final SyncDoneSummary? done;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final done = this.done;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: done != null ? l.syncuiDoneTitle : l.syncuiSheetLabel,
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
              if (done != null) ...[
                SyncDoneContent(summary: done),
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: SizedBox(
                    height: 48,
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SyncProgressHeader(),
                const SyncProgressRows(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 完成狀態的標頭（SyncSheetDone）：綠勾圈＋「同步完成」、右邊「N / N」綠字、全滿綠色進度條、
/// 「上傳 N 張　下載 N 張」＋右邊完成時間。
class SyncDoneContent extends StatelessWidget {
  const SyncDoneContent({super.key, required this.summary});
  final SyncDoneSummary summary;

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
                    fontSize: 18,
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
        Row(
          children: [
            Text(
              l.syncuiUploadCount(summary.uploaded),
              style: TextStyle(fontSize: 13, color: t.text2),
            ),
            const SizedBox(width: 16),
            Text(
              l.syncuiDownloadCount(summary.downloaded),
              style: TextStyle(fontSize: 13, color: t.text2),
            ),
            const Spacer(),
            Text(
              l.syncuiDoneJustNow,
              style: TextStyle(fontSize: 13, color: t.text2),
            ),
          ],
        ),
      ],
    );
  }
}

/// 標題、已完成 / 總數、總進度條、上傳與下載張數。
///
/// [popover]＝iPad 頭像 popover（SyncPopover 稿）：標題 19、進度條上下留白較多，
/// 張數列右側多一個連線種類（Wi-Fi）。
class SyncProgressHeader extends ConsumerWidget {
  const SyncProgressHeader({super.key, this.popover = false});
  final bool popover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final colors = SyncColors.of(context);
    final l = context.l10n;
    // 只取數字，傳輸清單裡逐位元組的變動不會讓標頭重建。
    final (done, total, up, down) = ref.watch(
      syncControllerProvider.select(
        (s) =>
            (s.transferDone, s.transferTotal, s.uploadCount, s.downloadCount),
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
          child: _Bar(
            height: 6,
            fraction: total == 0 ? 0 : done / total,
            track: colors.track,
            color: colors.progress,
          ),
        ),
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
    if (x.isDone) continue;
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
    final pendingCount = transfers.where((x) => !x.isDone).length;
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
    final waiting = !x.isActive && !x.isDone;
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
                    _DirectionTag(upload: x.isUpload),
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
                        l.syncuiWaiting,
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
                      ? _Bar(
                          height: 5,
                          fraction: 0,
                          track: colors.waitTrack,
                          color: colors.progress,
                        )
                      : _Bar(
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
        child = StoredImage(
          shownFile,
          cacheWidth: 150,
          showDownloadBadge: false,
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

class _DirectionTag extends StatelessWidget {
  const _DirectionTag({required this.upload});
  final bool upload;

  @override
  Widget build(BuildContext context) {
    final colors = SyncColors.of(context);
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
      decoration: BoxDecoration(
        color: colors.tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgIcon(
            upload ? SyncIcons.upload : SyncIcons.download,
            size: 14,
            strokeWidth: 2.2,
            color: colors.progress,
          ),
          const SizedBox(width: 3),
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
class _Bar extends StatelessWidget {
  const _Bar({
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
