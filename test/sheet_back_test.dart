import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ch extends ShareChannel {
  _Ch(this.initial);
  final List<String> initial;
  void Function(List<String>)? onShare;
  @override
  Future<List<String>> getInitialShare() async => initial;
  @override
  void setOnShare(void Function(List<String> paths)? cb) => onShare = cb;
}

/// 系統返回鍵：有 sheet 開著時只能關 sheet，不能動到後面的頁面或分頁。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late _Ch channel;

  setUp(() async {
    navBarHiddenCount.value = 0;
    SharedPreferences.setMockInitialValues({'onboarded': true});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('sheet_back');
    await Directory('${tmp.path}/images').create(recursive: true);
    await db.createPit(name: '坑A');
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    List<String> share = const [],
  }) async {
    channel = _Ch(share);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          shareChannelProvider.overrideWithValue(channel),
          sharedPrefsProvider.overrideWithValue(prefs),
        ],
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  const behind = ValueKey('behindPage');

  /// 在「坑」分頁推一個頁面當「後面的頁」。
  Future<void> pushBehind(WidgetTester tester) async {
    final ctx = tester.element(find.byType(PitsPage));
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(key: behind, body: Text('後面的頁')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(behind), findsOneWidget);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Android 預測式返回（手勢導覽）：start → update → commit，走 flutter/backgesture。
  Future<void> predictiveBack(WidgetTester tester) async {
    Future<void> send(String method, [Map<String, Object?>? args]) async {
      final data = SystemChannels.backGesture.codec.encodeMethodCall(
        MethodCall(method, args),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.backGesture.name,
        data,
        (_) {},
      );
    }

    final event = <String, Object?>{
      'touchOffset': <double>[5, 400],
      'progress': 0.1,
      'swipeEdge': 0,
    };
    await send('startBackGesture', event);
    await tester.pump(const Duration(milliseconds: 50));
    await send('updateBackGestureProgress', {...event, 'progress': 0.5});
    await tester.pump(const Duration(milliseconds: 50));
    await send('commitBackGesture');
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> openSheet(
    WidgetTester tester,
    BuildContext ctx, {
    required bool root,
  }) async {
    showModalBottomSheet<void>(
      context: ctx,
      useRootNavigator: root,
      builder: (_) => const SizedBox(height: 200, child: Text('SHEET')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SHEET'), findsOneWidget);
  }

  for (final root in [true, false]) {
    testWidgets('返回鍵只關 sheet（${root ? "最上層" : "分頁"} Navigator）', (
      tester,
    ) async {
      await pumpApp(tester);
      await pushBehind(tester);
      await openSheet(tester, tester.element(find.byKey(behind)), root: root);

      await back(tester);
      expect(find.text('SHEET'), findsNothing);
      expect(find.byKey(behind), findsOneWidget);

      // 再按一次才是返回上一頁。
      await back(tester);
      expect(find.byKey(behind), findsNothing);
      await unmount(tester);
    });
  }

  for (final root in [true, false]) {
    testWidgets('預測式返回手勢只關 sheet（${root ? "最上層" : "分頁"} Navigator）', (
      tester,
    ) async {
      await pumpApp(tester);
      await pushBehind(tester);
      await openSheet(tester, tester.element(find.byKey(behind)), root: root);

      await predictiveBack(tester);
      expect(find.text('SHEET'), findsNothing);
      expect(find.byKey(behind), findsOneWidget);

      await predictiveBack(tester);
      expect(find.byKey(behind), findsNothing);
      await unmount(tester);
    });
  }

  testWidgets('在「目標」分頁開最上層 sheet：返回鍵不切回「坑」', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('目標'));
    await tester.pump();
    await settle(tester);
    await openSheet(tester, tester.element(find.byType(GoalsPage)), root: true);
    await back(tester);
    expect(find.text('SHEET'), findsNothing);
    expect(find.byType(GoalsPage), findsOneWidget);
    expect(find.byType(PitsPage), findsNothing);
    await unmount(tester);
  });

  testWidgets('分享進來的「加入到」sheet：返回鍵只關 sheet', (tester) async {
    final f = File('${tmp.path}/in.png')..writeAsBytesSync(_png);
    await pumpApp(tester, share: [f.path]);
    expect(find.byType(ShareSheet), findsOneWidget);
    await back(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(find.byType(PitsPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('預測式返回手勢：分享「加入到」sheet 開著，後面的頁不會被退掉', (tester) async {
    final f = File('${tmp.path}/in.png')..writeAsBytesSync(_png);
    await pumpApp(tester);
    await pushBehind(tester);
    channel.onShare!([f.path]);
    await settle(tester);
    expect(find.byType(ShareSheet), findsOneWidget);
    await predictiveBack(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(find.byKey(behind), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('預測式返回手勢：被藏起來的分頁裡的頁面不認領手勢', (tester) async {
    await pumpApp(tester);
    await pushBehind(tester);
    await tester.tap(find.text('目標'));
    await tester.pump();
    await settle(tester);
    expect(find.byType(GoalsPage), findsOneWidget);
    await predictiveBack(tester);
    // 「坑」分頁的頁面還在（只是被藏起來），不會被目標分頁的返回退掉。
    expect(find.byKey(behind, skipOffstage: false), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('分享 sheet 開著時，後面有頁面也不會被返回', (tester) async {
    final f = File('${tmp.path}/in.png')..writeAsBytesSync(_png);
    await pumpApp(tester);
    await pushBehind(tester);
    channel.onShare!([f.path]);
    await settle(tester);
    expect(find.byType(ShareSheet), findsOneWidget);
    // 分享會導向「坑」分頁的頁面（取消則不動）；取消時後面的頁必須還在。
    await back(tester);
    expect(find.byType(ShareSheet), findsNothing);
    expect(find.byKey(behind), findsOneWidget);
    await unmount(tester);
  });
}

final _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
