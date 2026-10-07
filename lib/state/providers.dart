import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/album_queries.dart';
import '../data/database.dart';
import '../data/entity_queries.dart';
import '../data/goal_queries.dart';
import '../data/image_store.dart';

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

final groupsProvider = StreamProvider.family<List<OfficialGroup>, String>(
  (ref, pitId) => ref.watch(databaseProvider).watchGroups(pitId),
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
      ref.watch(databaseProvider).watchFanArts(key.$1, source: key.$2),
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

final reviewSettingsProvider = StreamProvider.family<ReviewSetting, int>(
  (ref, year) => ref.watch(databaseProvider).watchReviewSettings(year),
);
