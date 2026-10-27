import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/image_store.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/material_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/data/sensitive_queries.dart';
import 'package:huakeng/sync/remote.dart';
import 'package:huakeng/sync/sync_engine.dart';

/// 敏感內容標記（D-104）的資料層：遷移、標記邏輯、封面、年度回顧、同步。
void main() {
  late AppDatabase db;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  NewImage img(String name, {bool sensitive = false}) =>
      NewImage(file: name, width: 10, height: 20, sensitive: sensitive);

  Future<String> groupOf(String pitId) async =>
      (await db.watchGroups(pitId).first).first.id;

  Future<String> pitWithFlag({bool on = true}) async {
    final id = await db.createPit(name: '坑');
    if (on) await db.setPitSensitiveEnabled(id, true);
    return id;
  }

  group('預設值與寫入', () {
    test('所有放圖的表：sensitive 預設 false；新坑的 sensitiveEnabled 預設 false', () async {
      final pit = await db.createPit(name: '坑');
      expect((await db.watchPit(pit).first)!.sensitiveEnabled, isFalse);
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('o.png')]);
      await db.addFanArts(pit, [img('f.png')], author: '');
      await db.addJunk(pit, [img('j.png')]);
      await db.addMaterials(MaterialCategory.pose, [img('m.png')]);
      await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [img('i.png')],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      expect((await db.select(db.officialImages).getSingle()).sensitive, false);
      expect((await db.select(db.fanArts).getSingle()).sensitive, false);
      expect((await db.select(db.junkImages).getSingle()).sensitive, false);
      expect((await db.select(db.materialImages).getSingle()).sensitive, false);
      expect((await db.select(db.entityImages).getSingle()).sensitive, false);
    });

    test('NewImage.sensitive 會寫進每一種圖片列（官方、同人圖、雜物、素材庫、腦洞、摸魚、成圖、推活）', () async {
      final pit = await db.createPit(name: '坑');
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('o.png', sensitive: true)]);
      await db.addFanArts(pit, [img('f.png', sensitive: true)], author: '');
      await db.addJunk(pit, [img('j.png', sensitive: true)]);
      await db.addMaterials(MaterialCategory.pose, [
        img('m.png', sensitive: true),
      ]);
      await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [img('i.png', sensitive: true), img('i2.png')],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      await db.saveDraft(
        pitId: pit,
        images: [img('d.png', sensitive: true)],
        tagIds: const [],
        ideaIds: const [],
      );
      await db.savePiece(
        pitId: pit,
        title: 'p',
        body: '',
        images: [img('p.png', sensitive: true)],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 10, 1),
        ideaIds: const [],
        draftIds: const [],
      );
      await db.saveOshiRecord(
        pitId: pit,
        date: DateTime(2026, 10, 1),
        images: [img('k.png', sensitive: true)],
      );
      expect((await db.select(db.officialImages).getSingle()).sensitive, true);
      expect((await db.select(db.fanArts).getSingle()).sensitive, true);
      expect((await db.select(db.junkImages).getSingle()).sensitive, true);
      expect((await db.select(db.materialImages).getSingle()).sensitive, true);
      final e = {
        for (final r in await db.select(db.entityImages).get())
          r.imageFile: r.sensitive,
      };
      expect(e, {
        'i.png': true,
        'i2.png': false,
        'd.png': true,
        'p.png': true,
        'k.png': true,
      });
    });

    test('編輯腦洞：既有圖原樣送回保留標記；toNewImage 帶著 sensitive', () async {
      final pit = await db.createPit(name: '坑');
      final id = await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [img('i.png', sensitive: true)],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      final v = (await db.watchIdeaView(id).first)!;
      expect(v.images.single.sensitive, isTrue);
      final back = v.images.single.toNewImage();
      expect(back.sensitive, isTrue);
      // 取消標記
      await db.saveIdea(
        id: id,
        pitId: pit,
        title: 'i',
        body: '',
        images: [back.copyWith(sensitive: false)],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      expect((await db.select(db.entityImages).getSingle()).sensitive, false);
    });

    test('updatePit 的 sensitiveEnabled：null 不變、開關不影響圖片標記', () async {
      final pit = await db.createPit(name: '坑');
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('o.png', sensitive: true)]);
      await db.updatePit(pit, name: '坑', sensitiveEnabled: true);
      expect((await db.watchPit(pit).first)!.sensitiveEnabled, isTrue);
      await db.updatePit(pit, name: '坑2');
      expect((await db.watchPit(pit).first)!.sensitiveEnabled, isTrue);
      await db.updatePit(pit, name: '坑2', sensitiveEnabled: false);
      expect((await db.watchPit(pit).first)!.sensitiveEnabled, isFalse);
      // 標記保留
      expect((await db.select(db.officialImages).getSingle()).sensitive, true);
      expect(await db.sensitiveCountInPit(pit), 1);
    });

    test('跨格移動：標記跟著圖走（官方→同人圖→雜物）', () async {
      final pit = await db.createPit(name: '坑');
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('o.png', sensitive: true)]);
      final id = (await db.select(db.officialImages).getSingle()).id;
      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [id],
        to: AlbumCell.fan,
      );
      expect((await db.select(db.fanArts).getSingle()).sensitive, isTrue);
      // 回官方：取消隱藏的分身，也跟著目前的標記
      await db.setSensitive(SensitiveSource.fan, [
        (await db.select(db.fanArts).getSingle()).id,
      ], false);
      await db.moveAlbumImages(
        from: AlbumCell.fan,
        ids: [(await db.select(db.fanArts).getSingle()).id],
        to: AlbumCell.official,
        groupId: g,
      );
      final o = await (db.select(
        db.officialImages,
      )..where((x) => x.hidden.equals(false))).getSingle();
      expect(o.sensitive, isFalse);
    });
  });

  group('多選「敏感」：有未標的→全部標上；全部已標→全部取消', () {
    test('官方圖：部分已標 → 全部標；全部已標 → 全部取消', () async {
      final pit = await db.createPit(name: '坑');
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [
        img('a.png', sensitive: true),
        img('b.png'),
        img('c.png'),
      ]);
      final ids = [
        for (final r in await db.select(db.officialImages).get()) r.id,
      ];
      expect(await db.nextSensitiveValue(SensitiveSource.official, ids), true);
      expect(await db.setSensitive(SensitiveSource.official, ids, true), 2);
      expect((await db.sensitiveCounts(SensitiveSource.official, ids)), (
        total: 3,
        marked: 3,
      ));
      expect(await db.nextSensitiveValue(SensitiveSource.official, ids), false);
      expect(await db.setSensitive(SensitiveSource.official, ids, false), 3);
      expect(
        (await db.sensitiveCounts(SensitiveSource.official, ids)).marked,
        0,
      );
      // 沒有選中任何圖：沒事可做
      expect(await db.nextSensitiveValue(SensitiveSource.official, []), null);
    });

    test('素材庫、雜物、同人圖各自有效；已是目標狀態的列不動 updatedAt', () async {
      final pit = await db.createPit(name: '坑');
      await db.addMaterials(MaterialCategory.pose, [
        img('m1.png'),
        img('m2.png', sensitive: true),
      ]);
      await db.addJunk(pit, [img('j.png')]);
      await db.addFanArts(pit, [img('f.png')], author: '');
      final mats = [
        for (final r in await db.select(db.materialImages).get()) r.id,
      ];
      final before = {
        for (final r in await db.select(db.materialImages).get())
          r.id: r.updatedAt,
      };
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.setSensitive(SensitiveSource.material, mats, true);
      final after = {
        for (final r in await db.select(db.materialImages).get()) r.id: r,
      };
      expect(after.values.every((r) => r.sensitive), isTrue);
      final already = (await db.select(db.materialImages).get()).firstWhere(
        (r) => r.imageFile == 'm2.png',
      );
      expect(already.updatedAt, before[already.id]); // 本來就標了：不動
      final changed = after.values.firstWhere((r) => r.imageFile == 'm1.png');
      expect(changed.updatedAt.isAfter(before[changed.id]!), isTrue);

      final junk = (await db.select(db.junkImages).getSingle()).id;
      await db.setSensitive(SensitiveSource.junk, [junk], true);
      expect((await db.select(db.junkImages).getSingle()).sensitive, true);
      final fan = (await db.select(db.fanArts).getSingle()).id;
      await db.setSensitive(SensitiveSource.fan, [fan], true);
      expect((await db.select(db.fanArts).getSingle()).sensitive, true);
    });

    test('摸魚／成圖／推活／腦洞：作用在紀錄底下每一張圖，並更新紀錄 updatedAt', () async {
      final pit = await db.createPit(name: '坑');
      final d = await db.saveDraft(
        pitId: pit,
        images: [img('d1.png'), img('d2.png', sensitive: true)],
        tagIds: const [],
        ideaIds: const [],
      );
      final before = (await db.select(db.drafts).getSingle()).updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(await db.nextSensitiveValue(SensitiveSource.draft, [d]), true);
      await db.setSensitive(SensitiveSource.draft, [d], true);
      expect(
        (await db.select(db.entityImages).get()).every((e) => e.sensitive),
        isTrue,
      );
      expect(
        (await db.select(db.drafts).getSingle()).updatedAt.isAfter(before),
        isTrue,
      );
      expect(await db.nextSensitiveValue(SensitiveSource.draft, [d]), false);

      final o = await db.saveOshiRecord(
        pitId: pit,
        date: DateTime(2026, 10, 1),
        images: [img('k.png')],
      );
      await db.setSensitive(SensitiveSource.oshi, [o], true);
      expect(
        (await db.select(db.entityImages).get())
            .firstWhere((e) => e.imageFile == 'k.png')
            .sensitive,
        true,
      );
    });
  });

  group('封面', () {
    Future<String> coverId(String pit) async =>
        (await db.watchPit(pit).first)!.coverImageId ?? '';

    test('把現任封面標成敏感：封面改用坑內最新一張沒標記的圖', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('old.png')]);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.addFanArts(pit, [img('mid.png')], author: '');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.addOfficial(pit, g, [img('cover.png')]);
      final rows = {
        for (final r in await db.select(db.officialImages).get())
          r.imageFile: r.id,
      };
      final fan = (await db.select(db.fanArts).getSingle()).id;
      await db.setCover(pit, rows['cover.png']);
      expect(
        await db.coverCountAmong(SensitiveSource.official, [
          rows['cover.png']!,
        ]),
        1,
      );
      expect(
        await db.coverCountAmong(SensitiveSource.official, [rows['old.png']!]),
        0,
      );
      await db.setSensitive(SensitiveSource.official, [
        rows['cover.png']!,
      ], true);
      // 剩下兩張沒標記的：同人圖 mid（較新）
      expect(await coverId(pit), fan);
      // 再把同人圖標了：剩 old
      await db.setSensitive(SensitiveSource.fan, [fan], true);
      // 現任封面是 fan 這張 → 退到 old
      expect(await coverId(pit), rows['old.png']);
      // 全部標了：沒有可用的圖 → 清成 null（顯示坑名第一個字）
      await db.setSensitive(SensitiveSource.official, [rows['old.png']!], true);
      expect((await db.watchPit(pit).first)!.coverImageId, isNull);
    });

    test('標記不是封面的圖：封面不動；取消標記不會自動找回封面', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('a.png'), img('b.png')]);
      final rows = {
        for (final r in await db.select(db.officialImages).get())
          r.imageFile: r.id,
      };
      await db.setCover(pit, rows['a.png']);
      await db.setSensitive(SensitiveSource.official, [rows['b.png']!], true);
      expect(await coverId(pit), rows['a.png']);
      await db.setSensitive(SensitiveSource.official, [rows['a.png']!], true);
      expect((await db.watchPit(pit).first)!.coverImageId, isNull);
      await db.setSensitive(SensitiveSource.official, [rows['a.png']!], false);
      expect((await db.watchPit(pit).first)!.coverImageId, isNull);
    });

    test('封面是腦洞的圖：標敏感後同樣退到別張；推活格的選擇封面也清掉', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('plain.png')]);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final idea = await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [img('idea.png')],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      final eid = (await db.select(db.entityImages).getSingle()).id;
      await db.setCover(pit, eid);
      final o = await db.saveOshiRecord(
        pitId: pit,
        date: DateTime(2026, 10, 1),
        images: [img('k1.png'), img('k2.png')],
      );
      final k = (await db.watchCoverCandidates(pit, kind: 'oshi').first)
          .firstWhere((c) => c.file == 'k1.png');
      await db.setCellCover(pit, 'oshi', k.id);
      expect((await db.watchPit(pit).first)!.oshiCoverFile, 'k1.png');

      await db.setSensitive(SensitiveSource.idea, [idea], true);
      expect(await coverId(pit), isNot(eid));
      expect(
        await coverId(pit),
        (await db.select(db.officialImages).getSingle()).id,
      );
      await db.setSensitive(SensitiveSource.oshi, [o], true);
      expect((await db.watchPit(pit).first)!.oshiCoverFile, isNull);
    });

    test('編輯單張官方圖／同人圖標敏感：封面同樣處理', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('a.png')]);
      await db.addFanArts(pit, [img('f.png')], author: '作者');
      final o = (await db.select(db.officialImages).getSingle()).id;
      final f = (await db.select(db.fanArts).getSingle()).id;
      await db.setCover(pit, o);
      await db.updateOfficial(o, groupId: g, tagIds: const [], sensitive: true);
      expect(await coverId(pit), f);
      await db.updateFanArt(f, author: '作者', tagIds: const [], sensitive: true);
      expect((await db.watchPit(pit).first)!.coverImageId, isNull);
    });

    test('選擇封面的候選不含敏感的圖（坑開了敏感內容、excludeSensitive）；坑沒開或總開關關＝照常列出', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [
        img('a.png'),
        img('b.png', sensitive: true),
      ]);
      await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [img('i1.png', sensitive: true), img('i2.png')],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      Future<List<String>> files({String? kind, bool exclude = true}) async => [
        for (final c
            in await db
                .watchCoverCandidates(
                  pit,
                  kind: kind,
                  excludeSensitive: exclude,
                )
                .first)
          c.file,
      ];
      expect(await files(), unorderedEquals(['a.png', 'i2.png']));
      expect(await files(kind: 'official'), ['a.png']);
      // 總開關關（excludeSensitive=false）：全部列出
      expect(
        await files(exclude: false),
        unorderedEquals(['a.png', 'b.png', 'i1.png', 'i2.png']),
      );
      // 坑的開關關：就算有標記也列出
      await db.setPitSensitiveEnabled(pit, false);
      expect(
        await files(),
        unorderedEquals(['a.png', 'b.png', 'i1.png', 'i2.png']),
      );
    });

    test('各格封面（自動挑的最新一張）跳過敏感的圖；沒有可用的圖＝null', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('a.png')]);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.addOfficial(pit, g, [img('b.png', sensitive: true)]);
      expect(
        (await db.watchCellCovers(pit, excludeSensitive: true).first).official,
        'a.png',
      );
      expect((await db.watchCellCovers(pit).first).official, 'b.png');
      await db.addOfficial(pit, g, [img('c.png', sensitive: true)]);
      final a = (await db.select(db.officialImages).get()).firstWhere(
        (r) => r.imageFile == 'a.png',
      );
      await db.setSensitive(SensitiveSource.official, [a.id], true);
      expect(
        (await db.watchCellCovers(pit, excludeSensitive: true).first).official,
        isNull,
      );
    });
  });

  group('年度回顧', () {
    test('自動挑月份圖時跳過敏感的圖；手動挑的照用；總開關關＝不跳過', () async {
      final pit = await pitWithFlag();
      Future<void> piece(
        String file,
        DateTime at, {
        required int likes,
        bool sensitive = false,
        List<NewImage> more = const [],
      }) => db
          .savePiece(
            pitId: pit,
            title: file,
            body: '',
            images: [
              img(file, sensitive: sensitive),
              ...more,
            ],
            tagIds: const [],
            links: const [],
            targetLikes: 0,
            finishedAt: at,
            ideaIds: const [],
            draftIds: const [],
          )
          .then((id) async {
            await db.setActualLikes(id, likes);
          });
      await piece('hot.png', DateTime(2026, 8, 1), likes: 9, sensitive: true);
      await piece('cool.png', DateTime(2026, 8, 2), likes: 3);
      // 排除敏感：跳過互動量最高但敏感的那張
      expect(
        (await db.watchReviewMonths(2026, excludeSensitive: true).first)[8],
        'cool.png',
      );
      // 總開關關：照舊用互動量最高
      expect((await db.watchReviewMonths(2026).first)[8], 'hot.png');
      // 手動挑的：就算敏感也用
      await db.setReviewMonthImage(2026, 8, 'hot.png');
      expect(
        (await db.watchReviewMonths(2026, excludeSensitive: true).first)[8],
        'hot.png',
      );
      // 坑的開關關：標記不算
      await db.setReviewMonthImage(2026, 8, null);
      await db.setPitSensitiveEnabled(pit, false);
      expect(
        (await db.watchReviewMonths(2026, excludeSensitive: true).first)[8],
        'hot.png',
      );
    });

    test('一張成圖有多張圖：自動挑同一張成圖裡第一張沒標記的；全是敏感的成圖整張跳過；月份沒別的＝沒有預設圖', () async {
      final pit = await pitWithFlag();
      final first = await db.savePiece(
        pitId: pit,
        title: 'a',
        body: '',
        images: [img('s1.png', sensitive: true), img('s2.png')],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 3, 1),
        ideaIds: const [],
        draftIds: const [],
      );
      expect(first, isNotEmpty);
      expect(
        (await db.watchReviewMonths(2026, excludeSensitive: true).first)[3],
        's2.png',
      );
      await db.savePiece(
        pitId: pit,
        title: 'b',
        body: '',
        images: [img('t1.png', sensitive: true)],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 5, 1),
        ideaIds: const [],
        draftIds: const [],
      );
      final months = await db
          .watchReviewMonths(2026, excludeSensitive: true)
          .first;
      expect(months.containsKey(5), isFalse); // 這個月的圖全是敏感的：沒有預設圖
      final summaries = await db
          .watchReviewMonthSummaries(2026, excludeSensitive: true)
          .first;
      expect(summaries[5]!.pieceCount, 1); // 仍可手動挑
      expect(summaries[5]!.file, isNull);
    });
  });

  group('有效敏感的檔名集合（列表縮圖用）', () {
    Future<Set<String>> files() => db.watchSensitiveFiles().first;

    test('坑的開關關：不算；開：算；素材庫不看坑；已刪除的照算（最近刪除裡也要模糊，D-120）', () async {
      final off = await pitWithFlag(on: false);
      final on = await pitWithFlag();
      final g1 = await groupOf(off);
      final g2 = await groupOf(on);
      await db.addOfficial(off, g1, [img('off.png', sensitive: true)]);
      await db.addOfficial(on, g2, [
        img('on.png', sensitive: true),
        img('plain.png'),
      ]);
      await db.addMaterials(MaterialCategory.pose, [
        img('m.png', sensitive: true),
      ]);
      await db.saveIdea(
        pitId: on,
        title: 'i',
        body: '',
        images: [img('i.png', sensitive: true)],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      await db.saveIdea(
        pitId: off,
        title: 'i',
        body: '',
        images: [img('ioff.png', sensitive: true)],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      expect(await files(), {'on.png', 'm.png', 'i.png'});
      await db.setPitSensitiveEnabled(off, true);
      expect(await files(), containsAll(['off.png', 'ioff.png']));
      await db.setPitSensitiveEnabled(on, false);
      expect(await files(), {'off.png', 'ioff.png', 'm.png'});
      // 刪除：移到最近刪除，那裡的縮圖照樣按安全模式模糊（D-120）。
      final m = (await db.select(db.materialImages).getSingle()).id;
      await db.deleteMaterials([m]);
      expect(await files(), {'off.png', 'ioff.png', 'm.png'});
    });

    test('影片：截圖檔名也算（以截圖顯示的地方查得到）', () async {
      final pit = await pitWithFlag();
      await db.addJunk(pit, [
        const NewImage(
          file: 'v.mp4',
          kind: MediaKind.video,
          posterFile: 'v.jpg',
          sensitive: true,
        ),
      ]);
      expect(await files(), {'v.mp4', 'v.jpg'});
    });

    test('標記後即時更新（stream 重送），內容沒變不重送', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [img('a.png')]);
      final id = (await db.select(db.officialImages).getSingle()).id;
      final seen = <Set<String>>[];
      final sub = db.watchSensitiveFiles().listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.setSensitive(SensitiveSource.official, [id], true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.setPitSensitiveEnabled(pit, true); // 已是開：集合沒變
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(seen, [
        <String>{},
        {'a.png'},
      ]);
    });
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
      dirA = await Directory.systemTemp.createTemp('sens_a');
      dirB = await Directory.systemTemp.createTemp('sens_b');
      remote = MemoryRemote();
      engineA = SyncEngine(db: db, remote: remote, images: ImageStore(dirA));
      engineB = SyncEngine(db: b, remote: remote, images: ImageStore(dirB));
    });
    tearDown(() async {
      await b.close();
      await dirA.delete(recursive: true);
      await dirB.delete(recursive: true);
    });

    NewImage onDisk(String name, {bool sensitive = false}) {
      File('${dirA.path}/$name').writeAsBytesSync(Uint8List.fromList([1, 2]));
      return NewImage(file: name, width: 4, height: 5, sensitive: sensitive);
    }

    test('往返：坑的 sensitiveEnabled、各種圖片列與腦洞／推活的 images 都帶著標記', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [
        onDisk('o1.png', sensitive: true),
        onDisk('o2.png'),
      ]);
      await db.addFanArts(pit, [onDisk('f.png', sensitive: true)], author: '');
      await db.addJunk(pit, [onDisk('j.png', sensitive: true)]);
      await db.addMaterials(MaterialCategory.pose, [
        onDisk('m.png', sensitive: true),
      ]);
      await db.saveIdea(
        pitId: pit,
        title: 'i',
        body: '',
        images: [onDisk('i.png', sensitive: true), onDisk('i2.png')],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      await db.saveOshiRecord(
        pitId: pit,
        date: DateTime(2026, 10, 1),
        images: [onDisk('k.png', sensitive: true)],
      );
      await engineA.sync();
      await engineB.sync();

      expect((await b.watchPit(pit).first)!.sensitiveEnabled, isTrue);
      expect(
        {
          for (final r in await b.select(b.officialImages).get())
            r.imageFile: r.sensitive,
        },
        {'o1.png': true, 'o2.png': false},
      );
      expect((await b.select(b.fanArts).getSingle()).sensitive, true);
      expect((await b.select(b.junkImages).getSingle()).sensitive, true);
      expect((await b.select(b.materialImages).getSingle()).sensitive, true);
      expect(
        {
          for (final r in await b.select(b.entityImages).get())
            r.imageFile: r.sensitive,
        },
        {'i.png': true, 'i2.png': false, 'k.png': true},
      );
    });

    test('A 取消標記、B 拉到後跟著更新（updatedAt 有更新才會同步）', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [onDisk('o.png', sensitive: true)]);
      await engineA.sync();
      await engineB.sync();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final id = (await db.select(db.officialImages).getSingle()).id;
      await db.setSensitive(SensitiveSource.official, [id], false);
      await engineA.sync();
      await engineB.sync();
      expect((await b.select(b.officialImages).getSingle()).sensitive, false);
    });

    test(
      '舊版 App 寫的文件沒有 sensitive／sensitiveEnabled：套用時用預設（未標記、坑關閉），不丟例外',
      () async {
        final pit = await pitWithFlag();
        final g = await groupOf(pit);
        await db.addOfficial(pit, g, [onDisk('o.png', sensitive: true)]);
        await db.saveIdea(
          pitId: pit,
          title: 'i',
          body: '',
          images: [onDisk('i.png', sensitive: true)],
          tagIds: const [],
          draftIds: const [],
          pieceIds: const [],
        );
        await engineA.sync();

        // 把遠端文件改成舊版格式：拿掉新欄位
        for (final key in remote.files.keys.toList()) {
          if (!key.startsWith('meta__')) continue;
          final doc = jsonDecode(
            utf8.decode(remote.files[key]!),
          ) as Map<String, dynamic>;
          if (doc['data'] is! Map<String, dynamic>) continue;
          final data = doc['data'] as Map<String, dynamic>;
          data.remove('sensitive');
          data.remove('sensitiveEnabled');
          for (final m in (data['images'] as List<dynamic>? ?? const [])) {
            (m as Map<String, dynamic>).remove('sensitive');
          }
          remote.files[key] = Uint8List.fromList(utf8.encode(jsonEncode(doc)));
        }
        await engineB.sync();
        expect((await b.watchPit(pit).first)!.sensitiveEnabled, isFalse);
        expect((await b.select(b.officialImages).getSingle()).sensitive, false);
        expect((await b.select(b.entityImages).getSingle()).sensitive, false);
      },
    );
  });

  group('關閉開關不會刪除標記', () {
    test('關坑開關、再開：標記完整還在', () async {
      final pit = await pitWithFlag();
      final g = await groupOf(pit);
      await db.addOfficial(pit, g, [
        img('a.png', sensitive: true),
        img('b.png', sensitive: true),
      ]);
      expect(await db.sensitiveCountInPit(pit), 2);
      await db.setPitSensitiveEnabled(pit, false);
      expect(await db.sensitiveCountInPit(pit), 2);
      expect(await db.watchSensitiveFiles().first, isEmpty); // 顯示上等於沒有標記
      await db.setPitSensitiveEnabled(pit, true);
      expect(await db.watchSensitiveFiles().first, {'a.png', 'b.png'});
    });

    test(
      'sensitiveCountInPit 只算這個坑的官方圖、同人圖、雜物與腦洞／摸魚／成圖／推活的圖，不含已刪除與隱藏',
      () async {
        final pit = await pitWithFlag();
        final other = await pitWithFlag();
        final g = await groupOf(pit);
        await db.addOfficial(pit, g, [img('o.png', sensitive: true)]);
        await db.addFanArts(pit, [img('f.png', sensitive: true)], author: '');
        await db.addJunk(pit, [img('j.png', sensitive: true)]);
        await db.saveDraft(
          pitId: pit,
          images: [img('d.png', sensitive: true), img('d2.png')],
          tagIds: const [],
          ideaIds: const [],
        );
        await db.saveOshiRecord(
          pitId: pit,
          date: DateTime(2026, 10, 1),
          images: [img('k.png', sensitive: true)],
        );
        await db.addJunk(other, [img('x.png', sensitive: true)]);
        expect(await db.sensitiveCountInPit(pit), 5);
        expect(await db.sensitiveCountInPit(other), 1);
        // 軟刪除一張官方圖
        final oid = (await db.select(db.officialImages).getSingle()).id;
        await db.deleteOfficial([oid]);
        expect(await db.sensitiveCountInPit(pit), 4);
      },
    );
  });

  test('Value 欄位：sensitive 預設值為 false（新增列不給值）', () async {
    final pit = await db.createPit(name: '坑');
    await db
        .into(db.junkImages)
        .insert(JunkImagesCompanion.insert(pitId: pit, imageFile: 'x.png'));
    expect((await db.select(db.junkImages).getSingle()).sensitive, isFalse);
    await (db.update(db.junkImages))
        .write(const JunkImagesCompanion(sensitive: Value(true)));
    expect((await db.select(db.junkImages).getSingle()).sensitive, isTrue);
  });
}
