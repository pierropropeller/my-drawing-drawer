import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'remote.dart';
import '../l10n/l10n.dart';

/// Google Drive 的 App 專用資料夾（appDataFolder，使用者在 Drive 看不到，
/// scope 只要 `drive.appdata`）。直接呼叫 Drive REST v3。
class DriveRemote implements SyncRemote {
  DriveRemote({required this.headers, http.Client? client})
    : _http = client ?? http.Client();

  /// 取得帶 `Authorization: Bearer …` 的標頭；必要時由登入服務刷新。
  final Future<Map<String, String>> Function() headers;
  final http.Client _http;
  final Map<String, String> _ids = {};

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  Future<http.Response> _check(http.Response r) async {
    if (r.statusCode == 401) {
      throw SyncAuthException();
    }
    if (r.statusCode == 403) {
      // 403 多半是 Drive API 沒啟用或權限不足，不是登入過期；把原因帶出來方便排查。
      throw SyncAuthException(l10nStatic.syncDriveForbidden(r.body));
    }
    if (r.statusCode >= 400) {
      throw Exception(l10nStatic.syncDriveError(r.statusCode, r.body));
    }
    return r;
  }

  @override
  Future<List<RemoteFile>> list() async {
    final out = <RemoteFile>[];
    String? token;
    do {
      final uri = Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'pageSize': '1000',
          'fields': 'nextPageToken, files(id,name,modifiedTime)',
          'pageToken': ?token,
        },
      );
      final r = await _check(await _http.get(uri, headers: await headers()));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      for (final f in (body['files'] as List<dynamic>? ?? const [])) {
        final m = f as Map<String, dynamic>;
        _ids[m['name'] as String] = m['id'] as String;
        out.add(
          RemoteFile(
            name: m['name'] as String,
            modified: m['modifiedTime'] as String,
            id: m['id'] as String,
          ),
        );
      }
      token = body['nextPageToken'] as String?;
    } while (token != null);
    return out;
  }

  @override
  Future<Uint8List?> download(
    String name, {
    TransferProgress? onProgress,
  }) async {
    final id = _ids[name];
    if (id == null) return null;
    final req = http.Request('GET', Uri.parse('$_api/$id?alt=media'))
      ..headers.addAll(await headers());
    final resp = await _http.send(req);
    if (resp.statusCode >= 400) {
      await _check(await http.Response.fromStream(resp)); // 轉成對應的例外
    }
    // 串流讀取，依已收位元組回報進度（Content-Length 未知時 total 為 null）。
    final total = resp.contentLength;
    final out = BytesBuilder(copy: false);
    await for (final chunk in resp.stream) {
      out.add(chunk);
      onProgress?.call(out.length, total);
    }
    return out.takeBytes();
  }

  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) async {
    final existing = _ids[name];
    final h = await headers();
    final boundary = 'huakeng${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': name,
      if (existing == null) 'parents': ['appDataFolder'],
    });
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n',
        ),
      )
      ..add(utf8.encode('--$boundary\r\nContent-Type: $contentType\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final uri = Uri.parse(existing == null ? _upload : '$_upload/$existing')
        .replace(
          queryParameters: {
            'uploadType': 'multipart',
            'fields': 'id,modifiedTime',
          },
        );
    final req =
        _ProgressRequest(
            existing == null ? 'POST' : 'PATCH',
            uri,
            body.takeBytes(),
            onProgress,
          )
          ..headers.addAll(h)
          ..headers['Content-Type'] = 'multipart/related; boundary=$boundary';
    final r = await _check(
      await http.Response.fromStream(await _http.send(req)),
    );
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    _ids[name] = m['id'] as String;
    return m['modifiedTime'] as String;
  }
}

/// 分段送出請求內容的請求：socket 每取一段就回報已送出的位元組（供上傳進度）。
/// 進度是「已交給網絡層」的量，可能略快於對方實際收到的量；完成由呼叫端另行標示。
class _ProgressRequest extends http.BaseRequest {
  _ProgressRequest(super.method, super.url, this._body, this._onProgress) {
    contentLength = _body.length;
  }

  final Uint8List _body;
  final TransferProgress? _onProgress;
  static const _chunk = 32 * 1024;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_chunks());
  }

  Stream<List<int>> _chunks() async* {
    for (var i = 0; i < _body.length; i += _chunk) {
      final end = i + _chunk < _body.length ? i + _chunk : _body.length;
      yield Uint8List.sublistView(_body, i, end);
      _onProgress?.call(end, _body.length);
    }
  }
}
