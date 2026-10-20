import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'remote.dart';
import 'sync_log.dart';
import '../l10n/l10n.dart';

/// Google Drive 的 App 專用資料夾（appDataFolder，使用者在 Drive 看不到，
/// scope 只要 `drive.appdata`）。直接呼叫 Drive REST v3。
class DriveRemote implements SyncRemote, ThumbnailFallbackRemote {
  DriveRemote({
    required this.headers,
    http.Client? client,
    this.refreshAuth,
    this.requestTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(seconds: 120),
    this.headersTimeout = const Duration(seconds: 90),
    this.maxAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
  }) : _http = client ?? http.Client();

  /// 取得帶 `Authorization: Bearer …` 的標頭；必要時由登入服務刷新。
  final Future<Map<String, String>> Function() headers;

  /// 收到 401 時呼叫：丟掉快取的存取權杖，下一次 [headers] 會重新授權。沒有就不重試 401。
  final Future<void> Function()? refreshAuth;

  /// 單一請求（列表分頁、取得回應標頭）的時限。
  final Duration requestTimeout;

  /// 下載／回應內容串流的「閒置」時限：這麼久沒有收到任何資料就算逾時（大檔不受總時間限制）。
  final Duration idleTimeout;

  /// 上傳整個請求的時限。
  final Duration uploadTimeout;

  /// 取得授權標頭的時限（互動授權卡住時不致永遠等）。
  final Duration headersTimeout;

  /// 逾時／斷線／5xx 時最多嘗試幾次（含第一次）。
  final int maxAttempts;
  final Duration retryDelay;

  final http.Client _http;
  final Map<String, String> _ids = {};

  /// 本次同步 [list] 時順便取得的 `thumbnailLink`（檔名 → 連結）；連結會過期，
  /// 每次 [list] 重建，只在這次同步內使用，這樣備援縮圖每張只要一次請求。
  final Map<String, String> _thumbLinks = {};

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  Future<Map<String, String>> _headers() async {
    try {
      return await headers().timeout(headersTimeout);
    } on TimeoutException {
      throw SyncAuthException(l10nStatic.syncAuthExpiredDetail('timeout'));
    }
  }

  /// 401：標頭過期或失效；交給 [_run] 刷新授權後重試一次。
  Future<http.Response> _check(http.Response r) async {
    if (r.statusCode == 401) throw const _Unauthorized();
    if (r.statusCode == 403) {
      if (r.body.contains('ateLimitExceeded') ||
          r.body.contains('quotaExceeded')) {
        throw _Transient('HTTP 403 rate limit');
      }
      // 403 多半是 Drive API 沒啟用或權限不足，不是登入過期；把原因帶出來方便排查。
      throw SyncAuthException(l10nStatic.syncDriveForbidden(r.body));
    }
    if (r.statusCode == 429 || r.statusCode >= 500) {
      throw _Transient('HTTP ${r.statusCode}');
    }
    if (r.statusCode >= 400) {
      throw Exception(l10nStatic.syncDriveError(r.statusCode, r.body));
    }
    return r;
  }

  /// 執行一次請求並套用：逾時／斷線／5xx／429 重試（退避），401 刷新授權後重試一次；
  /// 用盡後丟出 [SyncNetworkException]，不會無限等待。
  Future<T> _run<T>(
    String step,
    Future<T> Function() op, {
    int? attempts,
  }) async {
    final max = attempts ?? maxAttempts;
    var attempt = 0;
    var refreshed = false;
    while (true) {
      attempt++;
      try {
        return await op();
      } on _Unauthorized {
        syncLog('$step 401');
        if (refreshed || refreshAuth == null) throw SyncAuthException();
        refreshed = true;
        attempt--; // 刷新授權的那次不算重試額度
        await refreshAuth!();
      } on SyncAuthException {
        rethrow;
      } on TimeoutException {
        syncLog('$step timeout (attempt $attempt/$max)');
        if (attempt >= max) {
          throw SyncNetworkException(l10nStatic.syncuiTimeout(step));
        }
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
      } on _Transient catch (e) {
        syncLog('$step ${e.what} (attempt $attempt/$max)');
        if (attempt >= max) {
          throw SyncNetworkException(
            l10nStatic.syncuiNetworkError(step, e.what),
          );
        }
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
      } on http.ClientException catch (e) {
        syncLog('$step client error ${e.runtimeType} (attempt $attempt/$max)');
        if (attempt >= max) {
          throw SyncNetworkException(
            l10nStatic.syncuiNetworkError(step, e.message),
          );
        }
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
      } on IOException catch (e) {
        syncLog('$step io error ${e.runtimeType} (attempt $attempt/$max)');
        if (attempt >= max) {
          throw SyncNetworkException(l10nStatic.syncuiNetworkError(step, '$e'));
        }
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
      }
    }
  }

  @override
  Future<List<RemoteFile>> list() async {
    final out = <RemoteFile>[];
    _thumbLinks.clear();
    String? token;
    var page = 0;
    do {
      page++;
      final uri = Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'pageSize': '1000',
          'fields': 'nextPageToken, files(id,name,modifiedTime,thumbnailLink)',
          'pageToken': ?token,
        },
      );
      final r = await _run(
        'list p$page',
        () async => _check(
          await _http
              .get(uri, headers: await _headers())
              .timeout(requestTimeout),
        ),
      );
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      for (final f in (body['files'] as List<dynamic>? ?? const [])) {
        final m = f as Map<String, dynamic>;
        _ids[m['name'] as String] = m['id'] as String;
        final link = m['thumbnailLink'] as String?;
        if (link != null && link.isNotEmpty) {
          _thumbLinks[m['name'] as String] = link;
        }
        out.add(
          RemoteFile(
            name: m['name'] as String,
            modified: m['modifiedTime'] as String,
            id: m['id'] as String,
          ),
        );
      }
      token = body['nextPageToken'] as String?;
      syncLog('list p$page: ${out.length} files so far, more=${token != null}');
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
    return _run('download', () async {
      final req = http.Request('GET', Uri.parse('$_api/$id?alt=media'))
        ..headers.addAll(await _headers());
      final resp = await _http.send(req).timeout(requestTimeout);
      if (resp.statusCode >= 400) {
        await _check(await http.Response.fromStream(resp)); // 轉成對應的例外
      }
      // 串流讀取，依已收位元組回報進度（Content-Length 未知時 total 為 null）。
      // 閒置逾時：每段資料之間不能超過 [idleTimeout]。
      final total = resp.contentLength;
      final out = BytesBuilder(copy: false);
      await for (final chunk in resp.stream.timeout(idleTimeout)) {
        out.add(chunk);
        onProgress?.call(out.length, total);
      }
      return out.takeBytes();
    });
  }

  /// 把 Drive `thumbnailLink` 的尺寸參數改成長邊 32（`=s32`）。
  /// 認得 `=s220`、`=s220-c`、`=w220-h160`、`=w220-h160-p-k-no` 這幾種結尾；
  /// 完全沒有尺寸參數時直接補上 `=s32`（否則 googleusercontent 會回原尺寸）。
  static String resizeThumbnailLink(String link) {
    final re = RegExp(r'=(?:s\d+|w\d+-h\d+)(?:-[\w]+)*$');
    if (re.hasMatch(link)) return link.replaceFirst(re, '=s32');
    final tail = link.substring(link.lastIndexOf('/') + 1);
    return tail.contains('=') ? link : '$link=s32';
  }

  /// 舊資料備援（D-099）：用 [list] 時帶回的 `thumbnailLink`（沒有才退回
  /// `files.get?fields=thumbnailLink` 多一次請求）把尺寸改成長邊 32（`=s32`），再帶登入 token 下載。
  /// 失敗（沒有縮圖、連結過期、網絡）一律回傳 null，不擋同步；只有授權過期才往上丟。
  @override
  Future<Uint8List?> fallbackThumbnail(String name) async {
    final id = _ids[name];
    if (id == null) return null;
    try {
      var link = _thumbLinks[name];
      if (link == null) {
        final meta = await _run(
          'thumbnailLink',
          () async => _check(
            await _http
                .get(
                  Uri.parse('$_api/$id')
                      .replace(queryParameters: {'fields': 'thumbnailLink'}),
                  headers: await _headers(),
                )
                .timeout(requestTimeout),
          ),
          attempts: 2,
        );
        link =
            (jsonDecode(meta.body) as Map<String, dynamic>)['thumbnailLink']
                as String?;
      }
      if (link == null || link.isEmpty) return null;
      final sized = resizeThumbnailLink(link);
      final r = await _run(
        'thumbnail',
        () async => _check(
          await _http
              .get(Uri.parse(sized), headers: await _headers())
              .timeout(requestTimeout),
        ),
        attempts: 2,
      );
      syncLog('thumbnail fallback ${r.bodyBytes.length}B');
      return r.bodyBytes.isEmpty ? null : r.bodyBytes;
    } on SyncAuthException {
      rethrow;
    } catch (e) {
      syncLog('thumbnailLink fallback failed (${e.runtimeType})');
      return null;
    }
  }

  @override
  Future<String> upload(
    String name,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    TransferProgress? onProgress,
  }) async {
    final boundary = 'huakeng${DateTime.now().microsecondsSinceEpoch}';
    // 新建檔案的上傳不自動重試（逾時時對方可能已建好，重送會產生同名重複檔）；
    // 覆蓋既有檔案是冪等的，可以重試。
    final isUpdate = _ids[name] != null;
    return _run('upload', () async {
      final existing = _ids[name];
      final h = await _headers();
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
        await (() async => http.Response.fromStream(
          await _http.send(req),
        ))().timeout(uploadTimeout),
      );
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      _ids[name] = m['id'] as String;
      return m['modifiedTime'] as String;
    }, attempts: isUpdate ? maxAttempts : 1);
  }
}

class _Unauthorized implements Exception {
  const _Unauthorized();
}

class _Transient implements Exception {
  _Transient(this.what);
  final String what;
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
