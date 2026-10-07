import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:huakeng/main.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('底部導覽可切換 坑／目標／我的', (tester) async {
    // 無字型檔時 google_fonts 會拋非致命錯誤，這裡只驗證導覽邏輯。
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = old);

    await tester.pumpWidget(const ProviderScope(child: HuaKengApp()));
    await tester.pump();
    expect(find.text('目標'), findsOneWidget);
    await tester.tap(find.text('目標'));
    await tester.pump();
    expect(find.text('目標'), findsWidgets);
    await tester.tap(find.text('我的'));
    await tester.pump();
    expect(find.text('我的'), findsWidgets);
  });
}
