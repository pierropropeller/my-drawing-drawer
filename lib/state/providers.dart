import 'dart:io';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/album_queries.dart';
import '../data/batch_tag_queries.dart';
import '../data/database.dart';
import '../data/entity_queries.dart';
import '../data/goal_queries.dart';
import '../data/image_location.dart';
import '../data/image_store.dart';
import '../data/income_queries.dart';
import '../data/junk_queries.dart';
import '../data/material_queries.dart';
import '../data/oshi_queries.dart';
import '../data/timeline_queries.dart';
import '../data/trash_queries.dart';
import '../media/gallery_repository.dart';
import '../media/media_import.dart';
import '../media/photo_manager_gallery.dart';
import '../media/player_frame_poster_generator.dart';
import '../media/video_probe.dart';
import '../ui/common/video_player_view.dart' show playbackFactoryProvider;
import '../ui/media_source/pick_images_for.dart';
import '../ui/picker/image_picker_sheet.dart';
import 'settings.dart' show settingsProvider;

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// 相容舊介面：false＝現坑（不含淺坑）、true＝封存坑。新程式請用 [pitsByStatusProvider]
/// 或（選擇清單用的）[selectablePitsProvider]。
final pitsProvider = StreamProvider.family<List<Pit>, bool>(
  (ref, archived) => ref.watch(databaseProvider).watchPits(archived: archived),
);

/// 主頁三個分頁：現坑／淺坑／封存坑（D-088）。
final pitsByStatusProvider = StreamProvider.family<List<Pit>, PitStatus>(
  (ref, status) => ref.watch(databaseProvider).watchPitsByStatus({status}),
);

/// 選擇清單用的坑（分享匯入、圖片移動、新增目標、日頁新增）：現坑＋淺坑，**不含封存坑**。
final selectablePitsProvider = StreamProvider<List<Pit>>(
  (ref) => ref.watch(databaseProvider).watchSelectablePits(),
);

final pitProvider = StreamProvider.family<Pit?, String>(
  (ref, id) => ref.watch(databaseProvider).watchPit(id),
);

final pitStatsProvider = StreamProvider.family<PitStats, String>(
  (ref, id) => ref.watch(databaseProvider).watchPitStats(id),
);

final imageStoreProvider = FutureProvider<ImageStore>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  final store = ImageStore(Directory(p.join(base.path, 'images')));
  await store.loadThumbIndex(); // 縮圖索引（D-099），列表格子才能同步查有沒有縮圖
  return store;
});

/// 讀手機相簿（D-084 自家圖片選擇器）。測試時換成假的，不需要外掛。
final galleryRepositoryProvider = Provider<GalleryRepository>(
  (ref) => PhotoManagerGallery(),
);

/// 直接開自家相簿選擇器（D-084），不經加圖來源選單。
/// 手機（＜600）的加圖、素材庫本身的加圖都用它；一般表單請用 [imagePickerProvider]。
final photoPickerProvider =
    Provider<Future<List<XFile>> Function(BuildContext context)>(
      (ref) =>
          (context) async =>
              await showAppImagePicker(
                context,
                repository: ref.read(galleryRepositoryProvider),
              ) ??
              const [],
    );

/// 表單／列表的「加圖」（D-080、D-084；iPad MediaMenu）。
/// 手機（視窗 ＜600）＝直接開自家選擇器；視窗 ≥600＝先彈出加圖來源選單
/// （照片／檔案／素材庫／拍照／貼上），見 `pickImagesWith`。
/// 傳入 context 才能開 bottom sheet；使用者關閉（✕、撳外面、返回）回傳空清單。
/// 獨立成 provider 方便測試時替換：`imagePickerProvider.overrideWithValue((_) async => files)`。
/// 選到的檔案請用 `importPickedMedia` 匯入，不要直接 `store.import`。
final imagePickerProvider =
    Provider<Future<List<XFile>> Function(BuildContext context)>(
      (ref) =>
          (context) => pickImagesWith(context, ref.read),
    );

/// 淺坑封面用的選圖：只列圖片、單選（和頭像同一種選擇器）。同樣獨立成 provider 方便測試替換。
final pitCoverPickerProvider =
    Provider<Future<List<XFile>> Function(BuildContext context)>(
      (ref) => ref.watch(avatarPickerProvider),
    );

/// 頭像用的選圖：只列圖片、單選。同樣獨立成 provider 方便測試替換。
final avatarPickerProvider =
    Provider<Future<List<XFile>> Function(BuildContext context)>(
      (ref) =>
          (context) async =>
              await showAppImagePicker(
                context,
                repository: ref.read(galleryRepositoryProvider),
                single: true,
                imagesOnly: true,
              ) ??
              const [],
    );

/// 播放器備援擷取的承載位置；由 App 最上層的 `PosterCaptureScope` 畫出來（見 main.dart）。
final posterCaptureSlotProvider = Provider<PosterCaptureSlot>((ref) {
  final slot = PosterCaptureSlot();
  ref.onDispose(slot.dispose);
  return slot;
});

/// 原生探測取不到截圖時，用播放器的解碼器擷取一格（測試可 override 成假的）。
final posterFrameGeneratorProvider = Provider<PosterFrameGenerator?>(
  (ref) => PlayerFramePosterGenerator(
    slot: ref.watch(posterCaptureSlotProvider),
    playbackFactory: ref.watch(playbackFactoryProvider),
  ),
);

/// 背景補影片截圖（D-080）：啟動時與影片檔寫入後（匯入、同步下載完成）跑，由 App 根 widget 監看。
/// 圖庫還沒準備好時是 null。
final posterFixerProvider = Provider<PosterFixer?>((ref) {
  final store = ref.watch(imageStoreProvider).value;
  if (store == null) return null;
  final fixer = PosterFixer(
    ref.watch(databaseProvider),
    store,
    probe: ref.watch(videoProbeProvider),
    player: ref.watch(posterFrameGeneratorProvider),
  )..start();
  ref.onDispose(fixer.dispose);
  return fixer;
});

/// UI 發現沒有截圖的影片時呼叫（列表格子、詳情頁）：請背景補。限流與重試上限在 [PosterFixer]。
/// 測試可 `overrideWithValue((f) {})` 換掉。
final posterRequestProvider = Provider<void Function(String file)>((ref) {
  return (file) => ref.read(posterFixerProvider)?.request(file);
});

/// 某支影片本次執行期間補好的截圖檔名（沒有＝null）。已經開著的畫面手上的資料可能是補好之前的，
/// 用它即時換上，不必重開。
final healedPosterProvider = StreamProvider.family<String?, String>((
  ref,
  file,
) async* {
  final fixer = ref.watch(posterFixerProvider);
  if (fixer == null) {
    yield null;
    return;
  }
  yield fixer.healed[file];
  await for (final f in fixer.healedStream) {
    if (f == file) yield fixer.healed[file];
  }
});

/// 分組：key＝(坑 id, 種類)，種類為 `official`（官方圖冊）、`fan`（好看同人圖）或 `oshi`（推活）。
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
    // 淺坑自己選的封面檔優先；否則是坑內某張圖。
    final own = pit?.coverFile;
    if (own != null && own.isNotEmpty) return own;
    final id = pit?.coverImageId;
    return id == null ? null : db.imageFileOf(id);
  });
});

final officialProvider =
    StreamProvider.family<List<OfficialImage>, (String, String?)>(
      (ref, key) =>
          ref.watch(databaseProvider).watchOfficial(key.$1, groupId: key.$2),
    );

/// 官方圖冊，可按分組、tag 篩選（D-089）。key＝(坑 id, 分組 id, tag id)。
final officialFilteredProvider =
    StreamProvider.family<List<OfficialImage>, (String, String?, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchOfficial(key.$1, groupId: key.$2, tagId: key.$3),
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

/// 某年每個月的月度小目標進度（D-112，年度回顧月份格的小進度圈）。
final monthGoalProgressProvider =
    StreamProvider.family<Map<int, MonthGoalProgress>, int>(
      (ref, year) => ref.watch(databaseProvider).watchMonthGoalProgress(year),
    );

final monthCoversProvider = StreamProvider.family<Map<int, String>, (int, int)>(
  (ref, k) => ref.watch(databaseProvider).watchMonthCovers(k.$1, k.$2),
);

final timelineProvider = StreamProvider.family<List<TimelineItem>, DateTime>(
  (ref, day) => ref.watch(databaseProvider).watchTimeline(day),
);

/// 連續日頁（D-072）的刷新訊號：腦洞／草稿／成圖（含圖片、tag）有變動就遞增。
/// UI 監看它，變動時重新載入已載入的頁；分頁查詢用 `ref.read(databaseProvider).loadTimelinePage(...)`。
final timelineRevisionProvider = StreamProvider<int>(
  (ref) => ref.watch(databaseProvider).watchTimelineRevision(),
);

/// 素材庫列表（D-071）；key＝分類，null＝全部。
final materialsProvider =
    StreamProvider.family<List<MaterialImage>, MaterialCategory?>(
      (ref, category) =>
          ref.watch(databaseProvider).watchMaterials(category: category),
    );

/// 最近刪除的全部內容（D-120）：Profile 入口的項目數、最近刪除頁。
final trashProvider = StreamProvider<TrashContents>(
  (ref) => ref.watch(databaseProvider).watchTrash(),
);

/// 素材庫各分類張數與總數（Profile 素材庫卡、移動 sheet）。
final materialCountsProvider = StreamProvider<MaterialCounts>(
  (ref) => ref.watch(databaseProvider).watchMaterialCounts(),
);

final reviewMonthsProvider = StreamProvider.family<Map<int, String?>, int>(
  (ref, year) => ref
      .watch(databaseProvider)
      .watchReviewMonths(
        year,
        excludeSensitive: ref.watch(
          settingsProvider.select((s) => s.sensitiveEnabled),
        ),
      ),
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
      (ref, year) => ref
          .watch(databaseProvider)
          .watchReviewMonthSummaries(
            year,
            excludeSensitive: ref.watch(
              settingsProvider.select((s) => s.sensitiveEnabled),
            ),
          ),
    );

final reviewSettingsProvider = StreamProvider.family<ReviewSetting, int>(
  (ref, year) => ref.watch(databaseProvider).watchReviewSettings(year),
);

/// 坑內頁五格各自的封面檔名。
///
/// 敏感內容（D-104）：總開關開著時，已標記敏感的圖不當封面（該坑要開了敏感內容才算）。
final cellCoversProvider = StreamProvider.family<CellCovers, String>(
  (ref, pitId) => ref
      .watch(databaseProvider)
      .watchCellCovers(
        pitId,
        excludeSensitive: ref.watch(
          settingsProvider.select((s) => s.sensitiveEnabled),
        ),
      ),
);

/// 選擇坑封面時，某一格（或整個坑）內可選的圖。key＝(坑 id, 格；null＝全部)。
final coverCandidatesProvider =
    StreamProvider.family<List<CoverCandidate>, (String, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchCoverCandidates(
            key.$1,
            kind: key.$2,
            // 敏感內容（D-104）：選擇封面不列出已標記的圖。
            excludeSensitive: ref.watch(
              settingsProvider.select((s) => s.sensitiveEnabled),
            ),
          ),
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

/// 圖片檔案是否已在本機（同步還沒下載完的封面蓋淡色＋下載 icon，D-028）。
/// 檔案下載完成時會自動更新成 true。
final imageExistsProvider = StreamProvider.family<bool, String>((
  ref,
  file,
) async* {
  final store = await ref.watch(imageStoreProvider.future);
  yield* store.watchExists(file);
});

/// 這張圖的縮圖有變動（到了、被正式縮圖取代）時遞增的版本號（D-099）；
/// UI 監聽它，收到後重新問 `ImageStore.thumbFileFor`。
final thumbVersionProvider = StreamProvider.family<int, String>((
  ref,
  file,
) async* {
  final store = await ref.watch(imageStoreProvider.future);
  yield* store.watchThumb(file);
});

/// 圖片所在的坑與格（同步進度 sheet 顯示「坑 · 格」）；找不到為 null。
final imageLocationProvider = FutureProvider.family<ImageLocation?, String>(
  (ref, file) => ref.watch(databaseProvider).imageLocationOf(file),
);

// ---- 批次 6–8（見 docs/DATA_API.md「批次 6–8」）----

/// 推活紀錄（日期新到舊）。key＝(坑 id, 分組 id?, tag id?)；兩個篩選可並用。
final oshiRecordsProvider =
    StreamProvider.family<List<OshiRecordView>, (String, String?, String?)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchOshiRecords(key.$1, groupId: key.$2, tagId: key.$3),
    );

final oshiRecordProvider = StreamProvider.family<OshiRecordView?, String>(
  (ref, id) => ref.watch(databaseProvider).watchOshiRecord(id),
);

/// 推活每個分組的筆數（key＝分組 id；沒有分組的是 null 這個 key）。
final oshiGroupCountsProvider =
    StreamProvider.family<Map<String?, int>, String>(
      (ref, pitId) => ref.watch(databaseProvider).watchOshiGroupCounts(pitId),
    );

/// 多選後 tag sheet 的三態。key＝(格, 選取的圖片列 id 以逗號串起來)；
/// 串接前請先排序，同一組選取才會共用同一個 provider。
final tagCoverageProvider =
    StreamProvider.family<List<TagCoverageEntry>, (AlbumCell, String)>(
      (ref, key) => ref
          .watch(databaseProvider)
          .watchTagCoverage(
            key.$1,
            key.$2.isEmpty ? const <String>[] : key.$2.split(','),
          ),
    );
