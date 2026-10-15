import 'dart:async';

import 'package:image_picker/image_picker.dart';

import '../data/album_queries.dart' show NewImage;
import '../data/database.dart';
import '../data/image_store.dart';
import '../data/media.dart';
import '../data/media_queries.dart';
import 'video_probe.dart';

/// 匯入一個從相簿／分享選到的媒體（D-080）：圖片、GIF、影片都走這一條。
///
/// - 種類由 [ImageStore.import] 判斷（內容優先、副檔名其次）；原檔照搬不轉檔。
/// - 圖片與 GIF：寬高由 [ImageStore.import] 讀出（GIF 取第一格）。
/// - 影片：用 [probe]（預設走原生 channel）取寬高、長度與第一格截圖，截圖存成獨立的 JPEG；
///   探測失敗不丟例外，影片照樣存，只是沒有 `posterFile`，之後由 [generateMissingPosters] 補。
///
/// 所有「選圖／分享進來 → 寫進資料庫」的地方都該用這個，不要直接呼叫 `store.import`。
Future<NewImage> importPickedMedia(
  ImageStore store,
  XFile f, {
  VideoProbe probe = const ChannelVideoProbe(),
}) async {
  final imported = await store.import(f);
  if (!imported.kind.isVideo) return imported;
  return _withVideoMeta(store, imported, probe);
}

Future<NewImage> _withVideoMeta(
  ImageStore store,
  NewImage imported,
  VideoProbe probe,
) async {
  VideoMeta? meta;
  try {
    meta = await probe.probe(store.fileOf(imported.file).path);
  } catch (_) {
    meta = null;
  }
  if (meta == null) return imported;
  String? poster;
  if (meta.hasPoster) {
    try {
      poster = await store.savePoster(meta.poster!);
    } catch (_) {
      poster = null;
    }
  }
  return imported.copyWith(
    width: meta.width > 0 ? meta.width : imported.width,
    height: meta.height > 0 ? meta.height : imported.height,
    durationMs: meta.durationMs,
    posterFile: poster,
  );
}

/// 找出還沒有截圖的影片（例如另一台裝置匯入、同步下載後本機還沒有截圖），在本機補產生。
///
/// - 只處理檔案已在本機的影片；還沒下載完的下次再處理（啟動時與同步下載完成後都會呼叫）。
/// - 探測失敗的影片略過，不會反覆卡住（下次啟動再試）。
/// - 回傳成功補上截圖的張數。可重複呼叫、同時只會有一份在跑。
Future<int> generateMissingPosters(
  AppDatabase db,
  ImageStore store, {
  VideoProbe probe = const ChannelVideoProbe(),
}) async {
  final pending = await db.videosWithoutPoster();
  var done = 0;
  for (final file in pending) {
    if (!store.exists(file)) continue;
    try {
      final meta = await probe.probe(store.fileOf(file).path);
      if (meta == null || !meta.hasPoster) continue;
      final poster = await store.savePoster(meta.poster!);
      await db.setMediaMeta(
        file,
        width: meta.width > 0 ? meta.width : null,
        height: meta.height > 0 ? meta.height : null,
        durationMs: meta.durationMs,
        posterFile: poster,
      );
      done++;
    } catch (_) {
      // 單支影片失敗不影響其他。
    }
  }
  return done;
}

/// 背景補截圖：啟動時跑一次，之後只要有影片檔寫進 [ImageStore]（匯入或同步下載完成）就排一次。
///
/// 合併多次觸發（debounce），並避免同時跑兩份。測試可傳入假的 [probe]。
class PosterFixer {
  PosterFixer(
    this.db,
    this.store, {
    this.probe = const ChannelVideoProbe(),
    this.debounce = const Duration(seconds: 2),
  });

  final AppDatabase db;
  final ImageStore store;
  final VideoProbe probe;
  final Duration debounce;

  StreamSubscription<String>? _sub;
  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// 開始監聽並立刻補一次。
  void start() {
    _sub ??= store.changes.listen((name) {
      if (mediaKindFromExtension(name) != MediaKind.video) return;
      _schedule();
    });
    unawaited(run());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(run()));
  }

  /// 跑一次補截圖；正在跑時只記錄「跑完再來一次」。
  Future<int> run() async {
    if (_disposed) return 0;
    if (_running) {
      _again = true;
      return 0;
    }
    _running = true;
    var total = 0;
    try {
      do {
        _again = false;
        total += await generateMissingPosters(db, store, probe: probe);
      } while (_again && !_disposed);
    } catch (_) {
      // 補不到就算了，下次再試。
    } finally {
      _running = false;
    }
    return total;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
  }
}
