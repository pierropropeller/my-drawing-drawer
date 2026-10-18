import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import 'sync_controller.dart';

/// 在前台時自動同步：啟動、回到前台、恢復網絡、本機資料變動（防抖）、以及依設定的間隔定時。
/// 一切在背景完成；使用者也可在「備份與同步」按「立即同步」。首次連結帳號時另由
/// SyncFirst 頁顯示進度（同步本身仍由 SyncController 執行，這裡只負責觸發）。
///
/// 全部是 Dart 端的前景觸發（Timer／生命週期／connectivity_plus），沒有 Android 專屬的
/// WorkManager 或前景服務，iOS 與 Android 同一套。iOS 沒有背景執行：App 在背景時不會同步，
/// 回到前景（resumed）立刻補一次。iPad 分屏時畫匣可能長時間是 `inactive`（焦點在另一個 App，
/// 但畫匣仍可見），這段時間照樣算前景，定時刷新不停。
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

  /// 進過真正的背景（hidden／paused／detached）還沒回到 resumed。
  bool _wentBackground = false;
  DateTime? _lastTrigger;

  /// 暫時性失敗（逾時、斷線、看門狗中止）後的自動重試：依序等這些時間再試，用完就交給
  /// 平常的觸發（回前景、定時、資料變動）。同步成功就歸零。
  static const retryDelays = [
    Duration(seconds: 15),
    Duration(seconds: 60),
    Duration(seconds: 180),
  ];
  Timer? _retry;
  int _retries = 0;

  /// 從 inactive 回到 resumed（下拉通知中心、系統對話框、分屏切換焦點）時，離上次觸發
  /// 不到這麼久就不重複觸發。
  static const _resumeCooldown = Duration(seconds: 30);

  bool get _enabled {
    final s = ref.read(settingsProvider);
    return s.autoSync && s.accountEmail != null;
  }

  void _trigger() {
    if (_foreground && _enabled) {
      _lastTrigger = DateTime.now();
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
    // inactive＝畫面還看得到但沒有焦點（iPad 分屏／Slide Over、系統對話框）：仍算前景。
    // hidden／paused／detached＝真的在背景（iOS 會被凍結）。
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wentBackground = true;
    }
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state != AppLifecycleState.resumed) return;
    // 從背景回來（iOS 回前景一定先經過 inactive）：一律立刻補一次；
    // 只是 inactive → resumed（下拉通知中心、分屏切換焦點）則 30 秒內不重複。
    final cameBack = _wentBackground;
    _wentBackground = false;
    final last = _lastTrigger;
    final recent =
        last != null && DateTime.now().difference(last) < _resumeCooldown;
    if (cameBack || !recent) _trigger();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodic?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
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
    ref.listen(syncControllerProvider, (prev, next) {
      if (prev?.phase == next.phase) return;
      if (next.phase == SyncPhase.idle) {
        _retries = 0;
        _retry?.cancel();
      } else if (next.phase == SyncPhase.error &&
          next.retryable &&
          _retries < retryDelays.length) {
        _retry?.cancel();
        _retry = Timer(retryDelays[_retries++], _trigger);
      }
    });
    ref.listen(onlineProvider, (prev, next) {
      if (next.value == true && prev?.value == false) _trigger(); // 恢復網絡後自動上傳
    });
    return widget.child;
  }
}
