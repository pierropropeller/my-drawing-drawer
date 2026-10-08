import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import 'drive_remote.dart';
import 'google_auth.dart';
import 'remote.dart';
import 'sync_engine.dart';
import '../l10n/l10n.dart';

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
  });
  final SyncPhase phase;
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

  bool get isSyncing => phase == SyncPhase.syncing;

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
  );
}

final accountServiceProvider = Provider<AccountService>(
  (ref) => GoogleAccountService(),
);

/// 遠端儲存；未連結帳號時為 null。測試時可替換成 [MemoryRemote]。
final syncRemoteProvider = Provider<SyncRemote?>((ref) {
  final email = ref.watch(settingsProvider.select((s) => s.accountEmail));
  if (email == null) return null;
  return DriveRemote(headers: ref.read(accountServiceProvider).headers);
});

class SyncController extends Notifier<SyncState> {
  bool _running = false;

  @override
  SyncState build() => const SyncState();

  /// 立即同步。離線、未連結或正在同步時不做事。回傳是否實際執行。
  Future<bool> syncNow() async {
    final remote = ref.read(syncRemoteProvider);
    if (remote == null || _running) return false;
    final online = ref.read(onlineProvider).value ?? true;
    if (!online) return false;
    _running = true;
    final settings = ref.read(settingsProvider);
    final email = settings.accountEmail;
    final first = email != null && settings.syncedAccount != email;
    state = SyncState(
      phase: SyncPhase.syncing,
      lastSyncAt: state.lastSyncAt,
      isFirstSync: first,
    );
    try {
      final engine = SyncEngine(
        db: ref.read(databaseProvider),
        remote: remote,
        images: await ref.read(imageStoreProvider.future),
      );
      final r = await engine.sync(
        onProgress: (p) => state = SyncState(
          phase: SyncPhase.syncing,
          lastSyncAt: state.lastSyncAt,
          stage: p.stage,
          imagesDone: p.imagesDone,
          imagesTotal: p.imagesTotal,
          isFirstSync: first,
        ),
      );
      if (email != null) {
        ref.read(settingsProvider.notifier).setSyncedAccount(email);
      }
      state = SyncState(
        phase: SyncPhase.idle,
        lastSyncAt: DateTime.now(),
        lastResult: r,
      );
      return true;
    } on SyncFormatException catch (e) {
      state = SyncState(
        phase: SyncPhase.error,
        lastSyncAt: state.lastSyncAt,
        message: e.message,
        isFirstSync: first,
        needsAppUpdate: true,
      );
      return true;
    } on SyncAuthException catch (e) {
      state = SyncState(
        phase: SyncPhase.error,
        lastSyncAt: state.lastSyncAt,
        message: e.message,
        isFirstSync: first,
      );
      return true;
    } catch (e) {
      state = SyncState(
        phase: SyncPhase.error,
        lastSyncAt: state.lastSyncAt,
        message: l10nStatic.syncFailed('$e'),
        isFirstSync: first,
      );
      return true;
    } finally {
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
