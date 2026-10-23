import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/sync/sync_kinds.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_new_page.dart';
import 'package:huakeng/ui/pits/pit_type_widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// P-041：封面。編輯坑三種類型（坑、淺坑、封存）都可以「從坑內選圖」或「從相簿選擇」，
/// 封面最後選的贏；開新淺坑有選填封面、開新坑（類型＝坑）沒有。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('huakeng_cover');
    await Directory('${tmp.path}/images').create();
    File('${tmp.path}/pick.png').writeAsBytesSync(_png1x1);
  });

  tearDown(() async {
    await db.close();
  });

  void setView(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          pitCoverPickerProvider.overrideWithValue(
            (_) async => [XFile('${tmp.path}/pick.png')],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: Material(child: home),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<Pit> pitOf(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => db.watchPit(id).first))!;

  Future<String> mkPit(PitStatus status) async {
    final id = await db.createPit(name: '坑X', status: status);
    final g = (await db.watchGroups(id).first).first;
    await db.addOfficial(id, g.id, const [
      NewImage(file: 'o1.png', width: 10, height: 10),
    ]);
    return id;
  }

  group('資料：封面最後選的贏', () {
    test('相簿封面換掉坑內封面參考；從坑內選圖再清掉相簿封面（任何類型）', () async {
      for (final st in PitStatus.values) {
        final id = await mkPit(st);
        final imgId = (await db.watchOfficial(id).first).first.id;
        await db.setCover(id, imgId);
        var p = (await db.watchPit(id).first)!;
        expect((p.coverImageId, p.coverFile), (imgId, null), reason: '$st');

        await db.setPitCoverFile(id, 'album.png');
        p = (await db.watchPit(id).first)!;
        expect((p.coverImageId, p.coverFile), (null, 'album.png'));

        await db.setCover(id, imgId);
        p = (await db.watchPit(id).first)!;
        expect((p.coverImageId, p.coverFile), (imgId, null));
      }
    });

    test('相簿封面在任何類型都會顯示（coverFileProvider）並隨同步文件帶上檔案', () async {
      for (final st in PitStatus.values) {
        final id = await mkPit(st);
        await db.setPitCoverFile(id, 'album-${st.name}.png');
        final p = (await db.watchPit(id).first)!;
        expect(p.coverFile, 'album-${st.name}.png');
        final doc = await const PitsKind().encode(db, id);
        expect(doc['coverFile'], 'album-${st.name}.png');
        expect(const PitsKind().imageFiles(doc), {'album-${st.name}.png'});
      }
    });
  });

  group('編輯坑（iPad modal）', () {
    for (final st in PitStatus.values) {
      testWidgets('${st.name}：有「從坑內選圖」和「從相簿選擇」；從相簿選後按儲存才寫入', (tester) async {
        setView(tester, 1194, 834);
        final id = await tester.runAsync(() => mkPit(st));
        var pit = await pitOf(tester, id!);
        await pump(tester, PitEditPage(pit: pit, asModal: true));
        expect(find.text('從坑內選圖'), findsOneWidget);
        final album = find.byKey(const ValueKey('pitCoverFromAlbum'));
        expect(album, findsOneWidget);
        expect(find.text('從相簿選擇'), findsOneWidget);

        await tester.tap(album);
        await settle(tester);
        await settle(tester);
        await settle(tester);
        // 還沒儲存：不寫入。
        pit = await pitOf(tester, id);
        expect(pit.coverFile, isNull);
        await tester.tap(find.text('儲存'));
        await settle(tester);
        pit = await pitOf(tester, id);
        expect(pit.coverFile, isNotNull);
        expect(pit.coverImageId, isNull);
        expect(pit.status, st);
        await unmount(tester);
      });
    }

    testWidgets('先從相簿選、再從坑內選圖：存的是坑內那張（相簿封面清掉）', (tester) async {
      setView(tester, 1194, 834);
      final id = await tester.runAsync(() => mkPit(PitStatus.active));
      final pit = await pitOf(tester, id!);
      await pump(tester, PitEditPage(pit: pit, asModal: true));
      await tester.tap(find.byKey(const ValueKey('pitCoverFromAlbum')));
      await settle(tester);
      await settle(tester);
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('設為封面').first);
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final saved = await pitOf(tester, id);
      expect(saved.coverImageId, isNotNull);
      expect(saved.coverFile, isNull);
      await unmount(tester);
    });

    testWidgets('先從坑內選圖、再從相簿選：存的是相簿那張', (tester) async {
      setView(tester, 1194, 834);
      final id = await tester.runAsync(() => mkPit(PitStatus.archived));
      final pit = await pitOf(tester, id!);
      await pump(tester, PitEditPage(pit: pit, asModal: true));
      await tester.tap(find.bySemanticsLabel('設為封面').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pitCoverFromAlbum')));
      await settle(tester);
      await settle(tester);
      await settle(tester);
      await tester.tap(find.text('儲存'));
      await settle(tester);
      final saved = await pitOf(tester, id);
      expect(saved.coverFile, isNotNull);
      expect(saved.coverImageId, isNull);
      await unmount(tester);
    });
  });

  group('開新坑', () {
    testWidgets('iPad modal：開新坑（類型＝坑）沒有封面欄位；切到淺坑有選填封面，選了會存', (tester) async {
      setView(tester, 1194, 834);
      await pump(tester, const PitNewPage(asModal: true));
      expect(find.byType(PitCoverPickTile), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(PitTypeSegment),
          matching: find.text('淺坑'),
        ),
      );
      await settle(tester);
      expect(find.byType(PitCoverPickTile), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('選擇封面'));
      await settle(tester);
      await settle(tester);
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('pit-name')), '新淺坑');
      await tester.tap(find.text('建立'));
      await settle(tester);
      final shallow = await tester.runAsync(
        () => db.watchPitsByStatus({PitStatus.shallow}).first,
      );
      expect(shallow!.single.coverFile, isNotNull);
      await unmount(tester);
    });

    testWidgets('窄的 sheet（單欄）：淺坑也有選填封面', (tester) async {
      setView(tester, 400, 834);
      await pump(tester, const PitNewPage(initialStatus: PitStatus.shallow));
      expect(find.byType(PitCoverPickTile), findsOneWidget);
      await unmount(tester);
    });
  });
}

const _png1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
];
