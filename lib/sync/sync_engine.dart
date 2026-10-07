import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database.dart';
import '../data/image_store.dart';
import 'remote.dart';
import 'sync_kinds.dart';

class SyncResult {
  int pushed = 0;
  int pulled = 0;
  int imagesUp = 0;
  int imagesDown = 0;

  bool get changed => pushed + pulled + imagesUp + imagesDown > 0;
  @override
  String toString() => '上傳 $pushed／下載 $pulled（圖片 ↑$imagesUp ↓$imagesDown）';
}

String _metaName(String kind, String id) => 'meta__${kind}__$id.json';
String _imageName(String file) => 'images__$file';

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

  Future<SyncResult> sync() async {
    final result = SyncResult();
    final files = {for (final f in await remote.list()) f.name: f};
    final known = {
      for (final r in await db.select(db.syncDocs).get()) _key(r.kind, r.id): r,
    };

    await _pull(files, known, result);
    await _pullMissingImages(files, result);
    await _push(files, known, result);
    return result;
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

  /// 補下載本機缺少、遠端有的圖片（涵蓋剛拉下來的文件，也涵蓋先前中斷的同步）。
  Future<void> _pullMissingImages(
    Map<String, RemoteFile> files,
    SyncResult result,
  ) async {
    final needed = <String>{};
    for (final r in await db.select(db.officialImages).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.fanArts).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.entityImages).get()) {
      needed.add(r.imageFile);
    }
    for (final r in await db.select(db.yearReviewMonths).get()) {
      if (r.imageFile != null) needed.add(r.imageFile!);
    }
    for (final name in needed) {
      if (images.fileOf(name).existsSync()) continue;
      if (!files.containsKey(_imageName(name))) continue;
      final bytes = await remote.download(_imageName(name));
      if (bytes == null) continue;
      await images.dir.create(recursive: true);
      await images.fileOf(name).writeAsBytes(bytes, flush: true);
      result.imagesDown++;
    }
  }

  Future<void> _push(
    Map<String, RemoteFile> files,
    Map<String, SyncDoc> known,
    SyncResult result,
  ) async {
    for (final kind in kinds) {
      final versions = await kind.versions(db);
      for (final e in versions.entries) {
        final seen = known[_key(kind.name, e.key)];
        if (seen != null && seen.updatedAtMs >= e.value) continue;

        final data = await kind.encode(db, e.key);
        // 圖片先傳。
        for (final file in kind.imageFiles(data)) {
          final name = _imageName(file);
          if (files.containsKey(name)) continue;
          final f = images.fileOf(file);
          if (!f.existsSync()) continue;
          final modified = await remote.upload(name, await f.readAsBytes());
          files[name] = RemoteFile(name: name, modified: modified);
          result.imagesUp++;
        }
        final doc = {
          'v': 1,
          'kind': kind.name,
          'id': e.key,
          'updatedAt': e.value,
          'data': data,
        };
        final modified = await remote.upload(
          _metaName(kind.name, e.key),
          Uint8List.fromList(utf8.encode(jsonEncode(doc))),
          contentType: 'application/json',
        );
        await _record(kind.name, e.key, e.value, modified);
        known[_key(kind.name, e.key)] = SyncDoc(
          kind: kind.name,
          id: e.key,
          updatedAtMs: e.value,
          remoteModified: modified,
        );
        result.pushed++;
      }
    }
  }

  /// 更換 Google 帳號時：清掉同步記錄，下次會把本機資料整個上傳到新帳號。
  Future<void> resetState() => db.delete(db.syncDocs).go();
}
