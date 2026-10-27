import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/media/thumbnail_maker.dart';
import 'package:huakeng/sync/drive_remote.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';
import 'package:image/image.dart' as img;

/// 縮圖機制（D-099）：上傳同時產縮圖、下載次序（meta → 縮圖 → 原圖）、舊資料補縮圖、
/// thumbnailLink 備援、沒有縮圖時照常運作。全部用假 Drive（MemoryRemote／MockClient）。

Uint8List pngBytes(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (final p in image) {
    p
      ..r = (p.x * 255 ~/ w)
      ..g = (p.y * 255 ~/ h)
      ..b = 128;
    if (alpha) p.a = 0;
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 帶雜訊的類照片影像（比漸層難壓）。
Uint8List noisyPng(int w, int h) {
  final image = img.Image(width: w, height: h, numChannels: 3);
  var seed = 12345;
  for (final p in image) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    final n = (seed >> 16) % 40;
    p
      ..r = (p.x * 255 ~/ w + n) % 256
      ..g = (p.y * 255 ~/ h + n) % 256
      ..b = (128 + n * 2) % 256;
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 不實作 [ThumbnailFallbackRemote] 的遠端（模擬沒有備援能力的後端）。
class PlainRemote implements SyncRemote {
  PlainRemote(this.inner);
  final MemoryRemote inner;
  @override
  Future<List<RemoteFile>> list() => inner.list();
  @override
  Future<Uint8List?> download(String name, {TransferProgress? onProgress}) =>
      inner.download(name, onProgress: onProgress);
  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) => inner.upload(
    name,
    bytes,
    contentType: contentType,
    onProgress: onProgress,
  );
}

/// 計次的假縮圖機：不碰引擎解碼，行為可控。
class CountingMaker implements ThumbnailMaker {
  CountingMaker({this.fail = const {}});
  final Set<String> fail;
  final calls = <String>[];
  @override
  Future<Uint8List?> make(File source, {bool placeholder = false}) async {
    final n = source.uri.pathSegments.last;
    calls.add(n);
    if (fail.contains(n)) return null;
    return Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase a, b;
  late Directory dirA, dirB;
  late ImageStore storeA, storeB;
  late List<String> log;
  late MemoryRemote remote;

  setUp(() async {
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    dirA = await Directory.systemTemp.createTemp('thumbs_a');
    dirB = await Directory.systemTemp.createTemp('thumbs_b');
    storeA = ImageStore(dirA);
    storeB = ImageStore(dirB);
    log = [];
    remote = MemoryRemote(
      onTransfer: (n, up) async => log.add('${up ? 'up' : 'down'}:$n'),
    );
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await dirA.delete(recursive: true);
    await dirB.delete(recursive: true);
  });

  Future<List<String>> addImages(int n, {int w = 1200, int h = 800}) async {
    final pit = await a.createPit(name: '坑A');
    final names = <String>[];
    for (var i = 0; i < n; i++) {
      final name = 'img$i.png';
      File('${dirA.path}/$name').writeAsBytesSync(pngBytes(w, h));
      names.add(name);
    }
    await a.addFanArts(pit, [
      for (final f in names) NewImage(file: f, width: w, height: h),
    ], author: 'x');
    return names;
  }

  String thumbOf(String f) => thumbRemoteName(f);
  int count(String prefix) => log.where((e) => e.startsWith(prefix)).length;

  test('上傳原圖同時上傳 thumbs（占位圖：長邊 32、JPEG、極小），占位圖先於原圖', () async {
    final names = await addImages(2);
    final engine = SyncEngine(db: a, remote: remote, images: storeA);
    final r = await engine.sync();
    expect(r.imagesUp, 2);
    expect(r.thumbsUp, 2);
    for (final f in names) {
      final bytes = remote.files[thumbOf(f)]!;
      expect(bytes.sublist(0, 2), [0xFF, 0xD8]); // JPEG
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.width, 32);
      expect(decoded.height, 21);
      expect(bytes.length, lessThan(3 * 1024));
      // 本機列表縮圖（480）另外存、不上傳
      expect(storeA.hasRealThumb(f), isTrue);
      expect(
        img.decodeJpg(storeA.thumbFileOf(f).readAsBytesSync())!.width,
        480,
      );
      expect(
        log.indexOf('up:${thumbOf(f)}'),
        lessThan(log.indexOf('up:images__$f')),
        reason: '縮圖要先於原圖',
      );
    }
  });

  test('占位圖大小：1200x800 類照片影像 ≤ 3KB、長邊 32；直圖長邊也是 32', () async {
    for (final bytes in [noisyPng(1200, 800), pngBytes(1200, 800)]) {
      final f = File('${dirA.path}/ph_${bytes.length}.png')
        ..writeAsBytesSync(bytes);
      final out = (await const DefaultThumbnailMaker().make(
        f,
        placeholder: true,
      ))!;
      expect(out.length, lessThanOrEqualTo(3 * 1024));
      final d = img.decodeJpg(out)!;
      expect([d.width, d.height], [32, 21]);
    }
    final tall = File('${dirA.path}/tall.png')
      ..writeAsBytesSync(noisyPng(600, 1200));
    final t = img.decodeJpg(
      (await const DefaultThumbnailMaker().make(tall, placeholder: true))!,
    )!;
    expect([t.width, t.height], [16, 32]);
  });

  test('影片原檔與壞檔不產縮圖，也不報錯；壞檔標記後不再重試', () async {
    final pit = await a.createPit(name: '坑A', junkEnabled: true);
    File('${dirA.path}/v.mp4').writeAsBytesSync([1, 2, 3]);
    File('${dirA.path}/bad.png').writeAsBytesSync([1, 2, 3, 4]);
    await a.addJunk(pit, [
      NewImage(file: 'v.mp4', width: 0, height: 0, kind: MediaKind.video),
      NewImage(file: 'bad.png', width: 1, height: 1),
    ]);
    final maker = CountingMaker(fail: {'bad.png'});
    final engine = SyncEngine(
      db: a,
      remote: remote,
      images: storeA,
      thumbnails: maker,
    );
    final r = await engine.sync();
    expect(r.imagesUp, 2);
    expect(r.thumbsUp, 0);
    expect(remote.files.keys.where((k) => k.startsWith('thumbs__')), isEmpty);
    expect(maker.calls, ['bad.png']); // 影片根本沒送去產生
    expect(storeA.thumbFailed('bad.png'), isTrue);
    // 再同步（補縮圖會掃一遍）：不再重試
    await engine.sync();
    expect(maker.calls, ['bad.png']);
  });

  test('下載次序：meta → 全部縮圖 → 原圖；縮圖階段有進度；原圖開始前縮圖都到了', () async {
    final names = await addImages(3);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    log.clear();

    final stages = <SyncProgress>[];
    var thumbsReadyWhenFirstImage = false;
    final watching = MemoryRemote(
      onTransfer: (n, up) async {
        log.add('${up ? 'up' : 'down'}:$n');
        if (!up && n.startsWith('images__') && !thumbsReadyWhenFirstImage) {
          thumbsReadyWhenFirstImage = names.every(storeB.hasPlaceholder);
        }
      },
    )..files.addAll(remote.files);
    final engineB = SyncEngine(db: b, remote: watching, images: storeB);
    final r = await engineB.sync(onProgress: stages.add);
    expect(r.thumbsDown, 3);
    expect(r.imagesDown, 3);
    expect(thumbsReadyWhenFirstImage, isTrue);

    final lastMeta = log.lastIndexWhere((e) => e.startsWith('down:meta__'));
    final firstThumb = log.indexWhere((e) => e.startsWith('down:thumbs__'));
    final lastThumb = log.lastIndexWhere((e) => e.startsWith('down:thumbs__'));
    final firstImage = log.indexWhere((e) => e.startsWith('down:images__'));
    expect(lastMeta, lessThan(firstThumb));
    expect(lastThumb, lessThan(firstImage));

    final thumbStages = stages.where(
      (s) => s.stage == SyncStage.downloadingThumbs,
    );
    expect(thumbStages, isNotEmpty);
    expect(thumbStages.first.thumbsTotal, 3);
    expect(thumbStages.last.thumbsDone, 3);
    final firstImageStage = stages.indexWhere(
      (s) => s.stage == SyncStage.downloadingImages,
    );
    expect(
      stages.lastIndexWhere((s) => s.stage == SyncStage.downloadingThumbs),
      lessThan(firstImageStage),
    );
    // 傳輸清單只含原圖（縮圖不佔 sheet 的列）
    expect(
      stages.last.transfers.every((t) => !t.file.startsWith('thumbs__')),
      isTrue,
    );
  });

  test('下載來的占位圖不算列表縮圖；原圖到了就換掉（占位檔刪除、原圖在本機）', () async {
    final names = await addImages(2);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    final failing = _FailImages(remote); // 原圖下載中（失敗）
    final engineB = SyncEngine(db: b, remote: failing, images: storeB);
    final r = await engineB.sync();
    expect(r.thumbsDown, 2);
    for (final f in names) {
      expect(storeB.hasPlaceholder(f), isTrue);
      expect(storeB.hasRealThumb(f), isFalse);
      expect(storeB.thumbFileFor(f), isNull);
      expect(
        storeB.placeholderFileFor(f)!.path,
        storeB.placeholderFileOf(f).path,
      );
      expect(storeB.exists(f), isFalse);
    }
    // 原圖到了
    await SyncEngine(db: b, remote: remote, images: storeB).sync();
    for (final f in names) {
      expect(storeB.exists(f), isTrue);
      expect(storeB.hasPlaceholder(f), isFalse);
      expect(storeB.placeholderFileOf(f).existsSync(), isFalse);
      expect(storeB.hasRealThumb(f), isTrue); // 本機由原圖產生 480
      expect(
        img.decodeJpg(storeB.thumbFileOf(f).readAsBytesSync())!.width,
        480,
      );
    }
  });

  test('B 已經有本機縮圖就不再下載；B 的原圖進來後兩邊縮圖一致不重傳', () async {
    await addImages(2);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    final engineB = SyncEngine(db: b, remote: remote, images: storeB);
    await engineB.sync();
    log.clear();
    final r = await engineB.sync();
    expect(r.thumbsDown, 0);
    expect(r.thumbsUp, 0);
    expect(count('up:'), 0);
    expect(count('down:thumbs__'), 0);
  });

  test('原圖下載最多同時 3 張（同步 sheet 同時顯示 3 張傳輸中）', () async {
    await addImages(7);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    final slow = MemoryRemote(
      progressSteps: 3,
      stepDelay: const Duration(milliseconds: 5),
    )..files.addAll(remote.files);
    var maxActive = 0;
    await SyncEngine(
      db: b,
      remote: slow,
      images: storeB,
      progressInterval: Duration.zero,
    ).sync(
      onProgress: (p) {
        final n = p.transfers.where((t) => t.isActive).length;
        if (n > maxActive) maxActive = n;
      },
    );
    expect(maxActive, 3);
    expect(Directory(dirB.path).listSync().whereType<File>(), hasLength(7));
  });

  group('舊資料補縮圖（一次性遷移）', () {
    test('補占位圖上傳的是 32px 小圖（≤ 3KB），不是 480 縮圖', () async {
      final pit = await a.createPit(name: '坑A');
      File('${dirA.path}/n.png').writeAsBytesSync(noisyPng(1200, 800));
      await a.addFanArts(pit, [
        NewImage(file: 'n.png', width: 1200, height: 800),
      ], author: 'x');
      await remote.upload('images__n.png', Uint8List.fromList([1]));
      final r = await SyncEngine(db: a, remote: remote, images: storeA).sync();
      expect(r.thumbsUp, 1);
      final up = remote.files[thumbOf('n.png')]!;
      expect(up.length, lessThanOrEqualTo(3 * 1024));
      expect(img.decodeJpg(up)!.width, 32);
    });

    test('限速（每次最多 N 張）、可續傳、不重複上傳；全補完後不再動作', () async {
      final names = await addImages(5);
      // 模擬舊版 App：Drive 上有原圖與 meta，沒有縮圖；本機也沒有縮圖快取。
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
      for (final f in storeA.thumbDir.listSync()) {
        f.deleteSync();
      }
      log.clear();

      final engine = SyncEngine(
        db: a,
        remote: remote,
        images: storeA,
        thumbBackfillLimit: 2,
      );
      expect((await engine.sync()).thumbsUp, 2);
      expect((await engine.sync()).thumbsUp, 2);
      expect((await engine.sync()).thumbsUp, 1);
      expect((await engine.sync()).thumbsUp, 0);
      final ups = log.where((e) => e.startsWith('up:thumbs__')).toList();
      expect(ups.length, 5);
      expect(ups.toSet().length, 5, reason: '同一張縮圖不能傳兩次');
      for (final f in names) {
        expect(remote.files.containsKey(thumbOf(f)), isTrue);
      }
    });

    test('沒有原圖的裝置不補縮圖（只有手上有原圖的那台才補）', () async {
      await addImages(2);
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
      log.clear();
      // B 原圖下載失敗＝手上沒有原圖
      final failing = _FailImages(remote);
      final r = await SyncEngine(db: b, remote: failing, images: storeB).sync();
      expect(r.thumbsUp, 0);
      expect(log.where((e) => e.startsWith('up:thumbs__')), isEmpty);
    });
  });

  group('thumbnailLink 備援', () {
    test('雲端還沒有占位圖：先拿 Drive 的 thumbnailLink（=s32）頂著，且不算列表縮圖', () async {
      final names = await addImages(3);
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
      for (final f in names) {
        remote.fallbackThumbs['images__$f'] = Uint8List.fromList([
          0xFF,
          0xD8,
          9,
        ]);
      }
      // B 的原圖下載失敗（模擬還在下載中）：列表只靠暫用縮圖
      final failing = _FailImages(remote);
      final engineB = SyncEngine(db: b, remote: failing, images: storeB);
      final r = await engineB.sync();
      expect(r.thumbsFallback, 3);
      for (final f in names) {
        expect(storeB.hasPlaceholder(f), isTrue);
        expect(storeB.hasRealThumb(f), isFalse);
        expect(storeB.thumbFileFor(f), isNull);
      }
      // 再同步一次：暫用縮圖已有，不再重複向 Drive 要
      final calls = remote.fallbackCalls;
      await engineB.sync();
      expect(remote.fallbackCalls, calls);

      // A 補好占位圖；B 已有占位圖，照單全收不再下載
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      expect(
        remote.files.keys.where((k) => k.startsWith('thumbs__')),
        hasLength(3),
      );
      final r2 = await engineB.sync();
      expect(r2.thumbsDown, 0);
    });

    test('備援失敗（回 null、丟例外）不阻塞同步，原圖照常下載', () async {
      await addImages(2);
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
      final r = await SyncEngine(
        db: b,
        remote: _ThrowingFallback(remote),
        images: storeB,
      ).sync();
      expect(r.imagesDown, 2);
      expect(r.thumbsFallback, 0);
      expect(r.thumbFailures, greaterThan(0));
    });

    test('遠端沒有備援能力時照常運作（沒有縮圖、不報錯）', () async {
      final names = await addImages(2);
      await SyncEngine(db: a, remote: remote, images: storeA).sync();
      remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
      final plain = PlainRemote(remote);
      final r = await SyncEngine(db: b, remote: plain, images: storeB).sync();
      expect(r.imagesDown, 2);
      expect(r.thumbFailures, 0);
      for (final f in names) {
        expect(File('${dirB.path}/$f').existsSync(), isTrue);
      }
    });
  });

  test('舊版裝置不產縮圖、舊 meta 沒有新欄位：新版照常同步', () async {
    // 舊版 App 的行為：只傳原圖與 meta
    final names = await addImages(2);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    remote.files.removeWhere((k, _) => k.startsWith('thumbs__'));
    final r = await SyncEngine(
      db: b,
      remote: PlainRemote(remote),
      images: storeB,
    ).sync();
    expect(r.pulled, greaterThan(0));
    expect(r.imagesDown, names.length);
    expect(r.thumbFailures, 0);
  });

  test('縮圖下載整批失敗：放棄縮圖階段但原圖照常', () async {
    final names = await addImages(30);
    await SyncEngine(db: a, remote: remote, images: storeA).sync();
    final broken = _BrokenThumbs(remote);
    final r = await SyncEngine(db: b, remote: broken, images: storeB).sync();
    expect(r.imagesDown, names.length);
    expect(r.thumbsDown, 0);
    // 連續失敗 12 張就停（並行 8 張，最多再多幾張在途），不會把 30 張都試完
    expect(broken.thumbTries, lessThan(30));
  });

  group('DriveRemote.fallbackThumbnail（files.get thumbnailLink）', () {
    DriveRemote make(http.Client c, {Future<void> Function()? refresh}) =>
        DriveRemote(
          headers: () async => {'Authorization': 'Bearer tok'},
          client: c,
          refreshAuth: refresh,
          retryDelay: Duration.zero,
        );

    http.Client client(
      List<http.Request> seen, {
      String? link = 'https://lh3.googleusercontent.com/x=s220',
      int getStatus = 200,
      int linkStatus = 200,
    }) => MockClient((req) async {
      seen.add(req);
      if (req.url.host == 'www.googleapis.com' &&
          req.url.queryParameters.containsKey('spaces')) {
        return http.Response(
          jsonEncode({
            'files': [
              {'id': 'F1', 'name': 'images__a.png', 'modifiedTime': 't'},
            ],
          }),
          200,
        );
      }
      if (req.url.path.endsWith('/F1')) {
        return http.Response(jsonEncode({'thumbnailLink': ?link}), getStatus);
      }
      return http.Response.bytes([0xFF, 0xD8, 7], linkStatus);
    });

    test('帶 token 取連結，尺寸改成 =s32（極小）再帶 token 下載', () async {
      final seen = <http.Request>[];
      final remote = make(client(seen));
      await remote.list();
      final bytes = await remote.fallbackThumbnail('images__a.png');
      expect(bytes, [0xFF, 0xD8, 7]);
      final get = seen[1];
      expect(get.url.queryParameters['fields'], 'thumbnailLink');
      expect(get.headers['Authorization'], 'Bearer tok');
      final dl = seen[2];
      expect(dl.url.toString(), 'https://lh3.googleusercontent.com/x=s32');
      expect(dl.headers['Authorization'], 'Bearer tok');
    });

    test('沒有連結、連結過期（403/404）、找不到檔案都回 null，不丟例外', () async {
      for (final c in [
        client([], link: null),
        client([], linkStatus: 404),
        client([], getStatus: 404),
      ]) {
        final remote = make(c);
        await remote.list();
        expect(await remote.fallbackThumbnail('images__a.png'), isNull);
      }
      final remote = make(client([]));
      expect(await remote.fallbackThumbnail('images__nope.png'), isNull);
    });

    test('授權過期（401）照常往上丟，讓同步流程重新授權', () async {
      final seen = <http.Request>[];
      final remote = make(client(seen, getStatus: 401));
      await remote.list();
      await expectLater(
        remote.fallbackThumbnail('images__a.png'),
        throwsA(isA<SyncAuthException>()),
      );
    });
  });

  group('縮圖產生器', () {
    Future<Uint8List?> run(Uint8List bytes) async {
      final f = File('${Directory.systemTemp.path}/mk_${bytes.length}.bin')
        ..writeAsBytesSync(bytes);
      addTearDown(f.deleteSync);
      return const DefaultThumbnailMaker().make(f);
    }

    test('大圖縮到長邊 480；小圖不放大；直圖也對', () async {
      final big = img.decodeJpg((await run(pngBytes(3000, 2000)))!)!;
      expect([big.width, big.height], [480, 320]);
      final small = img.decodeJpg((await run(pngBytes(200, 100)))!)!;
      expect([small.width, small.height], [200, 100]);
      final tall = img.decodeJpg((await run(pngBytes(800, 1600)))!)!;
      expect([tall.width, tall.height], [240, 480]);
    });

    test('透明 PNG 鋪白底；GIF 取第一格；壞檔回傳 null', () async {
      final t = img.decodeJpg((await run(pngBytes(600, 600, alpha: true)))!)!;
      final px = t.getPixel(10, 10);
      expect(px.r, greaterThan(240));
      expect(px.g, greaterThan(240));
      final gif = img.Image(width: 64, height: 32)
        ..clear(img.ColorRgb8(200, 30, 30));
      final g = await run(Uint8List.fromList(img.encodeGif(gif)));
      expect(g, isNotNull);
      expect(img.decodeJpg(g!)!.width, 64);
      expect(await run(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    });
  });

  test('ImageStore：占位圖與列表縮圖分開存；索引重載後一致', () async {
    await storeA.savePlaceholder('p1.png', Uint8List.fromList([1]));
    expect(storeA.hasPlaceholder('p1.png'), isTrue);
    expect(storeA.hasRealThumb('p1.png'), isFalse);
    expect(storeA.thumbFileFor('p1.png'), isNull);
    expect(storeA.placeholderFileFor('p1.png')!.path, contains('placeholders'));
    await storeA.saveThumb('p1.png', Uint8List.fromList([2]));
    expect(storeA.hasRealThumb('p1.png'), isTrue);
    expect(storeA.thumbFileFor('p1.png')!.path, contains('thumbs'));
    // 原圖到了：占位圖刪除，列表縮圖留著
    await storeA.save('p1.png', Uint8List.fromList([9]));
    expect(storeA.hasPlaceholder('p1.png'), isFalse);
    expect(storeA.hasRealThumb('p1.png'), isTrue);
    await storeA.markThumbFailed('bad.png');
    await storeA.savePlaceholder('q.png', Uint8List.fromList([1]));
    final fresh = ImageStore(dirA);
    await fresh.loadThumbIndex();
    expect(fresh.hasRealThumb('p1.png'), isTrue);
    expect(fresh.hasPlaceholder('q.png'), isTrue);
    expect(fresh.hasRealThumb('q.png'), isFalse);
    expect(fresh.thumbFailed('bad.png'), isTrue);
    expect(fresh.hasThumb('nope.png'), isFalse);
    // 版本通知：有縮圖寫入時送出遞增版本號
    final versions = <int>[];
    final sub = storeA.watchThumb('p2.png').listen(versions.add);
    await Future<void>.delayed(Duration.zero);
    await storeA.savePlaceholder('p2.png', Uint8List.fromList([1]));
    await storeA.saveThumb('p2.png', Uint8List.fromList([2]));
    await Future<void>.delayed(Duration.zero);
    expect(versions, [0, 1, 2]);
    await sub.cancel();
  });
}

/// 原圖下載一律失敗（模擬還在下載中）；其餘轉給 [MemoryRemote]。
class _FailImages extends PlainRemote implements ThumbnailFallbackRemote {
  _FailImages(super.inner);
  @override
  Future<Uint8List?> download(String name, {TransferProgress? onProgress}) {
    if (name.startsWith('images__')) throw SyncNetworkException('boom');
    return super.download(name, onProgress: onProgress);
  }

  @override
  Future<Uint8List?> fallbackThumbnail(String name) =>
      inner.fallbackThumbnail(name);
}

class _ThrowingFallback extends PlainRemote implements ThumbnailFallbackRemote {
  _ThrowingFallback(super.inner);
  @override
  Future<Uint8List?> fallbackThumbnail(String name) async =>
      throw StateError('link expired');
}

class _BrokenThumbs extends PlainRemote {
  _BrokenThumbs(super.inner);
  int thumbTries = 0;
  @override
  Future<Uint8List?> download(String name, {TransferProgress? onProgress}) {
    if (name.startsWith('thumbs__')) {
      thumbTries++;
      throw SyncNetworkException('boom');
    }
    return super.download(name, onProgress: onProgress);
  }
}
