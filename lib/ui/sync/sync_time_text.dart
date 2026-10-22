import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/relative_time.dart';

/// 現在時間；測試可覆寫成假時鐘。
final syncClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 完成時間的相對文字（D-109 ②）：每到文字該改變的那一刻才更新（約每分鐘），
/// 計時器只在這個 widget 存在（完成／部分失敗狀態顯示中）時存在。
class SyncRelativeTimeText extends ConsumerStatefulWidget {
  const SyncRelativeTimeText({super.key, required this.at, this.style});
  final DateTime at;
  final TextStyle? style;

  @override
  ConsumerState<SyncRelativeTimeText> createState() =>
      _SyncRelativeTimeTextState();
}

class _SyncRelativeTimeTextState extends ConsumerState<SyncRelativeTimeText> {
  Timer? _timer;

  DateTime _now() => ref.read(syncClockProvider)();

  void _schedule() {
    _timer?.cancel();
    final wait = syncRelativeTimeNextChange(widget.at, _now());
    if (wait == null) return;
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(SyncRelativeTimeText old) {
    super.didUpdateWidget(old);
    if (old.at != widget.at) _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      syncRelativeTime(widget.at, _now()),
      key: const Key('sync-time-text'),
      style: widget.style,
    );
  }
}
