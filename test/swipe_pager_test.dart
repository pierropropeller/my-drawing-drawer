import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/sliding_pills.dart';
import 'package:huakeng/ui/common/swipe_pager.dart';

/// D-118：內容跟著手指走、放手過 30% 換頁、pill 深色底跟著進度。
void main() {
  late ValueNotifier<double> progress;
  late int current;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                SlidingPillRow(
                  count: 4,
                  progress: progress,
                  fill: Colors.white,
                  border: Colors.grey,
                  capsuleColor: Colors.black,
                  pill: (context, i, mix, decorated) => GestureDetector(
                    onTap: () => setState(() => current = i),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('pill$i'),
                    ),
                  ),
                ),
                Expanded(
                  child: SwipePager<int>(
                    order: const [0, 1, 2, 3],
                    current: current,
                    progress: progress,
                    onChanged: (v) => setState(() => current = v),
                    itemBuilder: (context, i) => ListView(
                      key: PageStorageKey('list$i'),
                      children: [
                        for (var r = 0; r < 40; r++)
                          SizedBox(height: 50, child: Text('p$i r$r')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    progress = ValueNotifier(0);
    current = 0;
  });

  testWidgets('拉的時候兩頁一起動、進度是小數；放手過 30% 換到下一頁', (tester) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(400, 400));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-300, 0));
    await tester.pump();
    expect(progress.value, closeTo(320 / 800, 0.05));
    expect(find.text('p1 r0'), findsOneWidget); // 隔壁頁已經露出來
    await g.up();
    await tester.pumpAndSettle();
    expect(current, 1);
    expect(progress.value, 1);
  });

  testWidgets('拉不夠 30% 又慢：彈回原頁', (tester) async {
    await pump(tester);
    final g = await tester.startGesture(const Offset(400, 400));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pumpAndSettle();
    expect(current, 0);
    expect(progress.value, 0);
  });

  testWidgets('第一頁往右拉：只回彈，不循環', (tester) async {
    await pump(tester);
    await tester.dragFrom(const Offset(400, 400), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(current, 0);
  });

  testWidgets('點 pill 跳兩格：直接滑到目標，不經過中間那頁的進度停留；各頁記住捲動位置', (tester) async {
    await pump(tester);
    await tester.drag(find.text('p0 r3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pill2'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress.value, inExclusiveRange(0.0, 2.0));
    await tester.pumpAndSettle();
    expect(progress.value, 2);
    expect(find.text('p2 r0'), findsOneWidget);
    await tester.tap(find.text('pill0'));
    await tester.pumpAndSettle();
    expect(find.text('p0 r0'), findsNothing); // 第一頁仍在捲過的位置
  });

  testWidgets('邊緣 24px 起手不換頁（保留返回手勢）', (tester) async {
    await pump(tester);
    await tester.dragFrom(const Offset(790, 400), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(current, 0);
  });
}
