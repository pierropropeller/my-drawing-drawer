import '../data/trash_queries.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import 'drive_remote.dart';
import 'google_auth.dart';
import 'remote.dart';
import 'sync_engine.dart';
import 'sync_log.dart';
import 'sync_transfer.dart';
import '../l10n/l10n.dart';

export 'sync_transfer.dart';

enum SyncPhase { idle, syncing, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.message,
    this.lastResult,
    this.stage = SyncStage.pulling,
    this.imagesDone = 0,
    this.imagesTotal = 0,
    this.isFirstSync = false,
    this.needsAppUpdate = false,
    this.transfers = const [],
    this.transfersPlanned = false,
    this.docsDone = 0,
    this.docsTotal = 0,
    this.thumbsDone = 0,
    this.thumbsTotal = 0,
    this.retryable = false,
    this.quotaFull = false,
  });
  final SyncPhase phase;

  /// Drive 已滿（D-103）：最近一次上傳被拒絕。上傳留在佇列、下載照常；之後有空間、
  /// 上傳成功就清掉。同步進行中沿用上一次的值，所以排隊的行可以顯示「等待空間」。
  final bool quotaFull;

  /// 拉取階段的雲端文件進度（「資料 N / M」）；[docsTotal] 為 0＝還在列出雲端內容。
  final int docsDone;
  final int docsTotal;

  /// 縮圖階段（D-099）的進度（「縮圖 N / M」）；[thumbsTotal] 為 0＝沒有縮圖要處理。
  final int thumbsDone;
  final int thumbsTotal;

  /// 失敗是暫時性的（逾時、斷線、看門狗中止），稍後自動重試有意義；授權／格式問題不會。
  final bool retryable;
  final DateTime? lastSyncAt;
  final String? message;
  final SyncResult? lastResult;

  /// 同步中的階段（拉取文件／下載圖片／上傳）。
  final SyncStage stage;

  /// 目前階段的圖片進度（「圖片 N / M」）；[imagesTotal] 為 0＝還不知道或沒有圖片。
  final int imagesDone;
  final int imagesTotal;

  /// 正在進行（或剛失敗）的是這個帳號的首次同步。
  final bool isFirstSync;

  /// 遠端備份由較新版本的 App 建立（錯誤訊息在 [message]）。
  final bool needsAppUpdate;

  /// 這次同步要傳的所有圖片（先下載後上傳）與各自進度；同步結束（含失敗）就清空。
  final List<SyncTransfer> transfers;

  /// 傳輸清單是否已確定（拉取、比對完遠端之後）。
  final bool transfersPlanned;

  bool get isSyncing => phase == SyncPhase.syncing;

  /// 檢查中（D-052）：同步中、還在拉取／比對遠端，尚未知道有沒有圖片要傳。
  /// 頭像外圈轉不確定的弧，不可點。
  bool get isChecking => isSyncing && !transfersPlanned;

  /// 傳輸中（D-052）：同步中、有圖片要上傳或下載。頭像外圈是進度環，可點開「同步進度」。
  bool get isTransferring =>
      isSyncing && transfersPlanned && transfers.isNotEmpty;

  /// 頭像外圈要不要畫成進度環：傳輸中且還有沒處理完的張數。全部傳完後同步可能還在做
  /// 收尾（補縮圖等，最多幾十秒），這段時間外圈就收掉，不要一直停在滿圈（修正「同步完外圈不消失」）。
  bool get isRingTransferring => isTransferring && hasPendingTransfers;

  int get uploadCount => transfers.where((t) => t.isUpload).length;
  int get downloadCount => transfers.where((t) => t.isDownload).length;
  int get uploadDone => transfers.where((t) => t.isUpload && t.isDone).length;
  int get downloadDone =>
      transfers.where((t) => t.isDownload && t.isDone).length;

  /// 總張數與已成功張數（上傳＋下載）。
  int get transferTotal => transfers.length;
  int get transferDone => transfers.where((t) => t.isDone).length;

  /// 已處理完的張數（成功＋失敗，D-109）；進度條與進度環用它，失敗的也算走完。
  int get transferSettled => transfers.where((t) => t.isSettled).length;
  int get transferFailed => transfers.where((t) => t.isFailed).length;

  /// 還有沒處理完的傳輸（頭像外圈只在這段時間轉；全部傳完後收尾的工作不再顯示外圈）。
  bool get hasPendingTransfers => transfers.any((t) => !t.isSettled);

  /// 進度環：已處理張數／總張數（0~1）；沒有傳輸時為 null。
  double? get transferFraction =>
      transfers.isEmpty ? null : transferSettled / transfers.length;

  /// 上一次完成的同步裡，仍然失敗（留在佇列）的張數（D-109）；全部成功後為 0。
  int get failedCount => lastResult?.failedTransfers.length ?? 0;
  bool get hasFailures => failedCount > 0;

  /// 上一次完成的同步後，還沒上傳的張數（失敗的＋Drive 已滿而排隊的，D-103）。
  int get unuploadedCount => lastResult?.unuploadedCount ?? 0;

  /// 目前正在傳的那一張（沒有則 null）。
  SyncTransfer? get activeTransfer {
    for (final t in transfers) {
      if (t.isActive) return t;
    }
    return null;
  }

  /// 還在列出雲端內容（尚未知道有多少文件要拉）。
  bool get isListing =>
      isSyncing &&
      stage == SyncStage.pulling &&
      docsTotal == 0 &&
      imagesTotal == 0 &&
      !transfersPlanned;

  /// 正在拉取雲端文件且數量已知。
  bool get hasDocProgress =>
      isSyncing && stage == SyncStage.pulling && docsTotal > 0;

  /// 正在下載縮圖（D-099）且數量已知。
  bool get hasThumbProgress =>
      isSyncing && stage == SyncStage.downloadingThumbs && thumbsTotal > 0;

  double? get thumbFraction =>
      thumbsTotal > 0 ? (thumbsDone / thumbsTotal).clamp(0.0, 1.0) : null;

  /// 拉取階段的 0~1 進度。
  double? get docFraction =>
      docsTotal > 0 ? (docsDone / docsTotal).clamp(0.0, 1.0) : null;

  /// 目前階段的進度（拉取階段看文件數，其後看圖片數）；不知道時為 null（不確定進度條）。
  double? get progressFraction => hasDocProgress
      ? docFraction
      : hasThumbProgress
      ? thumbFraction
      : imageFraction;

  /// 是否有圖片進度可以顯示（頂部橫條「同步中・圖片 N / M」）。
  bool get hasImageProgress => isSyncing && imagesTotal > 0;

  /// 0~1；沒有圖片進度時為 null（顯示不確定進度條）。
  double? get imageFraction =>
      imagesTotal > 0 ? (imagesDone / imagesTotal).clamp(0.0, 1.0) : null;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    String? message,
    SyncResult? lastResult,
    SyncStage? stage,
    int? imagesDone,
    int? imagesTotal,
    bool? isFirstSync,
    bool? needsAppUpdate,
    List<SyncTransfer>? transfers,
    bool? transfersPlanned,
    int? docsDone,
    int? docsTotal,
    int? thumbsDone,
    int? thumbsTotal,
    bool? retryable,
    bool? quotaFull,
  }) => SyncState(
    phase: phase ?? this.phase,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    message: message,
    lastResult: lastResult ?? this.lastResult,
    stage: stage ?? this.stage,
    imagesDone: imagesDone ?? this.imagesDone,
    imagesTotal: imagesTotal ?? this.imagesTotal,
    isFirstSync: isFirstSync ?? this.isFirstSync,
    needsAppUpdate: needsAppUpdate ?? this.needsAppUpdate,
    transfers: transfers ?? this.transfers,
    transfersPlanned: transfersPlanned ?? this.transfersPlanned,
    docsDone: docsDone ?? this.docsDone,
    docsTotal: docsTotal ?? this.docsTotal,
    thumbsDone: thumbsDone ?? this.thumbsDone,
    thumbsTotal: thumbsTotal ?? this.thumbsTotal,
    retryable: retryable ?? this.retryable,
    quotaFull: quotaFull ?? this.quotaFull,
  );
}

final accountServiceProvider = Provider<AccountService>(
  (ref) => GoogleAccountService(),
);

/// 遠端儲存；未連結帳號時為 null。測試時可替換成 [MemoryRemote]。
final syncRemoteProvider = Provider<SyncRemote?>((ref) {
  final email = ref.watch(settingsProvider.select((s) => s.accountEmail));
  if (email == null) return null;
  final accounts = ref.read(accountServiceProvider);
  return DriveRemote(
    headers: accounts.headers,
    refreshAuth: () async {
      final a = accounts;
      if (a is GoogleAccountService) a.invalidateToken();
    },
  );
});

/// 單次同步連續這麼久沒有任何進展（沒有新的進度回報）就由看門狗中止、報錯並稍後重試。
/// 每個 Drive 請求另有自己的逾時與重試（見 `DriveRemote`），這是最後一道保險。
/// 測試可覆寫成很短的時間。
final syncStallTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 3),
);

class SyncController extends Notifier<SyncState> {
  bool _running = false;
  int _generation = 0;

  @override
  SyncState build() => const SyncState();

  bool _userInitiated = false;

  /// 使用者主動觸發的同步（「立即同步」、重試、首次連結、更換帳號）：同 [syncNow]，
  /// 但允許在拿不到靜默授權時彈出 Google 的互動授權畫面。自動同步請用 [syncNow]。
  Future<bool> syncNowByUser() {
    _userInitiated = true;
    return syncNow();
  }

  /// 立即同步。未連結或正在同步時不做事（**不看 connectivity**：沒有明確斷線就嘗試，
  /// 以實際請求的成敗為準，失敗會顯示在 [SyncState.message]）。回傳是否實際執行。
  ///
  /// 自動同步（啟動、回前景、定時、資料變動）絕不彈 Google／系統授權畫面，拿不到靜默授權就當離線
  /// （暫時失敗、退避重試）；要允許互動授權請用 [syncNowByUser]。
  Future<bool> syncNow() async {
    final userInitiated = _userInitiated;
    _userInitiated = false;
    final remote = ref.read(syncRemoteProvider);
    if (remote == null || _running) return false;
    _running = true;
    final accounts = ref.read(accountServiceProvider);
    if (accounts is GoogleAccountService) {
      accounts.allowInteractive = userInitiated;
    }
    final gen = ++_generation;
    final settings = ref.read(settingsProvider);
    final email = settings.accountEmail;
    final first = email != null && settings.syncedAccount != email;
    syncLog('syncNow start first=$first');
    // 上一次的結果（失敗張數、Drive 已滿）同步期間沿用，結束時換成這一次的。
    final prevResult = state.lastResult;
    final prevQuotaFull = state.quotaFull;
    state = SyncState(
      phase: SyncPhase.syncing,
      lastSyncAt: state.lastSyncAt,
      isFirstSync: first,
      lastResult: prevResult,
      quotaFull: prevQuotaFull,
    );
    // 看門狗：太久沒有進展就中止這一次（引擎在步驟之間檢查 cancel；卡在某個 await 的
    // 請求則由 Future.any 放棄它）。
    final stall = ref.read(syncStallTimeoutProvider);
    final cancel = SyncCancel();
    final stalled = Completer<SyncResult>();
    stalled.future.ignore();
    var lastActivity = DateTime.now();
    final checkEvery = stall ~/ 4 > const Duration(seconds: 10)
        ? const Duration(seconds: 10)
        : stall ~/ 4;
    // 引擎第一次回報進度（＝開始同步）時才啟動計時，之後每次回報都算有進展。
    Timer? watchdog;
    void armWatchdog() {
      watchdog ??= Timer.periodic(
        checkEvery < const Duration(milliseconds: 20)
            ? const Duration(milliseconds: 20)
            : checkEvery,
        (_) {
          if (!stalled.isCompleted &&
              DateTime.now().difference(lastActivity) > stall) {
            syncLog('watchdog: no progress for ${stall.inSeconds}s, aborting');
            cancel.cancel();
            stalled.completeError(SyncStalledException());
          }
        },
      );
    }

    SyncState failed(
      String message, {
      bool needsUpdate = false,
      bool retry = false,
    }) => SyncState(
      phase: SyncPhase.error,
      lastSyncAt: state.lastSyncAt,
      message: message,
      isFirstSync: first,
      needsAppUpdate: needsUpdate,
      retryable: retry,
      lastResult: prevResult,
      quotaFull: prevQuotaFull,
    );
    try {
      lastActivity = DateTime.now();
      Future<SyncResult> run() async {
        // 最近刪除過了 30 天的先清掉，狀態再一起同步（D-120）。
        await ref.read(databaseProvider).purgeExpiredTrash();
        final engine = SyncEngine(
          db: ref.read(databaseProvider),
          remote: remote,
          images: await ref.read(imageStoreProvider.future),
          // 暱稱／頭像是同步來的：文件一套用完就更新畫面，不必等圖片下載完。
          onPulled: () => ref.read(settingsProvider.notifier).reloadProfile(),
        );
        return engine.sync(
          cancel: cancel,
          onProgress: (p) {
            lastActivity = DateTime.now();
            armWatchdog();
            if (gen != _generation) return; // 已被看門狗放棄的舊一次同步
            state = SyncState(
              phase: SyncPhase.syncing,
              lastSyncAt: state.lastSyncAt,
              stage: p.stage,
              imagesDone: p.imagesDone,
              imagesTotal: p.imagesTotal,
              isFirstSync: first,
              transfers: p.transfers,
              transfersPlanned: p.transfersPlanned,
              docsDone: p.docsDone,
              docsTotal: p.docsTotal,
              thumbsDone: p.thumbsDone,
              thumbsTotal: p.thumbsTotal,
              lastResult: prevResult,
              quotaFull: p.quotaFull || prevQuotaFull,
            );
          },
        );
      }

      final r = await Future.any([run(), stalled.future]);
      await ref.read(settingsProvider.notifier).reloadProfile();
      if (email != null) {
        ref.read(settingsProvider.notifier).setSyncedAccount(email);
      }
      // 部分文件讀不了：不是整體失敗（其餘都已同步、帳號已記下），但要讓使用者看得出來。
      // 單張圖片失敗（D-109）不是錯誤：同步完成，失敗的列在 [SyncState.lastResult]
      // （同步 sheet 的「同步完成，N 張失敗」、頭像琥珀點），留在佇列等下次同步。
      final partial = r.skippedDocs.isNotEmpty
          ? l10nStatic.syncuiSkippedDocs(r.skippedDocs.length)
          : null;
      state = partial != null
          ? SyncState(
              phase: SyncPhase.error,
              lastSyncAt: DateTime.now(),
              lastResult: r,
              message: partial,
              isFirstSync: first,
              quotaFull: r.quotaFull,
            )
          : SyncState(
              phase: SyncPhase.idle,
              lastSyncAt: DateTime.now(),
              lastResult: r,
              quotaFull: r.quotaFull,
            );
      return true;
    } on SyncFormatException catch (e) {
      state = failed(e.message, needsUpdate: true);
      return true;
    } on SyncAuthUnavailableException catch (e) {
      // 背景拿不到靜默授權：照離線處理，安靜失敗、稍後退避重試（不彈任何畫面）。
      syncLog('syncNow auth unavailable (background)');
      state = failed(e.message, retry: true);
      return true;
    } on SyncAuthException catch (e) {
      syncLog('syncNow auth error');
      state = failed(e.message);
      return true;
    } on SyncStalledException catch (e) {
      state = failed(e.message, retry: true);
      return true;
    } on SyncNetworkException catch (e) {
      syncLog('syncNow network error: ${e.message}');
      state = failed(l10nStatic.syncFailed(e.message), retry: true);
      return true;
    } catch (e) {
      syncLog('syncNow error ${e.runtimeType}');
      state = failed(l10nStatic.syncFailed('$e'), retry: true);
      return true;
    } finally {
      watchdog?.cancel();
      _generation++; // 讓被放棄的舊一次同步之後的回報失效
      _running = false;
      if (accounts is GoogleAccountService) accounts.allowInteractive = false;
    }
  }

  /// 首次連結後開始同步，等到結束才回傳（SyncFirst 頁可以 await 它）。
  Future<bool> startFirstSync() => syncNowByUser();

  /// 開始同步但不等待：使用者按「先開始使用」離開 SyncFirst 後，同步由這個 controller
  /// 在背景繼續（狀態都在 [SyncState]，主頁橫條照常顯示進度）。
  void startFirstSyncInBackground() => unawaited(syncNowByUser());

  /// 更換同步帳號：登出舊帳號、清掉同步記錄（本機資料會整個上傳到新帳號）、重新登入。
  Future<String> switchAccount() async {
    final accounts = ref.read(accountServiceProvider);
    await accounts.signOut();
    final remote = ref.read(syncRemoteProvider);
    final email = await accounts.signIn();
    ref.read(settingsProvider.notifier).setAccount(email);
    await SyncEngine(
      db: ref.read(databaseProvider),
      remote: remote ?? MemoryRemote(),
      images: await ref.read(imageStoreProvider.future),
    ).resetState();
    unawaited(syncNowByUser());
    return email;
  }

  Future<void> disconnect() async {
    await ref.read(accountServiceProvider).signOut();
    ref.read(settingsProvider.notifier)
      ..setAccount(null)
      ..setSyncedAccount(null);
    state = const SyncState();
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// 本次同步「下載」清單的索引（檔名 → 傳輸）。清單每次更新才重建一次，所有圖片格共用。
final _downloadIndexProvider = Provider<Map<String, SyncTransfer>>((ref) {
  final list = ref.watch(syncControllerProvider.select((s) => s.transfers));
  return {
    for (final t in list)
      if (t.isDownload) t.file: t,
  };
});

/// 有連結同步（已連結帳號）或同步正在進行：本機沒有的圖都視為「待下載」（D-052）。
/// 首次同步先拉 meta、再列下載清單，meta 已套用但清單還沒排好的階段也算。
final syncLinkedProvider = Provider<bool>((ref) {
  final account = ref.watch(settingsProvider.select((s) => s.accountEmail));
  final syncing = ref.watch(
    syncControllerProvider.select((s) => s.phase == SyncPhase.syncing),
  );
  return account != null || syncing;
});

/// 坑的封面指向的圖還沒同步進來（meta 還在拉，圖的資料列不存在所以不知道檔名）：
/// 同步進行中或首次同步未完成時，封面格要顯示排隊中的下載角標。
final pitCoverPendingProvider = Provider<bool>((ref) {
  final syncing = ref.watch(
    syncControllerProvider.select((s) => s.phase == SyncPhase.syncing),
  );
  return syncing || ref.watch(firstSyncPendingProvider);
});

/// 圖片格的下載狀態（D-052 角標）：本機有這張圖→[ImageDownloadStatus.present]（不顯示角標）；
/// 沒有→`isMissing`，`progress` 是下載進度（正在下載且知道大小時），null＝排隊中／沒有在同步
/// （角標轉圈）。圖片下載完成時會自動變回 present。
final imageTransferProvider = Provider.family<ImageDownloadStatus, String>((
  ref,
  file,
) {
  final exists = ref.watch(imageExistsProvider(file)).value ?? true;
  if (exists) return ImageDownloadStatus.present;
  // 規則：本機沒有圖＋有連結同步（或同步中）＝待下載角標；沒連結＝只畫缺圖占位。
  if (!ref.watch(syncLinkedProvider)) {
    return const ImageDownloadStatus(isMissing: true, showBadge: false);
  }
  final t = ref.watch(_downloadIndexProvider.select((m) => m[file]));
  return ImageDownloadStatus(
    isMissing: true,
    progress: (t != null && t.isActive) ? t.progress : null,
  );
});
