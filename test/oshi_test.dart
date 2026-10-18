import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/goal_queries.dart';
import 'package:huakeng/data/oshi_queries.dart';
import 'package:huakeng/data/search_queries.dart';

/// 推活（D-057／D-062／D-065）：紀錄、分組、篩選、統計、tag 次數、刪坑連帶、搜尋。
void main() {
  late AppDatabase db;
  late String pitId;
  late List<OfficialGroup> groups;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '坑A');
    groups = await db.watchGroups(pitId, kind: 'oshi').first;
  });
  tearDown(() => db.close());

  Future<String> rec({
    String? id,
    required DateTime date,
    String? groupId,
    String? title,
    String? description,
    List<String> files = const ['a.png'],
    List<String> tagIds = const [],
    String? pit,
  }) => db.saveOshiRecord(
    id: id,
    pitId: pit ?? pitId,
    date: date,
    groupId: groupId,
    title: title,
    description: description,
    images: [for (final f in files) NewImage(file: f, width: 3, height: 4)],
    tagIds: tagIds,
  );

  test('新坑有三個預設推活分組，且不影響官方圖冊／同人圖分組', () async {
    expect(groups.map((g) => g.name), ['線下照片', '遊戲截圖', '對話記錄']);
    expect(groups.map((g) => g.sortOrder), [0, 1, 2]);
    expect((await db.watchGroups(pitId).first).length, 6);
    expect((await db.watchGroups(pitId, kind: 'fan').first).length, 5);
  });

  test('新增／編輯／讀取：欄位、日期只取年月日、圖片至少一張、文字 trim', () async {
    final tag = await db.createTag(pitId, '角色1');
    final id = await rec(
      date: DateTime(2026, 10, 5, 14, 30),
      groupId: groups[0].id,
      title: '  一週年展・現場 ',
      description: '   ',
      files: ['a.png', 'b.png'],
      tagIds: [tag],
    );
    var v = (await db.getOshiRecord(id))!;
    expect(v.record.date, DateTime(2026, 10, 5)); // 時間被抹掉
    expect(v.record.title, '一週年展・現場');
    expect(v.record.description, isNull); // 空白 → null
    expect(v.group!.name, '線下照片');
    expect(v.images.map((i) => i.file), ['a.png', 'b.png']);
    expect(v.images.first.width, 3);
    expect(v.tags.single.name, '角色1');

    // 編輯：換分組、拿掉 tag、換圖（相同檔名沿用）
    await db.saveOshiRecord(
      id: id,
      pitId: pitId,
      date: DateTime(2026, 10, 6),
      groupId: groups[1].id,
      title: null,
      description: '描述',
      images: const [
        NewImage(file: 'b.png'),
        NewImage(file: 'c.png'),
      ],
      tagIds: const [],
    );
    v = (await db.watchOshiRecord(id).first)!;
    expect(v.record.date, DateTime(2026, 10, 6));
    expect(v.group!.name, '遊戲截圖');
    expect(v.record.title, isNull);
    expect(v.record.description, '描述');
    expect(v.images.map((i) => i.file), ['b.png', 'c.png']);
    expect(v.tags, isEmpty);

    // 不分組也可以
    await rec(date: DateTime(2026, 10, 7), groupId: null);
    // 沒有圖不行；分組必須是推活分組
    expect(
      () => rec(date: DateTime(2026, 10, 7), files: const []),
      throwsArgumentError,
    );
    final fanGroup = (await db.watchGroups(pitId, kind: 'fan').first).first;
    expect(
      () => rec(date: DateTime(2026, 10, 7), groupId: fanGroup.id),
      throwsArgumentError,
    );
    final other = await db.createPit(name: '坑B');
    expect(
      () => rec(date: DateTime(2026, 10, 7), groupId: groups[0].id, pit: other),
      throwsArgumentError,
    );
    // 失敗的儲存整筆回滾，沒有留下半成品
    expect((await db.watchOshiRecords(pitId).first).length, 2);
  });

  test('watchOshiRecords：日期新到舊（同日建立較晚的在前）、分組與 tag 篩選、軟刪除', () async {
    final t1 = await db.createTag(pitId, '角色1');
    final t2 = await db.createTag(pitId, '角色2');
    final r1 = await rec(
      date: DateTime(2026, 10, 1),
      groupId: groups[2].id,
      tagIds: [t1],
    );
    final r2 = await rec(
      date: DateTime(2026, 10, 8),
      groupId: groups[1].id,
      tagIds: [t1],
    );
    final r3 = await rec(
      date: DateTime(2026, 10, 5),
      groupId: groups[0].id,
      tagIds: [t1, t2],
    );
    final r4 = await rec(date: DateTime(2026, 10, 5)); // 同日、較晚建立、沒分組
    expect((await db.watchOshiRecords(pitId).first).map((v) => v.record.id), [
      r2,
      r4,
      r3,
      r1,
    ]);
    expect(
      (await db.watchOshiRecords(pitId, groupId: groups[0].id).first).map(
        (v) => v.record.id,
      ),
      [r3],
    );
    expect(
      (await db.watchOshiRecords(pitId, tagId: t1).first).map(
        (v) => v.record.id,
      ),
      [r2, r3, r1],
    );
    expect(
      (await db.watchOshiRecords(pitId, tagId: t2).first).map(
        (v) => v.record.id,
      ),
      [r3],
    );
    expect(
      await db.watchOshiRecords(pitId, groupId: groups[1].id, tagId: t2).first,
      isEmpty,
    );
    // 別的坑看不到
    final other = await db.createPit(name: '坑B');
    expect(await db.watchOshiRecords(other).first, isEmpty);

    await db.deleteOshiRecords([r2]);
    expect(await db.getOshiRecord(r2), isNull);
    expect((await db.watchOshiRecords(pitId).first).length, 3);
    // 軟刪除：列還在、有 deletedAt（同步用）
    expect(
      (await (db.select(
        db.oshiRecords,
      )..where((o) => o.id.equals(r2))).getSingle()).deletedAt,
      isNotNull,
    );
  });

  test('筆數：watchOshiCount、PitStats.oshi、分組筆數；推活不計入圖片數與封面', () async {
    expect((await db.watchPitStats(pitId).first).oshi, 0);
    await rec(date: DateTime(2026, 10, 1), groupId: groups[0].id);
    await rec(date: DateTime(2026, 10, 2), groupId: groups[0].id);
    final r3 = await rec(date: DateTime(2026, 10, 3));
    expect(await db.watchOshiCount(pitId).first, 3);
    final stats = await db.watchPitStats(pitId).first;
    expect(stats.oshi, 3);
    expect(stats.imageCount, 0); // 推活的圖不算進坑的圖片數
    expect(stats.pieces + stats.ideas + stats.drafts, 0);
    final counts = await db.watchOshiGroupCounts(pitId).first;
    expect(counts[groups[0].id], 2);
    expect(counts[null], 1);

    // 推活格沒有封面；也不影響其他格封面
    final covers = await db.watchCellCovers(pitId).first;
    expect(covers.piece, isNull);
    expect(covers.draft, isNull);
    expect(covers.idea, isNull);

    // 推活不是封面候選
    expect(await db.watchCoverCandidates(pitId).first, isEmpty);

    await db.deleteOshiRecords([r3]);
    expect(await db.watchOshiCount(pitId).first, 2);
    expect((await db.watchPitStats(pitId).first).oshi, 2);
  });

  test('推活不計入目標與目標時間軸', () async {
    final goalId = await db.saveGoal(
      period: GoalPeriod.year,
      year: 2026,
      kind: GoalKind.draft,
      count: 5,
      pitId: pitId,
      tagIds: const [],
    );
    await rec(date: DateTime(2026, 10, 5));
    final g = (await db.watchGoalViews(GoalPeriod.year, 2026).first).single;
    expect(g.goal.id, goalId);
    expect(g.progress, 0);
    expect(await db.watchTimeline(DateTime(2026, 10, 5)).first, isEmpty);
  });

  test('分組：新增、改名、排序、刪除（紀錄變成沒有分組，可以刪光）', () async {
    await db.addGroup(pitId, '聯動活動', kind: 'oshi');
    var gs = await db.watchGroups(pitId, kind: 'oshi').first;
    expect(gs.map((g) => g.name), ['線下照片', '遊戲截圖', '對話記錄', '聯動活動']);
    await db.renameGroup(gs[3].id, '聯動');
    await db.reorderGroups([gs[3].id, gs[0].id, gs[1].id, gs[2].id]);
    gs = await db.watchGroups(pitId, kind: 'oshi').first;
    expect(gs.map((g) => g.name), ['聯動', '線下照片', '遊戲截圖', '對話記錄']);

    final id = await rec(date: DateTime(2026, 10, 1), groupId: gs[1].id);
    final before = (await db.getOshiRecord(id))!.record.updatedAt;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(await db.deleteGroup(gs[1].id), isTrue);
    final v = (await db.getOshiRecord(id))!;
    expect(v.record.groupId, isNull);
    expect(v.group, isNull);
    expect(v.record.updatedAt.isAfter(before), isTrue); // 紀錄文件要重新同步
    // 刪光也可以（推活分組是選填的）
    for (final g in await db.watchGroups(pitId, kind: 'oshi').first) {
      expect(await db.deleteGroup(g.id), isTrue);
    }
    expect(await db.watchGroups(pitId, kind: 'oshi').first, isEmpty);
    // 官方圖冊／同人圖分組不受影響
    expect((await db.watchGroups(pitId).first).length, 6);
    // 沒有被刪過分組的紀錄之外，刪光後 ensureOshiGroups 不會把預設補回來
    await db.ensureOshiGroups(pitId);
    expect(await db.watchGroups(pitId, kind: 'oshi').first, isEmpty);
  });

  test('ensureOshiGroups：沒有推活分組的坑（例如從舊版同步進來）補預設，且可重複呼叫', () async {
    await db
        .into(db.pits)
        .insert(PitsCompanion.insert(id: const Value('old'), name: '舊坑'));
    expect(await db.watchGroups('old', kind: 'oshi').first, isEmpty);
    await db.ensureOshiGroups('old');
    await db.ensureOshiGroups('old');
    final gs = await db.watchGroups('old', kind: 'oshi').first;
    expect(gs.map((g) => g.name), ['線下照片', '遊戲截圖', '對話記錄']);
    expect(gs.first.id, 'oshi-default-old-0'); // 決定性 id：兩台裝置各補一次也不會重複
  });

  test('tag 次數含推活與官方圖，已刪除的不算；刪除 tag 後紀錄不再顯示它', () async {
    final tag = await db.createTag(pitId, '角色1');
    final r1 = await rec(date: DateTime(2026, 10, 1), tagIds: [tag]);
    await rec(date: DateTime(2026, 10, 2), tagIds: [tag]);
    var usage = (await db.watchTagUsage(pitId).first).single;
    expect(usage.count, 2);
    await db.deleteOshiRecords([r1]);
    usage = (await db.watchTagUsage(pitId).first).single;
    expect(usage.count, 1);

    final og = (await db.watchGroups(pitId).first).first;
    await db.addOfficial(
      pitId,
      og.id,
      const [NewImage(file: 'o.png')],
      tagIds: [tag],
    );
    expect((await db.watchTagUsage(pitId).first).single.count, 2);
    await db.deleteTag(tag);
    final left = (await db.watchOshiRecords(pitId).first).single;
    expect(left.tags, isEmpty);
  });

  test('刪坑：推活紀錄一併軟刪除；推活活動讓坑排到主頁最前', () async {
    await db.createPit(name: '坑B');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    // 之後在坑A 新增推活 → 坑A 排最前
    await rec(date: DateTime(2026, 10, 1));
    expect((await db.watchPits(archived: false).first).first.id, pitId);

    await db.deletePit(pitId);
    expect(await db.watchOshiRecords(pitId).first, isEmpty);
    expect(await db.watchOshiCount(pitId).first, 0);
  });

  test('坑內搜尋：推活段（標題／描述／tag／分組名稱）、順序、計數、可見段', () async {
    final tag = await db.createTag(pitId, '角色1');
    final other = await db.createTag(pitId, '夏日企劃');
    for (var i = 0; i < 5; i++) {
      await rec(
        date: DateTime(2026, 10, 1 + i),
        groupId: groups[0].id,
        title: '展覽 $i',
        tagIds: [tag],
      );
    }
    await rec(
      date: DateTime(2026, 9, 1),
      groupId: groups[1].id,
      title: '抽卡',
      description: '保底出貨',
      tagIds: [other],
    );
    await db.saveIdea(
      pitId: pitId,
      title: '展覽的腦洞',
      body: '',
      images: const [],
      tagIds: [tag],
      draftIds: const [],
      pieceIds: const [],
    );

    var r = await db.watchPitSearch(pitId, tagId: tag).first;
    expect(r.oshi.total, 5);
    expect(r.oshi.items.length, 3);
    expect(r.oshi.more, 2); // 「+N」
    expect(r.oshi.items.first.record.title, '展覽 4'); // 新到舊
    expect(r.ideas.total, 1);
    expect(r.total, 6);
    expect(PitSearchSection.values, [
      PitSearchSection.pieces,
      PitSearchSection.official,
      PitSearchSection.fanArts,
      PitSearchSection.oshi,
      PitSearchSection.drafts,
      PitSearchSection.ideas,
    ]);
    // 0 筆的段不出現
    expect(r.visibleSections, [PitSearchSection.oshi, PitSearchSection.ideas]);
    expect(r.counts[PitSearchSection.pieces], 0);

    // 文字：描述、分組名稱、tag 名稱
    r = await db.watchPitSearch(pitId, text: '保底').first;
    expect(r.oshi.items.single.record.title, '抽卡');
    r = await db.watchPitSearch(pitId, text: '遊戲截圖').first;
    expect(r.oshi.total, 1); // 命中分組名稱
    r = await db.watchPitSearch(pitId, text: '夏日').first;
    expect(r.oshi.total, 1); // 命中 tag 名稱
    r = await db.watchPitSearch(pitId, text: '展覽 角色1').first;
    expect(r.oshi.total, 5);
    expect(r.ideas.total, 1);

    // 少於 3 筆：照實際筆數、沒有 +N
    r = await db.watchPitSearch(pitId, tagId: other).first;
    expect(r.oshi.items.length, 1);
    expect(r.oshi.more, 0);

    // 已刪除的不出現
    await db.deleteOshiRecords([r.oshi.items.single.record.id]);
    r = await db.watchPitSearch(pitId, tagId: other).first;
    expect(r.isEmpty, isTrue);
    expect(r.visibleSections, isEmpty);
  });

  test('「+N」跳轉：watchOshiRecords(tagId) 與搜尋的 tag 條件結果一致', () async {
    final tag = await db.createTag(pitId, '角色1');
    for (var i = 0; i < 4; i++) {
      await rec(date: DateTime(2026, 10, 1 + i), tagIds: [tag]);
    }
    await rec(date: DateTime(2026, 10, 9));
    final search = await db.watchPitSearch(pitId, tagId: tag).first;
    final list = await db.watchOshiRecords(pitId, tagId: tag).first;
    expect(list.length, search.oshi.total);
    expect(
      list.take(3).map((v) => v.record.id),
      search.oshi.items.map((v) => v.record.id),
    );
  });
}
