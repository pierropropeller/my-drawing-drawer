import 'dart:typed_data';

class RemoteFile {
  const RemoteFile({required this.name, required this.modified, this.id});
  final String name;
  final String modified; // 遠端的修改時間（字串，只用來比對是否變動）
  final String? id;
}

class SyncAuthException implements Exception {
  const SyncAuthException([this.message = '登入已失效，請重新連結 Google 帳號']);
  final String message;
  @override
  String toString() => message;
}

/// 遠端儲存（Google Drive 專用資料夾）。扁平命名空間：
/// `meta__{kind}__{id}.json`、`images__{檔名}`。
abstract class SyncRemote {
  Future<List<RemoteFile>> list();
  Future<Uint8List?> download(String name);

  /// 上傳（新增或覆蓋），回傳遠端的修改時間字串。
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
  });
}

/// 記憶體遠端：測試與（日後）本機資料夾備份共用。
class MemoryRemote implements SyncRemote {
  final Map<String, Uint8List> files = {};
  final Map<String, int> _version = {};
  int _clock = 0;

  @override
  Future<List<RemoteFile>> list() async => [
    for (final n in files.keys)
      RemoteFile(name: n, modified: '${_version[n]}', id: n),
  ];

  @override
  Future<Uint8List?> download(String name) async => files[name];

  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    files[name] = bytes;
    _version[name] = ++_clock;
    return '${_version[name]}';
  }
}
