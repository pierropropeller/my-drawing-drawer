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
    // 視窗尺寸 → 是否小於螢幕（display 834x1194）。
    const sizes = <String, Size>{
      '全螢幕直向 834x1194': Size(834, 1194),
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
      iosTest('${e.key}：系統 top=0 → 全螢幕 28／視窗化 72', (tester) async {
        await pumpPage(
          tester,
          window: e.value,
          display: const Size(834, 1194),
          systemTop: 0,
          platform: TargetPlatform.iOS,
        );
        final windowed = e.value.width < 834 - 1 || e.value.height < 1194 - 1;
        expect(
          headerTop(tester),
          windowed ? kTabletWindowedTopInsetFloor : kTabletTopInsetFloor,
        );
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

  group('視窗控制點（原生回報）', () {
    const display = Size(1194, 834);

    iosTest('量到控制點下緣 65 → 起點 ＝ 73（下緣＋8），高於保底', (tester) async {
      await pumpPage(
        tester,
        window: const Size(582, 800),
        display: display,
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(
          isPad: true,
          windowed: true,
          controlsRight: 82,
          controlsBottom: 65,
        ),
      );
      expect(headerTop(tester), 65 + kTabletControlsGap);
    });

    iosTest('量到控制點但很矮（下緣 20）→ 以原生數字為準（不低於 28）', (tester) async {
      await pumpPage(
        tester,
        window: const Size(582, 800),
        display: display,
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(
          isPad: true,
          windowed: true,
          controlsBottom: 20,
        ),
      );
      // 下緣＋8＝28，但已有原生確切數字就以它為準，不再套 72。
      expect(headerTop(tester), 28);
    });

    iosTest('量不到控制點、windowed=true → 72', (tester) async {
      await pumpPage(
        tester,
        window: display,
        display: display,
        systemTop: 24,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, windowed: true),
      );
      expect(headerTop(tester), kTabletWindowedTopInsetFloor);
    });

    iosTest('windowed=false（即使視窗較小）→ 維持 28', (tester) async {
      await pumpPage(
        tester,
        window: const Size(700, 600),
        display: display,
        systemTop: 24,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, windowed: false),
      );
      expect(headerTop(tester), kTabletTopInsetFloor);
    });

    iosTest('全螢幕、原生沒回報控制點 → 28', (tester) async {
      await pumpPage(
        tester,
        window: display,
        display: display,
        systemTop: 24,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, windowed: false, top: 24),
      );
      expect(headerTop(tester), kTabletTopInsetFloor);
    });

    iosTest('原生通知 windowInsetsChanged：拉窗後位置跟著變', (tester) async {
      await pumpPage(
        tester,
        window: display,
        display: display,
        systemTop: 0,
        platform: TargetPlatform.iOS,
        native: const NativeWindowInsets(isPad: true, windowed: false),
      );
      expect(headerTop(tester), 28);
      Future<void> push(Map<String, Object?> args) async {
        const codec = StandardMethodCodec();
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'io.molly.drawer/window',
          codec.encodeMethodCall(MethodCall('windowInsetsChanged', args)),
          (_) {},
        );
        await tester.pump();
      }

      await push({
        'isPad': true,
        'windowed': true,
        'controlsRight': 82.0,
        'controlsBottom': 64.0,
      });
      expect(headerTop(tester), 72);
      await push({'isPad': true, 'windowed': false});
      expect(headerTop(tester), 28);
    });

    // 各種視窗尺寸：頭像列＋返回鍵都在控制點下緣（65）之下，且不溢位。
    const windows = <String, Size>{
      '390x844': Size(390, 844),
      '400x900': Size(400, 900),
      '700x1000': Size(700, 1000),
      '834x1194': Size(834, 1194),
      '1194x834': Size(1194, 834),
      '1366x1024': Size(1366, 1024),
    };
    for (final e in windows.entries) {
      iosTest('${e.key}（視窗化）：頭像／返回鍵 ≥ 控制點下緣，無溢位', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final old = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = old);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = e.value;
        tester.view.display.size = const Size(1366, 1024);
        addTearDown(() {
          tester.view.reset();
          tester.view.display.reset();
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => TabletTopInsetGuard(
              loadNative: () async => const NativeWindowInsets(
                isPad: true,
                windowed: true,
                controlsBottom: 65,
              ),
              child: child!,
            ),
            home: Scaffold(
              // 側欄頂部頭像（rail／sidebar）＋右側頁面（AppBar 返回鍵）。
              body: Row(
                children: [
                  const SafeArea(
                    right: false,
                    child: SizedBox(
                      width: 84,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          key: Key('avatar'),
                          width: 44,
                          height: 44,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Scaffold(
                      appBar: AppBar(
                        leading: const BackButton(key: Key('back')),
                      ),
                      body: const SafeArea(child: SizedBox(key: header)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.getTopLeft(find.byKey(const Key('avatar'))).dy, 73);
        expect(
          tester.getTopLeft(find.byKey(const Key('back'))).dy,
          greaterThanOrEqualTo(65),
        );
        expect(errors, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });
    }
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
    expect(
      resolveTopInset(
        current: 0,
        isIos: true,
        isTablet: true,
        windowedByGeometry: true,
      ),
      72,
    );
    expect(
      resolveTopInset(
        current: 0,
        isIos: true,
        isTablet: false,
        windowedByGeometry: true,
      ),
      0,
    );
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
      'controlsRight': 82,
      'controlsBottom': 0,
    })!;
    expect(v.controlsRight, 82.0);
    expect(v.controlsBottom, isNull);
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
