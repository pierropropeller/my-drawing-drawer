import 'dart:async';

import 'package:image_picker/image_picker.dart';

import '../data/album_queries.dart' show NewImage;
import '../data/database.dart';
import '../data/image_store.dart';
import '../data/media.dart';
import '../data/media_queries.dart';
import 'player_frame_poster_generator.dart';
import 'video_playback_gate.dart';
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
///
/// - [shouldTry]：回傳 false 的檔案這次略過（呼叫端用來做失敗後的冷卻）。
/// - [onResult]：每支嘗試過的影片回報一次（成功時帶 poster 檔名，失敗帶 null）。
/// - [player]：原生探測取不到截圖（或整支讀不開）時的備援，用播放器解碼器擷取一格
///   （見 [PlayerFramePosterGenerator]）。[shouldTryPlayer] 回傳 false 的檔案略過備援；
///   真的去試了（`player.available`）會呼叫 [onPlayerTried]。
/// - [paused]：回傳 true（使用者正在播放影片）就在下一支之前停下來，等閘門放開再補。
Future<int> generateMissingPosters(
  AppDatabase db,
  ImageStore store, {
  VideoProbe probe = const ChannelVideoProbe(),
  bool Function(String file)? shouldTry,
  void Function(String file, String? poster)? onResult,
  PosterFrameGenerator? player,
  bool Function(String file)? shouldTryPlayer,
  void Function(String file)? onPlayerTried,
  bool Function()? paused,
}) async {
  try {
    await db.repairVideoKinds();
  } catch (_) {
    // 修不了不影響其他。
  }
  final pending = await db.videosWithoutPoster();
  var done = 0;
  for (final file in pending) {
    if (paused != null && paused()) break;
    if (!store.exists(file)) continue;
    if (shouldTry != null && !shouldTry(file)) continue;
    try {
      final path = store.fileOf(file).path;
      final meta = await probe.probe(path);
      if (meta != null && meta.hasPoster) {
        final poster = await store.savePoster(meta.poster!);
        await db.setMediaMeta(
          file,
          width: meta.width > 0 ? meta.width : null,
          height: meta.height > 0 ? meta.height : null,
          durationMs: meta.durationMs,
          posterFile: poster,
        );
        done++;
        onResult?.call(file, poster);
        continue;
      }
      // 原生取不到截圖：改用播放器的解碼器擷取（每支影片每次執行只試一次，由呼叫端控制）。
      PosterFrame? frame;
      if (player != null &&
          (shouldTryPlayer == null || shouldTryPlayer(file)) &&
          player.available) {
        onPlayerTried?.call(file);
        try {
          frame = await player.generate(
            path,
            width: meta?.width,
            height: meta?.height,
          );
        } catch (_) {
          frame = null;
        }
      }
      if (frame != null) {
        final poster = await store.savePoster(frame.bytes, ext: frame.ext);
        final hasSize = (meta?.width ?? 0) > 0 && (meta?.height ?? 0) > 0;
        await db.setMediaMeta(
          file,
          // 原生沒讀到寬高時用截圖的（比例正確）。
          width: hasSize ? meta!.width : frame.width,
          height: hasSize ? meta!.height : frame.height,
          durationMs: meta?.durationMs ?? frame.durationMs,
          posterFile: poster,
        );
        done++;
        onResult?.call(file, poster);
        continue;
      }
      if (meta != null) {
        // 截圖失敗也先把寬高與長度寫回（避免只剩光禿禿的 ▶），截圖之後再試。
        await db.setMediaMeta(
          file,
          width: meta.width > 0 ? meta.width : null,
          height: meta.height > 0 ? meta.height : null,
          durationMs: meta.durationMs,
        );
      }
      onResult?.call(file, null);
    } catch (_) {
      // 單支影片失敗不影響其他。
      onResult?.call(file, null);
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
    this.player,
    this.debounce = const Duration(seconds: 2),
    this.requestDebounce = const Duration(milliseconds: 300),
    this.retryAfter = const Duration(seconds: 20),
    this.maxAttempts = 3,
    VideoPlaybackGate? gate,
  }) : gate = gate ?? videoPlaybackGate;

  final AppDatabase db;
  final ImageStore store;
  final VideoProbe probe;

  /// 原生探測失敗時的備援（用播放器解碼器擷取一格）；null＝不用。
  final PosterFrameGenerator? player;
  final Duration debounce;

  /// UI 發現某支影片沒有截圖（[request]）後，等多久才跑（合併同時出現的一整頁）。
  final Duration requestDebounce;

  /// 同一支影片失敗後多久才准再試、最多試幾次（避免壞檔一直卡著 CPU）。
  final Duration retryAfter;
  final int maxAttempts;

  /// 使用者正在播放影片時不跑（原生探測與播放器備援都會搶解碼器）；放開後補做。
  final VideoPlaybackGate gate;

  // 這次執行期間已經用播放器備援試過的影片（每支只試一次，成敗都算）。
  final _playerTried = <String>{};
  final _attempts = <String, int>{};
  final _lastTry = <String, DateTime>{};
  final _healed = <String, String>{};
  final _healedCtl = StreamController<String>.broadcast();

  /// 這次執行期間補好的截圖（影片檔名 → poster 檔名）。
  /// 已經開著的畫面手上可能還是舊的（沒有 poster）資料，靠它即時換上。
  Map<String, String> get healed => Map.unmodifiable(_healed);

  /// 補好一支影片的截圖時送出該影片的檔名。
  Stream<String> get healedStream => _healedCtl.stream;

  bool _mayTry(String file) {
    final n = _attempts[file] ?? 0;
    // 原生次數用完了，但播放器備援還沒輪到（例如當時 App 在背景）：還是准許再來一次。
    final playerPending = player != null && !_playerTried.contains(file);
    if (n >= maxAttempts && !playerPending) return false;
    final last = _lastTry[file];
    if (last != null && DateTime.now().difference(last) < retryAfter) {
      return false;
    }
    return true;
  }

  void _onResult(String file, String? poster) {
    if (poster == null && gate.active) {
      // 被播放中斷的不算失敗：不計次數、不佔備援名額，放開後再試。
      _playerTried.remove(file);
      return;
    }
    _lastTry[file] = DateTime.now();
    if (poster == null) {
      // 播放器備援也失敗＝這支影片這次執行不會再有辦法，不要再反覆跑原生探測。
      _attempts[file] = _playerTried.contains(file)
          ? maxAttempts
          : (_attempts[file] ?? 0) + 1;
      return;
    }
    _attempts.remove(file);
    _healed[file] = poster;
    if (!_healedCtl.isClosed) _healedCtl.add(file);
  }

  /// 畫面上出現了沒有截圖的影片：排一次補截圖（合併、限流；失敗的有冷卻與次數上限）。
  void request(String file) {
    if (_disposed || _healed.containsKey(file) || !_mayTry(file)) return;
    if (gate.active) return; // 播放中：放開後 _onGate 會整批補。
    _timer?.cancel();
    _timer = Timer(requestDebounce, () => unawaited(run()));
  }

  StreamSubscription<String>? _sub;
  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// 開始監聽並立刻補一次。
  void start() {
    player?.availabilityChanges?.addListener(_onPlayerAvailable);
    gate.addListener(_onGate);
    _sub ??= store.changes.listen((name) {
      if (mediaKindFromExtension(name) != MediaKind.video) return;
      _schedule();
    });
    unawaited(run());
  }

  void _onGate() {
    if (_disposed || gate.active) return;
    _schedule();
  }

  // 播放器備援剛變成可用（承載容器掛上）：補做先前因為不能擷取而略過的影片。
  void _onPlayerAvailable() {
    if (_disposed || !(player?.available ?? false)) return;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(run()));
  }

  /// 跑一次補截圖；正在跑時只記錄「跑完再來一次」。
  Future<int> run() async {
    if (_disposed || gate.active) return 0;
    if (_running) {
      _again = true;
      return 0;
    }
    _running = true;
    var total = 0;
    try {
      do {
        _again = false;
        total += await generateMissingPosters(
          db,
          store,
          probe: probe,
          shouldTry: _mayTry,
          onResult: _onResult,
          player: player,
          shouldTryPlayer: (f) => !_playerTried.contains(f),
          onPlayerTried: _playerTried.add,
          paused: () => gate.active,
        );
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
    player?.availabilityChanges?.removeListener(_onPlayerAvailable);
    gate.removeListener(_onGate);
    _timer?.cancel();
    _sub?.cancel();
    _healedCtl.close();
  }
}
