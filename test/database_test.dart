import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huakeng/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('createPit 建立坑並附上預設分組', () async {
    final id = await db.createPit(name: '測試坑');
    final groups = await (db.select(
      db.officialGroups,
    )..where((g) => g.pitId.equals(id))).get();
    expect(groups.map((g) => g.name), AppDatabase.defaultGroups);
    final pit = await (db.select(
      db.pits,
    )..where((p) => p.id.equals(id))).getSingle();
    expect(pit.coverImageId, isNull); // 新坑預設沒有封面
    expect(pit.archived, isFalse);
    expect(pit.deletedAt, isNull);
  });
}
