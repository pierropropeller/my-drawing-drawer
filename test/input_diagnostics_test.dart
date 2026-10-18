import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/debug/input_diagnostics.dart';

void main() {
  testWidgets('panel lists arrowLeft key event and focus', (t) async {
    InputDiagLog.instance.clear();
    final c = TextEditingController(text: 'hello');
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => InputDiagnosticsOverlay(child: child!),
        home: Scaffold(body: TextField(controller: c)),
      ),
    );
    await t.tap(find.byType(TextField));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pump();
    expect(find.textContaining('KEY down Arrow Left'), findsOneWidget);
    expect(find.textContaining('FOC text field'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('inputDiagClose')));
    await t.pump();
    expect(find.textContaining('KEY down'), findsNothing);
  });
}
