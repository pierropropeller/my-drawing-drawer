import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/entity/scroll_back.dart';

/// D-122：返回列表時捲到最後看的那一篇（惰性列表，目標還沒建好也要能捲到）。
void main() {
  testWidgets('目標在很下面（還沒建好）也能逐步捲到畫面內', (tester) async {
    final anchors = ScrollBackAnchors();
    final ids = [for (var i = 0; i < 60; i++) 'id$i'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: ids.length,
            itemBuilder: (_, i) => anchors.wrap(
              ids[i],
              SizedBox(height: 100, child: Text(ids[i])),
            ),
          ),
        ),
      ),
    );
    expect(find.text('id40'), findsNothing);
    // 先建好第一張，才有「離目標最近」可用。
    final done = anchors.reveal('id40', ids);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await done;
    expect(find.text('id40'), findsOneWidget);
    final top = tester.getTopLeft(find.text('id40')).dy;
    expect(top, inInclusiveRange(0, 600));
  });

  testWidgets('已經在畫面內就不動', (tester) async {
    final anchors = ScrollBackAnchors();
    final ids = [for (var i = 0; i < 10; i++) 'id$i'];
    final c = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: c,
            itemCount: ids.length,
            itemBuilder: (_, i) => anchors.wrap(
              ids[i],
              SizedBox(height: 100, child: Text(ids[i])),
            ),
          ),
        ),
      ),
    );
    final done = anchors.reveal('id2', ids);
    await tester.pump();
    await tester.pump();
    await done;
    expect(c.offset, 0);
  });
}
