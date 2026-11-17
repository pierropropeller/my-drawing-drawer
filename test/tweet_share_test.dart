import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/author_link.dart';
import 'package:huakeng/data/author_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/main.dart';
import 'package:huakeng/share/share_channel.dart';
import 'package:huakeng/share/tweet_share.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/ui/common/nav_bar_hidden.dart';
import 'package:huakeng/ui/share/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Channel extends ShareChannel {
  _Channel(this.initial);
  final List<String> initial;
  @override
  Future<List<String>> getInitialShare() async => initial;
  @override
  void setOnShare(void Function(List<String> paths)? cb) {}
}

class _FakeTweets implements AuthorLinkService {
  _FakeTweets({this.fail = false});
  bool fail;
  int calls = 0;
  @override
  Future<TweetInfo> tweet(String id) async {
    calls++;
    if (fail) throw const AuthorLinkException();
    return TweetInfo(
      url: 'https://x.com/yukimi_ill/status/$id',
      author: const LinkedProfile(
        platform: LinkPlatform.x,
        userId: '42',
        handle: 'yukimi_ill',
        name: '雪見',
      ),
      media: const [
        TweetMedia(
          url: 'https://pbs.twimg.com/media/a.png?name=orig',
          isVideo: false,
        ),
        TweetMedia(
          url: 'https://pbs.twimg.com/media/b.png?name=orig',
          isVideo: false,
        ),
      ],
    );
  }

  @override
  Future<List<int>> download(String url) async => _png1x1;
  @override
  Future<LinkedProfile> lookup(LinkPlatform p, String key) =>
      throw UnimplementedError();
  @override
  Future<LinkedProfile> refresh(
    LinkPlatform p, {
    required String userId,
    String? handle,
  }) => throw UnimplementedError();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory tmp;
  late String pitA;
  late String pitB;

  setUp(() async {
    navBarHiddenCount.value = 0;
    SharedPreferences.setMockInitialValues({'onboarded': true});
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('tweet_share');
    await Directory('${tmp.path}/images').create(recursive: true);
    pitA = await db.createPit(name: '坑A');
    pitB = await db.createPit(name: '坑B');
  });

  Future<void> settle(WidgetTester tester, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester, AuthorLinkService svc) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    final List<Override> overrides = [
      databaseProvider.overrideWithValue(db),
      imageStoreProvider.overrideWith(
        (ref) async => ImageStore(Directory('${tmp.path}/images')),
      ),
      shareChannelProvider.overrideWithValue(
        _Channel(['https://x.com/yukimi_ill/status/1857000000000000000?s=20']),
      ),
      sharedPrefsProvider.overrideWithValue(prefs),
      authorLinkServiceProvider.overrideWithValue(svc),
      tweetShareTempDirProvider.overrideWithValue(() async => tmp),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const HuaKengApp(useGoogleFonts: false),
      ),
    );
    await settle(tester);
  }

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(ShareSheet), matching: f);

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(inSheet(find.text('加入')).last);
    await settle(tester, 40);
  }

  test('parseTweetUrl：x／twitter／fxtwitter，夾在文字裡也行', () {
    expect(
      parseTweetUrl('https://x.com/a_b/status/123456789?s=20'),
      '123456789',
    );
    expect(
      parseTweetUrl('看這個 https://twitter.com/abc/status/98765 好棒'),
      '98765',
    );
    expect(parseTweetUrl('https://fxtwitter.com/i/status/55555'), '55555');
    expect(parseTweetUrl('https://x.com/abc'), isNull);
    expect(parseTweetUrl('https://example.com/a/status/12345'), isNull);
  });

  test('fxtwitter 推文回傳：作者、原圖 name=orig、影片', () {
    final info = HttpAuthorLinkService.parseFxTweet({
      'tweet': {
        'id': '1857',
        'url': 'https://twitter.com/yukimi_ill/status/1857',
        'author': {
          'id': '42',
          'screen_name': 'yukimi_ill',
          'name': '雪見',
          'avatar_url': 'https://pbs.twimg.com/profile_images/1/a_normal.jpg',
        },
        'media': {
          'all': [
            {'type': 'photo', 'url': 'https://pbs.twimg.com/media/AAA.jpg'},
            {
              'type': 'video',
              'url': 'https://video.twimg.com/v.mp4',
              'thumbnail_url': 'https://pbs.twimg.com/t.jpg',
            },
          ],
        },
      },
    });
    expect(info.url, 'https://x.com/yukimi_ill/status/1857');
    expect(info.author.userId, '42');
    expect(info.author.avatarUrl, endsWith('a_400x400.jpg'));
    expect(info.media, hasLength(2));
    expect(info.media[0].url, 'https://pbs.twimg.com/media/AAA.jpg?name=orig');
    expect(info.media[1].isVideo, isTrue);
  });

  testWidgets('新作者：預設好看同人圖、合成一組，加入＝新增作者（連結 X）＋一組兩張＋原文連結', (tester) async {
    await pumpApp(tester, _FakeTweets());
    expect(inSheet(find.text('新作者')), findsOneWidget);
    expect(inSheet(find.text('@yukimi_ill')), findsOneWidget);
    expect(inSheet(find.text('2 張')), findsOneWidget);
    expect(inSheet(find.text('合成一組')), findsOneWidget);
    await tapAdd(tester);

    final authors = (await tester.runAsync(() => db.loadAuthors()))!;
    expect(authors, hasLength(1));
    expect(authors.single.name, '雪見');
    expect(authors.single.xUserId, '42');
    expect(authors.single.syncSource, 'x');
    final arts = (await tester.runAsync(() => db.select(db.fanArts).get()))!;
    expect(arts, hasLength(1), reason: '合成一組＝一筆多圖');
    expect(arts.single.authorId, authors.single.id);
    expect(
      arts.single.sourceUrl,
      'https://x.com/yukimi_ill/status/1857000000000000000',
    );
    // 下載的暫存檔清掉了。
    expect(Directory('${tmp.path}/share_import').listSync(), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('作者已在 Drawer：選他、坑＝他最近加圖的坑；刪一張只加一張', (tester) async {
    final id = (await db.addAuthor(
      AuthorsCompanion.insert(name: 'Yukimi')
          .copyWith(xUserId: const Value('42')),
    ));
    await db.addFanArts(pitB, const [], author: 'Yukimi', authorId: id);
    // 沒圖的 addFanArts 不會產生列；直接放一筆最近的同人圖。
    await db
        .into(db.fanArts)
        .insert(
          FanArtsCompanion.insert(
            pitId: pitB,
            imageFile: 'x.png',
            authorId: Value(id),
          ),
        );
    await pumpApp(tester, _FakeTweets());
    expect(inSheet(find.text('新作者')), findsNothing);
    expect(inSheet(find.text('Yukimi')), findsOneWidget);
    await tester.tap(inSheet(find.byKey(const ValueKey('shareThumbRemove0'))));
    await settle(tester, 4);
    expect(inSheet(find.text('1 張')), findsOneWidget);
    expect(inSheet(find.text('合成一組')), findsNothing);
    await tapAdd(tester);
    final arts = (await tester.runAsync(
      () => (db.select(
        db.fanArts,
      )..where((f) => f.imageFile.isNotValue('x.png'))).get(),
    ))!;
    expect(arts, hasLength(1));
    expect(arts.single.pitId, pitB);
    expect(arts.single.authorId, id);
    expect((await tester.runAsync(() => db.loadAuthors()))!, hasLength(1));
    expect(pitA, isNotEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('讀不到：顯示失敗＋重試，重試成功後可以加入；關閉不存東西', (tester) async {
    final svc = _FakeTweets(fail: true);
    await pumpApp(tester, svc);
    expect(inSheet(find.text('讀不到這則推文')), findsOneWidget);
    expect(inSheet(find.text('關閉')), findsOneWidget);
    svc.fail = false;
    await tester.tap(inSheet(find.byKey(const ValueKey('tweetRetry'))));
    await settle(tester);
    expect(svc.calls, 2);
    expect(inSheet(find.text('讀不到這則推文')), findsNothing);
    expect(inSheet(find.text('新作者')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
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
