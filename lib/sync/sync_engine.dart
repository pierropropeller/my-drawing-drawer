import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/image_store.dart';
import 'remote.dart';
import 'sync_kinds.dart';
import '../l10n/l10n.dart';

/// 目前這版 App 寫出／能讀的同步格式版本。
/// 之後若出現不相容的改動就把它加一；舊版 App 讀到較高的版本會停下來，不會弄壞資料。
/// 1＝初版（文件只有 `v: 1`）；2＝加入雜物、移動、商稿欄位、`formatVersion`。
const syncFormatVersion = 2;

/// 遠端備份的格式比這版 App 新：必須先更新 App。
class SyncFormatException extends SyncAuthException {
  SyncFormatException() : super(l10nStatic.syncNeedsAppUpdate);
}

/// 同步目前進行到哪個階段。
enum SyncStage { pulling, downloadingImages, uploading }

/// 同步進度（UI 顯示「圖片 N / M」）。
/// [imagesTotal] 在 [SyncStage.pulling] 為 0；進入下載／上傳階段後才知道數量。
class SyncProgress {
  const SyncProgress(this.stage, this.imagesDone, this.imagesTotal);
  final SyncStage stage;
  final int imagesDone;
  final int imagesTotal;

  @override
  String toString() => '$stage $imagesDone/$imagesTotal';
}

typedef SyncProgressListener = void Function(SyncProgress progress);

class SyncResult {
  int pushed = 0;
  int pulled = 0;
  int imagesUp = 0;
  int imagesDown = 0;

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

/// 離線優先同步：本機永遠先寫入；有網絡時把「比遠端新」的實體上傳，
/// 並拉取遠端較新的實體（以實體為單位，updatedAt 較新者勝，last-write-wins）。
/// 圖片先傳、文件後傳；刪除是軟刪除，同樣以文件同步。
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.images,
    this.kinds = allSyncKinds,
  });

  final AppDatabase db;
  final SyncRemote remote;
  final ImageStore images;
  final List<SyncKind> kinds;

  static String _key(String kind, String id) => '$kind|$id';

  /// [onProgress]：階段與圖片進度的回報（在 UI 執行緒呼叫，不要做耗時工作）。
  Future<SyncResult> sync({SyncProgressListener? onProgress}) async {
    final result = SyncResult();
    void report(SyncStage s, [int done = 0, int total = 0]) =>
        onProgress?.call(SyncProgress(s, done, total));

    report(SyncStage.pulling);
    final files = {for (final f in await remote.list()) f.name: f};
    final remoteFormat = await _checkFormat(files);
    final known = {
      for (final r in await db.select(db.syncDocs).get()) _key(r.kind, r.id): r,
    };

    await _pull(files, known, result);
    await _pullMissingImages(files, result, report);
    await _push(files, known, result, report);
    await _writeFormat(remoteFormat);
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
  ) async {
    for (final kind in kinds) {
      final prefix = 'meta__${kind.name}__';
      final local = await kind.versions(db);
      for (final f in files.values) {
        if (!f.name.startsWith(prefix) || !f.name.endsWith('.json')) continue;
        final id = f.name.substring(
          prefix.length,
          f.name.length - '.json'.length,
        );
        final seen = known[_key(kind.name, id)];
        if (seen != null && seen.remoteModified == f.modified) continue; // 遠端沒變

        final bytes = await remote.download(f.name);
        if (bytes == null) continue;
        Map<String, dynamic> doc;
        try {
          doc = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        } catch (_) {
          continue; // 壞掉的文件略過
        }
        // 較新格式的文件：整個同步停下來，不碰本機資料。
        _requireSupported(doc['formatVersion']);
        final remoteMs = doc['updatedAt'] as int;
        final localMs = local[id];
        if (localMs == null || remoteMs > localMs) {
          await kind.apply(db, doc['data'] as Map<String, dynamic>);
          result.pulled++;
        }
        await _record(kind.name, id, remoteMs, f.modified);
        known[_key(kind.name, id)] = SyncDoc(
          kind: kind.name,
          id: id,
          updatedAtMs: remoteMs,
          remoteModified: f.modified,
        );
      }
    }
  }

  /// 本機資料庫引用到的所有圖片檔名。
  Future<Set<String>> _referencedImages() async {
    final needed = <String>{};
    for (final r in await db.select(db.officialImages).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.fanArts).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.junkImages).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.entityImages).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.yearReviewMonths).get()) {
      if (r.imageFile != null) needed.add(r.imageFile!);
    }
    return needed;
  }

  /// 補下載本機缺少、遠端有的圖片（涵蓋剛拉下來的文件，也涵蓋先前中斷的同步）。
  Future<void> _pullMissingImages(
    Map<String, RemoteFile> files,
    SyncResult result,
    void Function(SyncStage, [int, int]) report,
  ) async {
    final todo = [
      for (final name in await _referencedImages())
        if (!images.exists(name) && files.containsKey(_imageName(name))) name,
    ];
    var done = 0;
    report(SyncStage.downloadingImages, done, todo.length);
    for (final name in todo) {
      final bytes = await remote.download(_imageName(name));
      if (bytes != null) {
        await images.save(name, bytes);
        result.imagesDown++;
      }
      // 下載失敗的也算處理過，避免進度卡住；下次同步會再試。
      report(SyncStage.downloadingImages, ++done, todo.length);
    }
  }

  Future<void> _push(
    Map<String, RemoteFile> files,
    Map<String, SyncDoc> known,
    SyncResult result,
    void Function(SyncStage, [int, int]) report,
  ) async {
    // 先找出要上傳的文件與其中尚未在遠端的圖片，才知道圖片總數。
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
    final toUpload = <String>{
      for (final p in pending)
        for (final file in p.kind.imageFiles(p.data))
          if (!files.containsKey(_imageName(file)) && images.exists(file)) file,
    };
    var done = 0;
    report(SyncStage.uploading, done, toUpload.length);

    for (final p in pending) {
      // 圖片先傳。
      for (final file in p.kind.imageFiles(p.data)) {
        final name = _imageName(file);
        if (files.containsKey(name)) continue;
        final f = images.fileOf(file);
        if (!f.existsSync()) continue;
        final modified = await remote.upload(name, await f.readAsBytes());
        files[name] = RemoteFile(name: name, modified: modified);
        result.imagesUp++;
        report(SyncStage.uploading, ++done, toUpload.length);
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
