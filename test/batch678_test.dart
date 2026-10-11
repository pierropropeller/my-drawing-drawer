import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/junk_queries.dart';

/// 批次 6–8 的資料層：D-070 date、D-069 草稿↔成圖兩側、D-060 官方圖 tag 與批次 tag、
/// D-058 封面與統計、D-059 分享進來的新增 API。
void main() {
  late AppDatabase db;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() => db.close());

  Future<String> idea(String title, {DateTime? date, DateTime? createdAt}) =>
      db.saveIdea(
        pitId: pitId,
        title: title,
        body: '',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
        date: date,
        createdAt: createdAt,
      );

  Future<String> draft(
    String title, {
    DateTime? date,
    List<String>? pieceIds,
    String file = 'd.png',
  }) => db.saveDraft(
    pitId: pitId,
    title: title,
    images: [NewImage(file: file)],
    tagIds: const [],
    ideaIds: const [],
    pieceIds: pieceIds,
    date: date,
  );

  Future<String> piece(
    String title,
    DateTime at, {
    List<String> draftIds = const [],
    String file = 'p.png',
    String? pit,
  }) => db.savePiece(
    pitId: pit ?? pitId,
    title: title,
    body: '',
    images: [NewImage(file: file)],
    tagIds: const [],
    links: const [],
    targetLikes: 0,
    finishedAt: at,
    ideaIds: const [],
    draftIds: draftIds,
    isPublished: true,
  );

  group('D-070 腦洞／草稿的 date', () {
    test('預設是現在；給日期就用日期；列表依 date 新到舊（不再看 updatedAt）', () async {
      final now = DateTime.now();
      final fresh = await idea('今天');
      final fi = (await db.watchIdeaView(fresh).first)!;
      expect(fi.idea.date.difference(now).inSeconds.abs() < 5, isTrue);

      final old = await idea('舊的', date: DateTime(2026, 1, 5));
      final mid = await idea('中間', date: DateTime(2026, 6, 5));
      expect((await db.watchIdeaViews(pitId).first).map((v) => v.idea.id), [
        fresh,
        mid,
        old,
      ]);
      // 編輯最舊的那筆（updatedAt 最新）不會讓它跳到最前
      await db.saveIdea(
        id: old,
        pitId: pitId,
        title: '舊的（改）',
        body: 'x',
        images: const [],
        tagIds: const [],
        draftIds: const [],
        pieceIds: const [],
      );
      var v = (await db.watchIdeaViews(pitId).first).map((v) => v.idea.id);
      expect(v, [fresh, mid, old]);
      expect((await db.watchIdeaView(old).first)!.idea.date, DateTime(2026, 1, 5));

      // 草稿同理
      final d1 = await draft('a', date: DateTime(2026, 3, 1));
      final d2 = await draft('b', date: DateTime(2026, 8, 1));
      expect((await db.watchDraftViews(pitId).first).map((v) => v.draft.id), [
        d2,
        d1,
      ]);
      // 改日期後重新排序
      await db.saveDraft(
        id: d1,
        pitId: pitId,
        title: 'a',
        images: const [NewImage(file: 'd.png')],
        tagIds: const [],
        ideaIds: const [],
        date: DateTime(2026, 12, 1),
      );
      expect((await db.watchDraftViews(pitId).first).map((v) => v.draft.id), [
        d1,
        d2,
      ]);
    });

    test('日期選擇器選的是「只有日期」：同一天沿用原本的時間、今天取現在、其他天 00:00', () async {
      final t = DateTime(2026, 3, 1, 15, 40);
      final id = await idea('x', date: t); // 帶時間：原樣
      expect((await db.watchIdeaView(id).first)!.idea.date, t);
      Future<DateTime> edit(DateTime d) async {
        await db.saveIdea(
          id: id,
          pitId: pitId,
          title: 'x',
          body: '',
          images: const [],
          tagIds: const [],
          draftIds: const [],
          pieceIds: const [],
          date: d,
        );
        return (await db.watchIdeaView(id).first)!.idea.date;
      }

      expect(await edit(DateTime(2026, 3, 1)), t); // 同一天：保留 15:40
      expect(await edit(DateTime(2026, 3, 9)), DateTime(2026, 3, 9)); // 其他天：00:00
      final today = DateTime.now();
      final got = await edit(DateTime(today.year, today.month, today.day));
      expect(got.difference(today).inSeconds.abs() < 5, isTrue); // 今天：現在
    });

    test('舊的 createdAt 參數仍可用（目標日頁 ＋ 傳「現在」）：新增時當作 date', () async {
      final at = DateTime(2026, 5, 20, 9, 30);
      final i = await idea('x', createdAt: at);
      final iv = (await db.watchIdeaView(i).first)!.idea;
      expect(iv.date, at);
      expect(iv.createdAt, at);
      final d = await db.saveDraft(
        pitId: pitId,
        images: const [NewImage(file: 'd.png')],
        tagIds: const [],
        ideaIds: const [],
        createdAt: at,
      );
      expect((await db.watchDraftView(d).first)!.draft.date, at);
    });

    test('目標進度與目標日時間軸用 date，不用 createdAt', () async {
      final goal = await db.saveGoal(
        period: GoalPeriod.month,
        year: 2026,
        month: 3,
        kind: GoalKind.idea,
        count: 2,
        pitId: pitId,
        tagIds: const [],
      );
      final dGoal = await db.saveGoal(
        period: GoalPeriod.year,
        year: 2026,
        kind: GoalKind.draft,
        count: 2,
        pitId: pitId,
        tagIds: const [],
      );
      // createdAt 是今天，date 在 2026/3
      await idea('三月', date: DateTime(2026, 3, 15, 10));
      await idea('四月', date: DateTime(2026, 4, 15, 10));
      await draft('三月草稿', date: DateTime(2026, 3, 15, 20));
      await draft('去年草稿', date: DateTime(2025, 12, 31, 23, 59));
      final month = (await db.watchGoalViews(GoalPeriod.month, 2026, month: 3).first)
          .singleWhere((g) => g.goal.id == goal);
      expect(month.progress, 1);
      final year = (await db.watchGoalViews(GoalPeriod.year, 2026).first)
          .singleWhere((g) => g.goal.id == dGoal);
      expect(year.progress, 1);

      final day = await db.watchTimeline(DateTime(2026, 3, 15)).first;
      expect(day.map((i) => i.title), ['三月草稿', '三月']); // 新到舊
      expect(day.first.time, DateTime(2026, 3, 15, 20));
      expect(await db.watchTimeline(DateTime(2026, 4, 15)).first, hasLength(1));
      // createdAt（今天）那天沒有東西
      final n = DateTime.now();
      expect(await db.watchTimeline(DateTime(n.year, n.month, n.day)).first, isEmpty);
    });

    test('成圖仍用 finishedAt', () async {
      await piece('p', DateTime(2026, 2, 3, 12));
      expect(await db.watchTimeline(DateTime(2026, 2, 3)).first, hasLength(1));
    });
  });

  group('D-069 草稿↔成圖兩側', () {
    test('從草稿側設定：兩邊都看得到（id、標題、第一張圖）；從成圖側設定也是', () async {
      final p1 = await piece('成圖一', DateTime(2026, 3, 1), file: 'p1.png');
      final p2 = await piece('成圖二', DateTime(2026, 3, 2), file: 'p2.png');
      final d1 = await draft('草稿一', pieceIds: [p1, p2], file: 'd1.png');
      final dv = (await db.watchDraftView(d1).first)!;
      expect(dv.pieceIds, [p2, p1]); // 完成日期新到舊
      expect(dv.linkedPieces.map((p) => p.title), ['成圖二', '成圖一']);
      expect(dv.linkedPieces.last.firstImage!.file, 'p1.png');
      final pv1 = (await db.watchPieceView(p1).first)!;
      expect(pv1.draftIds, [d1]);
      expect(pv1.linkedDrafts.single.title, '草稿一');
      expect(pv1.linkedDrafts.single.firstImage!.file, 'd1.png');

      // 從成圖側：成圖二改關聯另一份草稿
      final d2 = await draft('草稿二', file: 'd2.png');
      await db.savePiece(
        id: p2,
        pitId: pitId,
        title: '成圖二',
        body: '',
        images: const [NewImage(file: 'p2.png')],
        tagIds: const [],
        links: const [],
        targetLikes: 0,
        finishedAt: DateTime(2026, 3, 2),
        ideaIds: const [],
        draftIds: [d2],
      );
      expect((await db.watchDraftView(d1).first)!.pieceIds, [p1]);
      expect((await db.watchDraftView(d2).first)!.pieceIds, [p2]);
      expect((await db.watchPieceView(p2).first)!.linkedDrafts.single.id, d2);
    });

    test('pieceIds 不傳＝不動關係；傳空＝清空；重複 id 只算一次', () async {
      final p1 = await piece('成圖', DateTime(2026, 3, 1));
      final d = await draft('草稿', pieceIds: [p1, p1]);
      expect((await db.watchDraftView(d).first)!.pieceIds, [p1]);
      Future<void> edit({List<String>? pieceIds}) async {
        await db.saveDraft(
          id: d,
          pitId: pitId,
          title: '草稿',
          images: const [NewImage(file: 'd.png')],
          tagIds: const [],
          ideaIds: const [],
          pieceIds: pieceIds,
        );
      }

      await edit(); // 不傳
      expect((await db.watchDraftView(d).first)!.pieceIds, [p1]);
      await edit(pieceIds: const []);
      expect((await db.watchDraftView(d).first)!.pieceIds, isEmpty);
      expect((await db.watchPieceView(p1).first)!.draftIds, isEmpty);
    });

    test('已刪除的一邊不再顯示；刪除時關係被清掉', () async {
      final p1 = await piece('成圖', DateTime(2026, 3, 1));
      final d = await draft('草稿', pieceIds: [p1]);
      await db.deletePieces([p1]);
      final dv = (await db.watchDraftView(d).first)!;
      expect(dv.pieceIds, isEmpty);
      expect(dv.linkedPieces, isEmpty);

      final p2 = await piece('成圖二', DateTime(2026, 3, 1));
      await db.setDraftPieces(d, [p2]);
      await db.deleteDrafts([d]);
      expect((await db.watchPieceView(p2).first)!.linkedDrafts, isEmpty);
    });

    test('從草稿側修改會更新受影響成圖的 updatedAt（同步擁有者是成圖）', () async {
      final p1 = await piece('一', DateTime(2026, 3, 1));
      final p2 = await piece('二', DateTime(2026, 3, 1));
      final p3 = await piece('三', DateTime(2026, 3, 1));
      final d = await draft('草稿', pieceIds: [p1, p2]);
      Future<DateTime> at(String id) async =>
          (await db.watchPieceView(id).first)!.piece.updatedAt;
      final before = {p1: await at(p1), p2: await at(p2), p3: await at(p3)};
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.setDraftPieces(d, [p2, p3]); // 拿掉 p1、加上 p3，p2 不變但仍受影響
      expect((await at(p1)).isAfter(before[p1]!), isTrue); // 被移除的
      expect((await at(p3)).isAfter(before[p3]!), isTrue); // 新加的
    });
  });

  group('D-060 官方圖 tag', () {
    late List<OfficialGroup> og;
    late List<OfficialGroup> fg;
    setUp(() async {
      og = await db.watchGroups(pitId).first;
      fg = await db.watchGroups(pitId, kind: 'fan').first;
    });

    Future<List<OfficialImage>> addOfficial(
      List<String> files, {
      List<String> tagIds = const [],
      String? pit,
      String? group,
    }) async {
      await db.addOfficial(pit ?? pitId, group ?? og.first.id, [
        for (final f in files) NewImage(file: f),
      ], tagIds: tagIds);
      return (await db.watchOfficial(pit ?? pitId).first)
          .where((i) => files.contains(i.imageFile))
          .toList();
    }

    test('addOfficial 一次加圖＋分組＋tag；setOfficialTags 蓋 updatedAt', () async {
      final t1 = await db.createTag(pitId, '角色1');
      final t2 = await db.createTag(pitId, '角色2');
      final ims = await addOfficial(['a.png', 'b.png'], tagIds: [t1, t2]);
      for (final i in ims) {
        expect(
          (await db.watchTagIds(TagTarget.official, i.id).first).toSet(),
          {t1, t2},
        );
      }
      final before = ims.first.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.setOfficialTags(ims.first.id, [t2]);
      expect(await db.watchTagIds(TagTarget.official, ims.first.id).first, [t2]);
      final after = (await db.watchOfficial(pitId).first)
          .firstWhere((i) => i.id == ims.first.id);
      expect(after.updatedAt.isAfter(before), isTrue);
      // 次數含官方圖
      final usage = {
        for (final u in await db.watchTagUsage(pitId).first) u.tag.id: u.count,
      };
      expect(usage[t1], 1);
      expect(usage[t2], 2);
      // 刪除官方圖後不再計入
      await db.deleteOfficial([ims.last.id]);
      final usage2 = {
        for (final u in await db.watchTagUsage(pitId).first) u.tag.id: u.count,
      };
      expect(usage2[t1], 0);
      expect(usage2[t2], 1);
    });

    test('addFanArts 一次加圖＋作者＋出處＋tag；addJunk 純圖', () async {
      final t = await db.createTag(pitId, '角色1');
      await db.addFanArts(
        pitId,
        const [NewImage(file: 'f1.png'), NewImage(file: 'f2.png')],
        author: '@au',
        groupId: fg[1].id,
        tagIds: [t],
      );
      final fans = await db.watchFanArts(pitId, tagId: t).first;
      expect(fans, hasLength(2));
      expect(fans.every((f) => f.author == '@au' && f.groupId == fg[1].id), isTrue);
      await db.addJunk(pitId, const [NewImage(file: 'j.png')]);
      expect(await db.watchJunk(pitId).first, hasLength(1));
    });

    test('三態：全部有／部分有／都沒有；套用後立即反映', () async {
      final t1 = await db.createTag(pitId, 'A');
      final t2 = await db.createTag(pitId, 'B');
      final t3 = await db.createTag(pitId, 'C');
      final ims = await addOfficial(['1.png', '2.png', '3.png']);
      await db.setOfficialTags(ims[0].id, [t1, t2]);
      await db.setOfficialTags(ims[1].id, [t1]);
      await db.setOfficialTags(ims[2].id, [t1, t2]);
      var cov = await db.tagCoverage(AlbumCell.official, [ims[0].id, ims[1].id]);
      Map<String, TagCoverage> m(List<TagCoverageEntry> l) => {
        for (final e in l) e.tag.name: e.coverage,
      };
      expect(m(cov), {
        'A': TagCoverage.all,
        'B': TagCoverage.some,
        'C': TagCoverage.none,
      });
      expect(cov.first.total, 2);
      expect(cov.firstWhere((e) => e.tag.name == 'B').count, 1);
      expect(cov.firstWhere((e) => e.tag.name == 'B').tapAdds, isTrue);
      expect(cov.firstWhere((e) => e.tag.name == 'A').tapAdds, isFalse);
      // 選取三張
      cov = await db.tagCoverage(AlbumCell.official, ims.map((i) => i.id));
      expect(m(cov)['B'], TagCoverage.some);
      expect(m(cov)['A'], TagCoverage.all);
      // 空選取
      expect(await db.tagCoverage(AlbumCell.official, const []), isEmpty);
      // watch 版
      final first = await db.watchTagCoverage(AlbumCell.official, [ims[1].id]).first;
      expect(m(first), {
        'A': TagCoverage.all,
        'B': TagCoverage.none,
        'C': TagCoverage.none,
      });
      expect(t3, isNotEmpty);
    });

    test('applyBatchTags：加到全部、從全部移除、新增 tag，一個 transaction，只動有變的圖的 updatedAt', () async {
      final a = await db.createTag(pitId, 'A');
      final b = await db.createTag(pitId, 'B');
      final ims = await addOfficial(['1.png', '2.png', '3.png']);
      await db.setOfficialTags(ims[0].id, [a]);
      await db.setOfficialTags(ims[1].id, [a, b]);
      final ids = ims.map((i) => i.id).toList();
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      final created = await db.applyBatchTags(
        AlbumCell.official,
        ids.take(2),
        addTagIds: [b], // 第二張已有，第一張要補
        removeTagIds: [a],
        newTagNames: ['#新tag'],
      );
      expect(created, hasLength(1));
      final tagNames = {
        for (final t in await db.watchTags(pitId).first) t.id: t.name,
      };
      expect(tagNames[created.single], '新tag'); // 去掉開頭的 #
      for (final id in ids.take(2)) {
        expect(
          (await db.watchTagIds(TagTarget.official, id).first).toSet(),
          {b, created.single},
        );
      }
      // 第三張完全沒動：tag 與 updatedAt 都不變
      expect(await db.watchTagIds(TagTarget.official, ids[2]).first, isEmpty);
      final all = await db.watchOfficial(pitId).first;
      DateTime up(String id) => all.firstWhere((i) => i.id == id).updatedAt;
      expect(up(ids[2]), ims[2].updatedAt);
      expect(up(ids[0]).isAfter(ims[0].updatedAt), isTrue);
      expect(up(ids[1]).isAfter(ims[1].updatedAt), isTrue);

      // 重複套用同樣的變更：沒有任何變動，不蓋 updatedAt
      final snapshot = {for (final i in all) i.id: i.updatedAt};
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await db.applyBatchTags(
        AlbumCell.official,
        ids.take(2),
        addTagIds: [b],
        removeTagIds: [a],
      );
      final again = await db.watchOfficial(pitId).first;
      for (final i in again) {
        expect(i.updatedAt, snapshot[i.id]);
      }
      // 同名 tag 重用，不重複建立
      final reuse = await db.applyBatchTags(
        AlbumCell.official,
        ids,
        newTagNames: ['新tag'],
      );
      expect(reuse.single, created.single);
      expect((await db.watchTags(pitId).first).length, 3);
    });

    test('applyBatchTags：同人圖同樣可用；雜物不行；跨坑 tag 或混坑選取回滾', () async {
      final other = await db.createPit(name: '坑B');
      final foreign = await db.createTag(other, '別坑');
      final t = await db.createTag(pitId, 'A');
      await db.addFanArts(pitId, const [
        NewImage(file: 'f1.png'),
        NewImage(file: 'f2.png'),
      ], author: '');
      final fans = await db.watchFanArts(pitId).first;
      final fids = fans.map((f) => f.id).toList();
      await db.applyBatchTags(AlbumCell.fan, fids, addTagIds: [t]);
      expect((await db.watchFanArts(pitId, tagId: t).first), hasLength(2));
      final cov = await db.tagCoverage(AlbumCell.fan, fids);
      expect(cov.single.coverage, TagCoverage.all);

      await expectLater(
        db.applyBatchTags(AlbumCell.fan, fids, addTagIds: [foreign]),
        throwsArgumentError,
      );
      await expectLater(
        db.applyBatchTags(AlbumCell.junk, fids, addTagIds: [t]),
        throwsArgumentError,
      );
      // 新增 tag 後遇到錯誤 → 整個回滾（不留下新 tag）
      await expectLater(
        db.applyBatchTags(
          AlbumCell.fan,
          fids,
          addTagIds: [foreign],
          newTagNames: ['不該留下'],
        ),
        throwsArgumentError,
      );
      expect((await db.watchTags(pitId).first).map((x) => x.name), ['A']);
      // 混坑選取
      await db.addFanArts(other, const [NewImage(file: 'g.png')], author: '');
      final g = (await db.watchFanArts(other).first).single;
      await expectLater(
        db.applyBatchTags(AlbumCell.fan, [fids.first, g.id], addTagIds: [t]),
        throwsArgumentError,
      );
    });

    test('隱藏列（被移走的圖）不算選取、不算次數；移回後 tag 恢復', () async {
      final t = await db.createTag(pitId, 'A');
      final ims = await addOfficial(['1.png'], tagIds: [t]);
      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [ims.single.id],
        to: AlbumCell.junk,
      );
      expect(await db.tagCoverage(AlbumCell.official, [ims.single.id]), isEmpty);
      expect((await db.watchTagUsage(pitId).first).single.count, 0);
      final junk = (await db.watchJunk(pitId).first).single;
      await db.moveAlbumImages(
        from: AlbumCell.junk,
        ids: [junk.id],
        to: AlbumCell.official,
      );
      final back = (await db.watchOfficial(pitId).first).single;
      expect(back.id, ims.single.id); // 取消隱藏同一列
      expect(await db.watchTagIds(TagTarget.official, back.id).first, [t]);
      expect((await db.watchTagUsage(pitId).first).single.count, 1);
    });

    test('官方↔同人圖：tag 各格各自保留（隱藏列），移過去的新列沒有 tag，移回恢復', () async {
      final t = await db.createTag(pitId, 'A');
      final ims = await addOfficial(['1.png'], tagIds: [t]);
      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [ims.single.id],
        to: AlbumCell.fan,
        groupId: fg[0].id,
      );
      final fan = (await db.watchFanArts(pitId).first).single;
      expect(await db.watchTagIds(TagTarget.fanArt, fan.id).first, isEmpty);
      // 官方的 tag 留在隱藏列，不計入次數
      expect(await db.watchTagIds(TagTarget.official, ims.single.id).first, [t]);
      expect((await db.watchTagUsage(pitId).first).single.count, 0);
      await db.setTags(TagTarget.fanArt, fan.id, [t]);
      await db.moveAlbumImages(
        from: AlbumCell.fan,
        ids: [fan.id],
        to: AlbumCell.official,
      );
      final back = (await db.watchOfficial(pitId).first).single;
      expect(back.id, ims.single.id);
      expect(await db.watchTagIds(TagTarget.official, back.id).first, [t]);
    });

    test('官方圖跨坑移動：tag 按名稱對應目標坑（沒有就新增），原坑的隱藏列保留；移回恢復原 tag', () async {
      final other = await db.createPit(name: '坑B');
      final bOfficial = await db.watchGroups(other).first;
      final ta = await db.createTag(pitId, '角色1');
      final tb = await db.createTag(pitId, '只在A');
      final existingInB = await db.createTag(other, '角色1');
      final ims = await addOfficial(['1.png'], tagIds: [ta, tb]);

      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [ims.single.id],
        to: AlbumCell.official,
        targetPitId: other,
        groupId: bOfficial[1].id,
      );
      final inB = (await db.watchOfficial(other).first).single;
      expect(inB.groupId, bOfficial[1].id);
      final bTagIds = (await db.watchTagIds(TagTarget.official, inB.id).first).toSet();
      expect(bTagIds.length, 2);
      expect(bTagIds.contains(existingInB), isTrue); // 同名重用
      final bNames = {
        for (final t in await db.watchTags(other).first) t.id: t.name,
      };
      expect(bTagIds.map((i) => bNames[i]).toSet(), {'角色1', '只在A'});
      expect(await db.watchOfficial(pitId).first, isEmpty);
      // 原坑隱藏列的 tag 沒被動到
      expect(
        (await db.watchTagIds(TagTarget.official, ims.single.id).first).toSet(),
        {ta, tb},
      );
      // A 坑的使用次數：隱藏列不算
      expect((await db.watchTagUsage(pitId).first).every((u) => u.count == 0), isTrue);
      expect((await db.watchTagUsage(other).first).every((u) => u.count == 1), isTrue);

      // 在 B 坑改 tag，再移回 A：恢復 A 的隱藏列與它原本的 tag（取消隱藏的列保留自己的 tag）
      await db.moveAlbumImages(
        from: AlbumCell.official,
        ids: [inB.id],
        to: AlbumCell.official,
        targetPitId: pitId,
      );
      final backA = (await db.watchOfficial(pitId).first).single;
      expect(backA.id, ims.single.id);
      expect(
        (await db.watchTagIds(TagTarget.official, backA.id).first).toSet(),
        {ta, tb},
      );
    });
  });

  group('D-058 坑內六格資料', () {
    test('PitStats.oshi／各格封面：成圖格用最新一張成圖的第一張圖', () async {
      expect((await db.watchPitStats(pitId).first).pieces, 0);
      expect((await db.watchCellCovers(pitId).first).piece, isNull);
      await piece('舊', DateTime(2026, 1, 1), file: 'old.png');
      await piece('新', DateTime(2026, 6, 1), file: 'new.png');
      await piece('中', DateTime(2026, 3, 1), file: 'mid.png');
      var covers = await db.watchCellCovers(pitId).first;
      expect(covers.piece, 'new.png'); // 完成日期最晚
      // 刪掉最新的 → 換成次新
      final newest = (await db.watchPieceViews(pitId).first)
          .firstWhere((v) => v.piece.title == '新')
          .piece
          .id;
      await db.deletePieces([newest]);
      covers = await db.watchCellCovers(pitId).first;
      expect(covers.piece, 'mid.png');
      final stats = await db.watchPitStats(pitId).first;
      expect(stats.pieces, 2);
      expect(stats.oshi, 0);
    });

    test('草稿／腦洞格封面取 date 最新的一筆', () async {
      await db.saveDraft(
        pitId: pitId,
        images: const [NewImage(file: 'old.png')],
        tagIds: const [],
        ideaIds: const [],
        date: DateTime(2026, 1, 1),
      );
      await db.saveDraft(
        pitId: pitId,
        images: const [NewImage(file: 'new.png')],
        tagIds: const [],
        ideaIds: const [],
        date: DateTime(2026, 5, 1),
      );
      await db.saveDraft(
        pitId: pitId,
        images: const [NewImage(file: 'mid.png')],
        tagIds: const [],
        ideaIds: const [],
        date: DateTime(2026, 3, 1),
      );
      expect((await db.watchCellCovers(pitId).first).draft, 'new.png');
    });
  });
}
