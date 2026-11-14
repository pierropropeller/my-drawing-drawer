import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/author_link.dart';
import 'package:huakeng/data/author_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/l10n/l10n.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/theme/app_theme.dart';
import 'package:huakeng/ui/authors/author_detail_page.dart';
import 'package:huakeng/ui/authors/author_form_page.dart';
import 'package:huakeng/ui/authors/author_list_page.dart';
import 'package:huakeng/ui/authors/author_pick_sheet.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLink implements AuthorLinkService {
  _FakeLink({this.fail = false});
  final bool fail;
  @override
  Future<LinkedProfile> lookup(LinkPlatform p, String key) async {
    if (fail) throw const AuthorLinkException();
    return LinkedProfile(
      platform: p,
      userId: '123',
      handle: key,
      name: '雪見｜委託開放中',
    );
  }

  @override
  Future<LinkedProfile> refresh(
    LinkPlatform p, {
    required String userId,
    String? handle,
  }) async {
    if (fail) throw const AuthorLinkException();
    return LinkedProfile(
      platform: p,
      userId: userId,
      handle: handle ?? '',
      name: '雪見｜休息中',
    );
  }

  @override
  Future<List<int>> download(String url) async => throw Exception();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late SharedPreferences prefs;

  setUp(() async {
    navBarHiddenCount.value = 0;
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('author_ui');
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> showPage(
    WidgetTester tester,
    Widget page, {
    bool fail = false,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          imageStoreProvider.overrideWith((ref) async => ImageStore(tmp)),
          authorLinkServiceProvider.overrideWithValue(_FakeLink(fail: fail)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          theme: buildTheme(Brightness.light, useGoogleFonts: false),
          home: page,
        ),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('列表：作者數、坑分頁、主坑；換格子；長按多選→排序', (tester) async {
    final pit = await db.createPit(name: '坑A');
    final a = await db.addAuthor(AuthorsCompanion.insert(name: '雪見'));
    await db.addFanArts(
      pit,
      [const NewImage(file: '1.png', width: 1, height: 1)],
      author: '雪見',
      authorId: a,
    );
    await db.addAuthor(AuthorsCompanion.insert(name: '小林'));
    await showPage(tester, const AuthorListPage());
    expect(find.text('2 位'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('坑A'), findsWidgets);
    expect(find.text('還沒有同人圖'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('格子'));
    await settle(tester, rounds: 3);
    expect(prefs.getString('authorLayout'), 'grid');
    expect(find.text('雪見'), findsOneWidget);

    await tester.longPress(find.text('小林'));
    await settle(tester, rounds: 3);
    expect(find.text('已選 1 位'), findsOneWidget);
    expect(find.text('刪除'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorSortButton')));
    await settle(tester, rounds: 3);
    expect(find.text('編輯排序'), findsOneWidget);
    expect(find.text('長按拖動可自訂順序'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorSortDone')));
    await settle(tester, rounds: 3);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('新增作者：連結推特 → 使用推特資料 → 建立', (tester) async {
    await showPage(tester, const AuthorFormPage());
    expect(find.text('新增作者'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('authorLink-x')),
      'x.com/yukimi_ill',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('使用推特上的資料？'), findsOneWidget);
    await tester.tap(find.text('使用'));
    await settle(tester);
    expect(find.text('雪見｜委託開放中'), findsOneWidget);
    expect(find.text('@yukimi_ill'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorSave')));
    await settle(tester);
    final a = (await db.loadAuthors()).single;
    expect(a.xUserId, '123');
    expect(a.syncSource, 'x');
    expect(a.handle, '@yukimi_ill');
    expect(find.byType(AuthorDetailPage), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('連結失敗：一般失敗訊息＋重試', (tester) async {
    await showPage(tester, const AuthorFormPage(), fail: true);
    await tester.enterText(
      find.byKey(const ValueKey('authorLink-x')),
      'x.com/nobody',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('找不到這個帳號，或網路有問題'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('編輯作者：更新有變更 → 確認 → 名字換掉', (tester) async {
    final id = await db.addAuthor(
      AuthorsCompanion.insert(
        name: '雪見｜委託開放中',
        handle: const Value('@yukimi_ill'),
        xUserId: const Value('123'),
        xHandle: const Value('yukimi_ill'),
        syncSource: const Value('x'),
      ),
    );
    await showPage(tester, AuthorFormPage(authorId: id));
    expect(find.text('編輯作者'), findsOneWidget);
    expect(find.text('刪除作者'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorRefresh')));
    await settle(tester);
    expect(find.text('推特上的資料有變更'), findsOneWidget);
    await tester.tap(find.text('更新').last);
    await settle(tester);
    expect((await db.loadAuthor(id))!.name, '雪見｜休息中');
    await unmount(tester);
  });

  testWidgets('編輯作者：還沒連結的 X 貼連結 → 使用 → 名字、ID 換掉', (tester) async {
    final id = await db.addAuthor(AuthorsCompanion.insert(name: '舊名'));
    await showPage(tester, AuthorFormPage(authorId: id));
    await tester.enterText(
      find.byKey(const ValueKey('authorLink-x')),
      'x.com/yukimi_ill',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.tap(find.text('使用'));
    await settle(tester);
    expect(find.text('雪見｜委託開放中'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('authorSave')));
    await settle(tester);
    final a = (await db.loadAuthor(id))!;
    expect(a.name, '雪見｜委託開放中');
    expect(a.handle, '@yukimi_ill');
    expect(a.xUserId, '123');
    await unmount(tester);
  });

  testWidgets('選擇作者 sheet：不指定、新增作者並選擇', (tester) async {
    await db.addAuthor(AuthorsCompanion.insert(name: 'Renko'));
    String? picked = 'none';
    await showPage(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, set) => AuthorField(
            authorId: picked == 'none' ? null : picked,
            onChanged: (id) => set(() => picked = id),
          ),
        ),
      ),
    );
    expect(find.text('選擇作者'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorField')));
    await settle(tester);
    expect(find.text('Renko'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('authorPickNew')));
    await settle(tester);
    expect(find.text('建立並選擇'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('authorQuickName')),
      'Kaze',
    );
    await settle(tester, rounds: 2);
    await tester.tap(find.byKey(const ValueKey('authorQuickCreate')));
    await settle(tester);
    expect(find.text('Kaze'), findsOneWidget);
    expect(picked, isNotNull);
    await unmount(tester);
  });
}
