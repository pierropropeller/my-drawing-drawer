import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import 'sync_controller.dart';

/// 在前台時自動同步：啟動、回到前台、恢復網絡、本機資料變動（防抖）、以及依設定的間隔定時。
/// 一切在背景完成；使用者也可在「備份與同步」按「立即同步」。首次連結帳號時另由
/// SyncFirst 頁顯示進度（同步本身仍由 SyncController 執行，這裡只負責觸發）。
class SyncDriver extends ConsumerStatefulWidget {
  const SyncDriver({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SyncDriver> createState() => _SyncDriverState();
}

class _SyncDriverState extends ConsumerState<SyncDriver>
    with WidgetsBindingObserver {
  Timer? _periodic;
  Timer? _debounce;
  StreamSubscription<void>? _dbSub;
  bool _foreground = true;

  bool get _enabled {
    final s = ref.read(settingsProvider);
    return s.autoSync && s.accountEmail != null;
  }

  void _trigger() {
    if (_foreground && _enabled) {
      unawaited(ref.read(syncControllerProvider.notifier).syncNow());
    }
  }

  void _restartTimer() {
    _periodic?.cancel();
    final minutes = ref.read(settingsProvider).refreshMinutes;
    _periodic = Timer.periodic(Duration(minutes: minutes), (_) => _trigger());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _trigger();
      // 本機資料有變動：安靜 8 秒後上傳，避免連續編輯時一直同步。
      _dbSub = ref.read(databaseProvider).tableUpdates().listen((_) {
        if (ref.read(syncControllerProvider).phase == SyncPhase.syncing) return;
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 8), _trigger);
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _trigger();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    _debounce?.cancel();
    _dbSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.refreshMinutes),
      (_, _) => _restartTimer(),
    );
    ref.listen(settingsProvider.select((s) => s.accountEmail), (prev, next) {
      if (prev == null && next != null) _trigger();
    });
    ref.listen(onlineProvider, (prev, next) {
      if (next.value == true && prev?.value == false) _trigger(); // 恢復網絡後自動上傳
    });
    return widget.child;
  }
}
