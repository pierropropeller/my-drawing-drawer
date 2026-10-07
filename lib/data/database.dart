import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart' show GoalKind, GoalPeriod, OwnerType, TagTarget;

part 'database.g.dart';

@DriftDatabase(tables: [
  Pits,
  OfficialGroups,
  OfficialImages,
  FanArts,
  Tags,
  Ideas,
  Drafts,
  Pieces,
  EntityImages,
  PieceLinks,
  TagLinks,
  IdeaDrafts,
  IdeaPieces,
  DraftPieces,
  Goals,
  YearReviewMonths,
  ReviewSettings,
  Outbox,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'huakeng'));

  @override
  int get schemaVersion => 1;

  /// 官方圖預設分組（HANDOFF 3.2）。
  static const defaultGroups = ['設定圖', '海報宣傳', '素材', '自用截圖', '自定義'];

  /// 新增坑並建立預設官方圖分組。
  Future<String> createPit({required String name, String? description}) {
    return transaction(() async {
      final pit = await into(pits).insertReturning(
        PitsCompanion.insert(name: name, description: Value(description)),
      );
      for (var i = 0; i < defaultGroups.length; i++) {
        await into(officialGroups).insert(OfficialGroupsCompanion.insert(
          pitId: pit.id,
          name: defaultGroups[i],
          sortOrder: Value(i),
        ));
      }
      return pit.id;
    });
  }
}
