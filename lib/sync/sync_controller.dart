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
    this.retryable = false,
  });
  final SyncPhase phase;

  /// 拉取階段的雲端文件進度（「資料 N / M」）；[docsTotal] 為 0＝還在列出雲端內容。
  final int docsDone;
  final int docsTotal;

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

  int get uploadCount => transfers.where((t) => t.isUpload).length;
  int get downloadCount => transfers.where((t) => t.isDownload).length;
  int get uploadDone => transfers.where((t) => t.isUpload && t.isDone).length;
  int get downloadDone =>
      transfers.where((t) => t.isDownload && t.isDone).length;

  /// 總張數與已完成張數（上傳＋下載）。
  int get transferTotal => transfers.length;
  int get transferDone => transfers.where((t) => t.isDone).length;

  /// 進度環：已完成張數／總張數（0~1）；沒有傳輸時為 null。
  double? get transferFraction =>
      transfers.isEmpty ? null : transferDone / transfers.length;

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

  /// 拉取階段的 0~1 進度。
  double? get docFraction =>
      docsTotal > 0 ? (docsDone / docsTotal).clamp(0.0, 1.0) : null;

  /// 目前階段的進度（拉取階段看文件數，其後看圖片數）；不知道時為 null（不確定進度條）。
  double? get progressFraction => hasDocProgress ? docFraction : imageFraction;

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
    bool? retryable,
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
    retryable: retryable ?? this.retryable,
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

  /// 立即同步。未連結或正在同步時不做事（**不看 connectivity**：沒有明確斷線就嘗試，
  /// 以實際請求的成敗為準，失敗會顯示在 [SyncState.message]）。回傳是否實際執行。
  Future<bool> syncNow() async {
    final remote = ref.read(syncRemoteProvider);
    if (remote == null || _running) return false;
    _running = true;
    final gen = ++_generation;
    final settings = ref.read(settingsProvider);
    final email = settings.accountEmail;
    final first = email != null && settings.syncedAccount != email;
    syncLog('syncNow start first=$first');
    state = SyncState(
      phase: SyncPhase.syncing,
      lastSyncAt: state.lastSyncAt,
      isFirstSync: first,
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
    );
    try {
      lastActivity = DateTime.now();
      Future<SyncResult> run() async {
        final engine = SyncEngine(
          db: ref.read(databaseProvider),
          remote: remote,
          images: await ref.read(imageStoreProvider.future),
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
            );
          },
        );
      }

      final r = await Future.any([run(), stalled.future]);
      if (email != null) {
        ref.read(settingsProvider.notifier).setSyncedAccount(email);
      }
      // 部分文件／圖片讀不了：不是整體失敗（其餘都已同步、帳號已記下），但要讓使用者看得出來。
      final partial = r.skippedDocs.isNotEmpty
          ? l10nStatic.syncuiSkippedDocs(r.skippedDocs.length)
          : (r.imageFailures > 0
                ? l10nStatic.syncuiImagesFailed(r.imageFailures)
                : null);
      state = partial != null
          ? SyncState(
              phase: SyncPhase.error,
              lastSyncAt: DateTime.now(),
              lastResult: r,
              message: partial,
              isFirstSync: first,
            )
          : SyncState(
              phase: SyncPhase.idle,
              lastSyncAt: DateTime.now(),
              lastResult: r,
            );
      return true;
    } on SyncFormatException catch (e) {
      state = failed(e.message, needsUpdate: true);
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
    }
  }

  /// 首次連結後開始同步，等到結束才回傳（SyncFirst 頁可以 await 它）。
  Future<bool> startFirstSync() => syncNow();

  /// 開始同步但不等待：使用者按「先開始使用」離開 SyncFirst 後，同步由這個 controller
  /// 在背景繼續（狀態都在 [SyncState]，主頁橫條照常顯示進度）。
  void startFirstSyncInBackground() => unawaited(syncNow());

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
    unawaited(syncNow());
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

/// 圖片格的下載狀態（D-052 角標）：本機有這張圖→[ImageDownloadStatus.present]（不顯示角標）；
/// 沒有→`isMissing`，`progress` 是下載進度（正在下載且知道大小時），null＝排隊中／沒有在同步
/// （角標轉圈）。圖片下載完成時會自動變回 present。
final imageTransferProvider = Provider.family<ImageDownloadStatus, String>((
  ref,
  file,
) {
  final exists = ref.watch(imageExistsProvider(file)).value ?? true;
  if (exists) return ImageDownloadStatus.present;
  final t = ref.watch(_downloadIndexProvider.select((m) => m[file]));
  return ImageDownloadStatus(
    isMissing: true,
    progress: (t != null && t.isActive) ? t.progress : null,
  );
});
