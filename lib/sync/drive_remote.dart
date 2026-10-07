import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'remote.dart';

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
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw const SyncAuthException();
    }
    if (r.statusCode >= 400) {
      throw Exception('Drive 錯誤 ${r.statusCode}：${r.body}');
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
  Future<Uint8List?> download(String name) async {
    final id = _ids[name];
    if (id == null) return null;
    final r = await _check(
      await _http.get(
        Uri.parse('$_api/$id?alt=media'),
        headers: await headers(),
      ),
    );
    return r.bodyBytes;
  }

  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
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
    final req = http.Request(existing == null ? 'POST' : 'PATCH', uri)
      ..headers.addAll(h)
      ..headers['Content-Type'] = 'multipart/related; boundary=$boundary'
      ..bodyBytes = body.takeBytes();
    final r = await _check(
      await http.Response.fromStream(await _http.send(req)),
    );
    final m = jsonDecode(r.body) as Map<String, dynamic>;
    _ids[name] = m['id'] as String;
    return m['modifiedTime'] as String;
  }
}
