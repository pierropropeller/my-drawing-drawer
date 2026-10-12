import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/image_location.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/timeline_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 素材庫（D-071）：查詢、計數、移動、軟刪除、不影響其他統計，以及兩台裝置的同步（含圖片）。
void main() {
  late AppDatabase db;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  NewImage im(String f) => NewImage(file: f, width: 30, height: 40);

  test('分類 enum 的名稱是穩定的英文 id，順序＝畫面 pills 順序', () {
    expect(MaterialCategory.values.map((c) => c.name), [
      'clothing',
      'pose',
      'body',
      'palette',
      'scene',
      'style',
      'sticker',
    ]);
  });

  test('addMaterials：一個交易加一批、回傳 id、寬高保留；列表新的在前，同一批維持給定順序', () async {
    final ids1 = await db.addMaterials(MaterialCategory.clothing, [
      im('a1.png'),
      im('a2.png'),
      im('a3.png'),
    ]);
    expect(ids1.length, 3);
    var all = await db.watchMaterials().first;
    expect(all.map((m) => m.imageFile), ['a1.png', 'a2.png', 'a3.png']);
    expect(all.map((m) => m.id), ids1);
    expect(all.first.width, 30);
    expect(all.first.height, 40);
    expect(all.first.deviceId, '');

    // 第二批（同一秒內也要排在前面）
    await db.addMaterials(MaterialCategory.pose, [im('b1.png'), im('b2.png')]);
    all = await db.watchMaterials().first;
    expect(all.map((m) => m.imageFile), [
      'b1.png',
      'b2.png',
      'a1.png',
      'a2.png',
      'a3.png',
    ]);
    expect(await db.addMaterials(MaterialCategory.pose, const []), isEmpty);
  });

  test('createdAt 不同時依 createdAt 新到舊；分類篩選', () async {
    await db.addMaterials(MaterialCategory.scene, [im('old.png')]);
    await db.addMaterials(MaterialCategory.scene, [im('new.png')]);
    await db.addMaterials(MaterialCategory.body, [im('body.png')]);
    await db.customStatement(
      "UPDATE material_images SET created_at = 1000 WHERE image_file = 'new.png'",
    );
    await db.customStatement(
      "UPDATE material_images SET created_at = 2000 WHERE image_file = 'old.png'",
    );
    final scene = await db
        .watchMaterials(category: MaterialCategory.scene)
        .first;
    expect(scene.map((m) => m.imageFile), ['old.png', 'new.png']);
    expect(
      (await db.watchMaterials(category: MaterialCategory.body).first).length,
      1,
    );
    expect(
      await db.watchMaterials(category: MaterialCategory.style).first,
      isEmpty,
    );
  });

  test(
    'moveMaterials 改分類（沒變的不蓋 updatedAt）；deleteMaterials 軟刪除；計數即時更新',
    () async {
      final ids = await db.addMaterials(MaterialCategory.clothing, [
        im('1.png'),
        im('2.png'),
        im('3.png'),
      ]);
      var counts = await db.watchMaterialCounts().first;
      expect(counts.total, 3);
      expect(counts.of(MaterialCategory.clothing), 3);
      expect(counts.of(MaterialCategory.sticker), 0);
      expect(counts.byCategory.length, MaterialCategory.values.length);

      // 讓 updatedAt 可以區分
      await db.customStatement('UPDATE material_images SET updated_at = 1');
      await db.moveMaterials([ids[0], ids[1]], MaterialCategory.pose);
      await db.moveMaterials([ids[1]], MaterialCategory.pose); // 已在目標分類
      final rows = {
        for (final m in await db.select(db.materialImages).get()) m.id: m,
      };
      expect(rows[ids[0]]!.category, MaterialCategory.pose);
      expect(rows[ids[1]]!.category, MaterialCategory.pose);
      expect(rows[ids[2]]!.category, MaterialCategory.clothing);
      expect(rows[ids[0]]!.updatedAt.millisecondsSinceEpoch, greaterThan(1000));
      expect(rows[ids[2]]!.updatedAt.millisecondsSinceEpoch, 1000); // 沒動的不變

      counts = await db.watchMaterialCounts().first;
      expect(counts.of(MaterialCategory.pose), 2);
      expect(counts.of(MaterialCategory.clothing), 1);

      await db.deleteMaterials([ids[0], ids[2]]);
      counts = await db.watchMaterialCounts().first;
      expect(counts.total, 1);
      expect(counts.of(MaterialCategory.pose), 1);
      expect((await db.watchMaterials().first).single.id, ids[1]);
      // 軟刪除：列還在、有 deletedAt；已刪除的不能被移動
      final gone = await (db.select(
        db.materialImages,
      )..where((m) => m.id.equals(ids[0]))).getSingle();
      expect(gone.deletedAt, isNotNull);
      await db.moveMaterials([ids[0]], MaterialCategory.style);
      expect(
        (await (db.select(
          db.materialImages,
        )..where((m) => m.id.equals(ids[0]))).getSingle()).category,
        MaterialCategory.pose,
      );
      await db.deleteMaterials(const []);
    },
  );

  test('watchMaterials／watchMaterialCounts 是即時的', () async {
    final seen = <int>[];
    final sub = db.watchMaterialCounts().listen((c) => seen.add(c.total));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final ids = await db.addMaterials(MaterialCategory.palette, [im('x.png')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.deleteMaterials(ids);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(seen, [0, 1, 0]);
  });

  test('素材不影響坑統計、時間軸、封面與位置查詢', () async {
    final pitId = await db.createPit(name: '坑');
    await db.addMaterials(MaterialCategory.sticker, [im('m.png')]);
    final stats = await db.watchPitStats(pitId).first;
    expect(stats.imageCount, 0);
    expect(stats.official + stats.fanArts + stats.junk, 0);
    final page = await db.loadTimelinePage();
    expect(page.items, isEmpty);
    // 素材的圖沒有「坑 · 格」
    expect(await db.imageLocationOf('m.png'), isNull);
    expect(await db.watchPits(archived: false).first, hasLength(1));
  });

  group('同步', () {
    late AppDatabase b;
    late Directory dirA;
    late Directory dirB;
    late MemoryRemote remote;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      b = AppDatabase(NativeDatabase.memory());
      dirA = await Directory.systemTemp.createTemp('mat_a');
      dirB = await Directory.systemTemp.createTemp('mat_b');
      remote = MemoryRemote();
      engineA = SyncEngine(db: db, remote: remote, images: ImageStore(dirA));
      engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
    });
    tearDown(() => b.close());

    NewImage file(String name) {
      File('${dirA.path}/$name')
          .writeAsBytesSync(Uint8List.fromList([1, 2, 3, name.length]));
      return NewImage(file: name, width: 10, height: 20);
    }

    Future<void> tick() =>
        Future<void>.delayed(const Duration(milliseconds: 1100));

    test('A 加素材（含圖）→ B 拉到圖與分類；B 移動 → A 拉到；A 刪除 → B 看不到', () async {
      final ids = await db.addMaterials(MaterialCategory.pose, [
        file('m1.png'),
        file('m2.png'),
      ]);
      final up = await engineA.sync();
      expect(up.imagesUp, 2);
      final down = await engineB.sync();
      expect(down.imagesDown, 2);
      expect(File('${dirB.path}/m1.png').existsSync(), isTrue);
      var rows = await b.watchMaterials().first;
      expect(rows.map((m) => m.imageFile), ['m1.png', 'm2.png']);
      expect(rows.every((m) => m.category == MaterialCategory.pose), isTrue);
      expect((rows.first.width, rows.first.height), (10, 20));
      expect((await b.watchMaterialCounts().first).total, 2);

      await tick();
      await b.moveMaterials([ids[0]], MaterialCategory.body);
      await engineB.sync();
      await engineA.sync();
      final moved = await (db.select(
        db.materialImages,
      )..where((m) => m.id.equals(ids[0]))).getSingle();
      expect(moved.category, MaterialCategory.body);

      await tick();
      await db.deleteMaterials([ids[1]]);
      await engineA.sync();
      await engineB.sync();
      rows = await b.watchMaterials().first;
      expect(rows.map((m) => m.id), [ids[0]]);
      expect((await b.watchMaterialCounts().first).total, 1);
    });

    test('傳輸清單含素材的圖（上傳與下載），imageLocationOf 為 null', () async {
      await db.addMaterials(MaterialCategory.style, [file('t1.png')]);
      final up = <SyncProgress>[];
      await engineA.sync(onProgress: up.add);
      final planned = up.firstWhere((e) => e.transfersPlanned);
      expect(planned.transfers.map((t) => (t.file, t.isUpload)), [
        ('t1.png', true),
      ]);
      final down = <SyncProgress>[];
      await engineB.sync(onProgress: down.add);
      final plannedB = down.firstWhere((e) => e.transfersPlanned);
      expect(plannedB.transfers.map((t) => (t.file, t.isDownload)), [
        ('t1.png', true),
      ]);
      expect(await b.imageLocationOf('t1.png'), isNull);
    });

    test('只缺圖檔（文件已同步）時，下次同步補下載素材的圖', () async {
      await db.addMaterials(MaterialCategory.scene, [file('late.png')]);
      await engineA.sync();
      await engineB.sync();
      File('${dirB.path}/late.png').deleteSync();
      final r = await engineB.sync();
      expect(r.imagesDown, 1);
      expect(File('${dirB.path}/late.png').existsSync(), isTrue);
    });

    test('遠端文件缺 width/height 仍可套用；不認識的分類被略過而不中斷同步', () async {
      final id = (await db.addMaterials(MaterialCategory.sticker, [
        file('ok.png'),
      ])).single;
      await engineA.sync();
      // 手動寫兩份遠端文件：缺寬高的舊格式、未知分類
      Map<String, dynamic> doc(String docId, Map<String, dynamic> data) => {
        'v': 1,
        'formatVersion': syncFormatVersion,
        'kind': 'material',
        'id': docId,
        'updatedAt': 9999999999000,
        'data': data,
      };
      final base = {
        'createdAt': 1700000000000,
        'updatedAt': 9999999999000,
        'deletedAt': null,
        'deviceId': '',
      };
      Future<void> put(String docId, Map<String, dynamic> data) =>
          remote.upload(
            'meta__material__$docId.json',
            Uint8List.fromList(utf8.encode(jsonEncode(doc(docId, data)))),
          );
      await put('nodim', {
        ...base,
        'id': 'nodim',
        'imageFile': 'nodim.png',
        'category': 'palette',
      });
      await put('future', {
        ...base,
        'id': 'future',
        'imageFile': 'future.png',
        'category': 'hologram',
      });
      await engineB.sync();
      final rows = await b.select(b.materialImages).get();
      expect(rows.map((m) => m.id).toSet(), {id, 'nodim'});
      expect(rows.firstWhere((m) => m.id == 'nodim').width, 0);
    });
  });
}
