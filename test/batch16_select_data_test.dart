import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/album_queries.dart';
import 'package:huakeng/data/batch_tag_queries.dart';
import 'package:huakeng/data/database.dart';
import 'package:huakeng/data/entity_queries.dart';

/// 批次 16 資料層：摸魚、成圖多選的批量 tag（D-095，TagTarget.draft／piece）。
void main() {
  late AppDatabase db;
  late String pitId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    pitId = await db.createPit(name: '坑A');
  });
  tearDown(() => db.close());

  Future<String> draft(String title, {String? pit}) => db.saveDraft(
    pitId: pit ?? pitId,
    title: title,
    images: [NewImage(file: '$title.png')],
    tagIds: const [],
    ideaIds: const [],
  );

  Future<String> piece(String title, {String? pit}) => db.savePiece(
    pitId: pit ?? pitId,
    title: title,
    body: '',
    images: [NewImage(file: '$title.png')],
    tagIds: const [],
    links: const [],
    targetLikes: 0,
    finishedAt: DateTime(2026, 10, 1),
    ideaIds: const [],
    draftIds: const [],
  );

  Future<Set<String>> tagIdsOf(TagTarget target, String id) async =>
      (await db.watchTagIds(target, id).first).toSet();

  Future<DateTime> updatedAtOf(TagTarget target, String id) async {
    if (target == TagTarget.draft) {
      return (await (db.select(
        db.drafts,
      )..where((d) => d.id.equals(id))).getSingle()).updatedAt;
    }
    return (await (db.select(
      db.pieces,
    )..where((d) => d.id.equals(id))).getSingle()).updatedAt;
  }

  for (final target in [TagTarget.draft, TagTarget.piece]) {
    group('批次 tag（${target.name}）', () {
      Future<String> make(String title, {String? pit}) =>
          target == TagTarget.draft
          ? draft(title, pit: pit)
          : piece(title, pit: pit);

      test('覆蓋狀態、加、移除、新建', () async {
        final t1 = await db.createTag(pitId, 'A');
        final t2 = await db.createTag(pitId, 'B');
        final a = await make('a');
        final b = await make('b');
        await db.setTags(target, a, [t1]);

        var cov = await db.tagCoverageFor(target, [a, b]);
        expect(
          {for (final e in cov) e.tag.name: e.coverage},
          {'A': TagCoverage.some, 'B': TagCoverage.none},
        );

        final created = await db.applyBatchTagsFor(
          target,
          [a, b],
          addTagIds: [t1, t2],
          newTagNames: ['#新'],
        );
        expect(created, hasLength(1));
        cov = await db.tagCoverageFor(target, [a, b]);
        expect(cov, hasLength(3));
        expect(cov.every((e) => e.coverage == TagCoverage.all), isTrue);
        expect(await tagIdsOf(target, b), {t1, t2, created.single});

        await db.applyBatchTagsFor(target, [a, b], removeTagIds: [t2]);
        expect(await tagIdsOf(target, a), {t1, created.single});
        expect(await tagIdsOf(target, b), {t1, created.single});
      });

      test('有變動才更新 updatedAt（tag 隨文件同步）', () async {
        final t1 = await db.createTag(pitId, 'A');
        final a = await make('a');
        final b = await make('b');
        await db.setTags(target, a, [t1]);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        final beforeA = await updatedAtOf(target, a);
        final beforeB = await updatedAtOf(target, b);
        await db.applyBatchTagsFor(target, [a, b], addTagIds: [t1]);
        // a 本來就有 t1 → 沒變；b 新加 → 更新
        expect(await updatedAtOf(target, a), beforeA);
        expect((await updatedAtOf(target, b)).isAfter(beforeB), isTrue);
      });

      test('別坑的 tag、混坑選取丟錯；已刪除的不算選取', () async {
        final t1 = await db.createTag(pitId, 'A');
        final a = await make('a');
        final other = await db.createPit(name: '坑B');
        final foreign = await db.createTag(other, 'x');
        await expectLater(
          db.applyBatchTagsFor(target, [a], addTagIds: [foreign]),
          throwsArgumentError,
        );
        final o = await make('o', pit: other);
        await expectLater(
          db.applyBatchTagsFor(target, [a, o], addTagIds: [t1]),
          throwsArgumentError,
        );
        final b = await make('b');
        if (target == TagTarget.draft) {
          await db.deleteDrafts([b]);
        } else {
          await db.deletePieces([b]);
        }
        final cov = await db.tagCoverageFor(target, [a, b]);
        expect(cov.firstWhere((e) => e.tag.name == 'A').total, 1);
      });

      test('watchTagCoverageFor：套用後即時更新', () async {
        final t1 = await db.createTag(pitId, 'A');
        final a = await make('a');
        final seen = <TagCoverage>[];
        final sub = db
            .watchTagCoverageFor(target, [a])
            .listen((v) => seen.add(v.single.coverage));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await db.applyBatchTagsFor(target, [a], addTagIds: [t1]);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await sub.cancel();
        expect(seen.first, TagCoverage.none);
        expect(seen.last, TagCoverage.all);
      });
    });
  }
}
