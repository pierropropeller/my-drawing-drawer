import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/author_link.dart';
import '../data/author_queries.dart';
import '../data/database.dart';

/// 分享批次裡的連結（分享推文時，原生端把網址照字串放在批次裡，D-158）。
bool isShareLink(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

/// 推文圖下載到哪裡（`<暫存>/share_import`）。測試時換掉。
final tweetShareTempDirProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

enum TweetShareStatus { loading, failed, ready }

/// 從推文分享進來（D-158）：讀推文 → 下載原圖到暫存 → 找 Drawer 裡連結了這個 X 帳號的作者。
///
/// sheet 顯示讀取中／讀不到／可以加入三種狀態；縮圖可以刪、可以再加圖（[paths] 會變）。
class TweetShareController extends ChangeNotifier {
  TweetShareController({
    required this.link,
    required AuthorLinkService service,
    required AppDatabase db,
    Future<Directory> Function()? tempDir,
  }) : _service = service, // ignore: prefer_initializing_formals
       _db = db, // ignore: prefer_initializing_formals
       _tempDir = tempDir ?? getTemporaryDirectory;

  /// 分享進來的網址（原樣）。
  final String link;
  final AuthorLinkService _service;
  final AppDatabase _db;
  final Future<Directory> Function() _tempDir;

  TweetShareStatus status = TweetShareStatus.loading;
  TweetInfo? info;

  /// 目前要加入的檔案（下載的推文圖＋之後自己加的圖）。
  final List<String> paths = [];

  /// 這裡下載的暫存檔（結束時刪掉；使用者自己加的圖不刪）。
  final Set<String> owned = {};

  /// Drawer 裡已連結這個 X 帳號的作者；null＝新作者。
  Author? author;

  /// [author] 最近加入同人圖的坑。
  String? authorPitId;

  bool _disposed = false;

  /// 推文卡片上顯示的網址（去掉 https://）。
  String get displayUrl =>
      (info?.url ?? link).replaceFirst(RegExp(r'^https?://(www\.)?'), '');

  /// 讀推文（第一次與「重試」）。
  Future<void> load() async {
    status = TweetShareStatus.loading;
    _notify();
    try {
      final id = parseTweetUrl(link);
      if (id == null) throw const AuthorLinkException('not a tweet');
      final got = await _service.tweet(id);
      final dir = Directory('${(await _tempDir()).path}/share_import');
      await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final files = <String>[];
      for (final (i, m) in got.media.indexed) {
        try {
          final bytes = await _service.download(m.url);
          final f = File('${dir.path}/tweet_${stamp}_$i.${_ext(m)}');
          await f.writeAsBytes(bytes, flush: true);
          files.add(f.path);
        } catch (_) {
          // 一張下載失敗就略過，其他照樣加。
        }
      }
      if (got.media.isNotEmpty && files.isEmpty) {
        throw const AuthorLinkException('no media');
      }
      final a = await _db.findAuthorByXUserId(got.author.userId);
      final pit = a == null ? null : await _db.latestPitOfAuthor(a.id);
      if (_disposed) {
        for (final f in files) {
          _delete(f);
        }
        return;
      }
      info = got;
      author = a;
      authorPitId = pit;
      paths
        ..clear()
        ..addAll(files);
      owned.addAll(files);
      status = TweetShareStatus.ready;
    } catch (_) {
      status = TweetShareStatus.failed;
    }
    _notify();
  }

  static String _ext(TweetMedia m) {
    final path = Uri.tryParse(m.url)?.path.toLowerCase() ?? '';
    if (m.isVideo) return path.endsWith('.gif') ? 'gif' : 'mp4';
    final fmt = Uri.tryParse(m.url)?.queryParameters['format'];
    if (fmt != null && RegExp(r'^[a-z]{3,4}$').hasMatch(fmt)) {
      return fmt == 'jpeg' ? 'jpg' : fmt;
    }
    for (final e in ['png', 'webp', 'gif', 'jpeg', 'jpg']) {
      if (path.endsWith('.$e')) return e == 'jpeg' ? 'jpg' : e;
    }
    return 'jpg';
  }

  void remove(String path) {
    paths.remove(path);
    if (owned.remove(path)) _delete(path);
    _notify();
  }

  void addAll(Iterable<String> more) {
    paths.addAll(more);
    _notify();
  }

  /// 刪掉還留著的下載暫存檔（取消，或已經匯入完）。
  void cleanUp() {
    for (final f in owned) {
      _delete(f);
    }
    owned.clear();
  }

  static void _delete(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
