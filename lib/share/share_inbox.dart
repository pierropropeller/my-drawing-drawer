import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/settings.dart';
import 'share_channel.dart';

/// 分享進來、還沒處理的批次（每批＝一次分享的圖片檔案路徑）。
///
/// 在 App 啟動時就建立（見 main.dart），所以冷啟動、熱啟動、或還在開頭畫面時
/// 收到的分享都會先排在這裡；進到主畫面後由 ShareHost 逐批取出。
class ShareInbox extends Notifier<List<List<String>>> {
  @override
  List<List<String>> build() {
    final channel = ref.read(shareChannelProvider);
    channel.setOnShare(_add);
    ref.onDispose(() => channel.setOnShare(null));
    unawaited(_loadInitial(channel));
    return const [];
  }

  Future<void> _loadInitial(ShareChannel channel) async {
    final paths = await channel.getInitialShare();
    if (paths.isNotEmpty && ref.mounted) _add(paths);
  }

  void _add(List<String> paths) {
    if (!ref.mounted) return;
    state = [...state, paths];
  }

  /// 取出最前面的一批；沒有就回傳 null。
  List<String>? take() {
    if (state.isEmpty) return null;
    final first = state.first;
    state = state.sublist(1);
    return first;
  }
}

final shareInboxProvider = NotifierProvider<ShareInbox, List<List<String>>>(
  ShareInbox.new,
);

/// 上一次分享用的坑與位置（SharedPreferences；沒有持久化時只記在記憶體）。
class ShareMemory {
  ShareMemory(this._prefs);
  final SharedPreferences? _prefs;

  String? _pit;
  String? _section;

  String? get lastPit => _prefs?.getString('shareLastPit') ?? _pit;
  String? get lastSection => _prefs?.getString('shareLastSection') ?? _section;

  void save({required String? pitId, required String section}) {
    _pit = pitId;
    _section = section;
    if (pitId != null) _prefs?.setString('shareLastPit', pitId);
    _prefs?.setString('shareLastSection', section);
  }
}

final shareMemoryProvider = Provider<ShareMemory>(
  (ref) => ShareMemory(ref.watch(sharedPrefsProvider)),
);
