import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_driver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 只數 syncNow 被呼叫幾次，不真的同步。
class _CountingSync extends SyncController {
  static int calls = 0;
  @override
  Future<bool> syncNow() async {
    calls++;
    return true;
  }
}

/// 前景同步的觸發點（iOS／Android 共用，沒有平台專屬路徑）：啟動、定時、回到前景、
/// 恢復網絡；iPad 分屏時 inactive 仍算前景；背景（paused）不同步。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late StreamController<bool> online;

  setUp(() {
    _CountingSync.calls = 0;
    db = AppDatabase(NativeDatabase.memory());
    online = StreamController<bool>();
  });

  tearDown(() async {
    await online.close();
  });

  Future<void> pumpDriver(WidgetTester tester, {String? account}) async {
    SharedPreferences.setMockInitialValues({
      if (account != null) 'accountEmail': account,
      'onboarded': true,
      'refreshMinutes': 5,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          onlineProvider.overrideWith((ref) => online.stream),
          syncControllerProvider.overrideWith(_CountingSync.new),
        ],
        child: const MaterialApp(home: SyncDriver(child: SizedBox())),
      ),
    );
    online.add(true);
    await tester.pump();
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  void lifecycle(WidgetTester tester, AppLifecycleState s) =>
      tester.binding.handleAppLifecycleStateChanged(s);

  testWidgets('啟動即同步，之後依間隔（5 分鐘）定時刷新', (tester) async {
    await pumpDriver(tester, account: 'a@b.c');
    expect(_CountingSync.calls, 1);
    await tester.pump(const Duration(minutes: 5));
    expect(_CountingSync.calls, 2);
    await tester.pump(const Duration(minutes: 5));
    expect(_CountingSync.calls, 3);
    await unmount(tester);
  });

  testWidgets('沒連結帳號就不同步', (tester) async {
    await pumpDriver(tester);
    await tester.pump(const Duration(minutes: 11));
    expect(_CountingSync.calls, 0);
    await unmount(tester);
  });

  testWidgets('背景（paused）不同步；回到前景立刻補一次', (tester) async {
    await pumpDriver(tester, account: 'a@b.c');
    expect(_CountingSync.calls, 1);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 11));
    expect(_CountingSync.calls, 1);
    lifecycle(tester, AppLifecycleState.hidden);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(_CountingSync.calls, 2);
    await unmount(tester);
  });

  testWidgets('iPad 分屏：畫匣是 inactive（可見但沒焦點）時定時刷新照跑', (tester) async {
    await pumpDriver(tester, account: 'a@b.c');
    lifecycle(tester, AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 5));
    expect(_CountingSync.calls, 2);
    await tester.pump(const Duration(minutes: 5));
    expect(_CountingSync.calls, 3);
    await unmount(tester);
  });

  testWidgets('inactive → resumed 離上次同步不到 30 秒不重複觸發', (tester) async {
    await pumpDriver(tester, account: 'a@b.c');
    expect(_CountingSync.calls, 1);
    lifecycle(tester, AppLifecycleState.inactive);
    lifecycle(tester, AppLifecycleState.resumed);
    await tester.pump();
    expect(_CountingSync.calls, 1);
    await unmount(tester);
  });

  testWidgets('恢復網絡後立刻同步', (tester) async {
    await pumpDriver(tester, account: 'a@b.c');
    expect(_CountingSync.calls, 1);
    online.add(false);
    await tester.pump();
    expect(_CountingSync.calls, 1);
    online.add(true);
    await tester.pump();
    expect(_CountingSync.calls, 2);
    await unmount(tester);
  });
}
