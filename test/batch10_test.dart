import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/media.dart';
import 'package:huakeng/data/media_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:image_picker/image_picker.dart';

/// 批次 10 資料層：格子封面、媒體（D-080）、推活多選（D-079）。
void main() {
  late AppDatabase db;
  late String pitId;
  late String groupId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '坑A');
    groupId = (await db.watchGroups(pitId).first).first.id;
  });
  tearDown(() => db.close());

  Future<String> oshi(
    String file, {
    DateTime? date,
    String? group,
    String? pit,
    List<NewImage>? images,
  }) => db.saveOshiRecord(
    pitId: pit ?? pitId,
    date: date ?? DateTime(2026, 10, 1),
    groupId: group,
    images: images ?? [NewImage(file: file)],
  );

  Future<String> piece(
    String title,
    List<NewImage> images,
    DateTime at, {
    String? id,
  }) => db.savePiece(
    id: id,
    pitId: pitId,
    title: title,
    body: '',
    images: images,
    tagIds: const [],
    links: const [],
    targetLikes: 0,
    finishedAt: at,
    ideaIds: const [],
    draftIds: const [],
  );

  group('媒體種類判斷', () {
    List<int> bytes(String head, {int pad = 0}) => [
      ...head.codeUnits,
      ...List.filled(pad, 0),
    ];

    test('magic bytes：GIF、mp4、mov、webm/mkv、HEIC 不是影片、JPEG/PNG/WebP', () {
      expect(mediaKindFromBytes(bytes('GIF89a')), MediaKind.gif);
      expect(mediaKindFromBytes(bytes('GIF87a')), MediaKind.gif);
      // ....ftypisom / ftypqt / ftyp3gp4
      for (final brand in ['isom', 'mp42', 'M4V ', 'qt  ', '3gp4']) {
        expect(
          mediaKindFromBytes([0, 0, 0, 24, ...'ftyp$brand'.codeUnits]),
          MediaKind.video,
          reason: brand,
        );
      }
      expect(
        mediaKindFromBytes([0, 0, 0, 24, ...'ftypheic'.codeUnits]),
        MediaKind.image,
      );
      expect(
        mediaKindFromBytes([0, 0, 0, 24, ...'ftypavif'.codeUnits]),
        MediaKind.image,
      );
      expect(
        mediaKindFromBytes([0x1A, 0x45, 0xDF, 0xA3, 1, 2]),
        MediaKind.video,
      );
      expect(
        mediaKindFromBytes([0, 0, 0, 8, ...'wide'.codeUnits]),
        MediaKind.video,
      );
      expect(mediaKindFromBytes([0xFF, 0xD8, 0xFF, 0xE0]), MediaKind.image);
      expect(
        mediaKindFromBytes([0x89, ...'PNG'.codeUnits, 13, 10]),
        MediaKind.image,
      );
      expect(
        mediaKindFromBytes([
          ...'RIFF'.codeUnits,
          0,
          0,
          0,
          0,
          ...'WEBP'.codeUnits,
        ]),
        MediaKind.image,
      );
      expect(mediaKindFromBytes([1, 2, 3]), isNull);
      expect(mediaKindFromBytes(const []), isNull);
    });

    test('副檔名：gif、各種影片、大小寫、未知＝圖片', () {
      expect(mediaKindFromExtension('a.GIF'), MediaKind.gif);
      for (final e in ['mp4', 'MOV', 'm4v', 'webm', '3gp', 'mkv']) {
        expect(
          mediaKindFromExtension('/x/y/clip.$e'),
          MediaKind.video,
          reason: e,
        );
      }
      for (final n in [
        'a.jpg',
        'a.png',
        'a.webp',
        'a.heic',
        'noext',
        'a.',
        '',
      ]) {
        expect(mediaKindFromExtension(n), MediaKind.image, reason: n);
      }
    });

    test('detectMediaKind：內容優先，認不出才看副檔名', () {
      // 改了副檔名的 GIF 仍是 GIF
      expect(detectMediaKind('a.jpg', bytes('GIF89a')), MediaKind.gif);
      // 內容是 JPEG 就算叫 .mp4 也是圖片
      expect(detectMediaKind('a.mp4', [0xFF, 0xD8, 0xFF]), MediaKind.image);
      // 截斷／不認得的內容 → 副檔名
      expect(detectMediaKind('a.mp4', const [1, 2]), MediaKind.video);
      expect(detectMediaKind('a.gif', const []), MediaKind.gif);
    });

    test('MediaKindX.parse：不認得的值（較新版 App）當圖片；staticFileOf', () {
      expect(MediaKindX.parse('video'), MediaKind.video);
      expect(MediaKindX.parse('audio'), MediaKind.image);
      expect(MediaKindX.parse(null), MediaKind.image);
      expect(staticFileOf(MediaKind.image, 'a.png', 'p.jpg'), 'a.png');
      expect(staticFileOf(MediaKind.gif, 'a.gif', null), 'a.gif');
      expect(staticFileOf(MediaKind.video, 'v.mp4', 'p.jpg'), 'p.jpg');
      expect(staticFileOf(MediaKind.video, 'v.mp4', null), isNull);
      expect(staticFileOf(MediaKind.video, 'v.mp4', ''), isNull);
    });
  });

  group('ImageStore 匯入', () {
    late Directory src;
    late Directory dst;
    late ImageStore store;
    setUp(() async {
      src = await Directory.systemTemp.createTemp('b10_src');
      dst = await Directory.systemTemp.createTemp('b10_dst');
      store = ImageStore(dst);
    });
    tearDown(() async {
      await src.delete(recursive: true);
      await dst.delete(recursive: true);
    });

    XFile make(String name, List<int> bytes) {
      final f = File('${src.path}/$name')..writeAsBytesSync(bytes);
      return XFile(f.path);
    }

    test('影片：原檔照搬（位元組相同）、kind=video、寬高長度截圖先空著', () async {
      final bytes = [
        0,
        0,
        0,
        24,
        ...'ftypisom'.codeUnits,
        ...List.filled(300, 7),
      ];
      final im = await store.import(make('clip.mp4', bytes));
      expect(im.kind, MediaKind.video);
      expect(im.file, endsWith('.mp4'));
      expect(
        (im.width, im.height, im.durationMs, im.posterFile),
        (0, 0, null, null),
      );
      expect(store.fileOf(im.file).readAsBytesSync(), bytes);
    });

    test('importMedia：帶探測結果與截圖 → 截圖存成獨立檔案、其餘欄位照給的', () async {
      final bytes = [0, 0, 0, 24, ...'ftypqt  '.codeUnits, 1, 2, 3];
      final im = await store.importMedia(
        make('IMG_1.MOV', bytes),
        width: 1080,
        height: 1920,
        durationMs: 24000,
        posterBytes: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(im.file, endsWith('.mov'));
      expect(
        (im.kind, im.width, im.height, im.durationMs),
        (MediaKind.video, 1080, 1920, 24000),
      );
      expect(im.posterFile, endsWith('.jpg'));
      expect(im.posterFile, isNot(im.file));
      expect(store.fileOf(im.posterFile!).readAsBytesSync(), [1, 2, 3, 4]);
      expect(store.exists(im.posterFile!), isTrue);
    });

    test('GIF：kind=gif、原檔不動；圖片附帶的影片參數被忽略', () async {
      final gif = [...'GIF89a'.codeUnits, 1, 0, 1, 0, 0, 0, 0, 0x3B];
      final g = await store.importMedia(
        make('a.gif', gif),
        durationMs: 99,
        posterBytes: Uint8List.fromList([1]),
      );
      expect(g.kind, MediaKind.gif);
      expect(g.file, endsWith('.gif'));
      expect((g.durationMs, g.posterFile), (null, null));
      expect(store.fileOf(g.file).readAsBytesSync(), gif);
    });

    test('沒有副檔名的檔案依內容取預設副檔名', () async {
      final v = await store.import(
        make('noext', [0, 0, 0, 24, ...'ftypisom'.codeUnits, 5]),
      );
      expect(v.file, endsWith('.mp4'));
      final i = await store.import(make('blob', [1, 2, 3]));
      expect((i.kind, i.file.endsWith('.jpg')), (MediaKind.image, true));
    });
  });

  group('媒體欄位的儲存與讀出', () {
    const video = NewImage(
      file: 'v.mp4',
      width: 1920,
      height: 1080,
      kind: MediaKind.video,
      durationMs: 24000,
      posterFile: 'v_poster.jpg',
    );

    test('每一種放圖的地方都存得進去、讀得出來', () async {
      await db.addOfficial(pitId, groupId, const [video]);
      await db.addFanArts(pitId, const [video], author: '');
      await db.addJunk(pitId, const [video]);
      await db.addMaterials(MaterialCategory.pose, const [video]);
      final ideaId = await db.saveIdea(
        pitId: pitId,
        title: 'i',
        body: '',
        images: const [video],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      final oshiId = await oshi('x', images: const [video]);
      for (final r in [
        ...await db.select(db.officialImages).get(),
        ...await db.select(db.fanArts).get(),
        ...await db.select(db.junkImages).get(),
        ...await db.select(db.materialImages).get(),
      ]) {
        final (k, d, p) = switch (r) {
          OfficialImage() => (r.kind, r.durationMs, r.posterFile),
          FanArt() => (r.kind, r.durationMs, r.posterFile),
          JunkImage() => (r.kind, r.durationMs, r.posterFile),
          MaterialImage() => (r.kind, r.durationMs, r.posterFile),
          _ => throw StateError('?'),
        };
        expect((k, d, p), (MediaKind.video, 24000, 'v_poster.jpg'));
      }
      final ref = (await db.watchIdeaView(ideaId).first)!.images.single;
      expect(ref.kind, MediaKind.video);
      expect(ref.isVideo, isTrue);
      expect(ref.durationMs, 24000);
      expect(ref.poster, 'v_poster.jpg');
      expect(ref.staticFile, 'v_poster.jpg');
      final o = (await db.getOshiRecord(oshiId))!.images.single;
      expect(
        (o.kind, o.durationMs, o.poster),
        (MediaKind.video, 24000, 'v_poster.jpg'),
      );
    });

    test('預設值：不指定＝image、沒有長度與截圖', () async {
      await db.addJunk(pitId, const [NewImage(file: 'a.png')]);
      final j = (await db.select(db.junkImages).get()).single;
      expect(
        (j.kind, j.durationMs, j.posterFile),
        (MediaKind.image, null, null),
      );
      const ref = ImageRef('a.png', 1, 2);
      expect(
        (ref.kind, ref.isVideo, ref.isGif, ref.staticFile),
        (MediaKind.image, false, false, 'a.png'),
      );
    });

    test('跨格／跨坑移動帶著媒體欄位', () async {
      final other = await db.createPit(name: '坑B');
      await db.addJunk(pitId, const [video]);
      final id = (await db.watchJunk(pitId).first).single.id;
      await db.moveAlbumImages(
        from: AlbumCell.junk,
        to: AlbumCell.fan,
        ids: [id],
        targetPitId: other,
      );
      final f = (await db.select(db.fanArts).get()).single;
      expect(f.pitId, other);
      expect(
        (f.kind, f.durationMs, f.posterFile),
        (MediaKind.video, 24000, 'v_poster.jpg'),
      );
    });

    test('replaceEntityImages：表單把舊影片原樣（只帶檔名寬高）送回，不會洗成圖片', () async {
      final id = await db.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 10, 1),
        images: const [
          video,
          NewImage(file: 'b.png'),
        ],
      );
      // 模擬舊表單：NewImage(file, width, height)
      await db.saveOshiRecord(
        id: id,
        pitId: pitId,
        date: DateTime(2026, 10, 1),
        images: const [
          NewImage(file: 'b.png'),
          NewImage(file: 'v.mp4', width: 1920, height: 1080),
        ],
      );
      final imgs = (await db.getOshiRecord(id))!.images;
      expect(imgs.map((e) => e.file), ['b.png', 'v.mp4']);
      expect(imgs[1].kind, MediaKind.video);
      expect(imgs[1].durationMs, 24000);
      expect(imgs[1].poster, 'v_poster.jpg');
      // toNewImage 也可以原樣送回
      await db.saveOshiRecord(
        id: id,
        pitId: pitId,
        date: DateTime(2026, 10, 1),
        images: [for (final e in imgs) e.toNewImage()],
      );
      expect((await db.getOshiRecord(id))!.images[1].isVideo, isTrue);
    });

    test('setMediaMeta：補寫探測結果與截圖，所有出現該檔名的列都更新，擁有者 updatedAt 變新', () async {
      await db.addOfficial(pitId, groupId, const [
        NewImage(file: 'v.mp4', kind: MediaKind.video),
      ]);
      final oshiId = await oshi(
        'x',
        images: const [NewImage(file: 'v.mp4', kind: MediaKind.video)],
      );
      expect(await db.videosWithoutPoster(), ['v.mp4']);
      final before = (await db.getOshiRecord(oshiId))!.record.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.setMediaMeta(
        'v.mp4',
        width: 640,
        height: 360,
        durationMs: 5000,
        posterFile: 'p.jpg',
      );
      final o = (await db.select(db.officialImages).getSingle());
      expect(
        (o.width, o.height, o.durationMs, o.posterFile),
        (640, 360, 5000, 'p.jpg'),
      );
      final v = (await db.getOshiRecord(oshiId))!;
      expect(v.images.single.poster, 'p.jpg');
      expect(v.images.single.width, 640);
      expect(v.record.updatedAt.isAfter(before), isTrue);
      expect(await db.videosWithoutPoster(), isEmpty);
      // 沒給任何東西 → 不動
      await db.setMediaMeta('v.mp4');
    });
  });

  group('格子封面', () {
    test('預設＝各格最新一張；推活格現在也有封面', () async {
      await db.addOfficial(pitId, groupId, const [NewImage(file: 'o.png')]);
      await db.addFanArts(pitId, const [NewImage(file: 'f.png')], author: '');
      await piece('P', const [
        NewImage(file: 'p1.png'),
        NewImage(file: 'p2.png'),
      ], DateTime(2026, 5, 1));
      await oshi('old.png', date: DateTime(2026, 1, 1));
      await oshi('new.png', date: DateTime(2026, 9, 1));
      final c = await db.watchCellCovers(pitId).first;
      expect(c.official, 'o.png');
      expect(c.fanArt, 'f.png');
      expect(c.piece, 'p1.png');
      expect(c.oshi, 'new.png');
      expect(c.draft, isNull);
      expect(c.idea, isNull);
    });

    test('setCellCover：每一格各自選自己的封面，互不影響，也不動坑封面', () async {
      await db.addOfficial(pitId, groupId, const [
        NewImage(file: 'o1.png'),
        NewImage(file: 'o2.png'),
      ]);
      await db.addFanArts(pitId, const [
        NewImage(file: 'f1.png'),
        NewImage(file: 'f2.png'),
      ], author: '');
      await db.saveDraft(
        pitId: pitId,
        title: 'd',
        body: '',
        images: const [
          NewImage(file: 'd1.png'),
          NewImage(file: 'd2.png'),
        ],
        tagIds: const [],
        ideaIds: const [],
        pieceIds: const [],
      );
      await db.saveIdea(
        pitId: pitId,
        title: 'i',
        body: '',
        images: const [
          NewImage(file: 'i1.png'),
          NewImage(file: 'i2.png'),
        ],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      await piece('P', const [
        NewImage(file: 'p1.png'),
        NewImage(file: 'p2.png'),
      ], DateTime(2026, 5, 1));
      await oshi(
        'x',
        images: const [
          NewImage(file: 'k1.png'),
          NewImage(file: 'k2.png'),
        ],
      );
      await db.setCover(pitId, null);

      for (final (kind, file) in [
        ('official', 'o1.png'),
        ('fan', 'f1.png'),
        ('draft', 'd2.png'),
        ('idea', 'i2.png'),
        ('piece', 'p2.png'),
        ('oshi', 'k2.png'),
      ]) {
        final cands = await db.watchCoverCandidates(pitId, kind: kind).first;
        final pick = cands.firstWhere((c) => c.file == file);
        await db.setCellCover(pitId, kind, pick.id);
        expect(await db.chosenCellCoverId(pitId, kind), pick.id, reason: kind);
      }
      final c = await db.watchCellCovers(pitId).first;
      expect(
        [c.official, c.fanArt, c.draft, c.idea, c.piece, c.oshi],
        ['o1.png', 'f1.png', 'd2.png', 'i2.png', 'p2.png', 'k2.png'],
      );
      // 坑封面（主頁卡片）沒被動到
      expect((await db.watchPit(pitId).first)!.coverImageId, isNull);

      // 清除 → 回到自動
      await db.setCellCover(pitId, 'oshi', null);
      expect((await db.watchCellCovers(pitId).first).oshi, 'k1.png');
      expect(await db.chosenCellCoverId(pitId, 'oshi'), isNull);
      // 坑的 updatedAt 會動（才會跟著坑文件同步）
    });

    test('setCellCover 的錯誤：未知格子、別格／別坑的圖都丟 ArgumentError，且不改動', () async {
      await db.addOfficial(pitId, groupId, const [NewImage(file: 'o.png')]);
      await oshi('k.png');
      final oid = (await db.watchCoverCandidates(pitId, kind: 'official').first)
          .single
          .id;
      final kid =
          (await db.watchCoverCandidates(pitId, kind: 'oshi').first).single.id;
      await expectLater(
        db.setCellCover(pitId, 'junk', oid),
        throwsArgumentError,
      );
      await expectLater(
        db.setCellCover(pitId, 'oshi', oid),
        throwsArgumentError,
      );
      await expectLater(
        db.setCellCover(pitId, 'official', kid),
        throwsArgumentError,
      );
      final other = await db.createPit(name: '坑B');
      await expectLater(
        db.setCellCover(other, 'official', oid),
        throwsArgumentError,
      );
      final pit = (await db.watchPit(pitId).first)!;
      expect((pit.officialCoverId, pit.oshiCoverFile), (null, null));
    });

    test('指定的封面被刪除 → 退回該格最新一張；圖又出現（同檔名）就恢復', () async {
      final a = await oshi('a.png', date: DateTime(2026, 1, 1));
      await oshi('b.png', date: DateTime(2026, 9, 1));
      final cand = (await db.watchCoverCandidates(pitId, kind: 'oshi').first)
          .firstWhere((c) => c.file == 'a.png');
      await db.setCellCover(pitId, 'oshi', cand.id);
      expect((await db.watchCellCovers(pitId).first).oshi, 'a.png');
      await db.deleteOshiBatch([a]);
      expect((await db.watchCellCovers(pitId).first).oshi, 'b.png');
      expect(await db.chosenCellCoverId(pitId, 'oshi'), isNull);
    });

    test('官方圖冊：指定的圖被刪除、移到別格、移到別坑 → 退回最新', () async {
      await db.addOfficial(pitId, groupId, const [NewImage(file: 'o1.png')]);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.addOfficial(pitId, groupId, const [NewImage(file: 'o2.png')]);
      final cands = await db
          .watchCoverCandidates(pitId, kind: 'official')
          .first;
      final o1 = cands.firstWhere((c) => c.file == 'o1.png');
      await db.setCellCover(pitId, 'official', o1.id);
      expect((await db.watchCellCovers(pitId).first).official, 'o1.png');

      // 移到好看同人圖（原格的列被隱藏）
      await db.moveAlbumImages(
        from: AlbumCell.official,
        to: AlbumCell.fan,
        ids: [o1.id],
      );
      expect((await db.watchCellCovers(pitId).first).official, 'o2.png');
      // 移回來 → 隱藏的列恢復，指定的封面也跟著恢復
      final fanId = (await db.watchFanArts(pitId).first).single.id;
      await db.moveAlbumImages(
        from: AlbumCell.fan,
        to: AlbumCell.official,
        ids: [fanId],
      );
      expect((await db.watchCellCovers(pitId).first).official, 'o1.png');

      // 刪除
      await db.deleteOfficial([o1.id]);
      expect((await db.watchCellCovers(pitId).first).official, 'o2.png');
    });

    test('成圖／草稿：圖片被替換掉（檔名不在了）→ 退回；刪除擁有者 → 退回', () async {
      final p1 = await piece('A', const [
        NewImage(file: 'a1.png'),
        NewImage(file: 'a2.png'),
      ], DateTime(2026, 3, 1));
      await piece('B', const [NewImage(file: 'b1.png')], DateTime(2026, 4, 1));
      final cands = await db.watchCoverCandidates(pitId, kind: 'piece').first;
      expect(cands.map((c) => c.file).toSet(), {'a1.png', 'a2.png', 'b1.png'});
      await db.setCellCover(
        pitId,
        'piece',
        cands.firstWhere((c) => c.file == 'a2.png').id,
      );
      expect((await db.watchCellCovers(pitId).first).piece, 'a2.png');
      // 編輯成圖把 a2 拿掉
      await piece(
        'A',
        const [NewImage(file: 'a1.png')],
        DateTime(2026, 3, 1),
        id: p1,
      );
      expect((await db.watchCellCovers(pitId).first).piece, 'b1.png'); // 最新一張成圖
      // 重新指定 a1，再刪掉成圖 A
      final a1 = (await db.watchCoverCandidates(pitId, kind: 'piece').first)
          .firstWhere((c) => c.file == 'a1.png');
      await db.setCellCover(pitId, 'piece', a1.id);
      expect((await db.watchCellCovers(pitId).first).piece, 'a1.png');
      await db.deletePieces([p1]);
      expect((await db.watchCellCovers(pitId).first).piece, 'b1.png');
    });

    test('候選圖：oshi＝每一筆未刪除推活的每一張圖；其他坑與已刪除的不列；null 全部不含推活', () async {
      final other = await db.createPit(name: '坑B');
      await oshi(
        'x',
        images: const [
          NewImage(file: 'k1.png'),
          NewImage(file: 'k2.png'),
        ],
      );
      final gone = await oshi('gone.png');
      await oshi('o.png', pit: other);
      await db.deleteOshiBatch([gone]);
      final c = await db.watchCoverCandidates(pitId, kind: 'oshi').first;
      expect(c.map((e) => e.file).toSet(), {'k1.png', 'k2.png'});
      expect(c.every((e) => e.id.isNotEmpty), isTrue);
      final all = await db.watchCoverCandidates(pitId).first;
      expect(all.any((e) => e.file == 'k1.png'), isFalse);
    });

    test('影片封面用截圖；沒有截圖的影片跳過；指定的影片還沒有截圖 → 退回', () async {
      await oshi(
        'x',
        date: DateTime(2026, 9, 1),
        images: const [
          NewImage(file: 'v1.mp4', kind: MediaKind.video),
          NewImage(file: 'k.png'),
        ],
      );
      // 第一張是還沒截圖的影片 → 跳過，用 k.png
      expect((await db.watchCellCovers(pitId).first).oshi, 'k.png');
      await db.setMediaMeta('v1.mp4', posterFile: 'v1.jpg');
      expect((await db.watchCellCovers(pitId).first).oshi, 'v1.jpg');

      final c = (await db.watchCoverCandidates(pitId, kind: 'oshi').first)
          .firstWhere((e) => e.file == 'v1.mp4');
      expect(c.kind, MediaKind.video);
      expect(c.staticFile, 'v1.jpg');
      await db.setCellCover(pitId, 'oshi', c.id);
      expect((await db.watchCellCovers(pitId).first).oshi, 'v1.jpg');

      // 官方圖冊的影片同理
      await db.addOfficial(pitId, groupId, const [
        NewImage(file: 'ov.mp4', kind: MediaKind.video),
      ]);
      expect((await db.watchCellCovers(pitId).first).official, isNull);
      await db.setMediaMeta('ov.mp4', posterFile: 'ov.jpg');
      expect((await db.watchCellCovers(pitId).first).official, 'ov.jpg');
    });

    test('坑封面（setCover／imageFileOf）不變；影片坑封面回傳截圖', () async {
      await db.addOfficial(pitId, groupId, const [NewImage(file: 'o.png')]);
      final id = (await db.watchCoverCandidates(pitId, kind: 'official').first)
          .single
          .id;
      await db.setCover(pitId, id);
      expect(await db.imageFileOf(id), 'o.png');
      expect((await db.watchPit(pitId).first)!.coverImageId, id);
      // 沒影響各格封面設定
      expect(await db.chosenCellCoverId(pitId, 'official'), isNull);

      await db.addFanArts(pitId, const [
        NewImage(file: 'v.mp4', kind: MediaKind.video, posterFile: 'v.jpg'),
      ], author: '');
      final fid = (await db.watchFanArts(pitId).first).single.id;
      expect(await db.imageFileOf(fid), 'v.jpg');
    });

    test('月曆格／年度回顧／時間軸縮圖用靜態圖', () async {
      await piece('V', const [
        NewImage(file: 'v.mp4', kind: MediaKind.video, posterFile: 'v.jpg'),
      ], DateTime(2026, 10, 3));
      await piece('N', const [
        NewImage(file: 'n.mp4', kind: MediaKind.video),
        NewImage(file: 'n.png'),
      ], DateTime(2026, 10, 4));
      final covers = await db.watchMonthCovers(2026, 10).first;
      expect(covers[3], 'v.jpg');
      expect(covers[4], 'n.png');
      final byMonth = await db.pieceImagesByMonth(2026);
      expect(byMonth[10], containsAll(['v.jpg', 'n.png']));
      expect(byMonth[10], isNot(contains('v.mp4')));
    });
  });

  group('推活多選（D-079）', () {
    late List<OfficialGroup> groups;
    setUp(() async {
      groups = await db.watchGroups(pitId, kind: 'oshi').first;
    });

    test('setOshiGroupBatch：移到分組、不分組；只有真的改變的才更新 updatedAt', () async {
      final a = await oshi('a.png');
      final b = await oshi('b.png', group: groups[0].id);
      final c = await oshi('c.png');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final t0 = (await db.getOshiRecord(b))!.record.updatedAt;
      await db.setOshiGroupBatch([a, b, c], groups[0].id);
      for (final id in [a, b, c]) {
        expect((await db.getOshiRecord(id))!.record.groupId, groups[0].id);
      }
      expect((await db.getOshiRecord(a))!.record.updatedAt.isAfter(t0), isTrue);
      // b 本來就在這個分組：沒動
      expect((await db.getOshiRecord(b))!.record.updatedAt, t0);

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.setOshiGroupBatch([a, c], null);
      expect((await db.getOshiRecord(a))!.record.groupId, isNull);
      expect((await db.getOshiRecord(c))!.record.groupId, isNull);
      expect((await db.getOshiRecord(b))!.record.groupId, groups[0].id);
      // 圖片與 tag 不受影響
      expect((await db.getOshiRecord(a))!.images.single.file, 'a.png');
    });

    test(
      'setOshiGroupBatch：別坑的分組、官方分組、已刪分組 → ArgumentError 且整批不動；已刪紀錄略過',
      () async {
        final other = await db.createPit(name: '坑B');
        final otherGroup =
            (await db.watchGroups(other, kind: 'oshi').first).first;
        final a = await oshi('a.png');
        final gone = await oshi('g.png');
        await db.deleteOshiBatch([gone]);
        await expectLater(
          db.setOshiGroupBatch([a], otherGroup.id),
          throwsArgumentError,
        );
        await expectLater(
          db.setOshiGroupBatch([a], groupId), // 官方圖冊的分組
          throwsArgumentError,
        );
        expect(await db.deleteGroup(groups[1].id), isTrue);
        await expectLater(
          db.setOshiGroupBatch([a], groups[1].id),
          throwsArgumentError,
        );
        expect((await db.getOshiRecord(a))!.record.groupId, isNull);
        // 已刪紀錄略過、空清單無事
        await db.setOshiGroupBatch([gone], groups[0].id);
        await db.setOshiGroupBatch(const [], groups[0].id);
        expect(await db.getOshiRecord(gone), isNull);
      },
    );

    test('watchOshiRecords：oshiUngroupedFilter 只列沒有分組的紀錄', () async {
      final groups = await db.watchGroups(pitId, kind: 'oshi').first;
      final a = await oshi('a.png', group: groups[0].id);
      final b = await oshi('b.png');
      final c = await oshi('c.png');
      final ungrouped = await db
          .watchOshiRecords(pitId, groupId: oshiUngroupedFilter)
          .first;
      expect(ungrouped.map((v) => v.record.id).toSet(), {b, c});
      final grouped = await db
          .watchOshiRecords(pitId, groupId: groups[0].id)
          .first;
      expect(grouped.map((v) => v.record.id), [a]);
      final counts = await db.watchOshiGroupCounts(pitId).first;
      expect(counts[null], 2);
    });

    test('deleteOshiBatch：軟刪除、列表與筆數排除、已刪的不重複更新', () async {
      final a = await oshi('a.png');
      final b = await oshi('b.png');
      final c = await oshi('c.png');
      await db.deleteOshiBatch([a, b]);
      expect((await db.watchOshiRecords(pitId).first).map((v) => v.record.id), [
        c,
      ]);
      expect(await db.watchOshiCount(pitId).first, 1);
      final row = await (db.select(
        db.oshiRecords,
      )..where((o) => o.id.equals(a))).getSingle();
      expect(row.deletedAt, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.deleteOshiBatch([a]);
      final again = await (db.select(
        db.oshiRecords,
      )..where((o) => o.id.equals(a))).getSingle();
      expect(again.updatedAt, row.updatedAt);
      await db.deleteOshiBatch(const []);
    });

    test('批次 tag 通用版（TagTarget.oshi）：覆蓋狀態、加、移除、新建；只更新有變動的紀錄', () async {
      final t1 = await db.createTag(pitId, 'A');
      final t2 = await db.createTag(pitId, 'B');
      final a = await oshi('a.png');
      final b = await oshi('b.png');
      await db.setTags(TagTarget.oshi, a, [t1]);

      var cov = await db.tagCoverageFor(TagTarget.oshi, [a, b]);
      expect(
        {for (final e in cov) e.tag.name: e.coverage},
        {'A': TagCoverage.some, 'B': TagCoverage.none},
      );

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final ta = (await db.getOshiRecord(a))!.record.updatedAt;
      final created = await db.applyBatchTagsFor(
        TagTarget.oshi,
        [a, b],
        addTagIds: [t1, t2],
        newTagNames: ['#新'],
      );
      expect(created, hasLength(1));
      cov = await db.tagCoverageFor(TagTarget.oshi, [a, b]);
      expect(cov.every((e) => e.coverage == TagCoverage.all), isTrue);
      expect(cov, hasLength(3));
      // a 本來就有 t1，但加了 t2 與新 tag → 有變動；b 都是新加
      expect((await db.getOshiRecord(a))!.record.updatedAt.isAfter(ta), isTrue);
      expect((await db.getOshiRecord(b))!.tags.map((t) => t.name).toSet(), {
        'A',
        'B',
        '新',
      });

      await db.applyBatchTagsFor(TagTarget.oshi, [a, b], removeTagIds: [t2]);
      expect((await db.getOshiRecord(a))!.tags.map((t) => t.name).toSet(), {
        'A',
        '新',
      });

      // 別的坑的 tag 或混坑選取 → 丟錯；其他種類不支援
      final other = await db.createPit(name: '坑B');
      final foreign = await db.createTag(other, 'x');
      await expectLater(
        db.applyBatchTagsFor(TagTarget.oshi, [a], addTagIds: [foreign]),
        throwsArgumentError,
      );
      final o2 = await oshi('o.png', pit: other);
      await expectLater(
        db.applyBatchTagsFor(TagTarget.oshi, [a, o2], addTagIds: [t1]),
        throwsArgumentError,
      );
      await expectLater(
        db.applyBatchTagsFor(TagTarget.idea, [a], addTagIds: [t1]),
        throwsArgumentError,
      );
      // 刪除的紀錄不算選取
      await db.deleteOshiBatch([b]);
      cov = await db.tagCoverageFor(TagTarget.oshi, [a, b]);
      expect(cov.firstWhere((e) => e.tag.name == 'A').total, 1);
    });
  });
}
