import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/drag_select.dart';

/// 測試用頁面：N 格、可切換 grid／masonry，自己管選取集合。
class _Host extends StatefulWidget {
  const _Host({this.count = 30, this.masonry = false, this.initial = const {}});
  final int count;
  final bool masonry;
  final Set<int> initial;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Set<int> selected = {...widget.initial};
  bool finished = true;
  final taps = <int>[];
  final events = <Set<int>>[];

  Widget _cell(int i) => DragSelectItem(
    index: i,
    child: GestureDetector(
      key: ValueKey('c$i'),
      onTap: () => setState(() {
        taps.add(i);
        if (!selected.remove(i)) selected.add(i);
      }),
      child: Container(
        height: widget.masonry ? 60.0 + (i % 3) * 40 : null,
        color: selected.contains(i) ? Colors.red : Colors.blue,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final grid = widget.masonry
        ? MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: widget.count,
            itemBuilder: (_, i) => _cell(i),
          )
        : GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: widget.count,
            itemBuilder: (_, i) => _cell(i),
          );
    return MaterialApp(
      home: Scaffold(
        body: DragSelectArea(
          itemCount: widget.count,
          isSelected: selected.contains,
          onChanged: (idx, done) => setState(() {
            selected = idx;
            finished = done;
            events.add(idx);
          }),
          child: grid,
        ),
      ),
    );
  }
}

_HostState _state(WidgetTester t) => t.state<_HostState>(find.byType(_Host));

Finder _c(int i) => find.byKey(ValueKey('c$i'));

Future<TestGesture> _longPressAt(WidgetTester t, Offset p) async {
  final g = await t.startGesture(p);
  await t.pump(const Duration(milliseconds: 600));
  return g;
}

void main() {
  for (final masonry in [false, true]) {
    final name = masonry ? 'masonry' : 'grid';
    group(name, () {
      testWidgets('long press selects start item', (t) async {
        await t.pumpWidget(_Host(masonry: masonry));
        final g = await _longPressAt(t, t.getCenter(_c(4)));
        expect(_state(t).selected, {4});
        await g.up();
        await t.pump();
        expect(_state(t).selected, {4});
        expect(_state(t).finished, true);
      });

      testWidgets('range select in list order and reverse shrink', (t) async {
        await t.pumpWidget(_Host(masonry: masonry));
        final g = await _longPressAt(t, t.getCenter(_c(1)));
        await g.moveTo(t.getCenter(_c(7)));
        await t.pump();
        expect(_state(t).selected, {for (var i = 1; i <= 7; i++) i});
        // 拖回 index 4：超出的取消
        await g.moveTo(t.getCenter(_c(4)));
        await t.pump();
        expect(_state(t).selected, {1, 2, 3, 4});
        // 拖到起點之前：範圍反向
        await g.moveTo(t.getCenter(_c(0)));
        await t.pump();
        expect(_state(t).selected, {0, 1});
        await g.up();
        await t.pump();
        expect(_state(t).selected, {0, 1});
        expect(_state(t).finished, true);
      });

      testWidgets('keeps previously selected items outside range', (t) async {
        await t.pumpWidget(_Host(masonry: masonry, initial: const {10, 11}));
        final g = await _longPressAt(t, t.getCenter(_c(0)));
        await g.moveTo(t.getCenter(_c(2)));
        await t.pump();
        expect(_state(t).selected, {0, 1, 2, 10, 11});
        await g.up();
      });

      testWidgets('start on selected item = continuous deselect', (t) async {
        await t.pumpWidget(
          _Host(masonry: masonry, initial: const {0, 1, 2, 3, 4, 5}),
        );
        final g = await _longPressAt(t, t.getCenter(_c(1)));
        expect(_state(t).selected, {0, 2, 3, 4, 5});
        await g.moveTo(t.getCenter(_c(3)));
        await t.pump();
        expect(_state(t).selected, {0, 4, 5});
        await g.moveTo(t.getCenter(_c(2)));
        await t.pump();
        expect(_state(t).selected, {0, 3, 4, 5});
        await g.up();
        await t.pump();
      });

      testWidgets('no selection without long press; tap still toggles', (
        t,
      ) async {
        await t.pumpWidget(_Host(masonry: masonry));
        final g = await t.startGesture(t.getCenter(_c(4)));
        await g.moveBy(const Offset(0, -200));
        await t.pump();
        await g.moveBy(const Offset(0, -100));
        await t.pump(const Duration(milliseconds: 700));
        await g.up();
        await t.pump();
        expect(_state(t).selected, isEmpty);
        expect(_state(t).events, isEmpty);
        Scrollable.of(t.element(_c(4))).position.jumpTo(0);
        await t.pump();
        await t.tap(_c(0));
        await t.pump();
        expect(_state(t).selected, {0});
        expect(_state(t).events, isEmpty);
      });

      testWidgets('auto-scrolls near bottom edge and keeps selecting', (
        t,
      ) async {
        await t.pumpWidget(_Host(masonry: masonry, count: 90));
        final scrollable = Scrollable.of(t.element(_c(0)));
        expect(scrollable.position.pixels, 0);
        final g = await _longPressAt(t, t.getCenter(_c(0)));
        final h = t.view.physicalSize.height / t.view.devicePixelRatio;
        await g.moveTo(Offset(100, h - 10));
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(scrollable.position.pixels, greaterThan(100));
        expect(_state(t).selected.length, greaterThan(8));
        // 離開邊緣區就停
        await g.moveTo(Offset(100, h / 2));
        await t.pump();
        final stopped = scrollable.position.pixels;
        await t.pump(const Duration(milliseconds: 300));
        expect(scrollable.position.pixels, stopped);
        await g.up();
        await t.pump();
      });

      testWidgets('auto-scrolls up near top edge', (t) async {
        await t.pumpWidget(_Host(masonry: masonry, count: 90));
        final scrollable = Scrollable.of(t.element(_c(0)));
        scrollable.position.jumpTo(600);
        await t.pump();
        final g = await _longPressAt(t, const Offset(100, 300));
        await g.moveTo(const Offset(100, 6));
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(scrollable.position.pixels, lessThan(600));
        await g.up();
        await t.pump();
      });

      testWidgets('no auto-scroll away from edges', (t) async {
        await t.pumpWidget(_Host(masonry: masonry, count: 90));
        final scrollable = Scrollable.of(t.element(_c(0)));
        final g = await _longPressAt(t, t.getCenter(_c(0)));
        await g.moveTo(const Offset(100, 300));
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
        expect(scrollable.position.pixels, 0);
        await g.up();
      });
    });
  }

  testWidgets('haptic once per newly selected item', (t) async {
    var clicks = 0;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate' &&
            call.arguments == 'HapticFeedbackType.selectionClick') {
          clicks++;
        }
        return null;
      },
    );
    await t.pumpWidget(const _Host());
    final g = await _longPressAt(t, t.getCenter(_c(0)));
    expect(clicks, 1);
    await g.moveTo(t.getCenter(_c(3)));
    await t.pump();
    expect(clicks, 4);
    await g.moveTo(t.getCenter(_c(1)));
    await t.pump();
    expect(clicks, 4); // 縮回不震
    await g.up();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('按在項目以外的地方不參與手勢（旁邊的長按照常觸發）', (t) async {
    var outside = 0;
    final events = <Set<int>>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DragSelectArea(
            itemCount: 1,
            isSelected: (_) => false,
            onChanged: (idx, done) => events.add(idx),
            child: Row(
              children: [
                DragSelectItem(
                  index: 0,
                  child: const ColoredBox(
                    key: ValueKey('item'),
                    color: Colors.blue,
                    child: SizedBox(width: 100, height: 100),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('outside'),
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () => outside++,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.longPress(find.byKey(const ValueKey('outside')));
    expect(outside, 1);
    expect(events, isEmpty);
    await t.longPress(find.byKey(const ValueKey('item')));
    expect(events, isNotEmpty);
  });
}
