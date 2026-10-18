import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/theme/tokens.dart';
import 'package:huakeng/ui/album/move_sheet.dart';
import 'package:huakeng/ui/album/tag_batch_sheet.dart';
import 'package:huakeng/ui/common/themed_sheet.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// sheet 開著時系統切換深淺色（省電模式）：sheet 外殼底色要跟著變，不能停在開啟當下的顏色。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pit;
  final mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  setUp(() async {
    mode.value = ThemeMode.light;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('themed_sheet');
    await Directory('${tmp.path}/images').create(recursive: true);
    pit = await db.createPit(name: '坑A');
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openAndFlip(
    WidgetTester tester,
    void Function(BuildContext) open, {
    required Type content,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final List<Override> overrides = [
      databaseProvider.overrideWithValue(db),
      imageStoreProvider.overrideWith(
        (ref) async => ImageStore(Directory('${tmp.path}/images')),
      ),
      sharedPrefsProvider.overrideWithValue(prefs),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (_, m, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            themeMode: m,
            theme: buildTheme(Brightness.light, useGoogleFonts: false),
            darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => open(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    Color surface() {
      final m = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ThemedSheetSurface),
              matching: find.byType(Material),
            )
            .first,
      );
      return m.color!;
    }

    final lightGround = buildTheme(
      Brightness.light,
      useGoogleFonts: false,
    ).extension<AppTokens>()!.ground;
    final darkGround = buildTheme(
      Brightness.dark,
      useGoogleFonts: false,
    ).extension<AppTokens>()!.ground;
    expect(lightGround, isNot(darkGround));

    expect(find.byType(ThemedSheetSurface), findsOneWidget);
    expect(surface(), lightGround);
    mode.value = ThemeMode.dark;
    await settle(tester);
    expect(find.byType(ThemedSheetSurface), findsOneWidget);
    expect(surface(), darkGround);
    expect(find.byType(content), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('分享 sheet：開著時切深色，外殼底色跟著變', (tester) async {
    await openAndFlip(
      tester,
      (c) => showShareSheet(c, paths: const ['/tmp/x.png']),
      content: ShareSheet,
    );
  });

  testWidgets('移動 sheet：開著時切深色，外殼底色跟著變', (tester) async {
    await openAndFlip(
      tester,
      (c) => showMoveSheet(c, pitId: pit, from: AlbumCell.fan, count: 1),
      content: MoveSheet,
    );
  });

  testWidgets('tag 批次 sheet：開著時切深色，外殼底色跟著變', (tester) async {
    await openAndFlip(
      tester,
      (c) =>
          showBatchTagSheet(c, pitId: pit, cell: AlbumCell.fan, ids: const []),
      content: BatchTagSheet,
    );
  });
}
