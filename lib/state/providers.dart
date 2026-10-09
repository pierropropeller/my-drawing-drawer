import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/album_queries.dart';
import '../data/database.dart';
import '../data/entity_queries.dart';
import '../data/goal_queries.dart';
import '../data/image_location.dart';
import '../data/image_store.dart';
import '../data/income_queries.dart';
import '../data/junk_queries.dart';
import '../data/search_queries.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// 主頁：現坑（archived=false）／封存坑（archived=true）。
final pitsProvider = StreamProvider.family<List<Pit>, bool>(
  (ref, archived) => ref.watch(databaseProvider).watchPits(archived: archived),
);

final pitProvider = StreamProvider.family<Pit?, String>(
  (ref, id) => ref.watch(databaseProvider).watchPit(id),
);

final pitStatsProvider = StreamProvider.family<PitStats, String>(
  (ref, id) => ref.watch(databaseProvider).watchPitStats(id),
);

final imageStoreProvider = FutureProvider<ImageStore>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  return ImageStore(Directory(p.join(base.path, 'images')));
});

/// 相簿選圖。獨立成 provider 方便測試時替換。
final imagePickerProvider = Provider<Future<List<XFile>> Function()>(
  (ref) =>
      () => ImagePicker().pickMultiImage(),
);

/// 分組：key＝(坑 id, 種類)，種類為 `official`（官方圖冊）或 `fan`（好看同人圖）。
final groupsProvider =
    StreamProvider.family<List<OfficialGroup>, (String, String)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchGroups(key.$1, kind: key.$2),
    );

final tagsProvider = StreamProvider.family<List<Tag>, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchTags(pitId),
);

final tagUsageProvider = StreamProvider.family<List<TagUsage>, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchTagUsage(pitId),
);

final tagIdsProvider = StreamProvider.family<List<String>, (TagTarget, String)>(
  (ref, key) => ref.watch(databaseProvider).watchTagIds(key.$1, key.$2),
);

/// 坑的封面檔名；沒有封面或封面已被刪除時為 null。
final coverFileProvider = StreamProvider.family<String?, String>((ref, pitId) {
  final db = ref.watch(databaseProvider);
  return db.watchPit(pitId).asyncMap((pit) async {
    final id = pit?.coverImageId;
    return id == null ? null : db.imageFileOf(id);
  });
});

final officialProvider =
    StreamProvider.family<List<OfficialImage>, (String, String?)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchOfficial(key.$1, groupId: key.$2),
    );

final fanArtsProvider = StreamProvider.family<List<FanArt>, (String, String?)>(
  (ref, key) =>
      ref.watch(databaseProvider).watchFanArts(key.$1, groupId: key.$2),
);

final ideaViewsProvider =
    StreamProvider.family<List<IdeaView>, (String, String?)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchIdeaViews(key.$1, tagId: key.$2),
    );

final ideaViewProvider = StreamProvider.family<IdeaView?, String>(
  (ref, id) => ref.watch(databaseProvider).watchIdeaView(id),
);

final draftViewsProvider = StreamProvider.family<List<DraftView>, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchDraftViews(pitId),
);

final draftViewProvider = StreamProvider.family<DraftView?, String>(
  (ref, id) => ref.watch(databaseProvider).watchDraftView(id),
);

final pieceViewsProvider =
    StreamProvider.family<List<PieceView>, (String, String?)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchPieceViews(key.$1, tagId: key.$2),
    );

final pieceViewProvider = StreamProvider.family<PieceView?, String>(
  (ref, id) => ref.watch(databaseProvider).watchPieceView(id),
);

final goalViewsProvider =
    StreamProvider.family<List<GoalView>, (GoalPeriod, int, int?)>(
      (ref, k) =>
          ref.watch(databaseProvider).watchGoalViews(k.$1, k.$2, month: k.$3),
    );

final monthCoversProvider = StreamProvider.family<Map<int, String>, (int, int)>(
  (ref, k) => ref.watch(databaseProvider).watchMonthCovers(k.$1, k.$2),
);

final timelineProvider = StreamProvider.family<List<TimelineItem>, DateTime>(
  (ref, day) => ref.watch(databaseProvider).watchTimeline(day),
);

final reviewMonthsProvider = StreamProvider.family<Map<int, String?>, int>(
  (ref, year) => ref.watch(databaseProvider).watchReviewMonths(year),
);

/// 某月所有候選成圖（選擇 N 月的圖片 sheet）。key＝(年, 月)。
final reviewMonthPiecesProvider =
    StreamProvider.family<List<ReviewMonthPiece>, (int, int)>(
      (ref, k) =>
          ref.watch(databaseProvider).watchReviewMonthPieces(k.$1, k.$2),
    );

/// 每月候選數與目前的圖（`canPick`＝多於一張，長按才有反應）。
final reviewMonthSummariesProvider =
    StreamProvider.family<Map<int, ReviewMonthSummary>, int>(
      (ref, year) =>
          ref.watch(databaseProvider).watchReviewMonthSummaries(year),
    );

final reviewSettingsProvider = StreamProvider.family<ReviewSetting, int>(
  (ref, year) => ref.watch(databaseProvider).watchReviewSettings(year),
);

/// 坑內頁五格各自的封面檔名。
final cellCoversProvider = StreamProvider.family<CellCovers, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchCellCovers(pitId),
);

/// 選擇坑封面時，某一格（或整個坑）內可選的圖。key＝(坑 id, 格；null＝全部)。
final coverCandidatesProvider =
    StreamProvider.family<List<CoverCandidate>, (String, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchCoverCandidates(key.$1, kind: key.$2),
    );

/// 常用的 tag 在前（坑內搜尋的常用 tag、tag 篩選）。
final tagUsageByUsageProvider = StreamProvider.family<List<TagUsage>, String>(
  (ref, pitId) =>
      ref.watch(databaseProvider).watchTagUsage(pitId, byUsage: true),
);

/// 好看同人圖，可同時按分組（出處）與 tag 篩選。key＝(坑 id, 分組 id, tag id)。
final fanArtsFilteredProvider =
    StreamProvider.family<List<FanArt>, (String, String?, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchFanArts(key.$1, groupId: key.$2, tagId: key.$3),
    );

/// 草稿，可按 tag 篩選。key＝(坑 id, tag id)。
final draftViewsFilteredProvider =
    StreamProvider.family<List<DraftView>, (String, String?)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchDraftViews(key.$1, tagId: key.$2),
    );

/// 雜物（D-034）。
final junkProvider = StreamProvider.family<List<JunkImage>, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchJunk(pitId),
);

/// 年度商稿收入（D-047）。
final incomeProvider = StreamProvider.family<IncomeYear, int>(
  (ref, year) => ref.watch(databaseProvider).watchIncome(year),
);

/// 坑內搜尋。key＝(坑 id, 文字, tag id)。
final pitSearchProvider =
    StreamProvider.family<PitSearchResult, (String, String, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchPitSearch(key.$1, text: key.$2, tagId: key.$3),
    );

/// 圖片檔案是否已在本機（同步還沒下載完的封面蓋淡色＋下載 icon，D-028）。
/// 檔案下載完成時會自動更新成 true。
final imageExistsProvider = StreamProvider.family<bool, String>((
  ref,
  file,
) async* {
  final store = await ref.watch(imageStoreProvider.future);
  yield* store.watchExists(file);
});

/// 圖片所在的坑與格（同步進度 sheet 顯示「坑 · 格」）；找不到為 null。
final imageLocationProvider = FutureProvider.family<ImageLocation?, String>(
  (ref, file) => ref.watch(databaseProvider).imageLocationOf(file),
);
