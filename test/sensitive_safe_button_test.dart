import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/fan_art_preview_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/entity/draft_detail_page.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// D-110（`DraftDetailSafe`）：詳情頁照安全模式模糊（52px 圓），
/// 這一頁有標記的圖時標題列多一顆「安全模式」鈕：點一下直接關閉（全 App 設定），變成眼睛；再點重新開啟。
/// 安全模式關時詳情頁不加左上角小標（小標只在列表類）。列表頁沒有這顆鈕；總開關關＝什麼都沒有。
/// 全螢幕圖片預覽頁沒有安全模式（Molly 10/23）：一律正常顯示。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late Directory tmp;
  late String pitId;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('safe_button');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitId = await db.createPit(name: '坑A');
    await db.setPitSensitiveEnabled(pitId, true);
    final g = (await db.watchGroups(pitId).first).first.id;
    await db.addOfficial(pitId, g, const [
      NewImage(file: 'flag.png', sensitive: true),
      NewImage(file: 'plain.png'),
    ]);
    final fan = (await db.watchGroups(pitId, kind: 'fan').first).first.id;
    await db.addFanArts(
      pitId,
      const [
        NewImage(file: 'fflag.png', sensitive: true),
        NewImage(file: 'fplain.png'),
      ],
      author: '@作者',
      groupId: fan,
    );
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    bool master = true,
    bool safe = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'sensitiveEnabled': master,
      'safeMode': safe,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${tmp.path}/images')),
          ),
          imageTransferProvider.overrideWith(
            (ref, file) => ImageDownloadStatus.present,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.dark, useGoogleFonts: false),
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  const blur = ValueKey('sensitiveBlur');
  const circle = ValueKey('sensitiveCircle');
  const badge = ValueKey('sensitiveBadge');
  const button = ValueKey('sensitiveSafeButton');

  AlbumImage album(AlbumKind kind, String file) => AlbumImage(
    id: file,
    file: file,
    width: 100,
    height: 150,
    kind: kind,
    createdAt: DateTime(2026, 9, 21),
  );

  bool safeMode(WidgetTester tester, Type page) =>
      ProviderScope.containerOf(tester.element(find.byType(page).first))
          .read(settingsProvider)
          .safeMode;

  /// 開→關→開的共同斷言（詳情頁）。
  // ignore: unused_element
  Future<void> toggleFlow(WidgetTester tester, Type page) async {
    expect(find.byKey(blur), findsWidgets);
    expect(tester.getSize(find.byKey(circle).first).width, 52);
    expect(find.byKey(button), findsOneWidget);
    expect(find.byTooltip('關閉安全模式'), findsOneWidget);
    expect(safeMode(tester, page), isTrue);

    // 一鍵關閉：不確認、設定同步變、整頁立刻清晰、鈕變成「眼睛」。
    await tester.tap(find.byKey(button));
    await settle(tester);
    expect(safeMode(tester, page), isFalse);
    expect(find.byKey(blur), findsNothing);
    expect(find.byKey(badge), findsNothing);
    expect(find.byKey(button), findsOneWidget);
    expect(find.byTooltip('開啟安全模式'), findsOneWidget);

    // 再點一次：重新開啟，又模糊。
    await tester.tap(find.byKey(button));
    await settle(tester);
    expect(safeMode(tester, page), isTrue);
    expect(find.byKey(blur), findsWidgets);
    expect(find.byTooltip('關閉安全模式'), findsOneWidget);
  }

  /// 預覽頁沒有安全模式（Molly：預覽頁就不要安全模式了）：不論總開關／安全模式，
  /// 已標記的圖一律正常顯示——沒有模糊、沒有圓、沒有小標、標題列沒有鈕。
  void expectNoSafeMode() {
    expect(find.byKey(blur), findsNothing);
    expect(find.byKey(circle), findsNothing);
    expect(find.byKey(badge), findsNothing);
    expect(find.byKey(button), findsNothing);
  }

  group('圖片預覽頁沒有安全模式', () {
    Widget official() => ImagePreviewPage(
      pitId: pitId,
      images: [
        album(AlbumKind.official, 'flag.png'),
        album(AlbumKind.official, 'plain.png'),
      ],
      initialIndex: 0,
    );
    Widget fan() => FanArtPreviewPage(
      pitId: pitId,
      images: [
        album(AlbumKind.fanArt, 'fflag.png'),
        album(AlbumKind.fanArt, 'fplain.png'),
      ],
      initialIndex: 0,
    );
    Widget gallery() => const ImageGalleryPage(
      images: [
        ImageRef('flag.png', 1, 1, sensitive: true),
        ImageRef('plain.png', 1, 1),
      ],
    );

    for (final c in <(String, Widget Function())>[
      ('官圖 ImagePreview', official),
      ('同人圖 FanArtPreview', fan),
      ('全螢幕看圖 ImageGalleryPage（詳情頁點開）', gallery),
    ]) {
      for (final safe in [true, false]) {
        testWidgets('${c.$1}：總開關開、安全模式${safe ? '開' : '關'} → 一律正常', (
          tester,
        ) async {
          await pump(tester, c.$2(), safe: safe);
          expectNoSafeMode();
          await unmount(tester);
        });
      }
      testWidgets('${c.$1}：總開關關 → 一律正常', (tester) async {
        await pump(tester, c.$2(), master: false);
        expectNoSafeMode();
        await unmount(tester);
      });
    }
  });

  group('詳情頁', () {
    Future<String?> draft(WidgetTester tester, List<NewImage> images) =>
        tester.runAsync(
          () => db.saveDraft(
            pitId: pitId,
            title: '摸魚',
            images: images,
            tagIds: const [],
            ideaIds: const [],
          ),
        );

    testWidgets('摸魚詳情：標題列有鈕（在編輯前面）；點鈕整頁清晰', (tester) async {
      final id = await draft(tester, const [
        NewImage(file: 'flag.png', sensitive: true),
        NewImage(file: 'plain.png'),
      ]);
      await pump(tester, DraftDetailPage(draftId: id!, pitId: pitId));
      // 主圖（第 1 頁）＋縮圖列那張標記的圖。
      expect(find.byKey(blur), findsNWidgets(2));
      expect(find.byKey(button), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(button)).dx,
        lessThan(tester.getTopLeft(find.byTooltip('編輯')).dx),
      );
      await tester.tap(find.byKey(button));
      await settle(tester);
      expect(safeMode(tester, DraftDetailPage), isFalse);
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      expect(find.byTooltip('開啟安全模式'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('摸魚詳情：安全模式關 → 主圖與縮圖列都沒有左上角小標，標題列鈕是眼睛', (tester) async {
      final id = await draft(tester, const [
        NewImage(file: 'flag.png', sensitive: true),
        NewImage(file: 'plain.png'),
      ]);
      await pump(
        tester,
        DraftDetailPage(draftId: id!, pitId: pitId),
        safe: false,
      );
      expect(find.byKey(blur), findsNothing);
      expect(find.byKey(badge), findsNothing);
      expect(find.byTooltip('開啟安全模式'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('摸魚詳情沒有標記的圖：沒有鈕；總開關關：也沒有', (tester) async {
      final id = await draft(tester, const [NewImage(file: 'plain.png')]);
      await pump(tester, DraftDetailPage(draftId: id!, pitId: pitId));
      expect(find.byKey(button), findsNothing);
      await unmount(tester);

      final id2 = await draft(tester, const [
        NewImage(file: 'flag.png', sensitive: true),
      ]);
      await pump(
        tester,
        DraftDetailPage(draftId: id2!, pitId: pitId),
        master: false,
      );
      expect(find.byKey(button), findsNothing);
      expect(find.byKey(blur), findsNothing);
      await unmount(tester);
    });
  });

  group('列表頁', () {
    testWidgets('官方圖冊列表：只模糊、沒有安全模式鈕', (tester) async {
      await pump(tester, OfficialListPage(pitId: pitId));
      expect(find.byKey(blur), findsOneWidget);
      expect(tester.getSize(find.byKey(circle)).width, lessThan(52));
      expect(find.byKey(button), findsNothing);
      await unmount(tester);
    });
  });
}
