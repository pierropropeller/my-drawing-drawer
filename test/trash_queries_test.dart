import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';
import 'package:huakeng/data/junk_queries.dart';
import 'package:huakeng/data/trash_queries.dart';

/// D-120 最近刪除：列出、還原（含重開格子）、永久刪除、坑整個還原。
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  NewImage img(String f) => NewImage(file: f, width: 10, height: 10);

  test('刪除的腦洞、雜物出現在最近刪除；還原後回到原處，淺坑關掉的格子自動重開', () async {
    final pit = await db.createPit(
      name: '坑A',
      status: PitStatus.shallow,
      enabledSections: {PitSectionKey.idea, PitSectionKey.junk},
      junkEnabled: true,
    );
    final ideaId = await db.saveIdea(
      pitId: pit,
      title: '天台看煙花',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.addJunk(pit, [img('j.png')]);
    final junk = (await db.select(db.junkImages).get()).single;
    await db.deleteIdeas([ideaId]);
    await db.deleteJunk([junk.id]);

    var t = await db.loadTrash();
    expect(t.pits, isEmpty);
    expect(t.items.map((e) => e.kind).toSet(), {
      TrashKind.idea,
      TrashKind.junk,
    });
    expect(trashDaysLeft(t.items.first.deletedAt), 30);

    // 期間格子被關掉。
    await (db.update(db.pits)..where((p) => p.id.equals(pit))).write(
      const PitsCompanion(
        enabledSections: Value({}),
        junkEnabled: Value(false),
      ),
    );
    await db.restoreItems(t.items);
    t = await db.loadTrash();
    expect(t.isEmpty, isTrue);
    final p = await (db.select(
      db.pits,
    )..where((x) => x.id.equals(pit))).getSingle();
    expect(p.enabledSections, {PitSectionKey.idea, PitSectionKey.junk});
    expect(p.junkEnabled, isTrue);
    final idea = await (db.select(
      db.ideas,
    )..where((x) => x.id.equals(ideaId))).getSingle();
    expect(idea.deletedAt, isNull);
  });

  test('刪除坑：坑卡顯示項目數，坑內內容不另外列；還原坑連同一起刪的雜物', () async {
    final pit = await db.createPit(name: '坑C', junkEnabled: true);
    await db.addJunk(pit, [img('a.png'), img('b.png')]);
    await db.saveIdea(
      pitId: pit,
      title: 'x',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.deletePit(pit);
    var t = await db.loadTrash();
    expect(t.items, isEmpty);
    expect(t.pits.single.name, '坑C');
    expect(t.pits.single.itemCount, 3);
    await db.restorePit(pit);
    t = await db.loadTrash();
    expect(t.isEmpty, isTrue);
    final junk = await db.select(db.junkImages).get();
    expect(junk.every((j) => j.deletedAt == null), isTrue);
  });

  test('永久刪除：從最近刪除消失、坑內內容一併標記；超過 30 天的不列出', () async {
    final pit = await db.createPit(name: '坑', junkEnabled: true);
    await db.addJunk(pit, [img('a.png')]);
    final pit2 = await db.createPit(name: '坑2');
    await db.saveIdea(
      pitId: pit2,
      title: 'y',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    final junk = (await db.select(db.junkImages).get()).single;
    await db.deleteJunk([junk.id]);
    await db.deletePit(pit2);
    var t = await db.loadTrash();
    expect(t.count, 2);
    await db.purgeTrash(items: t.items, pitIds: t.pits.map((p) => p.id));
    t = await db.loadTrash();
    expect(t.isEmpty, isTrue);
    final idea = (await db.select(db.ideas).get()).single;
    expect(idea.deletedAt!.isAtSameMomentAs(kTrashPurgedAt), isTrue);

    final later = DateTime.now().add(const Duration(days: 31));
    await db.addJunk(pit, [img('c.png')]);
    final c = (await (db.select(
      db.junkImages,
    )..where((j) => j.imageFile.equals('c.png'))).getSingle());
    await db.deleteJunk([c.id]);
    expect((await db.loadTrash()).count, 1);
    expect((await db.loadTrash(now: later)).count, 0);
  });

  test('清理過期：超過 30 天的標成永久刪除，沒過期的留著；跑兩次不再動', () async {
    final pit = await db.createPit(name: '坑A');
    final old = await db.saveIdea(
      pitId: pit,
      title: '舊的',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    final fresh = await db.saveIdea(
      pitId: pit,
      title: '新的',
      body: '',
      images: const [],
      tagIds: const [],
      draftIds: const [],
      pieceIds: const [],
    );
    await db.deleteIdeas([old, fresh]);
    final longAgo = DateTime.now().subtract(const Duration(days: 31));
    await (db.update(db.ideas)..where((x) => x.id.equals(old))).write(
      IdeasCompanion(deletedAt: Value(longAgo)),
    );
    expect(await db.purgeExpiredTrash(), 1);
    final rows = {
      for (final r in await db.select(db.ideas).get()) r.id: r.deletedAt,
    };
    expect(rows[old]!.isAtSameMomentAs(kTrashPurgedAt), isTrue);
    expect(rows[fresh]!.isAtSameMomentAs(kTrashPurgedAt), isFalse);
    expect(await db.purgeExpiredTrash(), 0);
    final t = await db.loadTrash();
    expect(t.items.map((e) => e.id), [fresh]);
  });
}
