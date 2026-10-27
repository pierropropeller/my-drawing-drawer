import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/ui/common/tap_outside_unfocus.dart';

/// 打字時點空白處收起鍵盤；點按鈕照常、不搶。
void main() {
  testWidgets('點空白處：輸入框失去焦點；點按鈕：按鈕照常觸發', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TapOutsideUnfocus(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('f')),
              TextButton(
                onPressed: () => pressed++,
                child: const Text('btn'),
              ),
              const Expanded(child: SizedBox.expand(key: Key('blank'))),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('f')));
    await tester.pump();
    EditableTextState s() => tester.state(find.byType(EditableText));
    expect(s().widget.focusNode.hasFocus, isTrue);
    await tester.tap(find.text('btn'));
    await tester.pump();
    expect(pressed, 1);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('blank'))));
    await tester.pump();
    expect(s().widget.focusNode.hasFocus, isFalse);
  });
}
