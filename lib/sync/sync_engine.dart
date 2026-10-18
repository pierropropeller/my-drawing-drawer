import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/image_store.dart';
import 'remote.dart';
import 'sync_kinds.dart';
import 'sync_log.dart';
import 'sync_transfer.dart';
import '../l10n/l10n.dart';

/// 目前這版 App 寫出／能讀的同步格式版本。
/// 之後若出現不相容的改動就把它加一；舊版 App 讀到較高的版本會停下來，不會弄壞資料。
/// 1＝初版（文件只有 `v: 1`）；2＝加入雜物、移動、商稿欄位、`formatVersion`。
const syncFormatVersion = 2;

/// 遠端備份的格式比這版 App 新：必須先更新 App。
class SyncFormatException extends SyncAuthException {
  SyncFormatException() : super(l10nStatic.syncNeedsAppUpdate);
}

/// 讓呼叫端（看門狗）中止一次同步：引擎在每個步驟之間檢查，被中止就丟 [SyncStalledException]。
class SyncCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw SyncStalledException();
  }
}

/// 拉取文件時一次並行下載幾份（Drive 對單一使用者的請求頻率有限，不宜太高）。
const syncPullConcurrency = 8;

/// 連續這麼多張圖片下載失敗就放棄整次同步（多半是網絡或授權問題，不要把每張都等到逾時）。
const syncImageFailureLimit = 5;

/// 同步目前進行到哪個階段。
enum SyncStage { pulling, downloadingImages, uploading }

/// 同步進度。
/// [imagesTotal] 在 [SyncStage.pulling] 為 0；進入下載／上傳階段後才知道數量（舊版橫條用，
/// D-052 起 UI 改看 [transfers]）。
class SyncProgress {
  const SyncProgress(
    this.stage,
    this.imagesDone,
    this.imagesTotal, {
    this.transfers = const [],
    this.transfersPlanned = false,
    this.docsDone = 0,
    this.docsTotal = 0,
  });
  final SyncStage stage;

  /// 拉取階段：要下載的雲端文件（meta）份數與已處理份數；[docsTotal] 為 0＝還在列出雲端內容
  /// （或沒有東西要拉）。
  final int docsDone;
  final int docsTotal;
  final int imagesDone;
  final int imagesTotal;

  /// 這次同步所有要傳的圖片（先下載後上傳，依實際處理順序），每張的狀態與進度。
  /// 每次回報都是新的不可變快照。
  final List<SyncTransfer> transfers;

  /// 傳輸清單是否已確定。false＝還在拉取／比對遠端（「檢查中」）；
  /// true 且 [transfers] 為空＝檢查完沒有東西要傳。
  final bool transfersPlanned;

  @override
  String toString() => '$stage $imagesDone/$imagesTotal';
}

typedef SyncProgressListener = void Function(SyncProgress progress);

class SyncResult {
  int pushed = 0;
  int pulled = 0;
  int imagesUp = 0;
  int imagesDown = 0;

  /// 雲端文件讀不了（損壞、欄位不符）而略過的檔名；其餘照常同步。
  final List<String> skippedDocs = [];

  /// 下載失敗（已略過、下次再試）的圖片張數。
  int imageFailures = 0;

  bool get changed => pushed + pulled + imagesUp + imagesDown > 0;
  @override
  String toString() =>
      l10nStatic.syncResultSummary(pushed, pulled, imagesUp, imagesDown);
}

String _metaName(String kind, String id) => 'meta__${kind}__$id.json';
String _imageName(String file) => 'images__$file';

/// 遠端的格式版本標記（不屬於任何實體種類，舊版 App 會直接忽略）。
const _formatFile = 'meta__app__format.json';

class _Pending {
  _Pending(this.kind, this.id, this.version, this.data);
  final SyncKind kind;
  final String id;
  final int version;
  final Map<String, dynamic> data;
}

class _PullJob {
  _PullJob(this.kind, this.id, this.file);
  final SyncKind kind;
  final String id;
  final RemoteFile file;
}

class _PushPlan {
  _PushPlan(this.pending, this.uploads);
  final List<_Pending> pending;
  final List<String> uploads;
}

/// 維護逐張傳輸清單，並把快照（含節流）送給 UI。
class _Tracker {
  _Tracker(this.interval, this.listener);
  final Duration interval;
  final SyncProgressListener? listener;

  var _stage = SyncStage.pulling;
  var _done = 0;
  var _total = 0;
  var _planned = false;
  var _items = <SyncTransfer>[];
  var _docsDone = 0;
  var _docsTotal = 0;
  final _uploadIdx = <String, int>{};
  final _clock = Stopwatch()..start();
  int? _lastMs;

  void plan(List<String> downloads, List<String> uploads) {
    _items = [
      for (final f in downloads)
        SyncTransfer(file: f, direction: TransferDirection.download),
      for (final f in uploads)
        SyncTransfer(file: f, direction: TransferDirection.upload),
    ];
    for (var i = 0; i < uploads.length; i++) {
      _uploadIdx[uploads[i]] = downloads.length + i;
    }
    _planned = true; // 緊接著的 report 會送出
  }

  int? uploadIndex(String file) => _uploadIdx[file];

  void report(SyncStage s, int done, int total) {
    _stage = s;
    _done = done;
    _total = total;
    _emit(force: true);
  }

  void pull(int done, int total) {
    _stage = SyncStage.pulling;
    _docsDone = done;
    _docsTotal = total;
    _emit(force: done == 0 || done >= total);
  }

  void start(int i) {
    _items[i] = _items[i].copyWith(state: TransferState.active);
    _emit(); // 節流：緊接著會有進度或完成的通知
  }

  void progress(int i, int done, int? total) {
    final p = (total == null || total <= 0)
        ? null
        : (done / total).clamp(0.0, 1.0);
    final prev = _items[i].progress ?? 0;
    if (p == null || p < prev) return;
    _items[i] = _items[i].copyWith(state: TransferState.active, progress: p);
    _emit();
  }

  void finish(int i) {
    _items[i] = _items[i].copyWith(state: TransferState.done, progress: 1);
    // 完成後一定會接著 report（強制送出）。
  }

  void _emit({bool force = false}) {
    final l = listener;
    if (l == null) return;
    final now = _clock.elapsedMilliseconds;
    if (!force && _lastMs != null && now - _lastMs! < interval.inMilliseconds) {
      return;
    }
    _lastMs = now;
    l(
      SyncProgress(
        _stage,
        _done,
        _total,
        transfers: List.unmodifiable(_items),
        transfersPlanned: _planned,
        docsDone: _docsDone,
        docsTotal: _docsTotal,
      ),
    );
  }
}

/// 離線優先同步：本機永遠先寫入；有網絡時把「比遠端新」的實體上傳，
/// 並拉取遠端較新的實體（以實體為單位，updatedAt 較新者勝，last-write-wins）。
/// 圖片先傳、文件後傳；刪除是軟刪除，同樣以文件同步。
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.images,
    this.kinds = allSyncKinds,
    this.progressInterval = const Duration(milliseconds: 100),
  });

  final AppDatabase db;
  final SyncRemote remote;
  final ImageStore images;
  final List<SyncKind> kinds;

  /// 逐位元組的進度（傳輸中的百分比）最多這麼久通知一次（預設 100ms＝每秒 10 次），
  /// 避免畫面一直重繪；每張圖完成、階段切換則一定通知。測試可設 [Duration.zero] 取得全部。
  final Duration progressInterval;

  static String _key(String kind, String id) => '$kind|$id';

  /// [onProgress]：階段、圖片進度與逐張傳輸狀態的回報（在 UI 執行緒呼叫，不要做耗時工作）。
  ///
  /// 順序：拉取文件 → 規劃傳輸清單（下載＋上傳，此後 [SyncProgress.transfersPlanned] 為 true）
  /// → 逐張下載 → 逐張上傳。傳輸是一張接一張（不併行），所以同時最多一張 active。
  Future<SyncResult> sync({
    SyncProgressListener? onProgress,
    SyncCancel? cancel,
  }) async {
    final result = SyncResult();
    void check() => cancel?.throwIfCancelled();
    final tracker = _Tracker(progressInterval, onProgress);
    void report(SyncStage s, [int done = 0, int total = 0]) =>
        tracker.report(s, done, total);

    report(SyncStage.pulling);
    syncLog('sync: listing remote');
    final files = {for (final f in await remote.list()) f.name: f};
    check();
    syncLog('sync: remote has ${files.length} files');
    final remoteFormat = await _checkFormat(files);
    final known = {
      for (final r in await db.select(db.syncDocs).get()) _key(r.kind, r.id): r,
    };

    await _pull(files, known, result, tracker, check);

    // 規劃：要下載的、要上傳的，這時才知道總數。
    final toDownload = await _missingImages(files);
    final plan = await _planPush(files, known);
    tracker.plan(toDownload, plan.uploads);

    syncLog(
      'sync: plan download=${toDownload.length} upload=${plan.uploads.length} '
      'docsToPush=${plan.pending.length}',
    );
    await _pullMissingImages(files, toDownload, result, report, tracker, check);
    await _push(files, known, plan, result, report, tracker, check);
    await _writeFormat(remoteFormat);
    syncLog(
      'sync: done pulled=${result.pulled} pushed=${result.pushed} '
      'imgDown=${result.imagesDown} imgUp=${result.imagesUp} '
      'skippedDocs=${result.skippedDocs.length} imgFail=${result.imageFailures}',
    );
    return result;
  }

  /// 遠端有比這版新的格式標記就停下來；回傳遠端目前的格式版本（沒有標記為 null）。
  Future<int?> _checkFormat(Map<String, RemoteFile> files) async {
    if (!files.containsKey(_formatFile)) return null;
    final bytes = await remote.download(_formatFile);
    if (bytes == null) return null;
    try {
      final v = (jsonDecode(
        utf8.decode(bytes),
      ) as Map<String, dynamic>)['formatVersion'];
      _requireSupported(v);
      return v is int ? v : 1;
    } on SyncFormatException {
      rethrow;
    } catch (_) {
      return null; // 標記壞掉就略過，改由每份文件自己的版本把關。
    }
  }

  /// 遠端沒有標記、或標記比這版舊時，補寫這版的格式版本。
  Future<void> _writeFormat(int? remoteVersion) async {
    if (remoteVersion != null && remoteVersion >= syncFormatVersion) return;
    await remote.upload(
      _formatFile,
      Uint8List.fromList(
        utf8.encode(jsonEncode({'formatVersion': syncFormatVersion})),
      ),
      contentType: 'application/json',
    );
  }

  void _requireSupported(Object? version) {
    final v = version is int ? version : 1;
    if (v > syncFormatVersion) throw SyncFormatException();
  }

  Future<void> _record(
    String kind,
    String id,
    int updatedAtMs,
    String remoteModified,
  ) {
    return db
        .into(db.syncDocs)
        .insertOnConflictUpdate(
          SyncDocsCompanion.insert(
            kind: kind,
            id: id,
            updatedAtMs: updatedAtMs,
            remoteModified: Value(remoteModified),
          ),
        );
  }

  Future<void> _pull(
    Map<String, RemoteFile> files,
    Map<String, SyncDoc> known,
    SyncResult result,
    _Tracker tracker,
    void Function() check,
  ) async {
    // 先決定要下載哪些文件（依實體種類順序），總數確定後才開始下載，介面才有確定的進度。
    final jobs = <_PullJob>[];
    final localVersions = <String, Map<String, int>>{};
    for (final kind in kinds) {
      final prefix = 'meta__${kind.name}__';
      localVersions[kind.name] = await kind.versions(db);
      for (final f in files.values) {
        if (!f.name.startsWith(prefix) || !f.name.endsWith('.json')) continue;
        final id = f.name.substring(
          prefix.length,
          f.name.length - '.json'.length,
        );
        final seen = known[_key(kind.name, id)];
        if (seen != null && seen.remoteModified == f.modified) continue; // 遠端沒變
        jobs.add(_PullJob(kind, id, f));
      }
    }
    syncLog('pull: ${jobs.length} docs to fetch');
    tracker.pull(0, jobs.length);

    // 分批並行下載（每批 [syncPullConcurrency] 份），每批依序套用，一批一批回報進度。
    for (var i = 0; i < jobs.length; i += syncPullConcurrency) {
      check();
      final batch = jobs.sublist(
        i,
        i + syncPullConcurrency > jobs.length
            ? jobs.length
            : i + syncPullConcurrency,
      );
      final bytes = await Future.wait([
        for (final j in batch) remote.download(j.file.name),
      ]);
      check();
      for (var k = 0; k < batch.length; k++) {
        final job = batch[k];
        final data = bytes[k];
        if (data == null) continue;
        await _applyDoc(
          job,
          data,
          localVersions[job.kind.name]!,
          known,
          result,
        );
      }
      tracker.pull(i + batch.length, jobs.length);
      syncLog('pull: ${i + batch.length}/${jobs.length}');
    }
  }

  /// 套用一份雲端文件。單份壞掉（無法解析、欄位型別不符、舊新 schema 差異）只略過這一份並記錄，
  /// 不擋住其餘文件；較新格式（[SyncFormatException]）仍整個停下來。
  Future<void> _applyDoc(
    _PullJob job,
    Uint8List bytes,
    Map<String, int> local,
    Map<String, SyncDoc> known,
    SyncResult result,
  ) async {
    final kind = job.kind;
    final f = job.file;
    try {
      final doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      // 較新格式的文件：整個同步停下來，不碰本機資料。
      _requireSupported(doc['formatVersion']);
      final remoteMs = (doc['updatedAt'] as num).toInt();
      final localMs = local[job.id];
      if (localMs == null || remoteMs > localMs) {
        await kind.apply(db, doc['data'] as Map<String, dynamic>);
        result.pulled++;
      }
      await _record(kind.name, job.id, remoteMs, f.modified);
      known[_key(kind.name, job.id)] = SyncDoc(
        kind: kind.name,
        id: job.id,
        updatedAtMs: remoteMs,
        remoteModified: f.modified,
      );
    } on SyncFormatException {
      rethrow;
    } catch (e) {
      syncLog('pull: skip ${kind.name} doc (${e.runtimeType})');
      result.skippedDocs.add(f.name);
    }
  }

  /// 本機資料庫引用到的所有圖片檔名。
  Future<Set<String>> _referencedImages() async {
    final needed = <String>{};
    // 淺坑自己選的封面檔（D-088）。
    for (final r in await db.select(db.pits).get()) {
      final c = r.coverFile;
      if (c != null && c.isNotEmpty) needed.add(c);
    }
    for (final r in await db.select(db.officialImages).get()) {
      needed.add(r.imageFile);
      final poster = r.posterFile;
      if (poster != null && poster.isNotEmpty) needed.add(poster);
    }
    for (final r in await db.select(db.fanArts).get()) {
      needed.add(r.imageFile);
      final poster = r.posterFile;
      if (poster != null && poster.isNotEmpty) needed.add(poster);
    }
    for (final r in await db.select(db.junkImages).get()) {
      needed.add(r.imageFile);
      final poster = r.posterFile;
      if (poster != null && poster.isNotEmpty) needed.add(poster);
    }
    for (final r in await db.select(db.materialImages).get()) {
      needed.add(r.imageFile);
      final poster = r.posterFile;
      if (poster != null && poster.isNotEmpty) needed.add(poster);
    }
    for (final r in await db.select(db.entityImages).get()) {
      needed.add(r.imageFile);
      final poster = r.posterFile;
      if (poster != null && poster.isNotEmpty) needed.add(poster);
    }
    for (final r in await db.select(db.yearReviewMonths).get()) {
      if (r.imageFile != null) needed.add(r.imageFile!);
    }
    return needed;
  }

  /// 本機缺少、遠端有的圖片檔名（涵蓋剛拉下來的文件，也涵蓋先前中斷的同步）。
  Future<List<String>> _missingImages(Map<String, RemoteFile> files) async => [
    for (final name in await _referencedImages())
      if (name.isNotEmpty &&
          !images.exists(name) &&
          files.containsKey(_imageName(name)))
        name,
  ];

  Future<void> _pullMissingImages(
    Map<String, RemoteFile> files,
    List<String> todo,
    SyncResult result,
    void Function(SyncStage, [int, int]) report,
    _Tracker tracker,
    void Function() check,
  ) async {
    var done = 0;
    var consecutiveFailures = 0;
    report(SyncStage.downloadingImages, done, todo.length);
    for (var i = 0; i < todo.length; i++) {
      check();
      final name = todo[i];
      tracker.start(i);
      try {
        final bytes = await remote.download(
          _imageName(name),
          onProgress: (d, t) => tracker.progress(i, d, t),
        );
        if (bytes != null) {
          await images.save(name, bytes);
          result.imagesDown++;
        }
        consecutiveFailures = 0;
      } on SyncAuthException {
        rethrow;
      } catch (e) {
        // 單張失敗：記錄、略過（下次同步會再試）；連續失敗太多代表網絡或授權有問題，整次中止。
        result.imageFailures++;
        consecutiveFailures++;
        syncLog(
          'images: download ${i + 1}/${todo.length} failed (${e.runtimeType})',
        );
        if (consecutiveFailures >= syncImageFailureLimit) rethrow;
      }
      // 下載失敗的也算處理過，避免進度卡住；下次同步會再試。
      tracker.finish(i);
      report(SyncStage.downloadingImages, ++done, todo.length);
      if (done % 20 == 0) {
        syncLog('images: $done/${todo.length}');
      }
    }
  }

  /// 找出要上傳的文件，以及其中尚未在遠端的圖片（依文件順序、去重）。
  Future<_PushPlan> _planPush(
    Map<String, RemoteFile> files,
    Map<String, SyncDoc> known,
  ) async {
    final pending = <_Pending>[];
    for (final kind in kinds) {
      final versions = await kind.versions(db);
      for (final e in versions.entries) {
        final seen = known[_key(kind.name, e.key)];
        if (seen != null && seen.updatedAtMs >= e.value) continue;
        pending.add(
          _Pending(kind, e.key, e.value, await kind.encode(db, e.key)),
        );
      }
    }
    final uploads = <String>[];
    final seenFiles = <String>{};
    for (final p in pending) {
      for (final file in p.kind.imageFiles(p.data)) {
        if (file.isNotEmpty &&
            !files.containsKey(_imageName(file)) &&
            images.exists(file) &&
            seenFiles.add(file)) {
          uploads.add(file);
        }
      }
    }
    return _PushPlan(pending, uploads);
  }

  /// 上傳進度：圖片是以串流送出，回報「已交給網絡層的位元組」（見 `DriveRemote`），
  /// 沒有位元組進度的遠端（或很小的檔案）就是開始 0、完成 1。
  Future<void> _push(
    Map<String, RemoteFile> files,
    Map<String, SyncDoc> known,
    _PushPlan plan,
    SyncResult result,
    void Function(SyncStage, [int, int]) report,
    _Tracker tracker,
    void Function() check,
  ) async {
    final total = plan.uploads.length;
    var done = 0;
    report(SyncStage.uploading, done, total);

    for (final p in plan.pending) {
      check();
      // 圖片先傳。
      for (final file in p.kind.imageFiles(p.data)) {
        final name = _imageName(file);
        if (files.containsKey(name)) continue;
        final idx = tracker.uploadIndex(file);
        final f = images.fileOf(file);
        if (!f.existsSync()) {
          if (idx != null) {
            tracker.finish(idx);
            report(SyncStage.uploading, ++done, total);
          }
          continue;
        }
        if (idx != null) tracker.start(idx);
        final modified = await remote.upload(
          name,
          await f.readAsBytes(),
          onProgress: idx == null
              ? null
              : (d, t) => tracker.progress(idx, d, t),
        );
        files[name] = RemoteFile(name: name, modified: modified);
        result.imagesUp++;
        if (idx != null) tracker.finish(idx);
        report(SyncStage.uploading, ++done, total);
      }
      final doc = {
        'v': 1,
        'formatVersion': syncFormatVersion,
        'kind': p.kind.name,
        'id': p.id,
        'updatedAt': p.version,
        'data': p.data,
      };
      final modified = await remote.upload(
        _metaName(p.kind.name, p.id),
        Uint8List.fromList(utf8.encode(jsonEncode(doc))),
        contentType: 'application/json',
      );
      await _record(p.kind.name, p.id, p.version, modified);
      known[_key(p.kind.name, p.id)] = SyncDoc(
        kind: p.kind.name,
        id: p.id,
        updatedAtMs: p.version,
        remoteModified: modified,
      );
      result.pushed++;
    }
  }

  /// 更換 Google 帳號時：清掉同步記錄，下次會把本機資料整個上傳到新帳號。
  Future<void> resetState() => db.delete(db.syncDocs).go();
}
