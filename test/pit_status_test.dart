import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 淺坑／封存坑的資料層（D-088，批次 14）。
void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<Pit> pitOf(String id) async =>
      (await db.watchPit(id).first) ?? (throw StateError('no pit'));

  Future<void> addOfficialImages(String pitId, int n) async {
    final g = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(pitId, g.id, [
      for (var i = 0; i < n; i++) NewImage(file: 'o$pitId$i.png'),
    ]);
  }

  Future<String> addIdea(String pitId, {String title = '腦洞'}) => db.saveIdea(
    pitId: pitId,
    title: title,
    body: '',
    images: const [NewImage(file: 'idea.png')],
    tagIds: const [],
    draftIds: const [],
    pieceIds: const [],
  );

  group('狀態與預設值', () {
    test('新坑預設是現坑、沒有開啟的格子', () async {
      final id = await db.createPit(name: '坑');
      final p = await pitOf(id);
      expect(p.status, PitStatus.active);
      expect(p.enabledSections, isEmpty);
      expect(p.coverFile, isNull);
      expect(p.archived, isFalse); // 相容讀法
    });

    test('createPit 建淺坑：預設全部關；雜物開關跟著格子', () async {
      final a = await db.createPit(name: '淺', status: PitStatus.shallow);
      expect((await pitOf(a)).enabledSections, isEmpty);
      expect((await pitOf(a)).openSections, isEmpty);
      final b = await db.createPit(
        name: '淺2',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.fan, PitSectionKey.junk},
        coverFile: 'c.png',
      );
      final p = await pitOf(b);
      expect(p.enabledSections, {PitSectionKey.fan, PitSectionKey.junk});
      expect(p.junkEnabled, isTrue);
      expect(p.coverFile, 'c.png');
      expect(p.sectionOpen(PitSectionKey.fan), isTrue);
      expect(p.sectionOpen(PitSectionKey.official), isFalse);
      // 淺坑的預設分組照建（之後開格子才有分組可用）
      expect((await db.watchGroups(b).first), isNotEmpty);
    });

    test('現坑六格固定開、雜物看開關', () async {
      final id = await db.createPit(name: '坑');
      var p = await pitOf(id);
      expect(p.openSections, {
        PitSectionKey.official,
        PitSectionKey.fan,
        PitSectionKey.idea,
        PitSectionKey.draft,
        PitSectionKey.piece,
        PitSectionKey.oshi,
      });
      await db.updatePit(id, name: '坑', junkEnabled: true);
      p = await pitOf(id);
      expect(p.sectionOpen(PitSectionKey.junk), isTrue);
    });

    test('清單：現坑／淺坑／封存坑分開；選擇清單＝現坑＋淺坑（不含封存）', () async {
      final a = await db.createPit(name: '現');
      final s = await db.createPit(name: '淺', status: PitStatus.shallow);
      final z = await db.createPit(name: '封');
      await db.setPitStatus(z, PitStatus.archived);
      expect(
        [
          for (final p in await db.watchPitsByStatus({PitStatus.active}).first)
            p.id,
        ],
        [a],
      );
      expect(
        [
          for (final p in await db.watchPitsByStatus({PitStatus.shallow}).first)
            p.id,
        ],
        [s],
      );
      expect(
        [
          for (final p in await db.watchPitsByStatus({
            PitStatus.archived,
          }).first)
            p.id,
        ],
        [z],
      );
      final sel = [for (final p in await db.watchSelectablePits().first) p.id];
      expect(sel.toSet(), {a, s});
      // 相容舊介面
      expect(
        [for (final p in await db.watchPits(archived: false).first) p.id],
        [a],
      );
      expect(
        [for (final p in await db.watchPits(archived: true).first) p.id],
        [z],
      );
    });

    test('相容的 updatePit(archived:)：true 封存、false 取消封存但淺坑維持淺坑', () async {
      final a = await db.createPit(name: '現');
      await db.updatePit(a, name: '現', archived: true);
      expect((await pitOf(a)).status, PitStatus.archived);
      await db.updatePit(a, name: '現', archived: false);
      expect((await pitOf(a)).status, PitStatus.active);
      final s = await db.createPit(name: '淺', status: PitStatus.shallow);
      await db.updatePit(s, name: '淺2', archived: false);
      expect((await pitOf(s)).status, PitStatus.shallow);
    });
  });

  group('類型轉換', () {
    test('坑→淺坑：沒指定格子時，有資料的格子為開', () async {
      final id = await db.createPit(name: '坑');
      await addOfficialImages(id, 2);
      await addIdea(id);
      await db.setPitStatus(id, PitStatus.shallow);
      final p = await pitOf(id);
      expect(p.status, PitStatus.shallow);
      expect(p.enabledSections, {PitSectionKey.official, PitSectionKey.idea});
      // 資料都還在
      expect(await db.sectionContentCount(id, PitSectionKey.official), 2);
      expect(await db.sectionContentCount(id, PitSectionKey.idea), 1);
    });

    test('坑→淺坑：雜物開關開著，雜物格也開', () async {
      final id = await db.createPit(name: '坑', junkEnabled: true);
      await db.setPitStatus(id, PitStatus.shallow);
      expect((await pitOf(id)).enabledSections, {PitSectionKey.junk});
    });

    test('坑→淺坑：關掉有資料的格子要同意才會刪（沒同意就丟例外、全部不動）', () async {
      final id = await db.createPit(name: '坑');
      await addOfficialImages(id, 3);
      await expectLater(
        db.setPitStatus(
          id,
          PitStatus.shallow,
          enabledSections: {PitSectionKey.fan},
        ),
        throwsA(
          isA<PitSectionHasContent>().having((e) => e.counts, 'counts', {
            PitSectionKey.official: 3,
          }),
        ),
      );
      expect((await pitOf(id)).status, PitStatus.active);
      expect(await db.sectionContentCount(id, PitSectionKey.official), 3);
      await db.setPitStatus(
        id,
        PitStatus.shallow,
        enabledSections: {PitSectionKey.fan},
        deleteClosedContent: true,
      );
      expect(await db.sectionContentCount(id, PitSectionKey.official), 0);
      expect((await pitOf(id)).enabledSections, {PitSectionKey.fan});
    });

    test('淺坑→坑：六格全開、資料保留；雜物沿用淺坑的設定', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.idea, PitSectionKey.junk},
      );
      await addIdea(id);
      await db.setPitStatus(id, PitStatus.active);
      final p = await pitOf(id);
      expect(p.status, PitStatus.active);
      expect(p.enabledSections, isEmpty);
      expect(p.junkEnabled, isTrue);
      expect(p.openSections, containsAll(PitSectionKey.values));
      expect(await db.sectionContentCount(id, PitSectionKey.idea), 1);
    });

    test('任何→封存：資料保留、轉回後格子設定還原', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.official, PitSectionKey.piece},
      );
      await addOfficialImages(id, 2);
      await db.setPitStatus(id, PitStatus.archived);
      var p = await pitOf(id);
      expect(p.isArchived, isTrue);
      expect(await db.sectionContentCount(id, PitSectionKey.official), 2);
      await db.setPitStatus(id, PitStatus.shallow);
      p = await pitOf(id);
      expect(p.enabledSections, {PitSectionKey.official, PitSectionKey.piece});
      await db.setPitStatus(id, PitStatus.archived);
      await db.setPitStatus(id, PitStatus.active);
      expect((await pitOf(id)).enabledSections, isEmpty);
      expect((await pitOf(id)).isActive, isTrue);
    });

    test('現坑→封存→淺坑：沿用有資料的格子', () async {
      final id = await db.createPit(name: '坑');
      await addIdea(id);
      await db.setPitStatus(id, PitStatus.archived);
      await db.setPitStatus(id, PitStatus.shallow);
      expect((await pitOf(id)).enabledSections, {PitSectionKey.idea});
    });

    test('savePit：一次存名稱、描述、類型與格子', () async {
      final id = await db.createPit(name: '坑');
      await db.savePit(
        id,
        name: '新名',
        description: '描述',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.fan},
      );
      final p = await pitOf(id);
      expect(
        (p.name, p.description, p.status),
        ('新名', '描述', PitStatus.shallow),
      );
      expect(p.enabledSections, {PitSectionKey.fan});
    });
  });

  group('格子開關與內容', () {
    test('開啟格子：只加進集合', () async {
      final id = await db.createPit(name: '淺', status: PitStatus.shallow);
      await db.setPitSectionEnabled(id, PitSectionKey.official, true);
      await db.setPitSectionEnabled(id, PitSectionKey.junk, true);
      final p = await pitOf(id);
      expect(p.enabledSections, {PitSectionKey.official, PitSectionKey.junk});
      expect(p.junkEnabled, isTrue);
    });

    test('關掉空格子：直接關', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.official},
      );
      await db.setPitSectionEnabled(id, PitSectionKey.official, false);
      expect((await pitOf(id)).enabledSections, isEmpty);
    });

    test('關掉有內容的格子：沒同意就丟例外，同意後軟刪除該格內容（其他格不動）', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {
          PitSectionKey.official,
          PitSectionKey.idea,
          PitSectionKey.draft,
          PitSectionKey.piece,
          PitSectionKey.oshi,
          PitSectionKey.junk,
          PitSectionKey.fan,
        },
      );
      await addOfficialImages(id, 3);
      await db.addFanArts(id, const [NewImage(file: 'f.png')], author: '');
      await db.addJunk(id, const [
        NewImage(file: 'j.png'),
        NewImage(file: 'j2.png'),
      ]);
      final ideaId = await addIdea(id);
      await db.saveDraft(
        pitId: id,
        title: '摸魚',
        images: const [NewImage(file: 'd.png')],
        tagIds: const [],
        ideaIds: [ideaId],
      );
      await db.saveOshiRecord(
        pitId: id,
        date: DateTime(2026, 5, 1),
        images: const [NewImage(file: 'os.png')],
      );
      await db.savePiece(
        pitId: id,
        title: '成圖',
        body: '',
        images: const [NewImage(file: 'p.png')],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 5, 1),
        ideaIds: const [],
        draftIds: const [],
      );

      final counts = await db.sectionContentCounts(id);
      expect(counts, {
        PitSectionKey.official: 3,
        PitSectionKey.fan: 1,
        PitSectionKey.idea: 1,
        PitSectionKey.draft: 1,
        PitSectionKey.piece: 1,
        PitSectionKey.oshi: 1,
        PitSectionKey.junk: 2,
      });

      await expectLater(
        db.setPitSectionEnabled(id, PitSectionKey.official, false),
        throwsA(isA<PitSectionHasContent>()),
      );
      expect((await pitOf(id)).sectionOpen(PitSectionKey.official), isTrue);
      expect(await db.sectionContentCount(id, PitSectionKey.official), 3);

      for (final s in PitSectionKey.values) {
        await db.setPitSectionEnabled(id, s, false, deleteContent: true);
      }
      final p = await pitOf(id);
      expect(p.enabledSections, isEmpty);
      expect(p.junkEnabled, isFalse);
      expect(await db.sectionContentCounts(id), isEmpty);
      // 軟刪除：列還在、deletedAt 有值（同步才傳得出去）
      final rows = await db.select(db.officialImages).get();
      expect(rows, hasLength(3));
      expect(rows.every((r) => r.deletedAt != null), isTrue);
      expect((await db.select(db.ideas).get()).single.deletedAt, isNotNull);
    });

    test('刪除該格內容時，格子封面一併清掉；別的坑不受影響', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.official},
      );
      final other = await db.createPit(name: '別的坑');
      await addOfficialImages(id, 1);
      await addOfficialImages(other, 2);
      final img = (await db.watchOfficial(id).first).single;
      await db.setCellCover(id, 'official', img.id);
      await db.setPitSectionEnabled(
        id,
        PitSectionKey.official,
        false,
        deleteContent: true,
      );
      expect((await pitOf(id)).officialCoverId, isNull);
      expect(await db.sectionContentCount(other, PitSectionKey.official), 2);
    });

    test('被移到別格而隱藏的圖不計入數量', () async {
      final id = await db.createPit(name: '淺', status: PitStatus.shallow);
      await addOfficialImages(id, 2);
      final first = (await db.watchOfficial(id).first).first;
      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [first.id],
        to: AlbumCell.fan,
      );
      expect(await db.sectionContentCount(id, PitSectionKey.official), 1);
      expect(await db.sectionContentCount(id, PitSectionKey.fan), 1);
    });

    test('非淺坑：只有雜物能開關（不刪內容），其他格子丟 ArgumentError', () async {
      final id = await db.createPit(name: '坑');
      await db.addJunk(id, const [NewImage(file: 'j.png')]);
      await db.setPitSectionEnabled(id, PitSectionKey.junk, true);
      expect((await pitOf(id)).junkEnabled, isTrue);
      await db.setPitSectionEnabled(id, PitSectionKey.junk, false);
      expect((await pitOf(id)).junkEnabled, isFalse);
      expect(await db.sectionContentCount(id, PitSectionKey.junk), 1);
      expect(
        () => db.setPitSectionEnabled(id, PitSectionKey.fan, false),
        throwsArgumentError,
      );
    });
  });

  group('封面', () {
    test('淺坑封面檔優先；現坑選擇封面時清掉它', () async {
      final id = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        coverFile: 'mine.png',
      );
      expect((await pitOf(id)).coverFile, 'mine.png');
      await db.setPitCoverFile(id, 'new.png');
      expect((await pitOf(id)).coverFile, 'new.png');
      await db.setCover(id, null);
      expect((await pitOf(id)).coverFile, isNull);
    });
  });

  group('封存坑不計入目標、不出現在選擇清單', () {
    test('目標進度排除封存坑的內容（全部坑的目標也一樣）', () async {
      final live = await db.createPit(name: '現');
      final dead = await db.createPit(name: '封');
      for (final id in [live, dead]) {
        await db.savePiece(
          pitId: id,
          title: '成圖',
          body: '',
          images: const [],
          tagIds: const [],
          links: const [],
          targetLikes: 0,
          finishedAt: DateTime(2026, 5, 1),
          ideaIds: const [],
          draftIds: const [],
        );
      }
      await db.saveGoal(
        period: GoalPeriod.year,
        year: 2026,
        kind: GoalKind.piece,
        count: 5,
      );
      expect(
        (await db.watchGoalViews(GoalPeriod.year, 2026).first).single.progress,
        2,
      );
      await db.setPitStatus(dead, PitStatus.archived);
      expect(
        (await db.watchGoalViews(GoalPeriod.year, 2026).first).single.progress,
        1,
      );
      // 轉回後又計入
      await db.setPitStatus(dead, PitStatus.active);
      expect(
        (await db.watchGoalViews(GoalPeriod.year, 2026).first).single.progress,
        2,
      );
    });

    test('淺坑照樣計入目標', () async {
      final s = await db.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.piece},
      );
      await db.savePiece(
        pitId: s,
        title: '成圖',
        body: '',
        images: const [],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 5, 1),
        ideaIds: const [],
        draftIds: const [],
      );
      await db.saveGoal(
        period: GoalPeriod.year,
        year: 2026,
        kind: GoalKind.piece,
        count: 5,
      );
      expect(
        (await db.watchGoalViews(GoalPeriod.year, 2026).first).single.progress,
        1,
      );
    });
  });

  group('同步', () {
    late AppDatabase a;
    late AppDatabase b;
    late Directory dirA;
    late Directory dirB;
    late MemoryRemote remote;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      a = AppDatabase(NativeDatabase.memory());
      b = AppDatabase(NativeDatabase.memory());
      dirA = await Directory.systemTemp.createTemp('pitstatus_a');
      dirB = await Directory.systemTemp.createTemp('pitstatus_b');
      remote = MemoryRemote();
      engineA = SyncEngine(db: a, remote: remote, images: ImageStore(dirA));
      engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
    });
    tearDown(() async {
      await a.close();
      await b.close();
    });

    Map<String, dynamic> docOf(String pitId) =>
        (jsonDecode(utf8.decode(remote.files['meta__pits__$pitId.json']!))
                as Map<String, dynamic>)['data']
            as Map<String, dynamic>;

    test(
      '來回同步：status／enabledSections／coverFile（含圖檔）原樣到達，文件另帶相容的 archived',
      () async {
        await dirA.create(recursive: true);
        File('${dirA.path}/cover.png')
            .writeAsBytesSync(Uint8List.fromList([9, 9]));
        final id = await a.createPit(
          name: '淺坑',
          status: PitStatus.shallow,
          enabledSections: {PitSectionKey.official, PitSectionKey.oshi},
          coverFile: 'cover.png',
        );
        final z = await a.createPit(name: '封存');
        await a.setPitStatus(z, PitStatus.archived);
        await engineA.sync();
        expect(docOf(id)['status'], 'shallow');
        expect(docOf(id)['enabledSections'], 'official,oshi');
        expect(docOf(id)['archived'], isFalse);
        expect(docOf(z)['archived'], isTrue);

        final down = await engineB.sync();
        expect(down.imagesDown, 1);
        expect(File('${dirB.path}/cover.png').readAsBytesSync(), [9, 9]);
        final p = (await b.watchPit(id).first)!;
        expect(p.status, PitStatus.shallow);
        expect(p.enabledSections, {PitSectionKey.official, PitSectionKey.oshi});
        expect(p.coverFile, 'cover.png');
        expect((await b.watchPit(z).first)!.status, PitStatus.archived);

        // B 改了再傳回 A
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await b.setPitSectionEnabled(id, PitSectionKey.fan, true);
        await engineB.sync();
        await engineA.sync();
        expect((await a.watchPit(id).first)!.enabledSections, {
          PitSectionKey.official,
          PitSectionKey.fan,
          PitSectionKey.oshi,
        });
      },
    );

    Future<void> put(String id, Map<String, dynamic> data) => remote.upload(
      'meta__pits__$id.json',
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'kind': 'pits',
            'id': id,
            'updatedAt': data['updatedAt'],
            'data': data,
          }),
        ),
      ),
    );

    Map<String, dynamic> oldDoc(
      String id, {
      required bool archived,
      int t = 1700000000000,
    }) => {
      'id': id,
      'createdAt': t,
      'updatedAt': t,
      'deletedAt': null,
      'deviceId': '',
      'name': '舊坑',
      'description': null,
      'coverImageId': null,
      'officialCoverId': null,
      'fanArtCoverId': null,
      'archived': archived,
    };

    test('舊版文件（只有 archived）：true→封存、false→現坑', () async {
      await put('old-1', oldDoc('old-1', archived: false));
      await put('old-2', oldDoc('old-2', archived: true));
      await engineB.sync();
      expect((await b.watchPit('old-1').first)!.status, PitStatus.active);
      expect((await b.watchPit('old-2').first)!.status, PitStatus.archived);
      expect((await b.watchPit('old-1').first)!.enabledSections, isEmpty);
    });

    test('認不得的 status（未來新類型）當作沒有，依 archived 推', () async {
      await put('fut', {...oldDoc('fut', archived: true), 'status': 'frozen'});
      await engineB.sync();
      expect((await b.watchPit('fut').first)!.status, PitStatus.archived);
    });

    test('舊版 App 改了淺坑的名稱（文件沒有 status、archived=false）：保留淺坑與格子設定', () async {
      final id = await a.createPit(
        name: '淺',
        status: PitStatus.shallow,
        enabledSections: {PitSectionKey.idea},
      );
      await engineA.sync();
      await engineB.sync();
      // 舊版 App 之後的寫入：沒有 status／enabledSections，updatedAt 較新
      final t = DateTime.now().millisecondsSinceEpoch + 5000;
      await put(id, {...oldDoc(id, archived: false, t: t), 'name': '舊版改的名'});
      await engineB.sync();
      final p = (await b.watchPit(id).first)!;
      expect(p.name, '舊版改的名');
      expect(p.status, PitStatus.shallow);
      expect(p.enabledSections, {PitSectionKey.idea});
    });

    test('舊版 App 把封存的淺坑取消封存：status 依 archived 推成現坑', () async {
      final id = await a.createPit(name: '坑');
      await a.setPitStatus(id, PitStatus.archived);
      await engineA.sync();
      await engineB.sync();
      final t = DateTime.now().millisecondsSinceEpoch + 5000;
      await put(id, oldDoc(id, archived: false, t: t));
      await engineB.sync();
      expect((await b.watchPit(id).first)!.status, PitStatus.active);
    });
  });
}
