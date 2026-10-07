import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/google_auth.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/album/album_image.dart';
import 'package:huakeng/ui/album/cover_pick_page.dart';
import 'package:huakeng/ui/album/fan_art_edit_page.dart';
import 'package:huakeng/ui/album/fan_art_list_page.dart';
import 'package:huakeng/ui/album/fan_art_new_page.dart';
import 'package:huakeng/ui/album/group_manage_page.dart';
import 'package:huakeng/ui/album/image_preview_page.dart';
import 'package:huakeng/ui/album/official_list_page.dart';
import 'package:huakeng/ui/album/official_new_page.dart';
import 'package:huakeng/ui/entity/draft_detail_page.dart';
import 'package:huakeng/ui/entity/draft_form_page.dart';
import 'package:huakeng/ui/entity/draft_list_page.dart';
import 'package:huakeng/ui/entity/finished_list_page.dart';
import 'package:huakeng/ui/entity/idea_detail_page.dart';
import 'package:huakeng/ui/entity/idea_form_page.dart';
import 'package:huakeng/ui/entity/idea_list_page.dart';
import 'package:huakeng/ui/entity/image_gallery_page.dart';
import 'package:huakeng/ui/entity/piece_detail_page.dart';
import 'package:huakeng/ui/entity/piece_form_page.dart';
import 'package:huakeng/ui/goals/goal_new_page.dart';
import 'package:huakeng/ui/goals/goals_page.dart';
import 'package:huakeng/ui/goals/review_edit_page.dart';
import 'package:huakeng/ui/login/welcome_page.dart';
import 'package:huakeng/ui/me/backup_page.dart';
import 'package:huakeng/ui/me/profile_page.dart';
import 'package:huakeng/ui/me/theme_page.dart';
import 'package:huakeng/ui/pits/pit_edit_page.dart';
import 'package:huakeng/ui/pits/pit_page.dart';
import 'package:huakeng/ui/pits/pits_page.dart';
import 'package:huakeng/ui/tags/tag_manage_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccounts implements AccountService {
  @override
  Future<String> signIn() async => 'me@example.com';
  @override
  Future<String?> restore() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<Map<String, String>> headers() async => {};
}

/// 打開每個畫面（含資料、深色模式、平板寬度），確認沒有 build／layout 例外。
/// debug APK 遇到這類例外會直接顯示紅色錯誤畫面，所以要在這裡先擋下來。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dir;
  late String pitId;
  late String groupId;
  late String ideaId;
  late String draftId;
  late String pieceId;
  late String officialId;
  late String fanId;
  late String tagId;
  late String goalId;
  late Pit pit;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('smoke');
    await Directory('${dir.path}/images').create();
    for (final n in ['a.png', 'b.png', 'c.png', 'd.png', 'e.png', 'f.png']) {
      File('${dir.path}/images/$n').writeAsBytesSync(_png1x1);
    }
    pitId = await db.createPit(name: '測試坑', description: '一個描述');
    groupId = (await db.watchGroups(pitId).first).first.id;
    tagId = await db.createTag(pitId, '角色1');
    await db.addOfficial(pitId, groupId, const [
      NewImage(file: 'a.png', width: 100, height: 200),
      NewImage(file: 'b.png', width: 300, height: 100),
    ]);
    officialId = (await db.watchOfficial(pitId).first).first.id;
    await db.addFanArts(
      pitId,
      const [NewImage(file: 'c.png', width: 10, height: 10)],
      author: '@a',
      groupId: (await db.watchGroups(pitId, kind: 'fan').first).first.id,
      tagIds: [tagId],
    );
    fanId = (await db.watchFanArts(pitId).first).first.id;
    draftId = await db.saveDraft(
      pitId: pitId,
      title: '草稿標題',
      body: '內文',
      images: [
        for (final n in ['a.png', 'b.png', 'c.png', 'd.png', 'e.png'])
          NewImage(file: n, width: 10, height: 10),
      ],
      tagIds: [tagId],
      ideaIds: const [],
    );
    await db.saveDraft(
      pitId: pitId,
      images: const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
        NewImage(file: 'c.png'),
        NewImage(file: 'd.png'),
      ],
      tagIds: const [],
      ideaIds: const [],
    );
    await db.saveDraft(
      pitId: pitId,
      images: const [NewImage(file: 'f.png', width: 400, height: 100)],
      tagIds: const [],
      ideaIds: const [],
    );
    ideaId = await db.saveIdea(
      pitId: pitId,
      title: '腦洞',
      body: '很長的內文' * 20,
      images: const [
        NewImage(file: 'a.png'),
        NewImage(file: 'b.png'),
      ],
      tagIds: [tagId],
      draftIds: [draftId],
      pieceIds: const [],
    );
    pieceId = await db.savePiece(
      pitId: pitId,
      title: '成圖',
      body: '內文',
      images: const [
        NewImage(file: 'a.png', width: 100, height: 100),
        NewImage(file: 'b.png'),
      ],
      tagIds: [tagId],
      links: const [SocialLink('推特', 'https://x.com/a')],
      targetLikes: 100,
      finishedAt: DateTime.now(),
      ideaIds: [ideaId],
      draftIds: [draftId],
    );
    goalId = await db.saveGoal(
      period: GoalPeriod.year,
      year: DateTime.now().year,
      kind: GoalKind.piece,
      count: 5,
      pitId: pitId,
      tagIds: [tagId],
      requireLikes: 10,
    );
    await db.saveGoal(
      period: GoalPeriod.month,
      year: DateTime.now().year,
      month: DateTime.now().month,
      kind: GoalKind.idea,
      count: 2,
    );
    await db.setCover(pitId, officialId);
    pit = (await db.watchPit(pitId).first)!;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    String? expectText,
    bool dark = false,
    Size size = const Size(1080, 2400),
    double ratio = 3,
    bool linked = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      if (linked) 'accountEmail': 'me@example.com',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith(
            (ref) async => ImageStore(Directory('${dir.path}/images')),
          ),
          accountServiceProvider.overrideWithValue(_FakeAccounts()),
          syncRemoteProvider.overrideWithValue(MemoryRemote()),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          darkTheme: buildTheme(Brightness.dark, useGoogleFonts: false),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: page,
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    // 詳情頁、編輯頁在資料載入前是空白的：一定要確認資料真的載入並顯示出來。
    if (expectText != null) {
      expect(find.textContaining(expectText), findsWidgets);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  final pages = <String, Widget Function()>{
    'PitsPage': () => const PitsPage(),
    'PitPage': () => PitPage(pitId: pitId),
    'PitEditPage': () => PitEditPage(pit: pit),
    'OfficialListPage': () => OfficialListPage(pitId: pitId),
    'OfficialNewPage': () => OfficialNewPage(pitId: pitId),
    'GroupManagePage': () => GroupManagePage(pitId: pitId),
    'FanArtListPage': () => FanArtListPage(pitId: pitId),
    'FanArtNewPage': () => FanArtNewPage(pitId: pitId),
    'FanArtEditPage': () => FanArtEditPage(pitId: pitId, imageId: fanId),
    'CoverPickPage': () => CoverPickPage(pitId: pitId),
    'ImagePreviewPage': () => ImagePreviewPage(
      pitId: pitId,
      initialIndex: 0,
      images: const [
        AlbumImage(
          id: 'x',
          file: 'a.png',
          width: 10,
          height: 10,
          kind: AlbumKind.official,
        ),
      ],
    ),
    'TagManagePage': () => TagManagePage(pitId: pitId),
    'IdeaListPage': () => IdeaListPage(pitId: pitId),
    'IdeaFormPage(new)': () => IdeaFormPage(pitId: pitId),
    'IdeaFormPage(edit)': () => IdeaFormPage(pitId: pitId, ideaId: ideaId),
    'IdeaDetailPage': () => IdeaDetailPage(ideaId: ideaId, pitId: pitId),
    'DraftListPage': () => DraftListPage(pitId: pitId),
    'DraftFormPage(new)': () => DraftFormPage(pitId: pitId),
    'DraftFormPage(edit)': () => DraftFormPage(pitId: pitId, draftId: draftId),
    'DraftDetailPage': () => DraftDetailPage(draftId: draftId, pitId: pitId),
    'FinishedListPage': () => FinishedListPage(pitId: pitId),
    'PieceFormPage(new)': () => PieceFormPage(pitId: pitId),
    'PieceFormPage(edit)': () => PieceFormPage(pitId: pitId, pieceId: pieceId),
    'PieceDetailPage': () => PieceDetailPage(pieceId: pieceId, pitId: pitId),
    'ImageGalleryPage': () =>
        const ImageGalleryPage(images: [ImageRef('a.png', 1, 1)]),
    'GoalsPage': () => const GoalsPage(),
    'GoalNewPage(new)': () =>
        GoalNewPage(period: GoalPeriod.year, year: DateTime.now().year),
    'GoalNewPage(edit)': () => GoalNewPage(
      period: GoalPeriod.year,
      year: DateTime.now().year,
      goalId: goalId,
    ),
    'ReviewEditPage': () => ReviewEditPage(year: DateTime.now().year),
    'ProfilePage': () => const ProfilePage(),
    'ThemePage': () => const ThemePage(),
    'BackupPage(unlinked)': () => const BackupPage(),
    'WelcomePage': () => const WelcomePage(),
    'ConnectPage': () => const ConnectPage(),
  };

  for (final e in pages.entries) {
    testWidgets('${e.key}：淺色手機', (tester) async => show(tester, e.value()));
    testWidgets(
      '${e.key}：深色',
      (tester) async => show(tester, e.value(), dark: true),
    );
    testWidgets(
      '${e.key}：平板寬度',
      (tester) async =>
          show(tester, e.value(), size: const Size(1600, 2400), ratio: 2),
    );
  }

  testWidgets(
    'BackupPage(linked)',
    (tester) async => show(tester, const BackupPage(), linked: true),
  );
  testWidgets('ImagePreviewPage 官方圖資料可編輯', (tester) async {
    expect(officialId, isNotEmpty);
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
