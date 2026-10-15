import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/media_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 批次 10 的同步：格子封面跟坑文件走；媒體欄位與影片截圖檔跟著各自的文件走；舊版文件相容。
void main() {
  late AppDatabase a;
  late AppDatabase b;
  late Directory dirA;
  late Directory dirB;
  late MemoryRemote remote;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    dirA = await Directory.systemTemp.createTemp('sync10_a');
    dirB = await Directory.systemTemp.createTemp('sync10_b');
    remote = MemoryRemote();
    engineA = SyncEngine(db: a, remote: remote, images: ImageStore(dirA));
    engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await dirA.delete(recursive: true);
    await dirB.delete(recursive: true);
  });

  NewImage fileOn(
    Directory dir,
    String name, {
    MediaKind kind = MediaKind.image,
    int? durationMs,
    String? poster,
  }) {
    File('${dir.path}/$name').writeAsBytesSync(Uint8List.fromList([9, 8, 7]));
    if (poster != null) {
      File('${dir.path}/$poster').writeAsBytesSync(Uint8List.fromList([1, 2]));
    }
    return NewImage(
      file: name,
      width: 10,
      height: 20,
      kind: kind,
      durationMs: durationMs,
      posterFile: poster,
    );
  }

  Future<void> rewriteDoc(
    String key,
    void Function(Map<String, dynamic> data) edit,
  ) async {
    final doc =
        jsonDecode(utf8.decode(remote.files[key]!)) as Map<String, dynamic>;
    edit(doc['data'] as Map<String, dynamic>);
    doc['updatedAt'] = (doc['updatedAt'] as int) + 60000;
    (doc['data'] as Map<String, dynamic>)['updatedAt'] = doc['updatedAt'];
    remote.files[key] = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
  }

  test('格子封面跟著坑文件同步：官方（列 id）與推活（檔名）在另一台一樣有效', () async {
    final pitId = await a.createPit(name: '坑');
    final g = (await a.watchGroups(pitId).first).first.id;
    await a.addOfficial(pitId, g, [
      fileOn(dirA, 'o1.png'),
      fileOn(dirA, 'o2.png'),
    ]);
    await a.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 10, 1),
      images: [fileOn(dirA, 'k1.png'), fileOn(dirA, 'k2.png')],
    );
    final o = (await a.watchCoverCandidates(pitId, kind: 'official').first)
        .firstWhere((c) => c.file == 'o1.png');
    final k = (await a.watchCoverCandidates(pitId, kind: 'oshi').first)
        .firstWhere((c) => c.file == 'k2.png');
    await a.setCellCover(pitId, 'official', o.id);
    await a.setCellCover(pitId, 'oshi', k.id);

    await engineA.sync();
    await engineB.sync();
    final pit = (await b.watchPit(pitId).first)!;
    expect(pit.officialCoverId, o.id);
    expect(pit.oshiCoverFile, 'k2.png');
    final c = await b.watchCellCovers(pitId).first;
    expect((c.official, c.oshi), ('o1.png', 'k2.png'));

    // B 清掉推活封面 → A 拉到後退回自動
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final kb = (await b.watchCoverCandidates(pitId, kind: 'oshi').first).first;
    await b.setCellCover(pitId, 'oshi', kb.id);
    await b.setCellCover(pitId, 'oshi', null);
    await engineB.sync();
    await engineA.sync();
    expect((await a.watchPit(pitId).first)!.oshiCoverFile, isNull);
    expect((await a.watchCellCovers(pitId).first).oshi, 'k1.png');
  });

  test('影片：媒體欄位與截圖檔一起同步（官方圖、素材庫、推活），缺檔會補下載（含截圖）', () async {
    final pitId = await a.createPit(name: '坑');
    final g = (await a.watchGroups(pitId).first).first.id;
    await a.addOfficial(pitId, g, [
      fileOn(
        dirA,
        'v1.mp4',
        kind: MediaKind.video,
        durationMs: 24000,
        poster: 'v1.jpg',
      ),
    ]);
    await a.addMaterials(MaterialCategory.pose, [
      fileOn(dirA, 'm.gif', kind: MediaKind.gif),
    ]);
    final oid = await a.saveOshiRecord(
      pitId: pitId,
      date: DateTime(2026, 10, 1),
      images: [
        fileOn(
          dirA,
          'v2.mov',
          kind: MediaKind.video,
          durationMs: 5000,
          poster: 'v2.jpg',
        ),
        fileOn(dirA, 'p.png'),
      ],
    );

    final up = await engineA.sync();
    // 原檔 4（v1、m、v2、p）＋截圖 2
    expect(up.imagesUp, 6);
    expect(
      remote.files.keys,
      containsAll(['images__v1.jpg', 'images__v2.jpg']),
    );

    final down = await engineB.sync();
    expect(down.imagesDown, 6);
    for (final f in [
      'v1.mp4',
      'v1.jpg',
      'm.gif',
      'v2.mov',
      'v2.jpg',
      'p.png',
    ]) {
      expect(File('${dirB.path}/$f').existsSync(), isTrue, reason: f);
    }
    final o = (await b.select(b.officialImages).getSingle());
    expect(
      (o.kind, o.durationMs, o.posterFile),
      (MediaKind.video, 24000, 'v1.jpg'),
    );
    expect((await b.select(b.materialImages).getSingle()).kind, MediaKind.gif);
    final imgs = (await b.getOshiRecord(oid))!.images;
    expect(imgs.map((e) => e.kind), [MediaKind.video, MediaKind.image]);
    expect((imgs[0].durationMs, imgs[0].poster), (5000, 'v2.jpg'));

    // 截圖檔在 B 不見了 → 下次同步補下載
    File('${dirB.path}/v2.jpg').deleteSync();
    final again = await engineB.sync();
    expect(again.imagesDown, 1);
    expect(File('${dirB.path}/v2.jpg').existsSync(), isTrue);
  });

  test('先匯入影片、之後才補截圖：setMediaMeta 後下次同步把新欄位與截圖送出', () async {
    final pitId = await a.createPit(name: '坑');
    final g = (await a.watchGroups(pitId).first).first.id;
    await a.addOfficial(pitId, g, [
      fileOn(dirA, 'v.mp4', kind: MediaKind.video),
    ]);
    await engineA.sync();
    await engineB.sync();
    expect((await b.select(b.officialImages).getSingle()).posterFile, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    File('${dirA.path}/v.jpg').writeAsBytesSync([5, 5]);
    await a.setMediaMeta('v.mp4', durationMs: 7000, posterFile: 'v.jpg');
    final up = await engineA.sync();
    expect(up.imagesUp, 1); // 只有截圖是新的
    await engineB.sync();
    final o = await b.select(b.officialImages).getSingle();
    expect((o.durationMs, o.posterFile), (7000, 'v.jpg'));
    expect(File('${dirB.path}/v.jpg').existsSync(), isTrue);
  });

  test(
    '舊版文件相容：沒有 kind／durationMs／posterFile → 依副檔名推；不認得的 kind 當圖片；多出來的欄位忽略',
    () async {
      final pitId = await a.createPit(name: '坑');
      final g = (await a.watchGroups(pitId).first).first.id;
      await a.addOfficial(pitId, g, [
        fileOn(dirA, 'x.gif'),
        fileOn(dirA, 'y.png'),
      ]);
      await a.addMaterials(MaterialCategory.style, [fileOn(dirA, 'z.gif')]);
      final oid = await a.saveOshiRecord(
        pitId: pitId,
        date: DateTime(2026, 10, 1),
        images: [fileOn(dirA, 'e.gif'), fileOn(dirA, 'e.png')],
      );
      await engineA.sync();

      // 把遠端的文件改成舊版格式 / 未來格式
      final offs = await a.select(a.officialImages).get();
      for (final r in offs) {
        await rewriteDoc('meta__official__${r.id}.json', (d) {
          d
            ..remove('kind')
            ..remove('durationMs')
            ..remove('posterFile');
        });
      }
      final m = await a.select(a.materialImages).getSingle();
      await rewriteDoc('meta__material__${m.id}.json', (d) {
        d['kind'] = 'audio'; // 未來的新種類
        d['someFutureField'] = {'x': 1};
      });
      await rewriteDoc('meta__oshi__$oid.json', (d) {
        for (final im in d['images'] as List) {
          (im as Map<String, dynamic>)
            ..remove('kind')
            ..remove('durationMs')
            ..remove('posterFile');
        }
        d['futureField'] = 1;
      });

      final c = await engineB.sync();
      expect(c.pulled, greaterThan(0));
      final byFile = {
        for (final r in await b.select(b.officialImages).get()) r.imageFile: r,
      };
      expect(byFile['x.gif']!.kind, MediaKind.gif);
      expect(byFile['y.png']!.kind, MediaKind.image);
      expect(byFile['x.gif']!.posterFile, isNull);
      // 未來的種類：不丟例外，依副檔名推（.gif → gif）
      expect(
        (await b.select(b.materialImages).getSingle()).kind,
        MediaKind.gif,
      );
      final imgs = (await b.getOshiRecord(oid))!.images;
      expect(imgs.map((e) => e.kind), [MediaKind.gif, MediaKind.image]);
    },
  );

  test('舊版坑文件（沒有格子封面欄位）→ 新版套用後各格封面為空', () async {
    final pitId = await a.createPit(name: '坑');
    await engineA.sync();
    await rewriteDoc('meta__pits__$pitId.json', (d) {
      d
        ..remove('draftCoverFile')
        ..remove('ideaCoverFile')
        ..remove('pieceCoverFile')
        ..remove('oshiCoverFile');
    });
    await engineB.sync();
    final pit = (await b.watchPit(pitId).first)!;
    expect([
      pit.draftCoverFile,
      pit.ideaCoverFile,
      pit.pieceCoverFile,
      pit.oshiCoverFile,
    ], everyElement(isNull));
  });

  test('新版文件保留舊版需要的全部欄位（舊版讀得懂、多的欄位會被忽略）', () async {
    final pitId = await a.createPit(name: '坑');
    final g = (await a.watchGroups(pitId).first).first.id;
    await a.addOfficial(pitId, g, [
      fileOn(
        dirA,
        'v.mp4',
        kind: MediaKind.video,
        durationMs: 1,
        poster: 'v.jpg',
      ),
    ]);
    await a.addJunk(pitId, [fileOn(dirA, 'j.png')]);
    await engineA.sync();
    final off = await a.select(a.officialImages).getSingle();
    final doc = jsonDecode(
      utf8.decode(remote.files['meta__official__${off.id}.json']!),
    ) as Map<String, dynamic>;
    final data = doc['data'] as Map<String, dynamic>;
    for (final k in [
      'id',
      'pitId',
      'groupId',
      'imageFile',
      'width',
      'height',
      'imageKey',
      'hidden',
      'tagIds',
    ]) {
      expect(data.containsKey(k), isTrue, reason: k);
    }
    expect(data['kind'], 'video');
    expect(data['posterFile'], 'v.jpg');
    // 格式版本沒有被提高：舊版不會因為格式標記而拒絕同步
    expect(doc['formatVersion'], syncFormatVersion);
  });
}
