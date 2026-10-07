import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import 'drive_remote.dart';
import 'google_auth.dart';
import 'remote.dart';
import 'sync_engine.dart';

enum SyncPhase { idle, syncing, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.message,
    this.lastResult,
  });
  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final String? message;
  final SyncResult? lastResult;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    String? message,
    SyncResult? lastResult,
  }) => SyncState(
    phase: phase ?? this.phase,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    message: message,
    lastResult: lastResult ?? this.lastResult,
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
    state = state.copyWith(phase: SyncPhase.syncing);
    try {
      final engine = SyncEngine(
        db: ref.read(databaseProvider),
        remote: remote,
        images: await ref.read(imageStoreProvider.future),
      );
      final r = await engine.sync();
      state = SyncState(
        phase: SyncPhase.idle,
        lastSyncAt: DateTime.now(),
        lastResult: r,
      );
      return true;
    } on SyncAuthException catch (e) {
      state = SyncState(
        phase: SyncPhase.error,
        lastSyncAt: state.lastSyncAt,
        message: e.message,
      );
      return true;
    } catch (e) {
      state = SyncState(
        phase: SyncPhase.error,
        lastSyncAt: state.lastSyncAt,
        message: '同步失敗：$e',
      );
      return true;
    } finally {
      _running = false;
    }
  }

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
    ref.read(settingsProvider.notifier).setAccount(null);
    state = const SyncState();
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);
