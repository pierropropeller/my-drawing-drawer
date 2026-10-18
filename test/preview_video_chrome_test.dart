import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/ui/common/dismissible_preview.dart';
import 'package:huakeng/ui/common/video_player_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 預覽頁裡的影片：點一下＝影片控制列＋頁面 UI 一起顯示／隱藏（不互相打架）。
class _Fake extends ChangeNotifier implements MediaPlayback {
  bool _playing = false;
  @override
  bool get isInitialized => true;
  @override
  bool get isPlaying => _playing;
  @override
  bool get hasError => false;
  @override
  Duration get position => const Duration(seconds: 3);
  @override
  Duration get duration => const Duration(seconds: 24);
  @override
  double get aspectRatio => 16 / 9;
  @override
  double get volume => 1;
  @override
  bool get isLooping => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play() async {
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Widget buildView(BuildContext context) =>
      const IgnorePointer(child: SizedBox.expand());
}

void main() {
  Future<_Fake> pump(WidgetTester tester, {required bool playing}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _Fake().._playing = playing;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: DismissiblePreview(
            background: Colors.black,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  const PreviewChrome(child: Text('pageHeader')),
                  Expanded(
                    child: PreviewMediaArea(
                      child: VideoSurface(
                        playback: fake,
                        onFullscreen: () {},
                        hideDelay: const Duration(seconds: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return fake;
  }

  double op(WidgetTester tester, Finder f) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: f, matching: find.byType(AnimatedOpacity)).first,
      )
      .opacity;

  final bar = find.byKey(const ValueKey('videoControlBar'));

  testWidgets('播放中：點影片 → 控制列與頁面 UI 一起收起，再點一起叫出', (tester) async {
    await pump(tester, playing: true);
    expect(op(tester, bar), 1);
    expect(op(tester, find.text('pageHeader')), 1);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(op(tester, bar), 0);
    expect(op(tester, find.text('pageHeader')), 0);
    await tester.tapAt(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(op(tester, bar), 1);
    expect(op(tester, find.text('pageHeader')), 1);
    // 之後控制列 2 秒自動隱藏；頁面 UI 維持（不打架）。
    await tester.pump(const Duration(seconds: 3));
    expect(op(tester, bar), 0);
    expect(op(tester, find.text('pageHeader')), 1);
    // 這時點一下：兩個都顯示（頁面 UI 本來就在，不會被收掉）。
    await tester.tapAt(const Offset(400, 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(op(tester, bar), 1);
    expect(op(tester, find.text('pageHeader')), 1);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('暫停中（控制列固定顯示）：點一下仍可一起收起', (tester) async {
    await pump(tester, playing: false);
    expect(op(tester, bar), 1);
    await tester.tapAt(const Offset(400, 400));
    await tester.pumpAndSettle();
    expect(op(tester, bar), 0);
    expect(op(tester, find.text('pageHeader')), 0);
  });

  testWidgets('影片頁一樣可垂直拖曳退出（未過門檻彈回）', (tester) async {
    await pump(tester, playing: false);
    final g = await tester.startGesture(const Offset(400, 400));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    // 拖曳不算點一下：UI 沒有被收起。
    expect(op(tester, find.text('pageHeader')), 1);
    expect(op(tester, bar), 1);
  });
}
