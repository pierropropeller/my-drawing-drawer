import 'dart:convert';

import 'package:http/http.dart' as http;

/// 作者可連結的平台（D-156）。存在 [Authors.syncSource] 的是 [name]（`x`／`xhs`）。
enum LinkPlatform {
  x,
  xhs;

  static LinkPlatform? parse(String? s) => switch (s) {
    'x' => LinkPlatform.x,
    'xhs' => LinkPlatform.xhs,
    _ => null,
  };
}

/// 從平台查到的作者資料。[userId] 是平台的永久使用者 id（X 的 rest id、小紅書的 24 位 user_id），
/// 連結綁的是它，不是帳號名稱。
class LinkedProfile {
  const LinkedProfile({
    required this.platform,
    required this.userId,
    required this.handle,
    required this.name,
    this.avatarUrl,
    this.bannerUrl,
  });
  final LinkPlatform platform;
  final String userId;

  /// X：帳號名稱（不含 @）；小紅書：小紅書號。
  final String handle;
  final String name;
  final String? avatarUrl;
  final String? bannerUrl;
}

/// 查不到、帳號停用或設為私密、網路問題：一律同一種失敗（設計稿只有一種失敗訊息）。
class AuthorLinkException implements Exception {
  const AuthorLinkException([this.reason = '']);
  final String reason;
  @override
  String toString() => 'AuthorLinkException($reason)';
}

/// 使用者貼上的連結 → 查詢用的鍵。看不懂的格式回傳 null。
/// X：`x.com/<帳號>`、`twitter.com/<帳號>`、`@帳號`、`帳號`。
/// 小紅書：`xiaohongshu.com/user/profile/<24 位 id>`、24 位 id、`xhslink.com/…` 短連結、
/// 筆記網址（`/explore/<id>`、`/discovery/item/<id>`），或 App「複製連結」整段分享文字。
String? parseLinkInput(LinkPlatform p, String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  switch (p) {
    case LinkPlatform.x:
      final m = RegExp(
        r'^(?:https?://)?(?:www\.|mobile\.)?(?:x|twitter)\.com/@?([A-Za-z0-9_]{1,15})(?:[/?#].*)?$',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) {
        final h = m.group(1)!;
        const reserved = {'i', 'home', 'search', 'explore', 'settings'};
        return reserved.contains(h.toLowerCase()) ? null : h;
      }
      if (s.startsWith('@')) s = s.substring(1);
      return RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(s) ? s : null;
    case LinkPlatform.xhs:
      final m = RegExp(
        r'xiaohongshu\.com/user/profile/([0-9a-f]{24})',
        caseSensitive: false,
      ).firstMatch(s);
      if (m != null) return m.group(1)!.toLowerCase();
      if (RegExp(r'^[0-9a-f]{24}$', caseSensitive: false).hasMatch(s)) {
        return s.toLowerCase();
      }
      // 筆記連結（App 分享出來的短連結、網頁版筆記網址）：從筆記讀作者。
      final link = RegExp(
        r'(?:https?://)?(?:xhslink\.com/[^\s，。]+|(?:www\.)?xiaohongshu\.com/(?:explore|discovery/item)/[0-9a-f]{24}[^\s，。]*)',
        caseSensitive: false,
      ).firstMatch(s);
      if (link != null) {
        final u = link.group(0)!;
        return u.startsWith('http') ? u : 'https://$u';
      }
      return null;
  }
}

/// 查詢作者在平台上的資料。測試時換成假的。
abstract class AuthorLinkService {
  /// [key] 是 [parseLinkInput] 的結果。
  Future<LinkedProfile> lookup(LinkPlatform p, String key);

  /// 用連結時記下的資料重新查詢；查到的 [LinkedProfile.userId] 必須跟 [userId] 相同。
  Future<LinkedProfile> refresh(
    LinkPlatform p, {
    required String userId,
    String? handle,
  });

  /// 下載頭像／封面圖。
  Future<List<int>> download(String url);
}

/// 免費的非官方查詢：X 用 api.fxtwitter.com（用帳號名稱查，回傳裡有永久 id）；
/// 小紅書讀個人頁的 SSR 資料（可能被擋，擋了就是一般失敗）。
class HttpAuthorLinkService implements AuthorLinkService {
  HttpAuthorLinkService([http.Client? client])
    : _http = client ?? http.Client();
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);
  static const _ua =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';

  @override
  Future<LinkedProfile> lookup(LinkPlatform p, String key) => switch (p) {
    LinkPlatform.x => _x(key),
    LinkPlatform.xhs => _xhs(key),
  };

  @override
  Future<LinkedProfile> refresh(
    LinkPlatform p, {
    required String userId,
    String? handle,
  }) async {
    final LinkedProfile got;
    switch (p) {
      case LinkPlatform.x:
        // fxtwitter 只能用帳號名稱查：查到的 id 不同（帳號改名、名稱被別人拿走）就算失敗。
        if (handle == null || handle.isEmpty) {
          throw const AuthorLinkException('no handle');
        }
        got = await _x(handle);
      case LinkPlatform.xhs:
        got = await _xhs(userId);
    }
    if (got.userId != userId) throw const AuthorLinkException('id changed');
    return got;
  }

  @override
  Future<List<int>> download(String url) async {
    try {
      final r = await _http
          .get(Uri.parse(url), headers: {'User-Agent': _ua})
          .timeout(_timeout);
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) {
        throw AuthorLinkException('image ${r.statusCode}');
      }
      return r.bodyBytes;
    } on AuthorLinkException {
      rethrow;
    } catch (e) {
      throw AuthorLinkException('image ${e.runtimeType}');
    }
  }

  Future<String> _get(Uri uri) async {
    try {
      final r = await _http
          .get(
            uri,
            headers: {
              'User-Agent': _ua,
              'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
            },
          )
          .timeout(_timeout);
      if (r.statusCode != 200) throw AuthorLinkException('${r.statusCode}');
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } on AuthorLinkException {
      rethrow;
    } catch (e) {
      throw AuthorLinkException(e.runtimeType.toString());
    }
  }

  Future<LinkedProfile> _x(String handle) async {
    final body = await _get(Uri.https('api.fxtwitter.com', '/$handle'));
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthorLinkException('bad json');
    }
    final u = json['user'];
    if (u is! Map<String, dynamic>) throw const AuthorLinkException('no user');
    final id = '${u['id'] ?? ''}';
    final screen = '${u['screen_name'] ?? ''}';
    if (id.isEmpty || screen.isEmpty) throw const AuthorLinkException('empty');
    String? avatar = u['avatar_url'] as String?;
    // 預設是 48px 的 _normal，換成 400×400。
    if (avatar != null) {
      avatar = avatar.replaceFirstMapped(
        RegExp(r'_normal(\.[a-zA-Z]+)$'),
        (m) => '_400x400${m[1]}',
      );
    }
    final banner = u['banner_url'] as String?;
    return LinkedProfile(
      platform: LinkPlatform.x,
      userId: id,
      handle: screen,
      name: '${u['name'] ?? screen}',
      avatarUrl: (avatar ?? '').isEmpty ? null : avatar,
      bannerUrl: (banner ?? '').isEmpty ? null : banner,
    );
  }

  static final _xhsProfile = RegExp(r'/user/profile/([0-9a-f]{24})');
  static final _xhsNote = RegExp(r'/(?:explore|discovery/item)/([0-9a-f]{24})');

  Future<LinkedProfile> _xhs(String key) async {
    if (!key.startsWith('http')) return _xhsProfilePage(key);
    // 短連結：自己跟著轉址，直到看到個人頁或筆記網址。
    var url = Uri.parse(key);
    for (var hop = 0; hop < 6; hop++) {
      final p = _xhsProfile.firstMatch(url.path);
      if (p != null) return _xhsProfilePage(p.group(1)!);
      if (_xhsNote.hasMatch(url.path)) return _xhsFromNote(url);
      final req = http.Request('GET', url)
        ..followRedirects = false
        ..headers['User-Agent'] = _ua;
      String? loc;
      try {
        final r = await _http.send(req).timeout(_timeout);
        loc = r.headers['location'];
        await r.stream.drain<void>();
      } catch (e) {
        throw AuthorLinkException(e.runtimeType.toString());
      }
      if (loc == null || loc.isEmpty) break;
      url = url.resolve(loc);
    }
    throw const AuthorLinkException('short link');
  }

  /// 筆記頁的 `note.noteDetailMap.<id>.note.user` 有作者 id、名字、頭像。
  /// 個人頁拿得到就用個人頁（多了小紅書號、大頭像），拿不到就用筆記上的資料。
  Future<LinkedProfile> _xhsFromNote(Uri url) async {
    final state = _xhsState(await _get(url));
    Map<String, dynamic>? user;
    final map = (state?['note'] as Map?)?['noteDetailMap'];
    if (map is Map) {
      for (final v in map.values) {
        final u = ((v as Map?)?['note'] as Map?)?['user'];
        if (u is Map<String, dynamic>) {
          user = u;
          break;
        }
      }
    }
    final id = '${user?['userId'] ?? ''}';
    final name = '${user?['nickname'] ?? user?['nickName'] ?? ''}';
    if (id.isEmpty || name.isEmpty) throw const AuthorLinkException('no note');
    try {
      return await _xhsProfilePage(id);
    } on AuthorLinkException {
      final avatar = user!['avatar'] as String?;
      return LinkedProfile(
        platform: LinkPlatform.xhs,
        userId: id,
        handle: id,
        name: name,
        avatarUrl: (avatar ?? '').isEmpty ? null : avatar,
      );
    }
  }

  Future<LinkedProfile> _xhsProfilePage(String id) async {
    final html = await _get(
      Uri.https('www.xiaohongshu.com', '/user/profile/$id'),
    );
    final user = _xhsState(html)?['user'] as Map?;
    final info = (user?['userPageData'] as Map?)?['basicInfo'] as Map?;
    if (info == null) throw const AuthorLinkException('no data');
    final name = '${info['nickname'] ?? ''}';
    final red = '${info['redId'] ?? ''}';
    if (name.isEmpty) throw const AuthorLinkException('empty');
    final avatar = (info['imageb'] ?? info['images']) as String?;
    return LinkedProfile(
      platform: LinkPlatform.xhs,
      userId: id,
      handle: red.isEmpty ? id : red,
      name: name,
      avatarUrl: (avatar ?? '').isEmpty ? null : avatar,
    );
  }

  /// 頁面裡的 `window.__INITIAL_STATE__`（JS 物件，`undefined` 換成 null 再當 JSON 讀）。
  static Map<String, dynamic>? _xhsState(String html) {
    final start = html.indexOf('window.__INITIAL_STATE__=');
    if (start < 0) return null;
    final from = start + 'window.__INITIAL_STATE__='.length;
    final end = html.indexOf('</script>', from);
    if (end < 0) return null;
    final raw = html
        .substring(from, end)
        .trim()
        .replaceAll(RegExp(r';$'), '')
        .replaceAll(RegExp(r'(?<=[:\[,])undefined(?=[,}\]])'), 'null');
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
