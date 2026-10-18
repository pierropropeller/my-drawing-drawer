import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/dismissible_preview.dart';

/// 預覽頁共用手勢：點一下收起／叫出 UI、垂直拖曳退出、邊緣水平拖曳退出、放大時不退出。
void main() {
  const pageKey = Key('page');
  const zoomBtn = Key('zoom');

  /// 把一個預覽頁 push 在首頁上；回傳 navigator。
  Future<GlobalKey<NavigatorState>> pumpPreview(
    WidgetTester tester, {
    int pages = 1,
    int initialPage = 0,
    void Function(PageController)? onController,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const Text('home')),
    );
    final controller = PageController(initialPage: initialPage);
    addTearDown(controller.dispose);
    onController?.call(controller);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => DismissiblePreview(
          background: Colors.black,
          child: Scaffold(
            key: pageKey,
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                const PreviewChrome(
                  child: SizedBox(height: 60, child: Text('header')),
                ),
                Expanded(
                  child: PreviewMediaArea(
                    pageController: controller,
                    child: PageView.builder(
                      controller: controller,
                      physics: const ClampingScrollPhysics(),
                      itemCount: pages,
                      itemBuilder: (_, i) => Builder(
                        builder: (ctx) => ColoredBox(
                          color: Colors.grey,
                          child: Center(
                            child: ElevatedButton(
                              key: i == initialPage ? zoomBtn : null,
                              // 模擬「這張圖放大中」。
                              onPressed: () =>
                                  PreviewScope.maybeOf(ctx)!.setZoomed(i, true),
                              child: Text('image $i'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const PreviewChrome(
                  child: SizedBox(height: 60, child: Text('footer')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return nav;
  }

  double chromeOpacity(WidgetTester tester, String text) => tester
      .widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      )
      .opacity;

  // 圖片區中央空白處（不點到按鈕）。
  Offset blank(WidgetTester tester) =>
      tester.getTopLeft(find.byType(PreviewMediaArea)) + const Offset(30, 200);

  testWidgets('點一下圖片：標題列／操作列收起，再點一下叫出', (tester) async {
    await pumpPreview(tester);
    expect(chromeOpacity(tester, 'header'), 1);
    await tester.tapAt(blank(tester));
    await tester.pumpAndSettle();
    expect(chromeOpacity(tester, 'header'), 0);
    expect(chromeOpacity(tester, 'footer'), 0);
    // 收起時不可點（IgnorePointer）。
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.text('header'),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    await tester.tapAt(blank(tester));
    await tester.pumpAndSettle();
    expect(chromeOpacity(tester, 'header'), 1);
    expect(chromeOpacity(tester, 'footer'), 1);
  });

  testWidgets('垂直拖曳超過門檻：放手後 pop', (tester) async {
    await pumpPreview(tester);
    await tester.dragFrom(blank(tester), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('向上拖也能退出', (tester) async {
    await pumpPreview(tester);
    await tester.dragFrom(
      blank(tester) + const Offset(0, 300),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsNothing);
  });

  testWidgets('未過門檻：彈回原位，頁面還在，UI 狀態不變', (tester) async {
    await pumpPreview(tester);
    final before = tester.getTopLeft(find.byType(PageView));
    final g = await tester.startGesture(blank(tester));
    await g.moveBy(const Offset(0, 50));
    await tester.pump();
    // 拖曳中：圖片跟手位移、標題列淡出。
    expect(tester.getTopLeft(find.byType(PageView)).dy, greaterThan(before.dy));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsOneWidget);
    expect(tester.getTopLeft(find.byType(PageView)), before);
    expect(chromeOpacity(tester, 'header'), 1);
    // 放手後不算點一下（UI 沒被收起）。
    expect(chromeOpacity(tester, 'footer'), 1);
  });

  testWidgets('距離不夠但速度夠（快速一甩）：pop', (tester) async {
    await pumpPreview(tester);
    await tester.flingFrom(blank(tester), const Offset(0, 60), 2500);
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsNothing);
  });

  testWidgets('拖曳中背景漸淡（露出後面的頁面）', (tester) async {
    await pumpPreview(tester);
    ColoredBox bg() => tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(DismissiblePreview),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(bg().color.a, 1);
    final g = await tester.startGesture(blank(tester));
    await g.moveBy(const Offset(0, 150));
    await tester.pump();
    expect(bg().color.a, lessThan(1));
    expect(bg().color.a, greaterThan(0));
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('已放大：垂直拖曳不退出', (tester) async {
    await pumpPreview(tester);
    await tester.tap(find.byKey(zoomBtn));
    await tester.pump();
    await tester.dragFrom(blank(tester), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsOneWidget);
  });

  testWidgets('兩指操作：不退出', (tester) async {
    await pumpPreview(tester);
    final a = await tester.startGesture(blank(tester));
    final b = await tester.startGesture(blank(tester) + const Offset(100, 0));
    await a.moveBy(const Offset(0, 300));
    await b.moveBy(const Offset(0, 300));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsOneWidget);
  });

  group('多張圖（PageView）', () {
    testWidgets('中間那張：水平拖曳只是切換圖片，不退出', (tester) async {
      await pumpPreview(tester, pages: 3, initialPage: 1);
      await tester.dragFrom(blank(tester), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsOneWidget);
      expect(find.text('image 2'), findsOneWidget);
    });

    testWidgets('第一張再往右拖：退出', (tester) async {
      await pumpPreview(tester, pages: 3, initialPage: 0);
      await tester.dragFrom(blank(tester), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsNothing);
    });

    testWidgets('第一張往左拖：切到第二張，不退出', (tester) async {
      await pumpPreview(tester, pages: 3, initialPage: 0);
      await tester.dragFrom(blank(tester), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsOneWidget);
      expect(find.text('image 1'), findsOneWidget);
    });

    testWidgets('最後一張再往左拖：退出；往右拖則是回上一張', (tester) async {
      await pumpPreview(tester, pages: 3, initialPage: 2);
      await tester.dragFrom(blank(tester), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsOneWidget);
      expect(find.text('image 1'), findsOneWidget);
      // 回到最後一張再往左拖。
      await tester.dragFrom(blank(tester), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('image 2'), findsOneWidget);
      await tester.dragFrom(blank(tester), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsNothing);
    });

    testWidgets('多張圖時垂直拖曳照樣退出', (tester) async {
      await pumpPreview(tester, pages: 3, initialPage: 1);
      await tester.dragFrom(blank(tester), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(pageKey), findsNothing);
    });
  });

  testWidgets('頁面攔截返回時（pop 被擋）彈回原位', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: nav, home: const Text('home')),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PopScope(
          canPop: false,
          child: DismissiblePreview(
            background: Colors.black,
            child: const Scaffold(
              key: pageKey,
              body: PreviewMediaArea(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(SizedBox).last);
    await tester.dragFrom(const Offset(400, 600), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsOneWidget);
    expect(tester.getTopLeft(find.byType(SizedBox).last), before);
  });
}
