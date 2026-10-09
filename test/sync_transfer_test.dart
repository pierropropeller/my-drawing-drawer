import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/image_location.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/state/providers.dart';
import 'package:huakeng/state/settings.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_controller.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 同步傳輸模型（D-052）：逐張狀態／進度、節流、狀態計算、圖片位置、下載角標 provider。
void main() {
  late AppDatabase a;
  late AppDatabase b;
  late Directory dirA;
  late Directory dirB;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    a = AppDatabase(NativeDatabase.memory());
    b = AppDatabase(NativeDatabase.memory());
    dirA = await Directory.systemTemp.createTemp('tr_a');
    dirB = await Directory.systemTemp.createTemp('tr_b');
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<NewImage> imageOnA(String name) async {
    File('${dirA.path}/$name').writeAsBytesSync(Uint8List(64));
    return NewImage(file: name, width: 10, height: 20);
  }

  Future<String> seed(int n) async {
    final pitId = await a.createPit(name: '坑A');
    final g = (await a.watchGroups(pitId).first).first;
    await a.addOfficial(pitId, g.id, [
      for (var i = 0; i < n; i++) await imageOnA('$i.png'),
    ]);
    return pitId;
  }

  test('上傳：先規劃（全部 waiting）、逐張 active→done，進度 0..1 單調', () async {
    await seed(3);
    final remote = MemoryRemote(progressSteps: 4);
    final engine = SyncEngine(
      db: a,
      remote: remote,
      images: ImageStore(dirA),
      progressInterval: Duration.zero,
    );
    final events = <SyncProgress>[];
    await engine.sync(onProgress: events.add);

    // 規劃前：沒有清單、planned=false（檢查中）
    expect(events.first.transfersPlanned, isFalse);
    expect(events.first.transfers, isEmpty);
    final firstPlanned = events.firstWhere((e) => e.transfersPlanned);
    expect(firstPlanned.transfers.length, 3);
    expect(
      firstPlanned.transfers.every((t) => t.isUpload && t.isWaiting),
      isTrue,
    );
    expect(firstPlanned.transfers.every((t) => t.progress == null), isTrue);

    // 逐張：同時最多一張 active；每張的進度單調不減
    final last = <String, double>{};
    for (final e in events) {
      expect(e.transfers.where((t) => t.isActive).length, lessThanOrEqualTo(1));
      for (final t in e.transfers) {
        final p = t.progress;
        if (p != null) {
          expect(p, inInclusiveRange(0, 1));
          expect(p, greaterThanOrEqualTo(last[t.file] ?? 0));
          last[t.file] = p;
        }
      }
    }
    // 看得到中間進度（0.25 / 0.5 / 0.75）
    expect(
      events.any(
        (e) => e.transfers.any((t) => t.isActive && t.progress == 0.5),
      ),
      isTrue,
    );
    final end = events.last;
    expect(end.transfers.every((t) => t.isDone && t.progress == 1), isTrue);
  });

  test('下載：清單先下載後上傳、各自方向正確；沒有東西要傳 → planned 且清單空', () async {
    await seed(2);
    final remote = MemoryRemote();
    await SyncEngine(db: a, remote: remote, images: ImageStore(dirA)).sync();

    // B 拉下來：兩張下載
    final eb = SyncEngine(
      db: b,
      remote: remote,
      images: ImageStore(dirB),
      progressInterval: Duration.zero,
    );
    final ev = <SyncProgress>[];
    await eb.sync(onProgress: ev.add);
    final planned = ev.firstWhere((e) => e.transfersPlanned);
    expect(planned.transfers.length, 2);
    expect(planned.transfers.every((t) => t.isDownload), isTrue);

    // 再同步一次：沒有東西要傳
    final ev2 = <SyncProgress>[];
    await eb.sync(onProgress: ev2.add);
    expect(ev2.first.transfersPlanned, isFalse);
    expect(ev2.last.transfersPlanned, isTrue);
    expect(ev2.last.transfers, isEmpty);
  });

  test('節流：逐位元組進度最多每 interval 一次，完成一定通知', () async {
    await seed(1);
    final remote = MemoryRemote(progressSteps: 50);
    final engine = SyncEngine(
      db: a,
      remote: remote,
      images: ImageStore(dirA),
      progressInterval: const Duration(seconds: 10), // 這次測試期間內幾乎不會再通知
    );
    final events = <SyncProgress>[];
    await engine.sync(onProgress: events.add);
    final withProgress = events
        .where((e) => e.transfers.any((t) => t.isActive && t.progress != null))
        .length;
    expect(withProgress, lessThanOrEqualTo(1));
    expect(events.last.transfers.single.isDone, isTrue);
  });

  test('imageLocationOf：官方／同人圖／雜物／草稿／腦洞／成圖；隱藏與已刪除不算', () async {
    final pitId = await a.createPit(name: '坑A');
    final g = (await a.watchGroups(pitId).first).first;
    await a.addOfficial(pitId, g.id, [const NewImage(file: 'o.png')]);
    await a.addFanArts(pitId, [const NewImage(file: 'f.png')], author: 'x');
    await a.addJunk(pitId, [const NewImage(file: 'j.png')]);
    await a.saveDraft(
      pitId: pitId,
      title: 'd',
      images: const [NewImage(file: 'd.png')],
      tagIds: const [],
      ideaIds: const [],
    );
    await a.saveIdea(
      pitId: pitId,
      title: 'i',
      body: '',
      images: const [NewImage(file: 'i.png')],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await a.savePiece(
      pitId: pitId,
      title: 'p',
      body: '',
      images: const [NewImage(file: 'p.png')],
      tagIds: const [],
      links: const [],
      targetLikes: 0,
      finishedAt: DateTime(2026, 1, 1),
      ideaIds: const [],
      draftIds: const [],
    );
    final cells = {
      'o.png': ImageCell.official,
      'f.png': ImageCell.fan,
      'j.png': ImageCell.junk,
      'd.png': ImageCell.draft,
      'i.png': ImageCell.idea,
      'p.png': ImageCell.piece,
    };
    for (final e in cells.entries) {
      final loc = await a.imageLocationOf(e.key);
      expect(loc?.cell, e.value, reason: e.key);
      expect(loc?.pitName, '坑A');
      expect(loc?.pitId, pitId);
    }
    expect(await a.imageLocationOf('none.png'), isNull);

    // 移到雜物後：官方列被隱藏，位置變雜物
    final o = (await a.watchOfficial(pitId).first).single;
    await a.moveAlbumImages(
      from: AlbumCell.official,
      ids: [o.id],
      to: AlbumCell.junk,
    );
    expect((await a.imageLocationOf('o.png'))?.cell, ImageCell.junk);
    // 跨坑後位置跟著新坑
    final other = await a.createPit(name: '坑B');
    final j = (await a.watchJunk(pitId).first).firstWhere(
      (x) => x.imageFile == 'o.png',
    );
    await a.moveAlbumImages(
      from: AlbumCell.junk,
      ids: [j.id],
      to: AlbumCell.junk,
      targetPitId: other,
    );
    final moved = await a.imageLocationOf('o.png');
    expect((moved?.pitName, moved?.cell), ('坑B', ImageCell.junk));
  });

  group('SyncController 與 provider', () {
    late Directory dir;
    late ProviderContainer container;
    late MemoryRemote remote;

    Future<void> setup(MemoryRemote r) async {
      remote = r;
      dir = dirA;
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(a),
          imageStoreProvider.overrideWith((ref) async => ImageStore(dir)),
          syncRemoteProvider.overrideWithValue(remote),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      container.read(settingsProvider.notifier).setAccount('me@example.com');
      addTearDown(container.dispose);
    }

    test('狀態：isChecking → isTransferring（完成張數／總數）→ 結束清空', () async {
      await seed(3);
      await setup(MemoryRemote(progressSteps: 2));
      final seen = <SyncState>[];
      container.listen(syncControllerProvider, (_, s) => seen.add(s));
      await container.read(syncControllerProvider.notifier).syncNow();

      expect(seen.first.isSyncing, isTrue);
      expect(seen.first.isChecking, isTrue);
      expect(seen.first.isTransferring, isFalse);
      final transferring = seen.where((s) => s.isTransferring).toList();
      expect(transferring, isNotEmpty);
      expect(transferring.every((s) => !s.isChecking), isTrue);
      expect(transferring.first.transferTotal, 3);
      expect(transferring.first.uploadCount, 3);
      expect(transferring.first.downloadCount, 0);
      expect(transferring.first.transferFraction, 0);
      expect(transferring.last.transferDone, 3);
      expect(transferring.last.transferFraction, 1.0);
      expect(
        transferring.map((s) => s.transferDone).toList(),
        orderedEquals(transferring.map((s) => s.transferDone).toList()..sort()),
      );

      final end = container.read(syncControllerProvider);
      expect(end.phase, SyncPhase.idle);
      expect(end.transfers, isEmpty);
      expect(end.isChecking, isFalse);
      expect(end.isTransferring, isFalse);
      expect(end.transferFraction, isNull);
    });

    test('沒有東西要傳：檢查中 → 完全不進入傳輸中', () async {
      await a.createPit(name: 'x');
      await setup(MemoryRemote());
      final seen = <SyncState>[];
      container.listen(syncControllerProvider, (_, s) => seen.add(s));
      await container.read(syncControllerProvider.notifier).syncNow();
      expect(seen.any((s) => s.isChecking), isTrue);
      expect(seen.any((s) => s.isTransferring), isFalse);
    });

    test('失敗時清單也清掉', () async {
      await seed(1);
      await setup(
        MemoryRemote(
          onTransfer: (name, up) async {
            if (name.startsWith('images__')) throw StateError('boom');
          },
        ),
      );
      await container.read(syncControllerProvider.notifier).syncNow();
      final s = container.read(syncControllerProvider);
      expect(s.phase, SyncPhase.error);
      expect(s.transfers, isEmpty);
    });

    test('imageTransferProvider：缺圖時排隊中 null、下載中有進度、完成後 present', () async {
      // 先由 A 上傳
      await seed(2);
      final shared = MemoryRemote(progressSteps: 4);
      await SyncEngine(db: a, remote: shared, images: ImageStore(dirA)).sync();

      // B 端用 controller 下載；在第一張下載途中暫停，觀察 provider
      final gate = Completer<void>();
      final reached = Completer<void>();
      final remoteB = MemoryRemote(
        progressSteps: 4,
        onTransfer: (name, up) async {
          if (!up && name.startsWith('images__') && !reached.isCompleted) {
            reached.complete();
            await gate.future;
          }
        },
      )..files.addAll(shared.files);
      remote = remoteB;
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(b),
          imageStoreProvider.overrideWith((ref) async => ImageStore(dirB)),
          syncRemoteProvider.overrideWithValue(remoteB),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(c.dispose);
      c.read(settingsProvider.notifier).setAccount('me@example.com');
      // 保持 provider 存活
      for (final f in ['0.png', '1.png']) {
        c.listen(imageTransferProvider(f), (_, _) {});
      }
      await c.read(imageExistsProvider('0.png').future);
      await c.read(imageExistsProvider('1.png').future);
      expect(c.read(imageTransferProvider('0.png')).isMissing, isTrue);

      final done = c.read(syncControllerProvider.notifier).syncNow();
      await reached.future;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // 規劃後、還沒收到任何位元組：兩張都缺圖，進度未知（角標轉圈）
      final s = c.read(syncControllerProvider);
      expect(s.isTransferring, isTrue);
      expect(s.downloadCount, 2);
      for (final f in ['0.png', '1.png']) {
        expect(c.read(imageTransferProvider(f)).isMissing, isTrue);
        expect(c.read(imageTransferProvider(f)).progress, isNull);
      }

      gate.complete();
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        c.read(imageTransferProvider('0.png')),
        ImageDownloadStatus.present,
      );
      expect(c.read(imageTransferProvider('1.png')).isMissing, isFalse);
    });

    test('imageTransferProvider 下載進度（由進行中的清單算出）', () async {
      // 直接檢查 SyncState 的索引邏輯：active 下載有 progress 時 provider 帶出
      await seed(1);
      final shared = MemoryRemote();
      await SyncEngine(db: a, remote: shared, images: ImageStore(dirA)).sync();

      final seenProgress = <double?>[];
      final remoteB = MemoryRemote(
        progressSteps: 4,
        stepDelay: const Duration(milliseconds: 120),
      )..files.addAll(shared.files);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(b),
          imageStoreProvider.overrideWith((ref) async => ImageStore(dirB)),
          syncRemoteProvider.overrideWithValue(remoteB),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(c.dispose);
      c.read(settingsProvider.notifier).setAccount('me@example.com');
      c.listen(
        imageTransferProvider('0.png'),
        (_, v) => seenProgress.add(v.progress),
        fireImmediately: true,
      );
      await c.read(syncControllerProvider.notifier).syncNow();
      // 下載途中出現過確定的進度值（0~1，非 null）
      expect(seenProgress.any((p) => p != null && p > 0 && p < 1), isTrue);
    });
  });
}
