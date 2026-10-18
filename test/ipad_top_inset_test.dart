import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/window_top_inset.dart';

/// iPad 頁面頂部讓位：標題列起點 ≥ 保底值；手機、Android 不變。
void main() {
  const header = Key('header');

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size window,
    required Size display,
    required double systemTop,
    required TargetPlatform platform,
    NativeWindowInsets? native,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    tester.view.display.size = display;
    tester.view.padding = FakeViewPadding(top: systemTop);
    tester.view.viewPadding = FakeViewPadding(top: systemTop);
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TabletTopInsetGuard(loadNative: () async => native, child: child!),
        // 和實際頁面一樣：Scaffold(body: SafeArea(child: 標題列))。
        home: const Scaffold(
          body: SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(key: header, width: 40, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(); // 原生資訊載入後重建
  }

  double headerTop(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(header)).dy;

  /// 以指定平台跑；結束前還原（invariant 檢查之前）。
  void iosTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  group('iPad（iOS）', () {
    const sizes = <String, Size>{
      '全螢幕直向 834x1194': Size(834, 1194),
      '全螢幕橫向 1194x834': Size(1194, 834),
      '大視窗 1366x1024': Size(1366, 1024),
      '視窗模式 700x600': Size(700, 600),
      '窄分屏 400x900': Size(400, 900),
    };
    for (final e in sizes.entries) {
      iosTest('${e.key}：系統 top=24 → 標題列起點 ≥ ${kTabletTopInsetFloor.toInt()}', (
        tester,
      ) async {
        await pumpPage(
          tester,
          window: e.value,
          display: const Size(834, 1194),
          systemTop: 24,
          platform: TargetPlatform.iOS,
        );
        expect(headerTop(tester), greaterThanOrEqualTo(kTabletTopInsetFloor));
      });
      iosTest('${e.key}：系統 top=0（視窗模式）→ 仍 ≥ 保底值', (tester) async {
        await pumpPage(
          tester,
          window: e.value,
          display: const Size(834, 1194),
          systemTop: 0,
          platform: TargetPlatform.iOS,
        );
        expect(headerTop(tester), kTabletTopInsetFloor);
      });
    }

    iosTest('系統給的 top 比保底大就維持（不縮小）', (tester) async {
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 40,
        platform: TargetPlatform.iOS,
      );
      expect(headerTop(tester), 40);
    });

    iosTest('原生回報較大的 top 就採用；回報 0 不會蓋掉保底', (tester) async {
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, top: 34),
      );
      expect(headerTop(tester), 34);
    });

    iosTest('原生回報 0 不會蓋掉保底', (tester) async {
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, top: 0),
      );
      expect(headerTop(tester), kTabletTopInsetFloor);
    });

    iosTest('原生說是 iPad 就算 iPad（即使螢幕尺寸讀不到）', (tester) async {
      await pumpPage(
        tester,
        window: const Size(400, 900),
        display: Size.zero,
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true),
      );
      expect(headerTop(tester), kTabletTopInsetFloor);
    });
  });

  group('不變的情況', () {
    iosTest('iPhone（iOS、螢幕 390x844）：有瀏海的 top 原樣', (tester) async {
      await pumpPage(
        tester,
        window: const Size(390, 844),
        display: const Size(390, 844),
        systemTop: 47,
        platform: TargetPlatform.iOS,
      );
      expect(headerTop(tester), 47);
    });

    iosTest('iPhone：top=0 維持 0（不套保底）', (tester) async {
      await pumpPage(
        tester,
        window: const Size(390, 844),
        display: const Size(390, 844),
        systemTop: 0,
        platform: TargetPlatform.iOS,
      );
      expect(headerTop(tester), 0);
    });

    iosTest('原生說不是 iPad 就不是（即使螢幕很大）', (tester) async {
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: false),
      );
      expect(headerTop(tester), 0);
    });

    iosTest('Android 平板尺寸：不調整', (tester) async {
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 24,
        platform: TargetPlatform.android,
      );
      expect(headerTop(tester), 24);
      await pumpPage(
        tester,
        window: const Size(834, 1194),
        display: const Size(834, 1194),
        systemTop: 0,
        platform: TargetPlatform.android,
      );
      expect(headerTop(tester), 0);
    });
  });

  test('resolveTopInset：純函式', () {
    double r(double c, {bool ios = true, bool tablet = true, double? n}) =>
        resolveTopInset(
          current: c,
          isIos: ios,
          isTablet: tablet,
          native: n == null ? null : NativeWindowInsets(top: n),
        );
    expect(r(24), 28);
    expect(r(0), 28);
    expect(r(0, n: 31), 31);
    expect(r(50, n: 31), 50);
    expect(r(0, tablet: false), 0);
    expect(r(0, ios: false), 0);
  });

  test('NativeWindowInsets.fromMap：容錯', () {
    expect(NativeWindowInsets.fromMap(null), isNull);
    expect(NativeWindowInsets.fromMap('x'), isNull);
    final v = NativeWindowInsets.fromMap({
      'isPad': true,
      'top': 24,
      'leading': 'bad',
      'windowed': false,
    })!;
    expect(v.isPad, isTrue);
    expect(v.top, 24.0);
    expect(v.leading, isNull);
    expect(v.windowed, isFalse);
  });

  test('原生通道不存在時回 null（不丟例外）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('io.molly.drawer/window'),
          (call) async => throw MissingPluginException(),
        );
    expect(await WindowInsetsChannel.fetch(), isNull);
  });
}
