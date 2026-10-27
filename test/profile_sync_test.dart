import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/profile_queries.dart';
import 'package:huakeng/media/thumbnail_maker.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:huakeng/sync/sync_kinds.dart';

/// 假縮圖機：不碰引擎解碼。
class _Maker implements ThumbnailMaker {
  @override
  Future<Uint8List?> make(File source, {bool placeholder = false}) async =>
      Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase a, b;
  late Directory dirA, dirB;
  late ImageStore storeA, storeB;
  late MemoryRemote remote;

  setUp(() async {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    dirA = await Directory.systemTemp.createTemp('prof_a');
    dirB = await Directory.systemTemp.createTemp('prof_b');
    storeA = ImageStore(dirA);
    storeB = ImageStore(dirB);
    remote = MemoryRemote();
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await dirA.delete(recursive: true);
    await dirB.delete(recursive: true);
  });

  SyncEngine eng(AppDatabase db, ImageStore s, {List<SyncKind>? kinds}) =>
      SyncEngine(
        db: db,
        remote: remote,
        images: s,
        thumbnails: _Maker(),
        kinds: kinds ?? allSyncKinds,
      );

  DateTime ms(int v) => DateTime.fromMillisecondsSinceEpoch(v);

  test('存暱稱與頭像 → 同步上傳 profile 文件、頭像原圖與縮圖；另一台下載後有資料與頭像檔', () async {
    File('${dirA.path}/av.jpg').writeAsBytesSync([9, 9, 9]);
    await a.saveProfile(nickname: '小莫', avatarFile: 'av.jpg');
    final r = await eng(a, storeA).sync();
    expect(r.pushed, 1);
    expect(remote.files.containsKey('meta__profile__me.json'), isTrue);
    expect(remote.files.containsKey('images__av.jpg'), isTrue);
    expect(remote.files.containsKey(thumbRemoteName('av.jpg')), isTrue);

    final r2 = await eng(b, storeB).sync();
    expect(r2.pulled, 1);
    final row = (await b.getProfile())!;
    expect(row.nickname, '小莫');
    expect(row.avatarFile, 'av.jpg');
    expect(storeB.exists('av.jpg'), isTrue);
    expect(storeB.hasRealThumb('av.jpg'), isTrue); // 本機列表縮圖
    expect(storeB.hasPlaceholder('av.jpg'), isFalse); // 原圖到了，占位圖已清掉
  });

  test('頭像排在下載清單最前面（先於其他圖片）', () async {
    final names = <String>[];
    remote = MemoryRemote(
      onTransfer: (n, up) async {
        if (!up && n.startsWith('images__')) names.add(n);
      },
    );
    for (final f in ['x1.jpg', 'x2.jpg', 'av.jpg']) {
      File('${dirA.path}/$f').writeAsBytesSync([1, 2, 3]);
    }
    final pit = await a.createPit(name: '坑');
    await a.addFanArts(pit, [
      NewImage(file: 'x1.jpg', width: 1, height: 1),
      NewImage(file: 'x2.jpg', width: 1, height: 1),
    ], author: 'x');
    await a.saveProfile(nickname: 'n', avatarFile: 'av.jpg');
    await eng(a, storeA).sync();
    await eng(b, storeB).sync();
    expect(names.first, 'images__av.jpg');
  });

  test('last-write-wins：較新的編輯勝，較舊的本機編輯不推上去', () async {
    await a.saveProfile(nickname: 'A舊', avatarFile: null, at: ms(1000));
    await eng(a, storeA).sync();
    await eng(b, storeB).sync();
    expect((await b.getProfile())!.nickname, 'A舊');

    await b.saveProfile(nickname: 'B新', avatarFile: null, at: ms(5000));
    await a.saveProfile(nickname: 'A中', avatarFile: null, at: ms(3000));
    await eng(b, storeB).sync();
    await eng(a, storeA).sync();
    expect((await a.getProfile())!.nickname, 'B新');

    await a.saveProfile(nickname: 'A最新', avatarFile: null, at: ms(9000));
    await eng(a, storeA).sync();
    await eng(b, storeB).sync();
    expect((await b.getProfile())!.nickname, 'A最新');
  });

  test('本機較新的編輯在拉取時不被遠端覆蓋，且被推上去', () async {
    await a.saveProfile(nickname: '遠端舊', avatarFile: null, at: ms(1000));
    await eng(a, storeA).sync();
    await b.saveProfile(nickname: '本機新', avatarFile: null, at: ms(8000));
    await eng(b, storeB).sync();
    expect((await b.getProfile())!.nickname, '本機新');
    await eng(a, storeA).sync();
    expect((await a.getProfile())!.nickname, '本機新');
  });

  test('頭像清成 null 也會同步', () async {
    await a.saveProfile(nickname: 'n', avatarFile: 'av.jpg', at: ms(1000));
    await eng(a, storeA).sync();
    await eng(b, storeB).sync();
    await a.saveProfile(nickname: 'n', avatarFile: null, at: ms(2000));
    await eng(a, storeA).sync();
    await eng(b, storeB).sync();
    expect((await b.getProfile())!.avatarFile, isNull);
  });

  test('舊版 App（不認得 profile 種類）照常同步，不報錯、不動 profile；格式版本不變', () async {
    await a.saveProfile(nickname: '小莫', avatarFile: null);
    await eng(a, storeA).sync();
    final old = [
      for (final k in allSyncKinds)
        if (k.name != 'profile') k,
    ];
    final r = await eng(b, storeB, kinds: old).sync();
    expect(r.skippedDocs, isEmpty);
    expect(await b.getProfile(), isNull);
    expect(syncFormatVersion, 2);
  });

  group('設定與資料庫對齊', () {
    ProviderContainer make(AppDatabase db) {
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('saveProfile 寫進資料庫（updatedAt 現在）並更新設定', () async {
      final c = make(a);
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await c
          .read(settingsProvider.notifier)
          .saveProfile(nickname: '莫', avatarFile: 'z.jpg');
      expect(c.read(settingsProvider).nickname, '莫');
      final row = (await a.getProfile())!;
      expect(row.avatarFile, 'z.jpg');
      expect(row.updatedAt.isAfter(before), isTrue);
    });

    test('同步拉下來後 reloadProfile 讓設定（畫面）更新', () async {
      final c = make(a);
      await c.read(settingsProvider.notifier).reloadProfile();
      expect(c.read(settingsProvider).nickname, isEmpty);
      await a.saveProfile(nickname: '遠端', avatarFile: 'r.jpg');
      await c.read(settingsProvider.notifier).reloadProfile();
      expect(c.read(settingsProvider).nickname, '遠端');
      expect(c.read(settingsProvider).avatarFile, 'r.jpg');
    });

    test('升級前只存在設定裡的暱稱：補進資料庫、updatedAt=0，不會蓋掉雲端較新的', () async {
      final c = make(a);
      c.read(settingsProvider.notifier).setNickname('舊暱稱');
      await c.read(settingsProvider.notifier).reloadProfile();
      expect((await a.getProfile())!.updatedAt.millisecondsSinceEpoch, 0);

      await b.saveProfile(nickname: '新暱稱', avatarFile: null);
      await eng(b, storeB).sync();
      await eng(a, storeA).sync();
      await c.read(settingsProvider.notifier).reloadProfile();
      expect(c.read(settingsProvider).nickname, '新暱稱');
    });

    test('全新裝置（設定與資料庫都空）不會憑空產生 profile 紀錄', () async {
      final c = make(a);
      await c.read(settingsProvider.notifier).reloadProfile();
      expect(await a.getProfile(), isNull);
    });
  });

  group('縮圖補傳與盤點', () {
    test('補縮圖：最近加入的圖先補；仍缺縮圖的張數記在 thumbsStillMissing', () async {
      final pit = await a.createPit(name: '坑');
      final names = ['o1.jpg', 'o2.jpg', 'o3.jpg'];
      for (var i = 0; i < names.length; i++) {
        File('${dirA.path}/${names[i]}')
          ..writeAsBytesSync([1, 2, 3])
          ..setLastModifiedSync(DateTime(2026, 1, 1 + i * 10)); // o3 最新
      }
      await a.addFanArts(pit, [
        for (final n in names) NewImage(file: n, width: 1, height: 1),
      ], author: 'x');
      for (final n in names) {
        await remote.upload('images__$n', Uint8List.fromList([1]));
      }
      final up = <String>[];
      final spy = MemoryRemote(
        onTransfer: (n, u) async {
          if (u && n.startsWith('thumbs__')) up.add(n);
        },
      )..files.addAll(remote.files);
      final r = await SyncEngine(
        db: a,
        remote: spy,
        images: storeA,
        thumbnails: _Maker(),
        thumbBackfillLimit: 1,
      ).sync();
      expect(up, [thumbRemoteName('o3.jpg')]);
      expect(r.thumbsUp, 1);
      expect(r.thumbsStillMissing, 2);
    });

    test('預設補占位圖上限提高到 300', () {
      expect(syncThumbBackfillLimit, 300);
    });
  });

  group('DriveRemote 縮圖連結', () {
    test('resizeThumbnailLink 各種結尾都變成 =s32', () {
      const base = 'https://lh3.googleusercontent.com/abc';
      for (final tail in [
        '=s220',
        '=s220-c',
        '=w220-h160',
        '=w220-h160-p-k-no',
      ]) {
        expect(DriveRemote.resizeThumbnailLink('$base$tail'), '$base=s32');
      }
      expect(DriveRemote.resizeThumbnailLink(base), '$base=s32');
    });

    test('list 一次帶回 thumbnailLink：備援縮圖只要一次下載請求（不再 files.get）', () async {
      final seen = <http.Request>[];
      final client = MockClient((req) async {
        seen.add(req);
        if (req.url.queryParameters.containsKey('spaces')) {
          expect(req.url.queryParameters['fields'], contains('thumbnailLink'));
          return http.Response(
            '{"files":[{"id":"F1","name":"images__a.png","modifiedTime":"t",'
            '"thumbnailLink":"https://lh3.googleusercontent.com/x=s220"}]}',
            200,
          );
        }
        return http.Response.bytes([0xFF, 0xD8, 7], 200);
      });
      final d = DriveRemote(
        headers: () async => {'Authorization': 'Bearer t'},
        client: client,
        retryDelay: Duration.zero,
      );
      await d.list();
      final bytes = await d.fallbackThumbnail('images__a.png');
      expect(bytes, [0xFF, 0xD8, 7]);
      expect(seen.length, 2);
      expect(seen[1].url.toString(), 'https://lh3.googleusercontent.com/x=s32');
    });
  });
}
